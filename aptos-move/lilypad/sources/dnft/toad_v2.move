module aptoads_objects::dynamic_toads {
    use std::object::{Self, Object, ConstructorRef, ExtendRef, TransferRef, LinearTransferRef};
    use aptos_token::token::{Self as token_v1, Token};
    use token_objects::token::{Self as token_v2, MutatorRef, Token as TokenObject};
    use token_objects::collection::{Self as collection_v2, Collection};
    use token_objects::royalty::{Royalty};
    use std::string::{Self, String, utf8 as str};
    use std::option::{Self, Option};
    use aptos_std::string_utils;
    use aptos_std::type_info;
    use std::vector;
    use std::signer;
    use std::hash;
    friend pond::migration;

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Aptoad has key {
        background: String,
        body: String,
        clothing: Option<Object<Clothing>>,
        headwear: Option<Object<Headwear>>,
        eyewear: Option<Object<Eyewear>>,
        mouth: Option<Object<Mouth>>,
        fly: Option<Object<Fly>>,
        perfect: bool,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Clothing has key { }
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Headwear has key { }
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Eyewear has key { }
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Mouth has key { }
    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Fly has key { }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct Refs has key {
        transfer_ref: TransferRef,
        extend_ref: ExtendRef,
        mutator_ref: MutatorRef,
    }

    const LOWER_TO_UPPER_ASCII_DIFFERENCE: u64 = 32;
    const UPPERCASE_LOWER_BOUND: u64 = 65;
    const UPPERCASE_UPPER_BOUND: u64 = 90;
    const LOWERCASE_LOWER_BOUND: u64 = 97;
    const LOWERCASE_UPPER_BOUND: u64 = 122;
    const PERFECT_TOAD_NUM_TRAITS: u64 = 2;
    const MAX_TRAITS: u64 = 7;
    
    const DELIMITER: vector<u8> = b"::";
    
    // Equippable Headwear for an Aptoad. 🧢
    const TRAIT_DESCRIPTION_FORMAT: vector<u8> = b"Equippable {} for an Aptoad. {}";

    const BACKGROUND: vector<u8> = b"Background";
    const BODY: vector<u8> = b"Body";
    const CLOTHING: vector<u8> = b"Clothing";
    const HEADWEAR: vector<u8> = b"Headwear";
    const EYEWEAR: vector<u8> = b"Eyewear";
    const MOUTH: vector<u8> = b"Mouth";
    const FLY: vector<u8> = b"Fly";

    /// Action not authorized because the signer is not the owner of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// That type doesn't exist on the object
    const ENOT_A_VALID_OBJECT: u64 = 2;
    /// That trait type doesn't exist on the object
    const EINVALID_TRAIT_TYPE: u64 = 3;
    /// There is no background trait on the original token.
    const ENO_BACKGROUND_TRAIT: u64 = 4;
    /// There is no body trait on the original token.
    const ENO_BODY_TRAIT: u64 = 5;
    /// There exists an invalid property map key on the original token.
    const EINVALID_PROPERTY_MAP_KEY: u64 = 6;
    /// The object referenced does not have a Refs resource.
    const EOBJECT_DOES_NOT_HAVE_REFS: u64 = 7;
    /// The toad has no background.
    const ETOAD_HAS_NO_BACKGROUND: u64 = 8;
    /// The toad has no body.
    const ETOAD_HAS_NO_BODY: u64 = 9;
    /// The object passed in does not have a Refs resource.
    const EREFS_NOT_FOUND: u64 = 10;
    /// The object passed in already has that trait type equipped.
    const ETRAIT_TYPE_ALREADY_EQUIPPED: u64 = 11;
    /// The object passed in does not have that trait type equipped.
    const ETRAIT_TYPE_NOT_EQUIPPED: u64 = 12;
    /// The object passed in is not an Aptoad.
    const ENOT_A_TOAD: u64 = 12;
    /// The object passed in was not originally a perfect toad.
    const ENOT_PERFECT_TOAD: u64 = 12;
    /// Each Aptoad must have at least 2 and no more than 7 traits.
    const EINVALID_NUMBER_OF_TRAITS_AFTER_UPDATE: u64 = 12;


    // TODO: Remove later, this is purely for a sanity check
    /// The object passed in does not have a Refs resource.
    const EIMAGE_URIS_DONT_MATCH: u64 = 50;

    /// At this point, we can safely assume the owner has approved this request, and the resource signer approves of it as well
    /// this function should be safe to run multiple times, as we create a named token object and it will collide with the existing token
    /// and error.
    /// The merkle tree will verify the existence of this valid combination of traits.
    /// The keys & values passed in are verified, which is why we skip the get_map_from_traits check
    public(friend) fun create_v2_from_v1(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        token: Token,
        keys: vector<String>,
        values: vector<String>,
        unvalidated_image_uri: String,
    ) {
        let trait_map = simple_map::new_from(keys, values);
        let num_traits = get_num_traits_and_run_basic_check(&trait_map);

        // get v1 token info that we're going to use
        let token_id = token_v1::get_token_id(&token);
        let token_data_id = token_v1::get_tokendata_id(token_id);
        let token_uri = token_v1::get_tokendata_uri(resource_addr, token_data_id);
        let token_description = token_v1::get_tokendata_description(token_data_id);
        let (creator_addr, collection_name, token_name) = token_v1::get_token_data_id_fields(&token_id);
        assert!(resource_addr == creator_addr, error::invalid_argument(ECREATOR_ADDRESSES_DONT_MATCH));
        let constructor_ref = token_v2::create_named_token(
            resource_signer,
            collection_name,
            token_description,
            token_name,
            option::none(), // using collection wide royalties
            token_uri,
        );

        let token_signer = store_refs(&constructor_ref);

        // get base object
        let base_toad_object = object::object_from_constructor_ref(&constructor_ref);

        let (background, body, clothing, headwear, eyewear, mouth, fly, perfect) =
            create_v2_traits(
                resource_signer, resource_addr, collection_object, base_toad_object, keys, values
            );

        move_to(
            token_signer,
            Aptoad {
                background,
                body,
                clothing,
                headwear,
                eyewear,
                mouth,
                fly,
                perfect,
            }
        );


        // NOTE: These are redundant. We can remove these because they will likely change the gas cost
        // of the transaction drastically. The image_uri is assumed to be unchanged and valid since I've
        // never changed them.
        // TODO: Remove this:
        verified_uri_update(trait_map, base_toad_object, unvalidated_image_uri, proof);

        // image_uri is now verified
        let validated_image_uri = unvalidated_image_uri;

        // NOTE: Sanity check
        // TODO: Remove later
        assert!(validated_image_uri == token_uri, error::invalid_state(EIMAGE_URIS_DONT_MATCH));

        // TODO: Add token v1 => v2 swap event emission here!
        // TODO: Add token v1 => v2 swap event emission here!
        // TODO: Add token v1 => v2 swap event emission here!
    }

    fun create_v2_traits(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        base_toad_object: Object<Token>,
        keys: vector<String>,
        values: vector<String>,
    ): (String, String, Option<Object<Clothing>>, Option<Object<Headwear>>, Option<Object<Eyewear>>, Option<Object<Mouth>>, Option<Object<Fly>>, bool) acquires Clothing, Headwear, Eyewear, Mouth, Fly {
        let background = str(b"");
        let body = str(b"");
        let clothing = option::none<Object<Clothing>>();
        let headwear = option::none<Object<Headwear>>();
        let eyewear = option::none<Object<Eyewear>>();
        let mouth = option::none<Object<Mouth>>();
        let fly = option::none<Object<Fly>>();

        let num_traits = vector::length(&keys);
        while(vector::length(&keys) > 0) {
            // where k == trait_type && v == trait_name
            let k = vector::pop_back(&mut keys);
            let v = vector::pop_back(&mut values);
            if (k == str(BACKGROUND)) {
                background = v;
            } else if (k == str(BODY)) {
                body = v;
            } else if (k == str(CLOTHING)) {
                let clothing_constructor_ref = create_trait<Clothing>(resource_signer, v);
                let clothing_object = object::object_from_constructor_ref(&clothing_constructor_ref);
                only_equip_trait(base_toad_object, clothing_object);
            } else if (k == str(HEADWEAR)) {
                let headwear_constructor_ref = create_trait<Headwear>(resource_signer, v);
                let headwear_object = object::object_from_constructor_ref(&headwear_constructor_ref);
                only_equip_trait(base_toad_object, headwear_object);
            } else if (k == str(EYEWEAR)) {
                let eyewear_constructor_ref = create_trait<Eyewear>(resource_signer, v);
                let eyewear_object = object::object_from_constructor_ref(&eyewear_constructor_ref);
                only_equip_trait(base_toad_object, eyewear_object);
            } else if (k == str(MOUTH)) {
                let mouth_constructor_ref = create_trait<Mouth>(resource_signer, v);
                let mouth_object = object::object_from_constructor_ref(&mouth_constructor_ref);
                only_equip_trait(base_toad_object, mouth_object);
            } else if (k == str(FLY)) {
                let fly_constructor_ref = create_trait<Fly>(resource_signer, v);
                let fly_object = object::object_from_constructor_ref(&fly_constructor_ref);
                only_equip_trait(base_toad_object, fly_object);
            } else {
                // do nothing, could throw an error here to be extra safe...ok I'll do it.
                error::invalid_state(EINVALID_PROPERTY_MAP_KEY);
            };
        };

        assert!(background != str(b""), error::invalid_state(ENO_BACKGROUND_TRAIT));
        assert!(body != str(b""), error::invalid_state(ENO_BODY_TRAIT));

        let perfect = (num_traits == 2);
        (background, body, clothing, headwear, eyewear, mouth, fly, perfect)
    }

    fun internal_transfer<T1, T2>(
        trait_obj: Object<T1>,
        to: address,
    ) {
        let linear_transfer_ref = get_linear_transfer_ref(trait_obj);
        object::transfer_with_ref(linear_transfer_ref, to);
    }

    fun get_linear_transfer_ref<T>(
        trait_obj: Object<T>,
    ): LinearTransferRef acquires Clothing, Headwear, Eyewear, Mouth Fly {
        assert!(exists<Refs>(object::object_address(trait_obj)), error::invalid_state(EOBJECT_DOES_NOT_HAVE_REFS));
        object::generate_linear_transfer_ref(&borrow_global<Refs>(object_address).transfer_ref)
    }

    /// stores the refs and returns the signer for convenience
    fun store_refs(constructor_ref: &ConstructorRef): &signer {
        // get refs and token_signer for storing later
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token_v2::generate_mutator_ref(&constructor_ref);
        let token_signer = object::generate_signer(&constructor_ref);

        // store refs
        move_to(
            &token_signer,
            Refs {
                transfer_ref,
                extend_ref,
                mutator_ref,
            }
        );

        token_signer
    }

    fun create_trait_base_token<T>(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        trait_type: String,
        trait_name: String,
        image_uri: String,
    ): ConstructorRef {
        let trait_map = simple_map::new_from(
            vector<String> [ trait_type ],
            vector<String> [ trait_name ]
        );
        let num_traits = get_num_traits_and_run_basic_check(&trait_map);
        assert_trait_combo_in_merkle(&trait_map);

        // note this only works because we don't have repeated trait names. If we did we'd need to do smth else
        let constructor_ref = token_v2::create_named_token(
            resource_signer,
            collection_v2::name(collection_object),
            get_trait_description(trait_type, trait_name),
            trait_name,
            option::none(), // using collection wide royalties
            image_uri,
        );

        store_refs(&constructor_ref);
    }

    fun create_trait<T>(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        trait_type: String,
        trait_name: String,
        image_uri: String,
        // num_trait_type: u64,
    ): ConstructorRef {
        let constructor_ref = create_fungible_asset_or_smth(
            resource_signer,
            collection_object,
            image_uri,
        );
        let token_signer = object::generate_signer(&constructor_ref);

        if (type_info::type_of<T>() == type_info::type_of<Clothing>()) {
            move_to(&token_signer, Clothing { });
        } else if (type_info::type_of<T>() == type_info::type_of<Headwear>()) {
            move_to(&token_signer, Headwear { });
        } else if (type_info::type_of<T>() == type_info::type_of<Eyewear>()) {
            move_to(&token_signer, Eyewear { });
        } else if (type_info::type_of<T>() == type_info::type_of<Mouth>()) {
            move_to(&token_signer, Mouth { });
        } else if (type_info::type_of<T>() == type_info::type_of<Fly>()) {
            move_to(&token_signer, Fly { });
        };

        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);

        move_to(
            &token_signer,
            Refs {
                transfer_ref,
                extend_ref,
            }
        );
        
        // to disallow for unequipping/moving objects around without permission to do so
        object::disable_ungated_transfer(&transfer_ref);

        constructor_ref
    }

    /// intended to only be used by the singular equip
    /// this function will fail if there isn't a valid slot to equip
    public entry fun equip_and_update<T: key>(
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>,
        unvalidated_image_uri: String,
        proof: vector<vector<u8>>,
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        assert!(exists<Aptoad>(toad_object), error::invalid_argument(ENOT_A_TOAD));

        // make the change before creating the trait map
        only_equip_trait(toad_object, obj_to_equip);
        
        // create the new trait map
        let new_trait_map = get_v2_trait_map(toad_object);

        // runs all checks to ensure the state of the toad is valid post-change
        verified_uri_update(new_trait_map, base_toad_object, unvalidated_image_uri, proof);

        // gate the trait equip/unequip by paying with $FLY or something?
        // can also gate/disallow clones here. would use hash
        // also run checks either here or in `verified_uri_update`
    }

    /// intended to only be used by the singular equip
    /// this function will fail if there isn't a valid slot to unequip
    public entry fun unequip_and_update<T: key>(
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>,
        unvalidated_image_uri: String,
        proof: vector<vector<u8>>,
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        assert!(exists<Aptoad>(toad_object), error::invalid_argument(ENOT_A_TOAD));

        // make the change before creating the trait map
        only_unequip_trait(toad_object, obj_to_equip);
        
        // create the new trait map
        let new_trait_map = get_v2_trait_map(toad_object);

        // runs all checks to ensure the state of the toad is valid post-change
        verified_uri_update(new_trait_map, base_toad_object, unvalidated_image_uri, proof);

        // gate the trait equip/unequip by paying with $FLY or something?
        // can also gate/disallow clones here. would use hash
        // also run checks either here or in `verified_uri_update`
    }

    /// intended to be used by both v1 => v2 creator and future equips/unequips
    inline fun only_equip_trait<T: key>(
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        let object_address = object::object_address<T>(&obj_to_equip);

        let option_ref = get_trait_option<T>(toad_object);
        /*
        let option_ref = if (exists<Clothing>(object_address)) {
            // let clothing_obj = object::convert<T, Clothing>(obj_to_equip);
            // option::fill<Object<Clothing>>(&mut toad_obj_resources.clothing, clothing_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).clothing
            // internal_transfer(obj_to_equip, toad_object);
        } else if (exists<Headwear>(object_address)) {
            // let headwear_obj = object::convert<T, Headwear>(obj_to_equip);
            // option::fill<Object<Headwear>>(&mut toad_obj_resources.headwear, headwear_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).headwear
            // internal_transfer(obj_to_equip, toad_object);
        } else if (exists<Eyewear>(object_address)) {
            // let eyewear_obj = object::convert<T, Eyewear>(obj_to_equip);
            // option::fill<Object<Eyewear>>(&mut toad_obj_resources.eyewear, eyewear_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).eyewear
            // internal_transfer(obj_to_equip, toad_object);
        } else if (exists<Mouth>(object_address)) {
            // let mouth_obj = object::convert<T, Mouth>(obj_to_equip);
            // option::fill<Object<Mouth>>(&mut toad_obj_resources.mouth, mouth_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).mouth
            // internal_transfer(obj_to_equip, toad_object);
        } else if (exists<Fly>(object_address)) {
            // let fly_obj = object::convert<T, Fly>(obj_to_equip);
            // option::fill<Object<Fly>>(&mut toad_obj_resources.fly, fly_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).fly
            // internal_transfer(obj_to_equip, toad_object);
        } else {
            abort error::invalid_argument(EINVALID_TRAIT_TYPE)
        };
        */

        assert!(!option::is_some(option_ref), error::invalid_state(ETRAIT_TYPE_ALREADY_EQUIPPED));
        option::fill<T>(option_ref, obj_to_equip);
        internal_transfer(obj_to_equip, toad_object);
    }

    inline fun unequip_trait<T: key>(
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>,
    ) {
        abort 1
        // run checks to make sure if traits == 2 the toad also has to be perfect or it will fail.

        // run checks to see if it's a clone that exists already..?
        // you would do this by hashing the new concat_string you verified with merkle tree
        // and then using that as the seed for the object address checking to see if an object exists there.
        // ImageObject or something?
    }

    /// this should only be run after any change has taken place
    inline fun verify_num_traits(
        new_trait_map: &SimpleMap<String, String>,
    ) {
        let num_traits_after = simple_map::length(&new_trait_map);

        assert!(num_traits_after >= 2 && num_traits_after <= MAX_TRAITS, error::invalid_state(EINVALID_NUMBER_OF_TRAITS_AFTER_UPDATE));
        if (num_traits_after == 2) {
            assert!(is_perfect(toad_object), error::invalid_argument(ENOT_PERFECT_TOAD));
        };
    }

    /// obj_addr should always match mutator_ref addr
    /// we pass in trait_map instead of deriving it so that v1 => v2 can skip it, since some people
    /// may run 100s of migrations at once, would be exorbitant gas cost.
    /// In the migration case, there is no way to update the property maps using the regular toad contract,
    /// so this cannot be abused, all v1 toads will have correct property maps.
    /// TODO: Verify the above is true. (lol)
    inline fun verified_uri_update(
        new_trait_map: &SimpleMap<String, String>,
        obj_addr: address,
        image_uri: String,
        proof: vector<vector<u8>>,
    ) acquires Refs {
        verify_num_traits(new_trait_map);

        assert_trait_combo_in_merkle(new_trait_map, image_uri, proof);
        assert!(exists<Refs>(obj_addr), error::not_found(EREFS_NOT_FOUND));
        let ref_resources = borrow_global<Refs>(obj_addr);
        let mutator_ref = &ref_resources.mutator_ref;
        token_v2::set_uri(mutator_ref, image_uri);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                     trait info, view functions                    ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    #[view]
    public fun get_v2_trait_map(toad_object: Object<Aptoad>): &SimpleMap {
        let keys = vector<String> [];
        let values = vector<String> [];

        vector::push(&mut keys, str(BACKGROUND));
        vector::push(&mut values, get_background(toad_object));

        vector::push(&mut keys, str(BODY));
        vector::push(&mut values, get_body(toad_object));

        let clothing_trait_option = get_trait_option_from_toad<Clothing>(toad_object);
        if (option::is_some(clothing_trait_option)) {
            vector::push(&mut keys, trait_type_to_string<Clothing>());
            vector::push(&mut values, get_trait_name(*option::borrow(clothing_trait_option)));
        };
        let headwear_trait_option = get_trait_option_from_toad<Headwear>(toad_object);
        if (option::is_some(headwear_trait_option)) {
            vector::push(&mut keys, trait_type_to_string<Headwear>());
            vector::push(&mut values, get_trait_name(*option::borrow(headwear_trait_option)));
        };
        let eyewear_trait_option = get_trait_option_from_toad<Eyewear>(toad_object);
        if (option::is_some(eyewear_trait_option)) {
            vector::push(&mut keys, trait_type_to_string<Eyewear>());
            vector::push(&mut values, get_trait_name(*option::borrow(eyewear_trait_option)));
        };
        let mouth_trait_option = get_trait_option_from_toad<Mouth>(toad_object);
        if (option::is_some(mouth_trait_option)) {
            vector::push(&mut keys, trait_type_to_string<Mouth>());
            vector::push(&mut values, get_trait_name(*option::borrow(mouth_trait_option)));
        };
        let fly_trait_option = get_trait_option_from_toad<Fly>(toad_object);
        if (option::is_some(fly_trait_option)) {
            vector::push(&mut keys, trait_type_to_string<Fly>());
            vector::push(&mut values, get_trait_name(*option::borrow(fly_trait_option)));
        };
        &simple_map::new_from(keys, values)
    }

    #[view]
    public inline fun get_trait_option_from_toad<T: key>(toad_object: Object<Aptoad>): &Option<Object<T>> acquires Aptoad {
        if (exists<Clothing>(object_address)) {
            &borrow_global<Aptoad>(toad_object).clothing
        } else if (exists<Headwear>(object_address)) {
            &borrow_global<Aptoad>(toad_object).headwear
        } else if (exists<Eyewear>(object_address)) {
            &borrow_global<Aptoad>(toad_object).eyewear
        } else if (exists<Mouth>(object_address)) {
            &borrow_global<Aptoad>(toad_object).mouth
        } else if (exists<Fly>(object_address)) {
            &borrow_global<Aptoad>(toad_object).fly
        } else {
            abort error::invalid_argument(EINVALID_TRAIT_TYPE)
        }
    }

    #[view]
    public inline fun get_trait_name_from_toad<T: key>(
        toad_object: Object<Aptoad>,
    ): String {
        token_v2::name(get_trait_token_object_from_toad(toad_object))
    }

    #[view]
    public inline fun get_trait_token_object_from_toad<T: key>(
        toad_object: Object<Aptoad>,
    ): Object<Token> {
        let trait_object = get_trait_object_from_toad<T>(toad_object);
        let token_object = object::convert<T, Token>(trait_object);
        token_object
    }

    #[view]
    public inline fun get_trait_object_from_toad<T: key>(
        toad_object: Object<Aptoad>,
    ): Object<T> {
        if (throw_if_empty) {
            assert!(!option::is_some(&option_object), error::invalid_state(ETRAIT_TYPE_NOT_EQUIPPED));
        } else {
            // we could check exists<T>(toad_object) here but our contract is, by design, never allowed to get to that state.
            *option::borrow(get_trait_option_from_toad<T>(toad_object))
        }
    }

    #[view]
    public inline fun get_background(toad_object: Object<Aptoad>): String acquires Aptoad {
        borrow_global<Aptoad>(toad_object).background
    }

    #[view]
    public inline fun get_body(toad_object: Object<Aptoad>): String acquires Aptoad {
        borrow_global<Aptoad>(toad_object).body
    }

    #[view]
    public inline fun get_trait_name<T: key>(trait_object: Object<T>): String {
        let token_object = object::convert<T, Token>(trait_object);
        token_v2::name(token_object)
    }

    #[view]
    fun view_object<T: key>(obj: Object<T>): String acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        if (is_aptoad(obj)) {
            string_utils::debug_string(borrow_global<Aptoad>(obj))
        } else if (is_clothing(obj)) {
            string_utils::debug_string(borrow_global<Clothing>(obj))
        } else if (is_headwear(obj)) {
            string_utils::debug_string(borrow_global<Headwear>(obj))
        } else if (is_eyewear(obj)) {
            string_utils::debug_string(borrow_global<Eyewear>(obj))
        } else if (is_mouth(obj)) {
            string_utils::debug_string(borrow_global<Mouth>(obj))
        } else if (is_fly(obj)) {
            string_utils::debug_string(borrow_global<Fly>(obj))
        } else {
            error::invalid_argument(ENOT_A_VALID_OBJECT)
        }
    }

    #[view]
    public fun is_aptoad<T: key>(obj: Object<T>): bool {
        exists<Aptoad>(object::object_address(&obj))
    }

    #[view]
    public fun is_clothing<T: key>(obj: Object<T>): bool {
        exists<Clothing>(object::object_address(&obj))
    }

    #[view]
    public fun is_headwear<T: key>(obj: Object<T>): bool {
        exists<Headwear>(object::object_address(&obj))
    }

    #[view]
    public fun is_eyewear<T: key>(obj: Object<T>): bool {
        exists<Eyewear>(object::object_address(&obj))
    }

    #[view]
    public fun is_mouth<T: key>(obj: Object<T>): bool {
        exists<Mouth>(object::object_address(&obj))
    }

    #[view]
    public fun is_fly<T: key>(obj: Object<T>): bool {
        exists<Fly>(object::object_address(&obj))
    }

    #[view]
    public fun is_a_trait_type<T: key>(obj: Object<T>): bool acquires Clothing, Headwear, Eyewear, Mouth, Fly {
        is_clothing(obj) || is_headwear(obj) || is_eyewear(obj) || is_mouth(obj) || is_fly(obj)
    }

    #[view]
    public fun trait_type_to_string<T: key>(): String acquires Clothing, Headwear, Eyewear, Mouth, Fly {
        if (is_clothing(obj)) { str(CLOTHING) } else
        if (is_headwear(obj)) { str(HEADWEAR) } else
        if (is_eyewear(obj))  { str(EYEWEAR) } else
        if (is_mouth(obj))    { str(MOUTH) } else
        if (is_fly(obj))      { str(FLY) } else
        { error::invalid_argument(EINVALID_TRAIT_TYPE) }
    }

    /*
    / invalid if we are using fungible assets with the same name
    #[view]
    public fun trait_name<T: key>(obj: Object<T>): String acquires Clothing, Headwear, Eyewear, Mouth, Fly {
        if (is_clothing(obj)) {
            borrow_global<Clothing>(token_address).trait_name
        } else if (is_headwear(obj)) {
            borrow_global<Headwear>(token_address).trait_name
        } else if (is_eyewear(obj)) {
            borrow_global<Eyewear>(token_address).trait_name
        } else if (is_mouth(obj)) {
            borrow_global<Mouth>(token_address).trait_name
        } else if (is_fly(obj)) {
            borrow_global<Fly>(token_address).trait_name
        } else {
            error::invalid_argument(EINVALID_TRAIT_TYPE)
        }
    }
    */

    #[view]
    public fun get_trait_description(trait_type: String, trait_name: String): String {
        let trait_type_emoji = if (trait_type == str(CLOTHING))   { str(b"👕") }
                          else if (trait_type == str(HEADWEAR))   { str(b"🧢") }
                          else if (trait_type == str(EYEWEAR))    { str(b"🕶") }
                          else if (trait_type == str(MOUTH))      { str(b"👄") }
                          else if (trait_type == str(FLY))        { str(b"🪰") }
                          else { abort error::invalid_argument(EINVALID_TRAIT_TYPE) };

        std::string_utils::format2(TRAIT_DESCRIPTION_FORMAT, trait_type, trait_type_emoji);
    }


   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                           merkle validation                       ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// Check to see if the number of traits makes sense:
    /// 1 trait == single trait, can't be a background and can't be a body
    /// 2+ traits == must be the background and the body
    /// the implicit logic here means any toad with 2 traits is a perfect toad (only body & background)
    /// if we return 1, we know it's a valid single trait
    /// if we return 2, we know it's a valid perfect toad
    /// if we return 3+, we know it is a valid regular toad
    fun get_num_traits_and_run_basic_check(
        trait_map: &SimpleMap<String, String>,
    ): u64 {
        let num_traits = simple_map::length(trait_map);
        // if it's a single trait, it can't be a background or a body, otherwise it MUST have a background & a body
        if (num_traits == 1) {
            assert!(!simple_map::contains_key(&trait_map, str(BACKGROUND)), error::invalid_state(ETOAD_HAS_NO_BACKGROUND));
            assert!(!simple_map::contains_key(&trait_map, str(BODY)), error::invalid_state(ETOAD_HAS_NO_BODY));
        } else {
            assert!(simple_map::contains_key(&trait_map, str(BACKGROUND)), error::invalid_state(ETOAD_HAS_NO_BACKGROUND));
            assert!(simple_map::contains_key(&trait_map, str(BODY)), error::invalid_state(ETOAD_HAS_NO_BODY));
        };

        num_traits
    }

    /// concatenate the traits and trait names with the provided image URL.
    /// hash it, then pass it in with the proof vector to verify its a valid merkle leaf node
    fun assert_trait_combo_in_merkle(
        trait_map: &SimpleMap<String, String>,
        image_uri: String,
        proof: vector<vector<u8>>,
    ): {
        let concatenated_traits = join_traits(&trait_map, str(DELIMITER));
        let concatenated_trait_and_url = join_strings(concatenated_traits, concatenated_trait_and_url);
        let concatenated_trait_string = to_upper(concatenated_trait_and_url);
        let concatenated_trait_bytes = *string::bytes(&concatenated_trait_string);
        let internally_verified_leaf_hash = hash::sha3_256(concatenated_trait_bytes);
        
        let merkle_tree = &borrow_global<MigrationConfig>.merkle_tree;

        let is_valid_proof = merkle_tree::verify_proof(
            merkle_tree,
            internally_verified_leaf_hash,
            proof
        );
        assert!(is_valid_proof, error::invalid_argument(EINVALID_PROOF));
    }


    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                   toad-specific merkle helpers                    ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    inline fun join_strings(
        s1: String,
        s2: String,
        delimiter: String,
    ): String {
        std::string_utils::format3(
            b"{}{}{}",
            s1,
            delimiter,
            s2
        );
    }

    #[view]
    /// create a string of Trait_Type::Trait_Name for each toad trait, joined with ::
    /// it's always in alphabetical order of the trait types:
    /// BACKGROUND, BODY, CLOTHING, EYEWEAR, FLY, HEADWEAR, MOUTH
    public fun join_traits(
        trait_map: &SimpleMap<String, String>,
        delimiter: String,
    ): String {
        let concatenated_string = str(b"");
        let order = vector<u8> [BACKGROUND, BODY, CLOTHING, EYEWEAR, FLY, HEADWEAR, MOUTH];

        // create a vector of "TRAIT_TYPE::TRAIT_NAME" values
        let traits_and_names = vector::map_ref(&order, |key| {
            if (simple_map::contains_key(trait_map, &str(key))) {
                join_strings(
                    *key,
                    simple_map::borrow(trait_map, &str(*key)),
                    delimiter,
                )
            } else {
                str(b"")
            }
        });

        // for each "TRAIT::NAME" concatenate it into a bigger string
        vector::for_each(&traits_and_names, |trait_and_name| {
            // only add delimiter if the concatenated_string has a base to build off of
            concatenated_string = if (string::length(&concatenated_string) != 0) {
                join_strings(
                    concatenated_string,
                    trait_and_name,
                    delimiter
                );
            // otherwise it's the first potential trait in the base string, don't add a delimiter to the front
            } else {
                trait_and_name
                // note `concatenated_string` can be empty here if we aren't at the last element in the vector
            };
        });

        // concatenated_string cannot be empty at this point
        concatenated_string
    }

    #[view]
    public fun to_upper(s: String): String {
        str(to_upper_bytes(*string::bytes(&s)))
    }

    #[view]
    public fun to_lower(s: String): String {
        str(to_lower_bytes(*string::bytes(&s)))
    }

    #[view]
    public fun to_upper_bytes(s: vector<u8>): vector<u8> {
        vector::map(&s, |char| {
            // lowercase characters are ascii values 97-122, inclusive
            if (char >= LOWERCASE_LOWER_BOUND || char <= LOWERCASE_UPPER_BOUND) {
                char - LOWER_TO_UPPER_ASCII_DIFFERENCE
            } else {
                char
            }
        })
    }

    #[view]
    public fun to_lower_bytes(s: vector<u8>): vector<u8> {
        vector::map(&s, |char| {
            // uppercase characters are ascii values 65-90, inclusive
            if (char >= UPPERCASE_LOWER_BOUND || char <= UPPERCASE_UPPER_BOUND) {
                char + LOWER_TO_UPPER_ASCII_DIFFERENCE
            } else {
                char
            }
        })
    }


    #[test]
    fun test_if_empty_string_equal_empty_vec() {
        assert!(str(vector<u8>[]) == b"", 0);
    }

    #[test]
    fun test_upper_and_lower() {
        assert!(to_upper_bytes(b"abcdefghijklmnopqrstuvwxyz") == b"ABCDEFGHIJKLMNOPQRSTUVWXYZ");
        assert!(to_upper_bytes(b"hello") == b"HELLO");
        assert!(to_upper_bytes(b"hello WORLD") == b"HELLO WORLD");
        assert!(to_upper_bytes(b"hello WORLD !@#[`{") == b"HELLO WORLD !@#[`{");

        assert!(to_upper(str(b"abcdefghijklmnopqrstuvwxyz")) == str(b"ABCDEFGHIJKLMNOPQRSTUVWXYZ"));
        assert!(to_upper(str(b"hello")) == str(b"HELLO"));
        assert!(to_upper(str(b"hello WORLD")) == str(b"HELLO WORLD"));
        assert!(to_upper(str(b"hello WORLD !@#[`{")) == str(b"HELLO WORLD !@#[`{"));

        assert!(to_lower_bytes(b"ABCDEFGHIJKLMNOPQRSTUVWXYZ") == b"abcdefghijklmnopqrstuvwxyz");
        assert!(to_lower_bytes(b"HELLO") == b"hello");
        assert!(to_lower_bytes(b"hello WORLD") == b"hello world");
        assert!(to_lower_bytes(b"hello WORLD !@#[`{") == b"hello world !@#[`{");

        assert!(to_lower(str(b"ABCDEFGHIJKLMNOPQRSTUVWXYZ")) == str(b"abcdefghijklmnopqrstuvwxyz"));
        assert!(to_lower(str(b"HELLO")) == str(b"hello"));
        assert!(to_lower(str(b"hello WORLD")) == str(b"hello world"));
        assert!(to_lower(str(b"hello WORLD !@#[`{")) == str(b"hello world !@#[`{"));
    }
}
