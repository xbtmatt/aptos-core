module pond::toad_v2 {
    use std::object::{Self, Object, ConstructorRef, ExtendRef, TransferRef};
    use aptos_token::token::{Self as token_v1, Token as OldToken};
    use aptos_token_objects::token::{Self as token_v2, Token, MutatorRef};
    use aptos_token_objects::collection::{Self as collection_v2, Collection};
    use aptos_token_objects::royalty;
    use std::string::{Self, String, utf8 as str};
    use std::option::{Self, Option};
    use aptos_std::string_utils;
    use aptos_std::type_info;
    use aptos_std::primary_fungible_store;
    use std::vector;
    use std::signer;
    use std::hash;
    use std::error;
    use std::table;
    use std::event::{Self, EventHandle};
    use pond::lilypad;
    use pond::merkle_tree;
    use aptos_framework::simple_map::{Self, SimpleMap};
    //use pond::lilypad::{internal_get_resource_signer_and_addr};

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
        unique_combination_obj: Object<UniqueCombination>,
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

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct EventHandles has key {
        equip_events: EventHandle<EquipEvent>,
        unequip_events: EventHandle<UnequipEvent>,
        migration_events: EventHandle<MigrationEvent>,
        new_combination_events: EventHandle<NewCombinationEvent>,
    }

    struct EquipEvent has copy, drop, store {
        toad_object: Object<Aptoad>,
        equipped_trait: Object<Token>,
    }

    struct UnequipEvent has copy, drop, store {
        toad_object: Object<Aptoad>,
        unequipped_trait: Object<Token>,
    }

    struct MigrationEvent has copy, drop, store {
        creator: address,
        old_collection_name: String,
        new_collection_name: String,
        new_collection: Object<Collection>,
        new_token_name: String,
        toad_object: Object<Aptoad>,
        perfect: bool,
    }

    struct NewCombinationEvent has copy, drop, store {
        toad_obj: Object<Aptoad>,
        owner_addr: address,
        background: String,
        body: String,
        clothing: String,
        headwear: String,
        eyewear: String,
        mouth: String,
        fly: String,
        clothing_obj: Option<Object<Clothing>>,
        headwear_obj: Option<Object<Headwear>>,
        eyewear_obj: Option<Object<Eyewear>>,
        mouth_obj: Option<Object<Mouth>>,
        fly_obj: Option<Object<Fly>>,
    }

    struct Preconditions has key {
        num_combo_objects: u64,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct UniqueCombination has key {
        image_uri: String,
        transfer_ref: TransferRef,
        extend_ref: ExtendRef,
    }

    const LOWER_TO_UPPER_ASCII_DIFFERENCE: u64 = 32;
    const UPPERCASE_LOWER_BOUND: u64 = 65;
    const UPPERCASE_UPPER_BOUND: u64 = 90;
    const LOWERCASE_LOWER_BOUND: u64 = 97;
    const LOWERCASE_UPPER_BOUND: u64 = 122;
    const PERFECT_TOAD_NUM_TRAITS: u64 = 2;
    const MAX_TRAITS: u64 = 7;
    const COLLECTION_NAME: vector<u8> = b"Aptos Toad Overload";
    const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";
    const COLLECTION_V2_DESCRIPTION: vector<u8> = b"The flagship Aptos NFT | 4000 dynamic pixelated toads taking a leap into the Aptos pond.";
    const COLLECTION_V2_URI: vector<u8> = b"https://arweave.net/AbA33tqZQj3fJtfn8U4P3EQaCBD9pUWoVNRyTosCxeQ";
    const MAXIMUM_SUPPLY: u64 = 4000;
    const TREASURY_ADDRESS: address = @0x790bc9aa92d6e54fccc7ebd699386b0d526dad9686971ff1720dac513c5ba4dc;

    const DELIMITER: vector<u8> = b"::";

    // Equippable Headwear for an Aptoad.
    const TRAIT_DESCRIPTION_FORMAT: vector<u8> = b"Equippable {} for an Aptoad. {}";

    const PERFECT_TOAD_DESCRIPTION: vector<u8> = b"{} is a perfect toad- one of only ten.";

    const BACKGROUND: vector<u8> = b"Background";
    const BODY: vector<u8> = b"Body";
    const CLOTHING: vector<u8> = b"Clothing";
    const HEADWEAR: vector<u8> = b"Headwear";
    const EYEWEAR: vector<u8> = b"Eyewear";
    const MOUTH: vector<u8> = b"Mouth";
    const FLY: vector<u8> = b"Fly";

    /// Action not authorized because the signer is not the owner of this module.
    const ENOT_AUTHORIZED: u64 = 0;
    /// Action not authorized because the signer is not the owner of the object.
    const ENOT_OWNER: u64 = 1;
    /// That type doesn't exist on the object.
    const ENOT_A_VALID_OBJECT: u64 = 2;
    /// That trait type doesn't exist on the object.
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
    const ENOT_A_TOAD: u64 = 13;
    /// The object passed in was not originally a perfect toad.
    const ENOT_PERFECT_TOAD: u64 = 14;
    /// Each Aptoad must have at least 2 and no more than 7 traits.
    const EINVALID_NUMBER_OF_TRAITS_AFTER_UPDATE: u64 = 15;
    /// The Aptoad does not own the Combo object.
    const ETOAD_DOES_NOT_OWN_COMBO: u64 = 16;
    /// That trait type token already exists.
    const ETRAIT_TYPE_ALREADY_EXISTS: u64 = 17;

    /////////////// trait combos ///////////////
    /// That trait combination already exists.
    const ETRAIT_COMBO_ALREADY_EXISTS: u64 = 18;
    /// That trait combination does not exist.
    const ETRAIT_COMBO_DOES_NOT_EXIST: u64 = 19;
    /// That combination is already in use.
    const ETRAIT_COMBO_IN_USE: u64 = 20;
    /// The maximum supplies of the collections do not match.
    const EMAXIMUM_DOES_NOT_MATCH: u64 = 21;
    /// The combination objects need to be created prior to enabling the migration.
    const ECOMBO_OBJECTS_NOT_PRECREATED: u64 = 22;
    /// Incorrect combination of resource address and v2 collection name.
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 23;
    /// One of the arguments must be a toad or the creator resource address.
    const EINVALID_ARGUMENTS: u64 = 24;
    /// The given Aptoad Token Object is not in a collection owned by the given creator resource address.
    const ETOKEN_NOT_IN_COLLECTION: u64 = 25;
    /// The expectations for the internal state of the contract has been violated.
    const EINVALID_STATE: u64 = 26;

    /////////////// migration ///////////////
   /// Collection supply isn't equal to the collection maximum. There is an issue with the collection supply.
   const EMAX_NOT_SUPPLY: u64 = 27;
   /// Toad store doesn't exist yet.
   const ETOAD_STORE_DOES_NOT_EXIST: u64 = 28;
   /// Provided vector lengths do not match.
   const EVECTOR_LENGTHS_DO_NOT_MATCH: u64 = 29;
   /// Migrated vs unmigrated tokens are out of sync. The amount of both should sum to 4,000.
   const ESUPPLY_OUT_OF_SYNC: u64 = 30;

    const COMBO_SALT: vector<u8> = b"COMBO";


    // TODO: Remove later, this is purely for a sanity check
    /// The object passed in does not have a Refs resource.
    const EIMAGE_URIS_DONT_MATCH: u64 = 50;

    /// At this point, we can safely assume the owner has approved this request, and the resource signer approves of it as well
    /// this function should be safe to run multiple times, as we create a named token object and it will collide with the existing token
    /// and error.
    /// The merkle tree will verify the existence of this valid combination of traits.
    /// The keys & values passed in are verified, which is why we skip the get_map_from_traits check
    fun create_v2_toad(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        token: OldToken,
        keys: vector<String>,
        values: vector<String>,
        unvalidated_image_uri: String,
    ): Object<Aptoad> {
        let trait_map = simple_map::new_from<String, String>(keys, values);
        let num_traits = get_num_traits_and_run_basic_check(&trait_map);
        let is_perfect = (num_traits == 2);

        // get v1 token info that we're going to use
        let token_id = token_v1::get_token_id(&token);
        let token_data_id = token_v1::get_tokendata_id(token_id);
        let token_uri = token_v1::get_tokendata_uri(resource_addr, token_data_id);
        let token_description = if (is_perfect) {
            std::string_utils::format1(str(PERFECT_TOAD_DESCRIPTION), token_data_id.name)
        } else {
            token_v1::get_tokendata_description(token_data_id)
        };
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

        initialize_event_store(token_signer);
        emit_migration_event(
            token_signer,
            creator_addr,
            collection_name,
            collection_name,
            collection_object,
            token_name,
            base_toad_object,
            perfect,
        );

        // NOTE: These are redundant. We can remove these because they will likely change the gas cost
        // of the transaction drastically. The image_uri is assumed to be unchanged and valid since I've
        // never changed them.
        // TODO: Remove this:
        let leaf_hash = verified_uri_update(trait_map, base_toad_object, unvalidated_image_uri, proof);
        // image_uri is now verified
        let validated_image_uri = unvalidated_image_uri;
        // Sanity check. TODO: Remove later.
        assert!(validated_image_uri == token_uri, error::invalid_state(EIMAGE_URIS_DONT_MATCH));

        let unique_combination_obj = get_address_combo(resource_addr, leaf_hash);
        assert!(exists<UniqueCombination>(unique_combination_obj),
            error::invalid_state(EUNIQUE_COMBINATION_DOES_NOT_EXIST));

        move_to(
            token_signer,
            Aptoad {
                background: simple_map::borrow(&trait_map, &str(BACKGROUND)),
                body: simple_map::borrow(&trait_map, &str(BODY)),
                clothing: option::none<Object<Clothing>>(),
                headwear: option::none<Object<Headwear>>(),
                eyewear: option::none<Object<Eyewear>>(),
                mouth: option::none<Object<Mouth>>(),
                fly: option::none<Object<Fly>>(),
                perfect: is_perfect,
                unique_combination_obj,
            }
        );

        let abort_if_exists = true;
        try_unique_combination(
            leaf_hash,
            validated_image_uri,
            resource_addr,
            base_toad_object,
            abort_if_exists,
        );

        let is_verified_perfect = create_v2_traits(
            resource_signer,
            resource_addr,
            collection_object,
            base_toad_object,
            keys,
            values
        );

    }

    fun initialize_event_store(
        token_signer: &signer,
    ) acquires EventHandles {
        move_to(
            token_signer,
            EventHandles {
                equip_event: event::new_event_handle<EquipEvent>(token_signer),
                unequip_event: event::new_event_handle<UnequipEvent>(token_signer),
                migration_events: event::new_event_handle<MigrationEvent>(token_signer),
                new_combination_events: event::new_event_handle<NewCombinationEvent>(token_signer),
            }
        );
    }

    fun create_v2_traits(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        base_toad_object: Object<Token>,
        keys: vector<String>,
        values: vector<String>,
    ): bool acquires Clothing, Headwear, Eyewear, Mouth, Fly {
        let background = str(b"");
        let body = str(b"");

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
                equip_trait(base_toad_object, mint_trait<Clothing>(resource_signer, v));
            } else if (k == str(HEADWEAR)) {
                equip_trait(base_toad_object, mint_trait<Headwear>(resource_signer, v));
            } else if (k == str(EYEWEAR)) {
                equip_trait(base_toad_object, mint_trait<Eyewear>(resource_signer, v));
            } else if (k == str(MOUTH)) {
                equip_trait(base_toad_object, mint_trait<Mouth>(resource_signer, v));
            } else if (k == str(FLY)) {
                equip_trait(base_toad_object, mint_trait<Fly>(resource_signer, v));
            } else {
                // do nothing, could throw an error here to be extra safe...ok I'll do it.
                error::invalid_state(EINVALID_PROPERTY_MAP_KEY);
            };
        };

        assert!(background != str(b""), error::invalid_state(ENO_BACKGROUND_TRAIT));
        assert!(body != str(b""), error::invalid_state(ENO_BODY_TRAIT));

        let perfect = (num_traits == 2);
        (perfect)
    }

    /// transfer the object from the toad object to its owner and set `allow_ungated_transfer`
    fun internal_transfer<T>(
        trait_obj: Object<T>,
        to: address,
        allow_ungated_transfer: bool,
    ) {
        assert!(object::is_owner(trait_obj, to), error::permission_denied(ENOT_OWNER));
        assert!(exists<Refs>(object::object_address(trait_obj)), error::invalid_state(EOBJECT_DOES_NOT_HAVE_REFS));

        let transfer_ref = &borrow_global<Refs>(object_address).transfer_ref;

        if (allow_ungated_transfer) {
            object::enable_ungated_transfer(transfer_ref);
        } else {
            object::disable_ungated_transfer(transfer_ref);
        };

        let linear_transfer_ref = object::generate_linear_transfer_ref(transfer_ref);
        object::transfer_with_ref(linear_transfer_ref);
    }

    /// stores the refs and returns the signer for convenience
    inline fun store_refs(constructor_ref: &ConstructorRef): &signer {
        // get refs and token_signer for storing later
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let mutator_ref = token_v2::generate_mutator_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);

        // store refs
        move_to(
            &object_signer,
            Refs {
                transfer_ref,
                extend_ref,
                mutator_ref,
            }
        );

        object_signer
    }


   fun create_base_traits(
      resource_signer: &signer,
      resource_addr: address,
      trait_collection_object: Object<Collection>,
      v2_trait_types: vector<String>,
      v2_trait_names: vector<String>,
      v2_trait_symbols: vector<String>,
      v2_trait_uris: vector<String>,
   ) {
      assert!(
         vector::length(&v2_trait_types) ==
         vector::length(&v2_trait_names) ==
         vector::length(&v2_trait_symbols) ==
         vector::length(&v2_trait_uris),
         error::invalid_argument(EVECTOR_LENGTHS_DO_NOT_MATCH)
      );

      vector::reverse(&mut v2_trait_types);
      vector::reverse(&mut v2_trait_names);
      vector::reverse(&mut v2_trait_symbols);
      vector::reverse(&mut v2_trait_uris);
      while(vector::length(&v2_trait_types) > 0) {
         let trait_type = vector::pop_back(&mut v2_trait_types);
         let trait_name = vector::pop_back(&mut v2_trait_names);
         let trait_symbol = vector::pop_back(&mut v2_trait_symbols);
         let trait_uri = vector::pop_back(&mut v2_trait_uris);
         create_base_fungible_trait(
            resource_signer,
            resource_addr,
            trait_collection_object,
            trait_type,
            trait_name,
            trait_symbol,
            trait_uri
         );
      };
   }

    fun create_base_fungible_trait<T>(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        trait_type: String,
        trait_name: String,
        symbol: String,
        image_uri: String,
    ): ConstructorRef {
        let collection_name = collection_v2::name(collection_object);
        let token_address = create_token_address(
            resource_addr,
            &collection_name,
            trait_name
        );
        assert!(!object::exists_at(token_address), error::invalid_state(ETRAIT_TYPE_ALREADY_EXISTS));

        let constructor_ref = token_v2::create_named_token(
            resource_signer,
            collection_name,
            get_trait_description(trait_type, trait_name),
            trait_name,
            option::none(), // using collection wide royalties
            image_uri,
        );

        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            &constructor_ref,
            option::none<u128>(),
            trait_name,
            symbol,
            0,
            image_uri,
            collection_v2::uri(collection_object),
        );

        if (trait_type == trait_type_to_string<Clothing>()) {
            move_to(&token_signer, Clothing { });
        } else if (trait_type == trait_type_to_string<Headwear>()) {
            move_to(&token_signer, Headwear { });
        } else if (trait_type == trait_type_to_string<Eyewear>()) {
            move_to(&token_signer, Eyewear { });
        } else if (trait_type == trait_type_to_string<Mouth>()) {
            move_to(&token_signer, Mouth { });
        } else if (trait_type == trait_type_to_string<Fly>()) {
            move_to(&token_signer, Fly { });
        };

        store_refs(&constructor_ref);
    }

    fun mint_trait<T>(
        resource_signer: &signer,
        resource_addr: address,
        collection_object: Object<Collection>,
        trait_type: String,
        trait_name: String,
        image_uri: String,
        // num_trait_type: u64,
    ): Object<T> {
        let constructor_ref = create_fungible_asset_or_smth(
            resource_signer,
            collection_object,
            image_uri,
        );
        let token_signer = store_refs(&constructor_ref);

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

        object::address_to_object(signer::address_of(&token_signer))
    }

    /// intended to only be used by the singular equip
    /// this function will fail if there isn't a valid slot to equip
    public entry fun equip_and_update<T: key>(
        owner: &signer,
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>,
        unvalidated_image_uri: String,
        proof: vector<vector<u8>>,
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        assert!(exists<Aptoad>(toad_object), error::invalid_argument(ENOT_A_TOAD));
        let owner_addr = signer::address_of(owner);
        assert!(object::is_owner(toad_object, owner_addr), error::permission_denied(ENOT_OWNER));
        assert!(object::is_owner(obj_to_equip, owner_addr), error::permission_denied(ENOT_OWNER));
        assert!(exists<T>(obj_to_equip), error::invalid_argument(EINVALID_TRAIT_TYPE));
        // may have to use this if the compiler gets mad at the previous line
        // TODO: Remove this or remove above
        assert!(is_a_trait_type(obj_to_equip), error::invalid_argument(EINVALID_TRAIT_TYPE));


        // make the change before creating the trait map
        equip_trait<T>(toad_object, obj_to_equip);

        // create the new trait map
        let new_trait_map = get_v2_trait_map(toad_object);

        // runs all checks to ensure the state of the toad is valid post-change
        let leaf_hash =
            verified_uri_update(new_trait_map, base_toad_object, unvalidated_image_uri, proof);
        let validated_image_uri = unvalidated_image_uri;

        // gate the trait equip/unequip by paying with $FLY or something?

        // NOTE: We do this here and not in `equip_trait` because otherwise the migration function would call this
        // 5 times (and it would fail because the Aptoad would only have 1 trait on the first equip)
        let abort_if_exists = false;
        try_unique_combination(
            leaf_hash,
            validated_image_uri,
            token_v2::creator(toad_object),
            toad_object,
            abort_if_exists,
        );

        let (background, body, clothing, headwear, eyewear, mouth, fly) =

        emit_new_combination_event(
            internal_get_aptoad_signer(toad_object),
            owner_addr,
            get_background(toad_object),
            get_body(toad_object),
            get_trait_name_from_toad<Clothing>(toad_object),
            get_trait_name_from_toad<Headwear>(toad_object),
            get_trait_name_from_toad<Eyewear>(toad_object),
            get_trait_name_from_toad<Mouth>(toad_object),
            get_trait_name_from_toad<Fly>(toad_object),
            get_trait_option_from_toad<Clothing>(toad_object),
            get_trait_option_from_toad<Headwear>(toad_object),
            get_trait_option_from_toad<Eyewear>(toad_object),
            get_trait_option_from_toad<Mouth>(toad_object),
            get_trait_option_from_toad<Fly>(toad_object),
        );
    }

    /// intended to only be used by the singular equip
    /// this function will fail if there isn't a valid slot to unequip
    public entry fun unequip_and_update<T: key>(
        owner: &signer,
        toad_object: Object<Aptoad>,
        unvalidated_image_uri: String,
        proof: vector<vector<u8>>,
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        assert!(exists<Aptoad>(toad_object), error::invalid_argument(ENOT_A_TOAD));
        let owner_addr = signer::address_of(owner);
        assert!(object::is_owner(toad_object, owner_addr), error::permission_denied(ENOT_OWNER));

        // make the change before creating the trait map
        unequip_trait<T>(toad_object);

        // create the new trait map
        let new_trait_map = get_v2_trait_map(toad_object);

        // runs all checks to ensure the state of the toad is valid post-change
        let leaf_hash =
            verified_uri_update(new_trait_map, base_toad_object, unvalidated_image_uri, proof);
        let validated_image_uri = unvalidated_image_uri;

        // gate the trait equip/unequip by paying with $FLY or something?

        // NOTE: We do this here and not in `equip_trait` because otherwise the migration function would call this
        // 5 times (and it would fail because the Aptoad would only have 1 trait on the first equip)
        let abort_if_exists = false;
        try_unique_combination(
            leaf_hash,
            validated_image_uri,
            token_v2::creator(toad_object),
            toad_object,
            abort_if_exists,
        );

        let (background, body, clothing, headwear, eyewear, mouth, fly) =

        emit_new_combination_event(
            internal_get_aptoad_signer(toad_object),
            owner_addr,
            get_background(toad_object),
            get_body(toad_object),
            get_trait_name_from_toad<Clothing>(toad_object),
            get_trait_name_from_toad<Headwear>(toad_object),
            get_trait_name_from_toad<Eyewear>(toad_object),
            get_trait_name_from_toad<Mouth>(toad_object),
            get_trait_name_from_toad<Fly>(toad_object),
            get_trait_option_from_toad<Clothing>(toad_object),
            get_trait_option_from_toad<Headwear>(toad_object),
            get_trait_option_from_toad<Eyewear>(toad_object),
            get_trait_option_from_toad<Mouth>(toad_object),
            get_trait_option_from_toad<Fly>(toad_object),
        );
    }

    /// intended to be used by both v1 => v2 creator and future equips/unequips
    inline fun equip_trait<T: key>(
        toad_object: Object<Aptoad>,
        obj_to_equip: Object<T>
    ) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
        let option_ref = get_trait_option_from_toad<T>(toad_object);
        /*
        let option_ref = if (exists<Clothing>(obj_to_equip)) {
            // let clothing_obj = object::convert<T, Clothing>(obj_to_equip);
            // option::fill<Object<Clothing>>(&mut toad_obj_resources.clothing, clothing_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).clothing
        } else if (exists<Headwear>(obj_to_equip)) {
            // let headwear_obj = object::convert<T, Headwear>(obj_to_equip);
            // option::fill<Object<Headwear>>(&mut toad_obj_resources.headwear, headwear_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).headwear
        } else if (exists<Eyewear>(obj_to_equip)) {
            // let eyewear_obj = object::convert<T, Eyewear>(obj_to_equip);
            // option::fill<Object<Eyewear>>(&mut toad_obj_resources.eyewear, eyewear_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).eyewear
        } else if (exists<Mouth>(obj_to_equip)) {
            // let mouth_obj = object::convert<T, Mouth>(obj_to_equip);
            // option::fill<Object<Mouth>>(&mut toad_obj_resources.mouth, mouth_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).mouth
        } else if (exists<Fly>(obj_to_equip)) {
            // let fly_obj = object::convert<T, Fly>(obj_to_equip);
            // option::fill<Object<Fly>>(&mut toad_obj_resources.fly, fly_obj);
            &mut borrow_global_mut<Aptoad>(toad_object).fly
        } else {
            abort error::invalid_argument(EINVALID_TRAIT_TYPE)
        };
        */

        assert!(!option::is_some(option_ref), error::invalid_state(ETRAIT_TYPE_ALREADY_EQUIPPED));
        option::fill<T>(option_ref, obj_to_equip);

        let allow_ungated_transfer = false;
        emit_equip_event(toad_object, obj_to_equip);
        internal_transfer(obj_to_equip, toad_object, allow_ungated_transfer);
    }

    inline fun unequip_trait<T: key>(
        toad_object: Object<Aptoad>,
    ) {
        let obj_to_unequip = get_trait_object_from_toad<T>(toad_object);

        let allow_ungated_transfer = true;
        emit_unequip_event(toad_object, obj_to_unequip);
        internal_transfer(object::owner(toad_object), obj_to_unequip, allow_ungated_transfer);
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
    ): vector<u8> acquires Refs {
        verify_num_traits(new_trait_map);

        let leaf_hash = assert_trait_combo_in_merkle(new_trait_map, image_uri, proof);
        assert!(exists<Refs>(obj_addr), error::not_found(EREFS_NOT_FOUND));
        let ref_resources = borrow_global<Refs>(obj_addr);
        let mutator_ref = &ref_resources.mutator_ref;
        token_v2::set_uri(mutator_ref, image_uri);

        // combo_object call
        leaf_hash
    }

    inline fun internal_get_aptoad_signer(
        toad_obj: Object<Aptoad>
    ): &signer acquires Refs {
        &generate_signer_for_extending(&borrow_global<Refs>(toad_obj).extend_ref)
    }

    /// Merely keeps the combo object field in the Aptoad object up to date with its owner
    /// This cannot be abused because the owner is verified.
    public fun set_unique_combination(
        toad_obj: Object<Aptoad>,
        new_combo_object: Object<UniqueCombination>
    ) acquires Aptoad {
        assert!(object::is_owner(new_combo_object, toad_obj), error::invalid_state(ETOAD_DOES_NOT_OWN_COMBO));
        // TODO: Remove, should be redundant
        assert!(exists_at<Aptoad>(toad_obj), error::not_found(ENOT_A_TOAD));
        *&borrow_global_mut<Aptoad>(toad_obj).unique_combination_obj = new_combo_object;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                          v1 => v2 migration                       ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// gets all the trait types and trait names from a toad in its property map
    /// and creates a v2 toad from it. Transfers the toad to the owner after creation
    /// and stores the v1 toad into a simple resource that holds it indefinitely. (would burn if could)
    /// tracks the # migrated and unmigrated to avoid potential backdoors
    public entry fun swap_v1_for_v2(
        owner: &signer,
        toad_name: String,
        creator_addr: address,
        collection_name: String,
        unvalidated_image_uri: String,
    ) {
        let (v1_token, keys, values) =
            extract_generic_v1_token_and_traits(owner, toad_name, creator_addr, collection_name);

        let (resource_signer, resource_addr) = lilypad::internal_get_resource_signer_and_addr(creator_addr);
        let collection_object = borrow_global<ToadCollectionConfig>(resource_addr).v2_collection_object;

        // create v2 version
        let aptoad_object = create_v2_toad(
            resource_signer,
            resource_addr,
            collection_object,
            v1_token,
            keys,
            values,
            unvalidated_image_uri,
        );

        let owner_addr = signer::address_of(owner);
        object::transfer(resource_signer, aptoad_object, owner_addr);

        store_v1_toad_and_track_migrated(
            owner,
            resource_signer,
            v1_token,
            aptoad_object,
        );
    }

   public fun store_v1_toad_and_track_migrated(
      owner: &signer,
      resource_signer: &signer,
      v1_token: OldToken,
      aptoad_object: Object<Aptoad>,
   ) {
      store_toad(v1_token);
      increment_migrated_and_decrement_unmigrated(resource_signer);
   }

   fun increment_migrated_and_decrement_unmigrated(
      resource_addr: address,
   ) acquires ToadCollectionConfig {
      let collection_v2_config = borrow_global_mut<ToadCollectionConfig>(resource_addr);
      *collection_v2_config.unmigrated_v1_tokens = *collection_v2_config.unmigrated_v1_tokens - 1;
      *collection_v2_config.migrated_v1_tokens = *collection_v2_config.migrated_v1_tokens + 1;
      assert!(*collection_v2_config.migrated_v1_tokens + *collection_v2_config.unmigrated_v1_tokens == MAXIMUM_SUPPLY,
         error::invalid_state(ESUPPLY_OUT_OF_SYNC));
   }

   public fun assert_is_ready_for_migration(
      resource_addr: address,
      v1_collection_name: String,
      v2_collection_name: String,
   ) acquires Preconditions {
      assert!(is_ready_for_migration(resource_addr, v1_collection_name, v2_collection_name),
         error::invalid_state(ECOMBO_OBJECTS_NOT_PRECREATED));
   }

   #[view]
   /// we ensure the collection is ready for migration by checking to see how many combo objects
   /// have been created. It needs to match the collection supply, because the combo objects
   /// need to be pre-defined before migrating, otherwise early migraters could equip/unequip
   /// and sit on someone else's toad configuration, never allowing them to migrate
   public fun is_ready_for_migration(
      resource_addr: address,
      v1_collection_name: String,
      v2_collection_name: String,
      num_combo_objects: u64,
   ): bool acquires Preconditions {
      let v2_collection_addr = collection_v2::create_collection_address(&resource_addr, &v2_collection_name);
      assert!(object::exists_at<Collection>(v2_collection_addr), error::not_found(ECOLLECTION_DOES_NOT_EXIST));
      let collection_obj = object::address_to_object<Collection>(v2_collection_addr);

      // TODO: Check max supply? No way to do it yet for v2.
      let v1_current_supply = token_v1::get_collection_supply(resource_addr, v1_collection_name);
      let v1_max_supply = token_v1::get_collection_maximum(resource_addr, v1_collection_name);
      //let v2_current_supply = collection_v2::count(collection_object);

      //assert!(v1_max_supply == v2_max_supply, error::invalid_state(EMAXIMUM_DOES_NOT_MATCH));
      get_num_combo_objects(resource_addr) == v1_max_supply
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

    #[view]
    public fun get_unique_combination(toad_obj: Object<Aptoad>): Object<UniqueCombination> acquires Aptoad{
        assert!(exists_at<Aptoad>(toad_obj), error::not_found(ENOT_A_TOAD));
        &borrow_global<Aptoad>(aptoad).unique_combination_obj
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
        let trait_type_emoji = if (trait_type == str(CLOTHING))   { x"F09F9195" }
                          else if (trait_type == str(HEADWEAR))   { x"F09FA7A2" }
                          else if (trait_type == str(EYEWEAR))    { x"F09F95B6" }
                          else if (trait_type == str(MOUTH))      { x"F09F9184" }
                          else if (trait_type == str(FLY))        { x"F09FAAB0" }
                          else { abort error::invalid_argument(EINVALID_TRAIT_TYPE) };

        std::string_utils::format2(TRAIT_DESCRIPTION_FORMAT, trait_type, trait_type_emoji);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                             migration                             ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   struct ToadCollectionConfig has key {
      unmigrated_v1_tokens: u64,
      migrated_v1_tokens: u64,
      v1_collection: String,
      v2_collection: String,
      v2_collection_object: Object<Collection>,
      extend_ref: ExtendRef,
      transfer_ref: TransferRef,
      mutator_ref: CollectionMutatorRef,
      merkle_tree: MerkleTree,
   }

   struct TraitCollectionConfig has key {
      v2_collection: String,
      v2_collection_object: Object<Collection>,
      extend_ref: ExtendRef,
      transfer_ref: TransferRef,
      mutator_ref: CollectionMutatorRef,
   }

   struct ToadStore has key {
      inner: Table<TokenId, OldToken>,
   }

   public fun initialize_v2_collection(
      creator: &signer,
      v1_collection_name: String,
      v2_collection_name: String,
      v2_collection_description: String,
      v2_collection_uri: String,
      new_royalty_numerator: u64,
      new_royalty_denominator: u64,
      treasury_address: address,
      root_hash: vector<u8>,
      v2_trait_collection_name: String,
      v2_trait_collection_description: String,
      v2_trait_collection_uri: String,
      v2_trait_types: vector<String>,
      v2_trait_names: vector<String>,
      v2_trait_symbols: vector<String>,
      v2_trait_uris: vector<String>,
   ) acquires ToadCollectionConfig {
      let creator_addr = signer::address_of(creator);
      lilypad::assert_lilypad_exists(creator_addr);
      let (resource_signer, resource_addr) = lilypad::internal_get_resource_signer_and_addr(creator_addr);

      // ensures the original collection exists (and is, by implication, owned by `resource_signer`)
      token_v1::check_collection_exists(resource_addr, v1_collection_name);

      // check maximums and supplies
      let maximum = *option::extract(token_v1::get_collection_maximum(resource_addr, v1_collection_name));
      let supply = *option::extract(token_v1::get_collection_supply(resource_addr, v1_collection_name));
      assert!(maximum == supply, error::invalid_state(EMAX_NOT_SUPPLY));
      assert!(maximum == MAXIMUM_SUPPLY, error::invalid_state(EMAXIMUM_DOES_NOT_MATCH));

      let royalty_obj = royalty::create(new_royalty_numerator, new_royalty_denominator, treasury_address);

      // create the collection & get its constructor ref
      let toad_collection_constructor_ref = collection_v2::create_fixed_collection(
         &resource_signer,
         v2_collection_description,
         MAXIMUM_SUPPLY,
         v2_collection_name,
         royalty_obj,
         v2_collection_uri,
      );

      // create object reference and refs from constructor_ref
      let toad_collection_object = object::object_from_constructor_ref<Collection>(&toad_collection_constructor_ref);
      let extend_ref = object::generate_extend_ref(&toad_collection_constructor_ref);
      let transfer_ref = object::generate_transfer_ref(&toad_collection_constructor_ref);
      let mutator_ref = collection_v2::generate_mutator_ref(&toad_collection_constructor_ref);

      // store misc info in collection config for bookkeeping as well as the collection object refs
      // this also creates & stores the merkle tree root hash, which is our validator for
      // image URLs created from a hash of the concatenation of all `TRAIT_TYPE::TRAIT_NAME`s
      move_to(
         &resource_signer,
         ToadCollectionConfig {
            unmigrated_v1_tokens: MAXIMUM_SUPPLY,
            migrated_v1_tokens: 0,
            v1_collection: v1_collection_name,
            v2_collection: v2_collection_name,
            v2_collection_object: toad_collection_object,
            extend_ref: extend_ref,
            transfer_ref: transfer_ref,
            mutator_ref: mutator_ref,
            merkle_tree: merkle_tree::new(root_hash),
         }
      );

      // add the creator_addr to the resource address so we can obtain it easily
      lilypad::add_creator_addr_to_resource_signer(creator);

      let trait_collection_constructor_ref = initialize_trait_collection(
         resource_signer,
         v2_trait_collection_name,
         v2_trait_collection_description,
         v2_trait_collection_uri,
         royalty_obj,
      );

      let trait_collection_object = object::object_from_constructor_ref<Collection>(&trait_collection_constructor_ref);

      create_base_traits(
         resource_signer,
         resource_addr,
         trait_collection_object,
         v2_trait_types,
         v2_trait_names,
         v2_trait_symbols,
         v2_trait_uris,
      );

      assert_is_ready_for_migration(resource_addr, v1_collection_name, v2_collection_name);
   }

   public fun get_collection_name(): String {
      str(COLLECTION_NAME)
   }

   fun initialize_trait_collection(
      resource_signer: &signer,
      v2_trait_collection_name: String,
      v2_trait_collection_description: String,
      v2_trait_collection_uri: String,
      royalty_obj: Object<Royalty>,
   ): &ConstructorRef {
       // create the collection & get its constructor ref
      let collection_constructor_ref = collection_v2::create_unlimited_collection(
         &resource_signer,
         v2_trait_collection_description,
         v2_trait_collection_name,
         royalty_obj,
         v2_trait_collection_uri,
      );

      // create object reference and refs from constructor_ref
      let collection_object = object::object_from_constructor_ref<Collection>(&collection_constructor_ref);
      let extend_ref = object::generate_extend_ref(&collection_constructor_ref);
      let transfer_ref = object::generate_transfer_ref(&collection_constructor_ref);
      let mutator_ref = collection_v2::generate_mutator_ref(&collection_constructor_ref);

      // store misc info in collection config for bookkeeping as well as the collection object refs
      move_to(
         &resource_signer,
         TraitCollectionConfig {
            v2_collection: v2_trait_collection_name,
            v2_collection_object: collection_object,
            extend_ref: extend_ref,
            transfer_ref: transfer_ref,
            mutator_ref: mutator_ref,
         }
      );

      &collection_constructor_ref
   }

   fun store_toad(
      resource_signer: &signer,
      token: OldToken,
   ) acquires ToadStore {
      let resource_addr = signer::address_of(resource_signer);
      assert!(exists<ToadStore>(resource_addr), error::invalid_state(ETOAD_STORE_DOES_NOT_EXIST));
      let toad_store = borrow_global_mut<ToadStore>(resource_addr);
      table::add(&mut toad_store.inner, token.id, token);
   }

   #[view]
   public fun get_merkle_tree(
      resource_addr: address,
   ): MerkleTree acquires ToadCollectionConfig {
      borrow_global<ToadCollectionConfig>(resource_addr).merkle_tree
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
    ): vector<u8> {
        let concatenated_traits = join_traits(&trait_map, str(DELIMITER));
        let concatenated_trait_and_url = join_strings(concatenated_traits, concatenated_trait_and_url);
        let concatenated_trait_string = to_upper(concatenated_trait_and_url);
        let concatenated_trait_bytes = *string::bytes(&concatenated_trait_string);
        let internally_verified_leaf_hash = hash::sha3_256(concatenated_trait_bytes);

        let merkle_tree = get_merkle_tree();
        merkle_tree::assert_verify_proof(
            merkle_tree,
            internally_verified_leaf_hash,
            proof
        );

        std::debug::print(&concatenated_trait_string);
        internally_verified_leaf_hash
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

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                         misc, event emitters                      ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    /// Emits a new combination event from the Aptoad Token Object
    inline fun emit_new_combination_event(
        token_signer: &signer,
        owner_addr: address,
        background: String,
        body: String,
        clothing: String,
        headwear: String,
        eyewear: String,
        mouth: String,
        fly: String,
        clothing_obj: Option<Object<Clothing>>,
        headwear_obj: Option<Object<Headwear>>,
        eyewear_obj: Option<Object<Eyewear>>,
        mouth_obj: Option<Object<Mouth>>,
        fly_obj: Option<Object<Fly>>,
    ) acquires EventHandles {
        let event_handles = borrow_global_mut<EventHandles>(signer::address_of(token_signer));
        event::emit_event(
            &mut event_handles.new_combination_events,
            NewCombinationEvent {
                toad_obj: object::address_to_object<Aptoad>(signer::address_of(token_signer)),
                old_collection_name,
                owner_addr,
                background,
                body,
                clothing,
                headwear,
                eyewear,
                mouth,
                fly,
                clothing_obj,
                headwear_obj,
                eyewear_obj,
                mouth_obj,
                fly_obj,
            }
        );
    }

    inline fun emit_migration_event(
        token_signer: &signer,
        creator: address,
        old_collection_name: String,
        new_collection_name: String,
        new_collection: Object<Collection>,
        new_token_name: String,
        toad_object: Object<Aptoad>,
        perfect: bool,
    ) acquires EventHandles {
        let event_handles = borrow_global_mut<EventHandles>(signer::address_of(token_signer));
        event::emit_event(
            &mut event_handles.migration_events,
            MigrationEvent {
                creator,
                old_collection_name,
                new_collection_name,
                new_collection,
                new_token_name,
                toad_object,
                perfect,
            }
        );
    }

    inline fun emit_equip_event(
        toad_object: Object<Aptoad>,
        equipped_trait: Object<Token>,
    ) acquires EventHandles {
        let event_handles = borrow_global_mut<EventHandles>(signer::address_of(token_signer));
        event::emit_event(
            &mut event_handles.equip_events,
            EquipEvent {
                toad_object,
                equipped_trait,
            }
        );
    }

    inline fun emit_unequip_event(
        toad_object: Object<Aptoad>,
        unequipped_trait: Object<Token>,
    ) acquires EventHandles {
        let event_handles = borrow_global_mut<EventHandles>(signer::address_of(token_signer));
        event::emit_event(
            &mut event_handles.unequip_events,
            UnequipEvent {
                toad_object,
                unequipped_trait,
            }
        );
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                            trait combo                            ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Can't have

    #[view]
    public fun get_address_combo(
        resource_address: address,
        leaf_hash: vector<u8>,
    ): address {
        let seed = copy leaf_hash;
        vector::append(&mut seed, COMBO_SALT);
        object::create_object_address(&resource_address, seed)
    }

    #[view]
    public fun trait_combo_exists(
        at: address,
    ): (bool) {
        exists<UniqueCombination>(obj_addr)
    }

    #[view]
    public fun trait_combo_in_use(
        at: address,
        resource_addr: address,
    ): bool {
        assert!(trait_combo_exists(at), error::invalid_argument(ETRAIT_COMBO_DOES_NOT_EXIST));
        !object::is_owner(at, resource_addr)
    }

    #[view]
    public fun get_num_combo_objects(
        resource_addr: address,
    ): u64 {
        borrow_global<Preconditions>(resource_addr).num_combo_objects
    }

    /// This function tries to create the unique combo object
    /// If it fails, it uses the existing combo address for the combo object reference
    /// It then transfers the existing combo object to the resource address
    /// and transfers the new combo object to the toad object.
    fun try_unique_combination(
        leaf_hash: vector<u8>,
        image_uri: String,
        resource_address: address,
        toad_obj: Object<Aptoad>,
        abort_if_exists: bool,
    ) acquires UniqueCombination, Aptoad {
        let creator_addr = lilypad::get_creator_addr(resource_address);
        let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(creator_addr);
        let trait_combo_obj = try_create_unique_combination(
                leaf_hash,
                image_uri,
                resource_address,
                abort_if_exists,
        );
        update_combo_owners(
            trait_combo_obj,
            resource_address,
            toad_obj,
        );
    }

    /// This function creates a unique combination object from the given toad object and its traits.
    /// Each combo object is created by the resource signer, can be found with `get_address_combo(...)`
    /// Each unique combination is an object and it represents a slot in a global
    /// pseudo-dictionary of combination data.
    /// Does not verify the existence of the combination in the merkle tree, merely creates/uses it.
    inline fun try_create_unique_combination(
        leaf_hash: vector<u8>,
        image_uri: String,
        resource_addr: address,
        abort_if_exists: bool,
    ): Object<UniqueCombination> acquires UniqueCombination {
        let creator_addr = lilypad::get_creator_addr(resource_addr);
        let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(creator_addr);
        let trait_combo_address = get_address_combo(&resource_address, leaf_hash);
        if (abort_if_exists) {
            assert!(!trait_combo_exists(trait_combo_address),
                error::invalid_state(ETRAIT_COMBO_ALREADY_EXISTS));
        };

        let constructor_ref = object::create_named_object(resource_signer, leaf_hash);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        let object_signer = object::generate_signer(&constructor_ref);

        object::disable_ungated_transfer(&transfer_ref);

        move_to(
            &object_signer,
            UniqueCombination {
                image_uri,
                transfer_ref,
                extend_ref,
                event_handle: event_handle,
            }
        );

        let num_objs = borrow_global_mut<Preconditions>(trait_combo_address).num_combo_objects;
        *num_objs = *num_objs + 1;

        object::object_from_constructor_ref<UniqueCombination>(&constructor_ref)
    }

    inline fun get_event_handle(
        trait_combo_address: address,
    ): &EventHandle<CreateUniqueCombinationEvent> acquires UniqueCombination {
        &borrow_global_mut<UniqueCombination>(trait_combo_address).event_handle
    }

    inline fun get_transfer_ref(
        trait_combo_address: address,
    ): &TransferRef acquires UniqueCombination {
        &borrow_global_mut<UniqueCombination>(trait_combo_address).event_handle
    }

    /// The Aptoad Token Object must exist at this point.
    /// This changes the owner of the existing, in use Combo Object from the Aptoad to the resource address
    /// And changes the owner of the (possibly) new Combo Object to the Aptoad from the resource addr
    inline fun update_combo_owners(
        new_combo_object: Object<UniqueCombination>,
        resource_addr: address,
        toad_obj: Object<Aptoad>,
    ) acquires UniqueCombination, Aptoad {
        assert!(trait_combo_exists(new_combo_object), error::not_found(ETRAIT_COMBO_DOES_NOT_EXIST));

        // transfer the existing combo object to the resource_addr
        let existing_combo_object = get_unique_combination(toad_obj);

        if (existing_combo_object == new_combo_object) {
            return
        };

        // the toad should own the previous/existing combo object
        assert!(object::is_owner(existing_combo_object, toad_obj), error::invalid_state(EINVALID_STATE));
        let existing_combo_object_transfer_ref = get_transfer_ref(existing_combo_object);
        object::transfer_with_ref(
            object::generate_linear_transfer_ref(existing_combo_object_transfer_ref, resource_addr)
        );

        // resource_addr should own the new trait combo object
        assert!(object::is_owner(new_combo_object, resource_addr), error::invalid_state(EINVALID_STATE));
        object::transfer_ref(
            object::generate_linear_transfer_ref(get_transfer_ref(new_combo_object), toad_obj)
        );

        set_unique_combination(toad_obj, new_combo_object);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////                                                                   ///////////////////////
    ///////////////////////                             unit tests                            ///////////////////////
    ///////////////////////                                                                   ///////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
