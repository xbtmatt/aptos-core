module migration::token_utils {
    use aptos_token::token::{Self as token_v1, TokenDataId, TokenId, TokenMutabilityConfig, CollectionMutabilityConfig};
    use aptos_token::property_map::{Self, PropertyMap};
    use std::string::{String, utf8 as str};
    use std::option::{Self, Option};
    use std::vector;
    use std::error;

    /// The token provided is fungible because it has a supply greater than 1.
    const ETOKEN_IS_FUNGIBLE: u64 = 0;
    /// The number of keys in the property map does not match the number of keys passed in.
    const ENUM_KEYS_INCORRECT: u64 = 1;
    /// One of the keys passed in does not exist in the property map.
    const EKEY_NOT_FOUND: u64 = 2;

    // Property key stored in default_properties controlling who can burn the token.
    // the corresponding property value is BCS serialized bool.
    const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";
    const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";
    const TOKEN_PROPERTY_MUTABLE: vector<u8> = b"TOKEN_PROPERTY_MUTATBLE";

    struct CollectionDataV1 has copy, drop, store {
        creator: address,
        description: String,
        name: String,
        uri: String,
        supply: u64,
        maximum: u64,
        mutability_config: CollectionMutabilityConfig,
    }

    /// Supply is asserted to be one when getting this data.
    struct TokenDataV1 has copy, drop, store {
        token_id: TokenId,
        description: String,
        maximum: u64,
        uri: String,
        royalty_payee_address: address,
        royalty_points_denominator: u64,
        royalty_points_numerator: u64,
        name: String,
        mutability_config: TokenMutabilityConfig,
        property_keys: vector<String>,
        property_values: vector<String>,
        property_types: vector<String>,
        burnable_by_creator: Option<bool>,
        burnable_by_owner: Option<bool>,
        token_property_mutable: Option<bool>,
    }

    #[view]
    public fun get_collection_v1_data(
        creator_address: address,
        collection_name: String
    ): CollectionDataV1 {
        CollectionDataV1 {
            creator: creator_address,
            description: token_v1::get_collection_description(creator_address, collection_name),
            name: collection_name,
            uri: token_v1::get_collection_uri(creator_address, collection_name),
            supply: option::extract(&mut token_v1::get_collection_supply(creator_address, collection_name)),
            maximum: token_v1::get_collection_maximum(creator_address, collection_name),
            mutability_config: token_v1::get_collection_mutability_config(creator_address, collection_name),
        }
    }

    #[view]
    public fun get_token_v1_data(
        creator_address: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
    ): TokenDataV1 {
        let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = assert_and_create_nft_token_id(creator_address, token_data_id);
        let (royalty_payee_address, royalty_points_denominator, royalty_points_numerator) = get_royalty_fields(token_data_id);

        let (property_values,
            property_types,
            burnable_by_creator,
            burnable_by_owner,
            token_property_mutable) = get_property_map_values_and_types(creator_address, token_id, keys);

        TokenDataV1 {
            token_id,
            description: token_v1::get_tokendata_description(token_data_id),
            maximum: token_v1::get_tokendata_maximum(token_data_id),
            uri: token_v1::get_tokendata_uri(creator_address, token_data_id),
            royalty_payee_address,
            royalty_points_denominator,
            royalty_points_numerator,
            name: token_name,
            mutability_config: token_v1::get_tokendata_mutability_config(token_data_id),
            property_keys: keys,
            property_values,
            property_types,
            burnable_by_creator,
            burnable_by_owner,
            token_property_mutable,
        }
    }

    public fun get_royalty_fields(token_data_id: TokenDataId): (address, u64, u64) {
        let royalty = token_v1::get_tokendata_royalty(token_data_id);

        let payee = token_v1::get_royalty_payee(&royalty);
        let denominator = token_v1::get_royalty_denominator(&royalty);
        let numerator = token_v1::get_royalty_numerator(&royalty);
        (payee, denominator, numerator)
    }

    /// NFTs will always only have a supply of one, we assert that this is true
    /// And then we create a token id based on the token data id and the largest property version.
    public fun assert_and_create_nft_token_id(
        creator: address,
        token_data_id: TokenDataId,
    ): TokenId {
        let property_version = token_v1::get_tokendata_largest_property_version(creator, token_data_id);
        assert!(option::extract(&mut token_v1::get_token_supply(creator, token_data_id)) == 1, error::invalid_argument(ETOKEN_IS_FUNGIBLE));
        token_v1::create_token_id(token_data_id, property_version)
    }

    #[view]
    public fun view_property_map_values_and_types(
        owner_address: address,
        creator_address: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
    ): (vector<String>, vector<String>, Option<bool>, Option<bool>, Option<bool>) {
        let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
        let token_id = assert_and_create_nft_token_id(creator_address, token_data_id);
        get_property_map_values_and_types(owner_address, token_id, keys)
    }

    /// Since there is no `keys(...)` function on mainnet yet, we must pass in the keys to the property map and verify the vector length matches the property map length.
    /// Then we reconstruct the property map keys, values, and types based on the keys we passed in.
    public fun get_property_map_values_and_types(
        owner_address: address,
        token_id: TokenId,
        keys: vector<String>,
    ): (vector<String>, vector<String>, Option<bool>, Option<bool>, Option<bool>) {
        let property_map = token_v1::get_property_map(owner_address, token_id);
        let property_map_length = property_map::length(&property_map);

        // Get all default properties as Option<bool> values, and remove them from the keys vector.
        let burnable_by_creator = get_property_bool_as_option_and_remove_key(&mut keys, &property_map, &str(BURNABLE_BY_CREATOR));
        let burnable_by_owner = get_property_bool_as_option_and_remove_key(&mut keys, &property_map, &str(BURNABLE_BY_OWNER));
        let token_property_mutable = get_property_bool_as_option_and_remove_key(&mut keys, &property_map, &str(TOKEN_PROPERTY_MUTABLE));

        assert!(vector::length(&keys) == property_map_length, error::invalid_argument(ENUM_KEYS_INCORRECT));

        let values = vector<String> [];
        let types = vector<String> [];

        vector::for_each(keys, |k| {
            assert!(property_map::contains_key(&property_map, &k), error::invalid_argument(EKEY_NOT_FOUND));
            let property_value = property_map::borrow(&property_map, &k);
            let v = str(b"asdfkjf");//property_map::read_string(&property_map, &k);//std::from_bcs::to_string(property_map::borrow_value(property_value));
            let t = property_map::borrow_type(property_value);

            vector::push_back(&mut values, v);
            vector::push_back(&mut types, t);
        });

        (values, types, burnable_by_creator, burnable_by_owner, token_property_mutable)
    }

    inline fun get_property_bool_as_option_and_remove_key(
        keys: &mut vector<String>,
        property_map: &PropertyMap,
        key: &String,
    ): Option<bool> {
        if (property_map::contains_key(property_map, key)) {
            assert!(vector::contains(keys, key), error::invalid_argument(EKEY_NOT_FOUND));
            let _ = vector::remove_value(keys, key);
            option::some(property_map::read_bool(property_map, key))
        } else {
            option::none<bool>()
        }
    }

    // CollectionDataV1 getters

    public fun get_collection_creator(collection_data_v1: &CollectionDataV1): address {
        collection_data_v1.creator
    }
    public fun get_collection_description(collection_data_v1: &CollectionDataV1): String {
        collection_data_v1.description
    }
    public fun get_collection_name(collection_data_v1: &CollectionDataV1): String {
        collection_data_v1.name
    }
    public fun get_collection_uri(collection_data_v1: &CollectionDataV1): String {
        collection_data_v1.uri
    }
    public fun get_collection_supply(collection_data_v1: &CollectionDataV1): u64 {
        collection_data_v1.supply
    }
    public fun get_collection_maximum(collection_data_v1: &CollectionDataV1): u64 {
        collection_data_v1.maximum
    }
    public fun get_collection_mutability_config(collection_data_v1: &CollectionDataV1): CollectionMutabilityConfig {
        collection_data_v1.mutability_config
    }

    // TokenDataV1 getters

    public fun get_token_id(token_data_v1: &TokenDataV1): TokenId {
        token_data_v1.token_id
    }
    public fun get_token_description(token_data_v1: &TokenDataV1): String {
        token_data_v1.description
    }
    public fun get_token_maximum(token_data_v1: &TokenDataV1): u64 {
        token_data_v1.maximum
    }
    public fun get_token_uri(token_data_v1: &TokenDataV1): String {
        token_data_v1.uri
    }
    public fun get_token_royalty_payee_address(token_data_v1: &TokenDataV1): address {
        token_data_v1.royalty_payee_address
    }
    public fun get_token_royalty_points_denominator(token_data_v1: &TokenDataV1): u64 {
        token_data_v1.royalty_points_denominator
    }
    public fun get_token_royalty_points_numerator(token_data_v1: &TokenDataV1): u64 {
        token_data_v1.royalty_points_numerator
    }
    public fun get_token_name(token_data_v1: &TokenDataV1): String {
        token_data_v1.name
    }
    public fun get_token_mutability_config(token_data_v1: &TokenDataV1): TokenMutabilityConfig {
        token_data_v1.mutability_config
    }
    public fun get_token_property_keys(token_data_v1: &TokenDataV1): vector<String> {
        token_data_v1.property_keys
    }
    public fun get_token_property_values(token_data_v1: &TokenDataV1): vector<String> {
        token_data_v1.property_values
    }
    public fun get_token_property_types(token_data_v1: &TokenDataV1): vector<String> {
        token_data_v1.property_types
    }
    public fun get_token_burnable_by_creator(token_data_v1: TokenDataV1): bool {
        if (option::is_some(&token_data_v1.burnable_by_creator)) {
            option::extract(&mut token_data_v1.burnable_by_creator)
        } else {
            false
        }
    }
    public fun get_token_burnable_by_owner(token_data_v1: TokenDataV1): bool {
        if (option::is_some(&token_data_v1.burnable_by_owner)) {
            option::extract(&mut token_data_v1.burnable_by_owner)
        } else {
            false
        }
    }
    public fun get_token_property_mutable(token_data_v1: TokenDataV1): bool {
        if (option::is_some(&token_data_v1.token_property_mutable)) {
            option::extract(&mut token_data_v1.token_property_mutable)
        } else {
            false
        }
    }
    public fun get_token_burnable_by_creator_option(token_data_v1: &TokenDataV1): Option<bool> {
        token_data_v1.burnable_by_creator
    }
    public fun get_token_burnable_by_owner_option(token_data_v1: &TokenDataV1): Option<bool> {
        token_data_v1.burnable_by_owner
    }
    public fun get_token_property_mutable_option(token_data_v1: &TokenDataV1): Option<bool> {
        token_data_v1.token_property_mutable
    }
}
