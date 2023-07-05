/// This module serves to discern whether or not a unique combination of traits already exists.
/// We hash the trait_types::trait_names in a concatenated string together and then use that as a seed
/// for the derived resource account.
/// We copy all the trait values and objects at the time of creation, and set a flag that specifies
/// whether or not the UniqueCombination is currently in use.
module pond::unique_combinations {
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
    use std::error;
    use std::event::{Self, EventHandle};
    use pond::toad_v2::{Aptoad};
    use pond::lilypad::{internal_get_resource_signer_and_addr};
    friend pond::toad_v2;

    struct Preconditions has key {
        num_combo_objects: u64,
    }

    struct CombinationConfig has key {
        in_use: bool,
        image_uri: String,
        transfer_ref: TransferRef,
        extend_ref: ExtendRef,
        new_combination_events: EventHandle<CreateUniqueCombinationEvent>,
    }

    struct CreateUniqueCombinationEvent has copy, drop, store {
        toad_obj: Option<Object<Aptoad>>,
        created_by: address,
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

    /// That trait combination already exists.
    const ETRAIT_COMBO_ALREADY_EXISTS: u64 = 0;
    /// That trait combination does not exist.
    const ETRAIT_COMBO_DOES_NOT_EXIST: u64 = 1;
    /// That combination is already in use.
    const ETRAIT_COMBO_IN_USE: u64 = 2;
    /// The maximum supplies of the collections do not match.
    const EMAXIMUM_DOES_NOT_MATCH: u64 = 3;
    /// The combination objects need to be created prior to enabling the migration.
    const ECOMBO_OBJECTS_NOT_PRECREATED: u64 = 4;

    #[view]
    public fun get_address(
        resource_address: address,
        leaf_hash: vector<u8>,
    ): address {
        object::create_object_address(&resource_address, leaf_hash)
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
    ): bool {
        assert!(trait_combo_exists(at), error::invalid_argument(ETRAIT_COMBO_DOES_NOT_EXIST));
        exists<UniqueCombination>(obj_addr)
    }

    #[view]
    /// we ensure the collection is ready for migration by checking to see how many combo objects
    /// have been created. It needs to match the collection supply, because the combo objects
    /// need to be pre-defined before migrating, otherwise early migraters could equip/unequip
    /// and sit on someone else's toad configuration, never allowing them to migrate
    public fun is_ready_for_migration(
        resource_addr: address,
    ) acquires Preconditions {
        let v1_max_supply = 0;
        let v2_max_supply = 0;
        assert!(v1_max_supply == v2_max_supply, error::invalid_state(EMAXIMUM_DOES_NOT_MATCH));
        let resource_creator_addr = collection_v2::creator(collection_object);
        assert!(borrow_global<Preconditions>(resource_addr).num_combo_objects == v2_max_supply,
            error::invalid_state(ECOMBO_OBJECTS_NOT_PRECREATED));
    }

    public(friend) fun precreate_combos(
        leaf_hashes: vector<vector<u8>>,
        image_uris: vector<u8>,
    )

    public(friend) fun try_unique_combination(
        leaf_hash: vector<u8>,
        image_uri: String,
        toad_obj: Option<Object<Aptoad>>,
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
    ) acquires UniqueCombination {
        // let toad_token = object::convert<Aptoad, Token>(toad_obj);
        let resource_addr = token_v2::creator(toad_obj);
        let creator_addr = lilypad::get_creator_addr(resource_addr);
        let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(creator_addr);
        let trait_combo_address = get_address(&resource_address, leaf_hash);
        if (!trait_combo_exists(trait_combo_address)) {
            let constructor_ref = object::create_named_object(resource_signer, leaf_hash);
            let transfer_ref = object::generate_transfer_ref(&constructor_ref);
            let extend_ref = object::generate_extend_ref(&constructor_ref);
            let object_signer = object::generate_signer(&constructor_ref);

            object::disable_ungated_transfer(&transfer_ref);

            let event_handle = event::new_event_handle<CreateUniqueCombinationEvent>(&object_signer);

            event::emit_event(
                &mut event_handle,
                CreateUniqueCombinationEvent {
                    toad_obj,
                    created_by,
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

            move_to(
                &object_signer,
                CombinationConfig {
                    in_use: true,
                    image_uri,
                    transfer_ref,
                    extend_ref,
                    new_combination_events: event_handle,
                }
            );
        } else {
            set_in_use(trait_combo_address, true);
        };
    }

    public(friend) fun set_in_use_from_toad<Aptoad>(
        toad_obj: Object<Aptoad>,
    ) acquires CombinationConfig {
        set_in_use(
            get_address()
        )
    }

    public(friend) fun set_in_use(
        trait_combo_address: address,
        in_use: bool,
    ) acquires CombinationConfig {
        assert!(trait_combo_in_use(trait_combo_address), error::already_exists(ETRAIT_COMBO_IN_USE));
        *borrow_global_mut<UniqueCombination>(trait_combo_address).in_use = in_use;
    }

}
