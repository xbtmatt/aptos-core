
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
