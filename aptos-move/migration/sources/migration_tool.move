module migration::migration_tool {
    use std::object::{Self, Object, ExtendRef, TransferRef, DeleteRef};
    use std::string::{String, utf8 as str};
    use std::error;
    use std::signer;
    use aptos_token_objects::aptos_token::{Self as no_code_token};//, AptosCollection};
    //use aptos_token_objects::token::{Self as token_v2, Token as TokenObject};
    use aptos_token_objects::collection::{Self as collection_v2, Collection};//, CollectionObject};
    use aptos_token::token::{Self as token_v1, TokenId, Token as TokenV1};
    use migration::token_v1_utils::{Self};
    use migration::package_manager::{Self};
    use std::table::{Self, Table};
    use std::vector;

    /// There is no migration config at the given address.
    const ECONFIG_NOT_FOUND: u64 = 0;
    /// You are not the owner of the token.
    const ENOT_TOKEN_OWNER: u64 = 1;
    /// The token store does not exist.
    const ETOKEN_STORE_DOES_NOT_EXIST: u64 = 2;

    const MIGRATION_CONFIG: vector<u8> = b"migration_config";

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    /// Per collection + creator combo
    /// Stores the collection specific configuration details used in migration
    struct MigrationConfig has key {
        creator: address,
        collection_v2: Object<Collection>,
        collection_data_v1: token_v1_utils::CollectionDataV1,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef,
        delete_ref: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TokenStore has key {
        inner: Table<TokenId, TokenV1>,
    }

    public entry fun create_migration_config_from_token(
        creator: &signer,
        collection_name: String,
        mutable_token_name: bool,
        tokens_freezable_by_creator: bool,
        token_name: String,
        owner_address: address,
        keys: vector<String>,
    ) {
        let creator_address = signer::address_of(creator);
        let token_v1_data = token_v1_utils::get_token_v1_data(
            creator_address,
            owner_address,
            collection_name,
            token_name,
            keys
        );
        let token_mutability_config = token_v1_utils::get_token_mutability_config(&token_v1_data);
        create_migration_config(
            creator,
            collection_name,
            token_v1::get_token_mutability_description(&token_mutability_config),
            token_v1::get_token_mutability_royalty(&token_mutability_config),
            mutable_token_name,
            token_v1_utils::get_token_property_mutable(copy token_v1_data), // TODO: Verify this is the right field, i.e., not the one within token_mutability
            token_v1::get_token_mutability_uri(&token_mutability_config),
            token_v1_utils::get_token_burnable_by_creator(copy token_v1_data),
            tokens_freezable_by_creator,
            token_v1_utils::get_token_royalty_points_numerator(&token_v1_data),
            token_v1_utils::get_token_royalty_points_denominator(&token_v1_data),
        );
    }

    public entry fun create_migration_config(
        creator: &signer,
        collection_name: String,
        mutable_token_description: bool,
        mutable_royalty: bool,             // collection wide
        mutable_token_name: bool,
        mutable_token_properties: bool,
        mutable_token_uri: bool,
        tokens_burnable_by_creator: bool,
        tokens_freezable_by_creator: bool,
        royalty_numerator: u64,            // collection wide
        royalty_denominator: u64,          // collection wide
    ) {
        let constructor_ref = object::create_object_from_account(creator);
        let obj_address = object::address_from_constructor_ref(&constructor_ref);
        std::aptos_account::create_account(obj_address);
        let obj_signer = object::generate_signer(&constructor_ref);

        let creator_address = signer::address_of(creator);
        let collection_data_v1 = token_v1_utils::get_collection_v1_data(creator_address, collection_name);
        package_manager::add_name(
            get_seed_str(creator_address, collection_name),
            obj_address
        );

        let collection_mutability_config = token_v1_utils::get_collection_mutability_config(&collection_data_v1);
        no_code_token::create_collection(
            &obj_signer,
            token_v1_utils::get_collection_description(&collection_data_v1),
            token_v1_utils::get_collection_supply(&collection_data_v1),
            collection_name,
            token_v1_utils::get_collection_uri(&collection_data_v1),
            token_v1::get_collection_mutability_description(&collection_mutability_config),
            mutable_royalty,
            token_v1::get_collection_mutability_uri(&collection_mutability_config),
            mutable_token_description,
            mutable_token_name,
            mutable_token_properties,
            mutable_token_uri,
            tokens_burnable_by_creator,
            tokens_freezable_by_creator,
            royalty_numerator,
            royalty_denominator,
        );

        let collection_object_address = collection_v2::create_collection_address(&obj_address, &collection_name);

        move_to(
            &obj_signer,
            MigrationConfig {
                creator: creator_address,
                collection_v2: object::address_to_object<Collection>(collection_object_address),
                collection_data_v1,
                extend_ref: object::generate_extend_ref(&constructor_ref),
                transfer_ref: object::generate_transfer_ref(&constructor_ref),
                delete_ref: object::generate_delete_ref(&constructor_ref),
            },
        );

        move_to(
            &obj_signer,
            TokenStore {
                inner: table::new<TokenId, TokenV1>(),
            }
        )
    }

    fun get_migration_signer_from_creator(
        creator: &signer,
        collection_name: String,
    ): signer acquires MigrationConfig {
        let obj = get_config_address(signer::address_of(creator), collection_name);
        internal_get_migration_signer(obj)
    }

    #[view]
    public fun get_config_address(
        creator: address,
        collection_name: String,
    ): address {
        let seed_str = get_seed_str(creator, collection_name);
        let obj_addr = package_manager::get_name(seed_str);
        assert!(exists<MigrationConfig>(obj_addr), error::not_found(ECONFIG_NOT_FOUND));
        obj_addr
    }

    #[view]
    public fun get_seed_str(
        creator: address,
        collection_name: String,
    ): String {
        let seed_str = std::string_utils::format2(&b"{}::{}", collection_name, str(MIGRATION_CONFIG));
        std::string_utils::format2(&b"{}::{}", creator, seed_str)
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

        let config_obj_addr = get_config_address(creator_address, collection_name);
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
        table::add(&mut token_store.inner, token_v1::get_token_id(&token), token);
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
    public fun get_v2_address_from_name(
        creator_address: address,
        collection_name: String,
        token_name: String,
    ): address {
        let name = create_token_lookup_string(creator_address, collection_name, token_name);
        package_manager::get_name(name)
    }

    #[view]
    public fun token_balance(
        owner_address: address,
        creator_address: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
    ): u64 {
        let token_v1_data = token_v1_utils::get_token_v1_data(
            owner_address,
            creator_address,
            collection_name,
            token_name,
            keys
        );
        let token_id = token_v1_utils::get_token_id(&token_v1_data);
        token_v1::balance_of(owner_address, token_id)
    }

    #[view]
    public fun token_in_token_store(
        creator_address: address,
        collection_name: String,
        token_name: String,
    ): bool acquires TokenStore {
        let config_addr = get_config_address(creator_address, collection_name);
        assert!(exists<TokenStore>(config_addr), error::invalid_state(ETOKEN_STORE_DOES_NOT_EXIST));
        let token_store = borrow_global_mut<TokenStore>(config_addr);
        let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = token_v1_utils::assert_and_create_nft_token_id(creator_address, token_data_id);
        table::contains(&token_store.inner, token_id)
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
    use aptos_token_objects::aptos_token::{AptosToken};

    const COLLECTION_NAME: vector<u8> = b"Jumpy Jackrabbits";
    const COLLECTION_DESCRIPTION: vector<u8> = b"A collection of jumpy jackrabbits!";
    const COLLECTION_URI: vector<u8> = b"https://upload.wikimedia.org/wikipedia/commons/thumb/6/6d/Jackrabbit2_crop.JPG";
    const TOKEN_URI: vector<u8> = b"https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Juvenile_Black-tailed_Jackrabbit_Eating.jpg";
    const TOKEN_NAME: vector<u8> = b"Jumpy Jackrabbit #1";
    const MAXIMUM_SUPPLY: u64 = 1000;

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
            vector<bool> [true, true, true],
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
            vector<bool> [true, true, true, true, true],
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
    fun test_happy_path(
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
        let migrator_address = signer::address_of(migrator);
        
        // create the migration config
        migration_tool::create_migration_config_from_token(
            creator,
            str(COLLECTION_NAME),
            true,
            true,
            str(TOKEN_NAME),
            migrator_address,
            get_property_map_keys(),
        );

        let creator_address = signer::address_of(creator);
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

        let token_object_address = migration_tool::get_v2_address_from_name(
            creator_address,
            str(COLLECTION_NAME),
            str(TOKEN_NAME)
        );

        let token_obj = object::address_to_object<AptosToken>(token_object_address);
        assert!(object::is_owner(token_obj, migrator_address), 1);
    }
}
