/// This module serves to discern whether or not a unique combination of traits already exists.
/// We hash the trait_types::trait_names in a concatenated string together and then use that as a seed
/// for the derived resource account.
/// We copy all the trait values and objects at the time of creation, and set a flag that specifies
/// whether or not the UniqueCombination is currently in use.
module pond::trait_combo {
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

    struct UniqueCombination has key {
        image_uri: String,
        transfer_ref: TransferRef,
        extend_ref: ExtendRef,
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
    /// Incorrect combination of resource address and v2 collection name.
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 5;
    /// Aptoad object not found at the given address.
    const ENOT_A_TOAD: u64 = 6;
    /// One of the arguments must be a toad or the creator resource address.
    const EINVALID_ARGUMENTS: u64 = 7;
    /// The given Aptoad Token Object is not in a collection owned by the given creator resource address.
    const ETOKEN_NOT_IN_COLLECTION: u64 = 8;
    /// The expectations for the internal state of the contract has been violated.
    const EINVALID_STATE: u64 = 9;

    const COMBO_SALT: vector<u8> = b"COMBO";

    #[view]
    public fun get_address(
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
    /// we ensure the collection is ready for migration by checking to see how many combo objects
    /// have been created. It needs to match the collection supply, because the combo objects
    /// need to be pre-defined before migrating, otherwise early migraters could equip/unequip
    /// and sit on someone else's toad configuration, never allowing them to migrate
    public fun is_ready_for_migration(
        resource_addr: address,
        v1_collection_name: String,
        v2_collection_name: String,
    ) acquires Preconditions {
        let v2_collection_addr = collection_v2::create_collection_address(&resource_addr, &v2_collection_name);
        assert!(object::exists_at<Collection>(v2_collection_addr), error::not_found(ECOLLECTION_DOES_NOT_EXIST));
        let collection_obj = object::address_to_object<Collection>(v2_collection_addr);

        // TODO: Check max supply? No way to do it yet for v2.
        let v1_current_supply = token_v1::get_collection_supply(resource_addr, v1_collection_name);
        let v1_max_supply = token_v1::get_collection_maximum(resource_addr, v1_collection_name);
        //let v2_current_supply = collection_v2::count(collection_object);

        assert!(borrow_global<Preconditions>(resource_addr).num_combo_objects == v1_max_supply,
            error::invalid_state(ECOMBO_OBJECTS_NOT_PRECREATED));
        //assert!(v1_max_supply == v2_max_supply, error::invalid_state(EMAXIMUM_DOES_NOT_MATCH));
    }

    /// This function tries to create the unique combo object
    /// If it fails, it uses the existing combo address for the combo object reference
    /// It then transfers the existing combo object to the resource address
    /// and transfers the new combo object to the toad object.
    public(friend) fun try_unique_combination(
        leaf_hash: vector<u8>,
        image_uri: String,
        resource_address: address,
        toad_obj: Object<Aptoad>,
        abort_if_exists: bool,
    ) acquires UniqueCombination, Aptoad {
        // let toad_token = object::convert<Aptoad, Token>(toad_obj);
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
    /// Each combo object is created by the resource signer, can be found with `get_address(...)`
    /// Each unique combination is an object and it represents a slot in a global
    /// pseudo-dictionary of combination data.
    /// Does not verify the existence of the combination in the merkle tree, merely creates/uses it.
    inline fun try_create_unique_combination(
        leaf_hash: vector<u8>,
        image_uri: String,
        resource_addr: address,
        abort_if_exists: bool,
    ): Object<UniqueCombination> acquires UniqueCombination {
        // let toad_token = object::convert<Aptoad, Token>(toad_obj);
        let creator_addr = lilypad::get_creator_addr(resource_addr);
        let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(creator_addr);
        let trait_combo_address = get_address(&resource_address, leaf_hash);
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
        let existing_combo_object = toad_v2::get_unique_combination(toad_obj);

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

        toad_v2::set_unique_combination(toad_obj, new_combo_object);
    }

    // public(friend) fun get_in_use(
    //     resource_addr: address,
    //     trait_combo_address: address,
    // ) {

    // }

}
