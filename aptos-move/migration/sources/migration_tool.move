module migration::migration_tool {
    use std::object::{Self, Object, ExtendRef, TransferRef, DeleteRef};
    use std::string::{String, utf8 as str};
    use std::error;
    use std::signer;
    use aptos_token_objects::aptos_token::{Self as no_code_token};//, AptosCollection};
    //use aptos_token_objects::token::{Self as token_v2, Token as TokenObject};
    use aptos_token_objects::collection::{Self as collection_v2, Collection};//, CollectionObject};
    use aptos_token::token::{Self as token_v1, TokenId, Token as TokenV1};
    use migration::token_utils::{Self};
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


    /// Per collection + creator combo
    /// Stores the collection specific configuration details used in migration
    struct MigrationConfig has key {
        creator: address,
        collection_v2: Object<Collection>,
        collection_data_v1: token_utils::CollectionDataV1,
        extend_ref: ExtendRef,
        transfer_ref: TransferRef,
        delete_ref: DeleteRef,
    }

    struct TokenStore has key {
        inner: Table<TokenId, TokenV1>,
    }

    public entry fun create_migration_config_from_token(
        creator: &signer,
        collection_name: String,
        mutable_token_name: bool,
        tokens_freezable_by_creator: bool,
        token_name: String,
        keys: vector<String>,
    ) {
        let creator_address = signer::address_of(creator);
        let token_v1_data = token_utils::get_token_v1_data(creator_address, collection_name, token_name, keys);
        let token_mutability_config = token_utils::get_token_mutability_config(&token_v1_data);
        create_migration_config(
            creator,
            collection_name,
            token_v1::get_token_mutability_description(&token_mutability_config),
            token_v1::get_token_mutability_royalty(&token_mutability_config),
            mutable_token_name,
            token_utils::get_token_property_mutable(copy token_v1_data), // TODO: Verify this is the right field, i.e., not the one within token_mutability
            token_v1::get_token_mutability_uri(&token_mutability_config),
            token_utils::get_token_burnable_by_creator(copy token_v1_data),
            tokens_freezable_by_creator,
            token_utils::get_token_royalty_points_numerator(&token_v1_data),
            token_utils::get_token_royalty_points_denominator(&token_v1_data),
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
        let seed_str = std::string_utils::format2(&b"{}::{}", collection_name, str(MIGRATION_CONFIG));
        let constructor_ref = object::create_object_from_account(creator);
        let obj_address = object::address_from_constructor_ref(&constructor_ref);
        let obj_signer = object::generate_signer(&constructor_ref);

        let creator_address = signer::address_of(creator);
        let collection_data_v1 = token_utils::get_collection_v1_data(creator_address, collection_name);
        let full_seed_str = std::string_utils::format2(&b"{}::{}", creator_address, seed_str);
        package_manager::add_name(full_seed_str, obj_address);


        let collection_mutability_config = token_utils::get_collection_mutability_config(&collection_data_v1);
        no_code_token::create_collection(
            &obj_signer,
            token_utils::get_collection_description(&collection_data_v1),
            token_utils::get_collection_supply(&collection_data_v1),
            collection_name,
            token_utils::get_collection_uri(&collection_data_v1),
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
        let token_v1_data = token_utils::get_token_v1_data(creator_address, collection_name, token_name, keys);
        let token_id = token_utils::get_token_id(&token_v1_data);

        let owner_address = signer::address_of(owner);
        assert!(token_v1::balance_of(owner_address, token_id) == 1, error::permission_denied(ENOT_TOKEN_OWNER));

        let (values, types, _, _, _) = token_utils::view_property_map_values_and_types(owner_address, creator_address, collection_name, token_name, keys);
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
            token_utils::get_token_description(&token_v1_data),
            token_name,
            token_utils::get_token_uri(&token_v1_data),
            keys,
            types,
            bcs_serialized_values,
        );

        store_token(
            &obj_signer,
            token
        );

        let token_address = object::create_guid_object_address(config_obj_addr, token_creation_num);

        // this doesn't work becuase it's trying to transfer the config object
        // we want to transfer the no_code_token token, but idek how to get the address for it...?

        // OK so I tried create_guid_obj_address but......forgot that since the object itself is the creator, and i created with named object creation, i dont think it has a GUID._
        // very confusing and frustrating, will have to think about this from devex perspective.
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
    public fun token_balance(
        owner: address,
        creator_address: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
    ): u64 {
        let token_v1_data = token_utils::get_token_v1_data(creator_address, collection_name, token_name, keys);
        let token_id = token_utils::get_token_id(&token_v1_data);
        token_v1::balance_of(owner, token_id)
    }

}
