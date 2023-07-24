module migration::migration_tool {
    use std::object::{Self, ConstructorRef, ExtendRef, TransferRef, DeleteRef};
    use std::string::{String, utf8 as str};
    use std::error;
    use std::signer;
    use std::option::{Self, Option};
    use aptos_token_objects::aptos_token::{Self as no_code_token};//, AptosCollection};
    use aptos_token_objects::collection::{Self as collection_v2};//, CollectionObject};
    use aptos_token::token::{Self as token_v1, TokenId, Token as TokenV1};
    use migration::token_v1_utils::{Self};
    use migration::package_manager::{Self};
    use aptos_std::smart_table::{Self, SmartTable};
    use std::vector;

    /// There is no migration config at the given address.
    const ECONFIG_NOT_FOUND: u64 = 0;
    /// You are not the owner of the token.
    const ENOT_TOKEN_OWNER: u64 = 1;
    /// The token store does not exist.
    const ETOKEN_STORE_DOES_NOT_EXIST: u64 = 2;
    /// The given signer is not the owner of the collection.
    const ENOT_COLLECTION_OWNER: u64 = 3;
    /// The migration is already enabled.
    const EMIGRATION_ENABLED: u64 = 4;
    /// The migration has not been enabled yet.
    const EMIGRATION_NOT_ENABLED: u64 = 5;
    /// The migration has started already.
    const EMIGRATION_STARTED: u64 = 6;
    /// The collection must exist to enable the migration.
    const ECOLLECTION_DOES_NOT_EXIST_FOR_MIGRATION: u64 = 7;
    /// The collection already exists; changes can no longer be made to the migration config.
    const ECOLLECTION_EXISTS: u64 = 8;
    /// The collection already exists; changes can no longer be made to the migration config.
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 9;
    /// The sender is not the creator of the collection.
    const ENOT_CREATOR: u64 = 10;
    /// The specified original collection does not exist.
    const ECOLLECTION_V1_DOES_NOT_EXIST: u64 = 11;

    const MIGRATION_CONFIG: vector<u8> = b"migration_config";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Per collection + creator combo
    /// Stores the collection specific configuration details used in migration
    struct MigrationConfig has key {
        creator_address: address,
        collection_v2_address: Option<address>,
        collection_config: CollectionConfig,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef,
        delete_ref: DeleteRef,
        enabled: bool,
    }

    struct CollectionConfig has copy, drop, store {
        creator_address: address,
        name: String,
        description: String,
        max_supply: u64,
        uri: String,
        mutable_collection_description: bool,
        mutable_collection_royalty: bool,
        mutable_collection_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        royalty_numerator: u64,
        royalty_denominator: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Separate from MigrationConfig because deleting it has different constraints
    struct TokenStore has key {
        inner: SmartTable<TokenId, TokenV1>,
    }

    fun create_migration_object(
        creator: &signer,
        collection_name: String,
    ): ConstructorRef {
        let constructor_ref = object::create_object_from_account(creator);
        let config_obj_addr = object::address_from_constructor_ref(&constructor_ref);
        std::aptos_account::create_account(config_obj_addr);

        package_manager::add_name(
            get_seed_str(signer::address_of(creator), collection_name),
            config_obj_addr
        );

        constructor_ref
    }

    /// This function creates a migration config based on the former collection being used.
    /// The characteristics it takes from the former collection that cannot be altered:
    ///     - Collection name
    ///     - Collection supply
    /// Everything else can be configured from the client by querying the former collection
    /// details with view functions in the `token_v1_utils.move` module.
    public entry fun upsert_collection_config(
        creator: &signer,
        collection_name: String,
        collection_description: String,
        //max_supply: u64,
        collection_uri: String,
        mutable_collection_description: bool,
        mutable_collection_royalty: bool,
        mutable_collection_uri: bool,
        mutable_token_description: bool,
        mutable_token_name: bool,               // new v2 field
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,      // new v2 field
        royalty_numerator: u64,
        royalty_denominator: u64,
    ) acquires MigrationConfig, TokenStore {
        let creator_address = signer::address_of(creator);
        assert!(token_v1::check_collection_exists(creator_address, collection_name), error::invalid_argument(ECOLLECTION_V1_DOES_NOT_EXIST));
        let max_supply = std::option::extract(&mut token_v1::get_collection_supply(creator_address, collection_name));

        let collection_config = CollectionConfig {
            creator_address,
            name: collection_name,
            description: collection_description,
            max_supply,
            uri: collection_uri,
            mutable_collection_description,
            mutable_collection_royalty,
            mutable_collection_uri,
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
            royalty_numerator,
            royalty_denominator,
        };

        if (config_exists(creator_address, collection_name)) {
            let config_obj_addr = config_addr(creator_address, collection_name);
            // ensure collection does not already exist, because we cannot
            // change the config after it is created
            assert!(!collection_object_exists(creator_address, collection_name),
                error::invalid_state(ECOLLECTION_EXISTS));
            // ensure migration has not started, should be redundant because migration
            // can't be enabled unless collection exists
            assert!(!migration_enabled(creator_address, collection_name),
                error::invalid_state(EMIGRATION_ENABLED));
            // sanity check to ensure TokenStore table has no length, would mean migration has started
            assert!(tokens_migrated(creator_address, collection_name) == 0, error::invalid_state(EMIGRATION_STARTED));
            let migration_config = borrow_global_mut<MigrationConfig>(config_obj_addr);
            migration_config.collection_config = collection_config;
        } else {
            let constructor_ref = create_migration_object(creator, collection_name);
            let obj_signer = object::generate_signer(&constructor_ref);
            move_to(
                &obj_signer,
                MigrationConfig {
                    creator_address,
                    collection_v2_address: option::none<address>(),
                    collection_config,
                    extend_ref: object::generate_extend_ref(&constructor_ref),
                    transfer_ref: object::generate_transfer_ref(&constructor_ref),
                    delete_ref: object::generate_delete_ref(&constructor_ref),
                    enabled: false,
                }
            );

            move_to(
                &obj_signer,
                TokenStore {
                    inner: smart_table::new<TokenId, TokenV1>(),
                }
            );
        };
    }

    /// This function uses the existing collection config to create a migration config
    /// and creates the collection.
    /// The created v2 collection cannot be burned or destroyed; be considerate of this.
    public entry fun create_collection_and_enable_migration(
        creator: &signer,
        collection_name: String,
    ) acquires MigrationConfig {
        let creator_address = signer::address_of(creator);
        assert!(!collection_object_exists(creator_address, collection_name), error::invalid_state(ECOLLECTION_DOES_NOT_EXIST_FOR_MIGRATION));

        let config_obj_addr = config_addr(creator_address, collection_name);
        let collection_config = borrow_global<MigrationConfig>(config_obj_addr).collection_config;

        let obj_signer = internal_get_migration_signer(config_obj_addr);

        no_code_token::create_collection(
            &obj_signer,            
            collection_config.description,
            collection_config.max_supply,
            collection_config.name,
            collection_config.uri,
            collection_config.mutable_collection_description,
            collection_config.mutable_collection_royalty,
            collection_config.mutable_collection_uri,
            collection_config.mutable_token_description,
            collection_config.mutable_token_name,
            collection_config.mutable_token_properties,
            collection_config.mutable_token_uri,
            collection_config.tokens_burnable_by_creator,
            collection_config.tokens_freezable_by_creator,
            collection_config.royalty_numerator,
            collection_config.royalty_denominator,
        );

        let generated_collection_address =
            collection_v2::create_collection_address(&config_addr(creator_address, collection_name), &collection_name);
        let collection_v2_address = &mut (borrow_global_mut<MigrationConfig>(config_obj_addr).collection_v2_address);
        option::fill(collection_v2_address, generated_collection_address);
        enable_migration(creator, collection_name);
    }

    /// The creator can only call this if the v2 collection exists.
    public entry fun enable_migration(
        creator: &signer,
        collection_name: String,
    ) acquires MigrationConfig {
        let creator_address = signer::address_of(creator);
        let config_obj_addr = config_addr(creator_address, collection_name);
        assert!(collection_object_exists(creator_address, collection_name), error::invalid_state(ECOLLECTION_DOES_NOT_EXIST_FOR_MIGRATION));
        borrow_global_mut<MigrationConfig>(config_obj_addr).enabled = true;
    }

    /// Emergency disable in case something goes wrong and the creator needs to stop migration.
    public entry fun disable_migration(
        creator: &signer,
        collection_name: String,
    ) acquires MigrationConfig {
        let config_obj_addr = config_addr(signer::address_of(creator), collection_name);
        borrow_global_mut<MigrationConfig>(config_obj_addr).enabled = false;
    }

    inline fun migration_enabled(
        creator_address: address,
        collection_name: String,
    ): bool {
        let config_obj_addr = config_addr(creator_address, collection_name);
        borrow_global<MigrationConfig>(config_obj_addr).enabled
    }

    public entry fun withdraw_aptos_coin(
        creator: &signer,
        collection_name: String,
    ) acquires MigrationConfig {
        withdraw_balance<aptos_std::aptos_coin::AptosCoin>(creator, collection_name);
    }

    public entry fun withdraw_balance<CoinType>(
        creator: &signer,
        collection_name: String,
    ) acquires MigrationConfig {
        let obj_signer = get_migration_signer(creator, collection_name);
        let amount = aptos_std::coin::balance<CoinType>(signer::address_of(&obj_signer));
        aptos_std::aptos_account::transfer_coins<CoinType>(&obj_signer, signer::address_of(creator), amount);
    }

    public fun get_migration_signer(
        creator: &signer,
        collection_name: String,
    ): signer acquires MigrationConfig {
        let config_obj_addr = config_addr(signer::address_of(creator), collection_name);
        let config_obj = object::address_to_object<MigrationConfig>(config_obj_addr);
        assert!(object::is_owner(config_obj, signer::address_of(creator)), error::permission_denied(ENOT_COLLECTION_OWNER));
        internal_get_migration_signer(config_obj_addr)
    }

    #[view]
    public fun config_exists(
        creator_address: address,
        collection_name: String,
    ): bool {
        package_manager::name_exists(get_seed_str(creator_address, collection_name))
    }

    #[view]
    public fun collection_object_exists(
        creator_address: address,
        collection_name: String,
    ): bool acquires MigrationConfig {
        let collection_addr_option = get_collection_address(creator_address, collection_name);
        if (option::is_some(&collection_addr_option)) {
            object::is_object(*option::borrow<address>(&collection_addr_option))
        } else {
            false
        }
    }

    #[view]
    public fun tokens_migrated(
        creator_address: address,
        collection_name: String,
    ): u64 acquires TokenStore {
        let config_obj_addr = config_addr(creator_address, collection_name);
        aptos_std::smart_table::length(&borrow_global<TokenStore>(config_obj_addr).inner)
    }

    #[view]
    public fun get_collection_address(
        creator_address: address,
        collection_name: String,
    ): Option<address> acquires MigrationConfig {
        let config_obj_addr = config_addr(creator_address, collection_name);
        borrow_global<MigrationConfig>(config_obj_addr).collection_v2_address
    }

    #[view]
    public fun get_config_address(
        creator_address: address,
        collection_name: String,
    ): address {
        config_addr(creator_address, collection_name)
    }

    inline fun config_addr(
        creator_address: address,
        collection_name: String,
    ): address {
        let seed_str = get_seed_str(creator_address, collection_name);
        let obj_addr = package_manager::get_name(seed_str);
        assert!(exists<MigrationConfig>(obj_addr), error::not_found(ECONFIG_NOT_FOUND));
        obj_addr
    }

    #[view]
    public fun get_seed_str(
        creator_address: address,
        collection_name: String,
    ): String {
        let seed_str = std::string_utils::format2(&b"{}::{}", collection_name, str(MIGRATION_CONFIG));
        std::string_utils::format2(&b"{}::{}", creator_address, seed_str)
    }

    inline fun internal_get_migration_signer(
        obj_addr: address,
    ): signer acquires MigrationConfig {
        assert!(exists<MigrationConfig>(obj_addr), error::not_found(ECONFIG_NOT_FOUND));
        object::generate_signer_for_extending(&borrow_global<MigrationConfig>(obj_addr).extend_ref)
    }

    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    ///////////////////   SWAP FUNCTIONS   ///////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////

    public entry fun migrate_v1_to_v2(
        owner: &signer,
        creator_address: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
    ) acquires MigrationConfig, TokenStore {
        let owner_address = signer::address_of(owner);
        let token_v1_data = token_v1_utils::get_token_v1_data(
            creator_address,
            owner_address,
            collection_name,
            token_name,
            keys
        );
        let token_id = token_v1_utils::get_token_id(&token_v1_data);

        assert!(token_v1::balance_of(owner_address, token_id) == 1, error::permission_denied(ENOT_TOKEN_OWNER));

        let (values, types, _, _, _) = token_v1_utils::view_property_map_values_and_types(owner_address, creator_address, collection_name, token_name, keys);
        let token = token_v1::withdraw_token(owner, token_id, 1);

        let config_obj_addr = config_addr(creator_address, collection_name);
        assert!(borrow_global<MigrationConfig>(config_obj_addr).enabled, error::invalid_state(EMIGRATION_NOT_ENABLED));
        let obj_signer = internal_get_migration_signer(config_obj_addr);

        let bcs_serialized_values: vector<vector<u8>> = vector::map(values, |value| {
            std::bcs::to_bytes(&value)
        });

        let token_creation_num = std::account::get_guid_next_creation_num(config_obj_addr);
        no_code_token::mint(
            &obj_signer,
            collection_name,
            token_v1_utils::get_token_description(&token_v1_data),
            token_name,
            token_v1_utils::get_token_uri(&token_v1_data),
            keys,
            types,
            bcs_serialized_values,
        );

        store_token(
            &obj_signer,
            token
        );

        let token_address = object::create_guid_object_address(config_obj_addr, token_creation_num);
        let name_for_token_lookup = create_token_lookup_string(creator_address, collection_name, token_name);
        package_manager::add_name(name_for_token_lookup, token_address);

        object::transfer_call(&obj_signer, token_address, owner_address);
    }

    fun store_token(
        obj_signer: &signer,
        token: TokenV1,
    ) acquires TokenStore {
        let obj_addr = signer::address_of(obj_signer);
        assert!(exists<TokenStore>(obj_addr), error::invalid_state(ETOKEN_STORE_DOES_NOT_EXIST));
        let token_store = borrow_global_mut<TokenStore>(obj_addr);
        smart_table::add(&mut token_store.inner, token_v1::get_token_id(&token), token);
    }

    #[view]
    public fun create_token_lookup_string(
        creator_address: address,
        collection_name: String,
        token_name: String,
    ): String {
        std::string_utils::format3(&b"{}::{}::{}", creator_address, token_name, collection_name)
    }

    #[view]
    /// Since we create tokens with account GUID it's difficult to retrieve them, so we store
    /// the token addresses in package_manager and retrieve them from there.
    public fun get_v2_token_address_from_name(
        creator_address: address,
        collection_name: String,
        token_name: String,
    ): address {
        let name = create_token_lookup_string(creator_address, collection_name, token_name);
        package_manager::get_name(name)
    }

    #[view]
    public fun token_in_token_store(
        creator_address: address,
        collection_name: String,
        token_name: String,
    ): bool acquires TokenStore {
        let config_addr = config_addr(creator_address, collection_name);
        assert!(exists<TokenStore>(config_addr), error::invalid_state(ETOKEN_STORE_DOES_NOT_EXIST));
        let token_store = borrow_global_mut<TokenStore>(config_addr);
        let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = token_v1_utils::assert_and_create_nft_token_id(creator_address, token_data_id);
        smart_table::contains(&token_store.inner, token_id)
    }
}
