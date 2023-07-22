module migration::migration_tool {
    use std::object::{Self, Object, ExtendRef, TransferRef, DeleteRef};
    use std::string::{Self, String, utf8 as str};
    use std::error;
    use std::signer;
    use aptos_token_objects::aptos_token::{Self as no_code_token};
    //use aptos_token_objects::token::{Self as token_v2, Token as TokenObject};
    use aptos_token_objects::collection::{Self as collection_v2, Collection};//, CollectionObject};
    use aptos_token::token::{Self as token_v1};
    use migration::token_utils::{Self};
    use migration::package_manager::{Self};

    /// There is no migration config at the given address.
    const ECONFIG_NOT_FOUND: u64 = 0;

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
        let constructor_ref = object::create_named_object(creator, *string::bytes(&seed_str));
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

        let collection_object_address = collection_v2::create_collection_address(&creator_address, &collection_name);

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
    }

    #[view]
    public fun get_migration_signer_from_creator(
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
    public inline fun get_seed_str(
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

}
