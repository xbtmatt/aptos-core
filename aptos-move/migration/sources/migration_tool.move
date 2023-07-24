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

    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    ///////////////////       TESTS        ///////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////

module migration::unit_tests {
    #[test_only]
    use std::signer;
    #[test_only]
    use aptos_framework::account;
    #[test_only]
    use aptos_framework::timestamp;
    #[test_only]
    use migration::migration_tool;
    #[test_only]
    use migration::token_v1_utils;
    #[test_only]
    use migration::package_manager;
    #[test_only]
    use aptos_token::token::{Self as token_v1};
    #[test_only]
    use std::string::{String, utf8 as str};
    #[test_only]
    use std::bcs;
    #[test_only]
    use std::object;
    #[test_only]
    use std::option;
    #[test_only]
    use aptos_token_objects::aptos_token::{AptosToken, Self as no_code_token};
    #[test_only]
    use aptos_token_objects::token::{Self as token_v2};
    #[test_only]
    use aptos_token_objects::collection::{Self as collection_v2};
    #[test_only]
    use aptos_token_objects::royalty;

    const COLLECTION_NAME: vector<u8> = b"Jumpy Jackrabbits";
    const COLLECTION_DESCRIPTION: vector<u8> = b"A collection of jumpy jackrabbits!";
    const COLLECTION_URI: vector<u8> = b"https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Jackrabbit2_crop.JPG";
    const TOKEN_URI: vector<u8> = b"https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Juvenile_Black-tailed_Jackrabbit_Eating.jpg";
    const TOKEN_NAME: vector<u8> = b"Jumpy Jackrabbit #1";
    const MAXIMUM_SUPPLY: u64 = 1000;
    const MUTABLE_TOKEN_NAME: bool = true;
    const TOKENS_FREEZABLE_BY_CREATOR: bool = true;
    const TOKEN_MUTABILITY_CONFIG: vector<bool> = vector<bool>[false, true, false, true, false];
    const COLLECTION_MUTABILITY_CONFIG: vector<bool> = vector<bool>[true, false, true];

    #[test_only]
    fun get_property_map_keys(): vector<String> {
        vector<String> [ str(b"key 1"),
                         str(b"key 2"),
                         str(b"key 3") ]
    }
    #[test_only]
    fun get_property_map_values(): vector<vector<u8>> {
        vector<vector<u8>> [ bcs::to_bytes(&str(b"value 1")),
                             bcs::to_bytes(&str(b"value 2")),
                             bcs::to_bytes(&str(b"value 3")) ]
    }
    #[test_only]
    fun get_property_map_types(): vector<String> {
        vector<String> [ str(b"0x1::string::String"),
                         str(b"0x1::string::String"),
                         str(b"0x1::string::String") ]
    }

    #[test_only]
    fun setup_test(
        creator: &signer,
        resource_account: &signer,
        migrator: &signer,
        aptos_framework: &signer,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        account::create_account_for_test(signer::address_of(creator));
        account::create_account_for_test(signer::address_of(migrator));
        aptos_std::resource_account::create_resource_account(creator, vector<u8>[], vector<u8>[]);
        package_manager::init_module_for_test(resource_account);

        token_v1::create_collection_script(
            creator,
            str(COLLECTION_NAME),
            str(COLLECTION_DESCRIPTION),
            str(COLLECTION_URI),
            MAXIMUM_SUPPLY,
            COLLECTION_MUTABILITY_CONFIG,
        );
    }

    #[test_only]
    fun mint_v1_token_to(
        creator: &signer,
        receiver: &signer,
    ) {
        let collection_name = str(COLLECTION_NAME);
        let token_name = str(TOKEN_NAME);
        token_v1::create_token_script(
            creator,
            collection_name,
            token_name,
            str(COLLECTION_DESCRIPTION),
            1,
            1,
            str(b""),
            signer::address_of(creator),
            10,
            1,
            TOKEN_MUTABILITY_CONFIG,
            get_property_map_keys(),
            get_property_map_values(),
            get_property_map_types(),
        );

        let creator_address = signer::address_of(creator);
        let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = token_v1_utils::assert_and_create_nft_token_id(creator_address, token_data_id);
        token_v1::direct_transfer(creator, receiver, token_id, 1);
    }

    #[test(creator = @deployer, resource_account = @migration, migrator = @0xbeefcafe, aptos_framework = @0x1)]
    fun test_happy_path_from_token_config(
        creator: &signer,
        resource_account: &signer,
        migrator: &signer,
        aptos_framework: &signer,
    ) {
        setup_test(
            creator,
            resource_account,
            migrator,
            aptos_framework
        );
        mint_v1_token_to(creator, migrator);
        let creator_address = signer::address_of(creator);
        let migrator_address = signer::address_of(migrator);
        // for use at the end of this function
        let token_v1_data = token_v1_utils::get_token_v1_data(
            creator_address,
            migrator_address,
            str(COLLECTION_NAME),
            str(TOKEN_NAME),
            get_property_map_keys(),
        );

        let collection_v1_data = &token_v1_utils::get_collection_v1_data(
            creator_address,
            str(COLLECTION_NAME),
        );

        let coll_mut_config = token_v1::get_collection_mutability_config(creator_address, str(COLLECTION_NAME));
        let collection_mutability_uri = token_v1::get_collection_mutability_uri(&coll_mut_config);
        let _collection_mutability_maximum = token_v1::get_collection_mutability_maximum(&coll_mut_config);
        let collection_mutability_description = token_v1::get_collection_mutability_description(&coll_mut_config);

        let token_data_id = token_v1::create_token_data_id(creator_address, str(COLLECTION_NAME), str(TOKEN_NAME));
        let token_mut_config = token_v1::get_tokendata_mutability_config(token_data_id);
        let _token_mutability_maximum = token_v1::get_token_mutability_maximum(&token_mut_config);
        let token_mutability_royalty = token_v1::get_token_mutability_royalty(&token_mut_config);
        let token_mutability_uri = token_v1::get_token_mutability_uri(&token_mut_config);
        let token_mutability_description = token_v1::get_token_mutability_description(&token_mut_config);
        let token_mutability_default_properties = token_v1::get_token_mutability_default_properties(&token_mut_config);

        migration_tool::upsert_collection_config(
            creator,
            str(COLLECTION_NAME),
            token_v1_utils::get_collection_description(collection_v1_data),
            token_v1_utils::get_collection_uri(collection_v1_data),
            collection_mutability_description,
            token_mutability_royalty,           // collection wide mutable royalties from 1 token data
            collection_mutability_uri,
            token_mutability_description,
            MUTABLE_TOKEN_NAME,
            token_mutability_default_properties,
            token_mutability_uri,
            token_v1_utils::get_token_burnable_by_creator(token_v1_data),
            TOKENS_FREEZABLE_BY_CREATOR,
            token_v1_utils::get_token_royalty_points_numerator(&token_v1_data),
            token_v1_utils::get_token_royalty_points_denominator(&token_v1_data),
        );
        
        // create the migration config
        migration_tool::create_collection_and_enable_migration(creator, str(COLLECTION_NAME));

        migration_tool::migrate_v1_to_v2(
            migrator,
            creator_address,
            str(COLLECTION_NAME),
            str(TOKEN_NAME),
            get_property_map_keys(),
        );

        assert!(migration_tool::token_in_token_store(
            creator_address,
            str(COLLECTION_NAME),
            str(TOKEN_NAME),
        ), 0);

        assert!(migration_tool::tokens_migrated(
            creator_address,
            str(COLLECTION_NAME),
        ) == 1, 0);

        let token_object_address = migration_tool::get_v2_token_address_from_name(
            creator_address,
            str(COLLECTION_NAME),
            str(TOKEN_NAME)
        );

        let token_obj = object::address_to_object<AptosToken>(token_object_address);
        assert!(object::is_owner(token_obj, migrator_address), 1);

        let collection_obj = token_v2::collection_object(token_obj);

        let v2_mutable_collection_description = no_code_token::is_mutable_collection_description(collection_obj);
        let v2_mutable_collection_royalty = no_code_token::is_mutable_collection_royalty(collection_obj);
        let v2_mutable_collection_uri = no_code_token::is_mutable_collection_uri(collection_obj);
        let v2_mutable_token_description = no_code_token::is_mutable_description(token_obj);
        let v2_mutable_token_name = no_code_token::is_mutable_name(token_obj);
        let v2_mutable_token_properties = no_code_token::are_properties_mutable(token_obj);
        let v2_mutable_token_uri = no_code_token::is_mutable_uri(token_obj);
        let v2_tokens_burnable_by_creator = no_code_token::are_collection_tokens_burnable(collection_obj);
        let v2_token_is_burnable = no_code_token::is_burnable(token_obj);
        
        let v2_tokens_freezable_by_creator = no_code_token::is_freezable_by_creator(token_obj);

        let token_mut_config = token_v1::create_token_mutability_config(&TOKEN_MUTABILITY_CONFIG);
        assert!(coll_mut_config == token_v1::get_collection_mutability_config(creator_address, str(COLLECTION_NAME)), 2);
        let token_data_id = token_v1::create_token_data_id(creator_address, str(COLLECTION_NAME), str(TOKEN_NAME));
        assert!(token_mut_config == token_v1::get_tokendata_mutability_config(token_data_id), 3);
        let _token_mutability_maximum = token_v1::get_token_mutability_maximum(&token_mut_config);
        let token_mutability_royalty = token_v1::get_token_mutability_royalty(&token_mut_config);
        let token_mutability_uri = token_v1::get_token_mutability_uri(&token_mut_config);
        let token_mutability_description = token_v1::get_token_mutability_description(&token_mut_config);
        let token_mutability_default_properties = token_v1::get_token_mutability_default_properties(&token_mut_config);

        assert!(v2_mutable_collection_description == collection_mutability_description, 1);
        assert!(v2_mutable_collection_uri == collection_mutability_uri, 2);
        assert!(v2_mutable_token_description == token_mutability_description, 3);
        assert!(v2_mutable_token_name == MUTABLE_TOKEN_NAME, 4);
        assert!(v2_tokens_burnable_by_creator == token_v1_utils::get_token_burnable_by_creator(token_v1_data), 5);
        assert!(v2_tokens_freezable_by_creator == TOKENS_FREEZABLE_BY_CREATOR, 6);
        assert!(v2_token_is_burnable == token_v1_utils::get_token_burnable_by_creator(token_v1_data), 7);
        assert!(v2_mutable_token_properties == token_mutability_default_properties, 8);
        assert!(v2_mutable_token_uri == token_mutability_uri, 9);

        let _royalty_payee_address = token_v1_utils::get_token_royalty_payee_address(&token_v1_data);
        let royalty_numerator = token_v1_utils::get_token_royalty_points_numerator(&token_v1_data);
        let royalty_denominator = token_v1_utils::get_token_royalty_points_denominator(&token_v1_data);
        let royalty = option::extract(&mut aptos_token_objects::royalty::get(collection_obj));
        // can't set royalties receiver in no_code_token
        //assert!(royalty_payee_address == royalty::payee_address(&royalty), 10);
        assert!(royalty_numerator == royalty::numerator(&royalty), 11);
        assert!(royalty_denominator == royalty::denominator(&royalty), 12);

        let collection_description = token_v1_utils::get_collection_description(collection_v1_data);
        let collection_name = token_v1_utils::get_collection_name(collection_v1_data);
        let collection_uri = token_v1_utils::get_collection_uri(collection_v1_data);
        let _collection_maximum = token_v1_utils::get_collection_maximum(collection_v1_data);
        assert!(collection_v2::description(collection_obj) == collection_description, 13);
        assert!(collection_v2::name(collection_obj) == collection_name, 14);
        assert!(collection_v2::uri(collection_obj) == collection_uri, 15);

         // No collection_v2 maximum getter yet.
        //assert!(collection_v2::maximum(collection_obj) == collection_maximum, 16);

        // based off token since we created migration script with token
        // this would change if we did full migration config initialization (not using token, have to specify alll args)
        assert!(v2_mutable_collection_royalty == token_mutability_royalty, 17);

        migration_tool::withdraw_balance<aptos_framework::aptos_coin::AptosCoin>(creator, str(COLLECTION_NAME));
    }
}
