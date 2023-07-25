module test_examples::delete_object {
    use aptos_framework::object::{Self, ExtendRef, DeleteRef};

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct ObjectInfo has key {
        extend_ref: ExtendRef,
        delete_ref: DeleteRef,
    }

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
    struct TestResource has key {
        value: u64,
    }

    fun init(creator: &signer) acquires ObjectInfo {
        let constructor_ref = object::create_object_from_account(creator);
        let obj_signer = object::generate_signer(&constructor_ref);
        let obj_address = object::address_from_constructor_ref(&constructor_ref);
        move_to(
            &obj_signer,
            ObjectInfo {
                extend_ref: object::generate_extend_ref(&constructor_ref),
                delete_ref: object::generate_delete_ref(&constructor_ref),
            },
        );

        // let _ = move_from<Resource>();

        // let TokenOffer {
        //     fee_schedule: _,
        //     item_price: _,
        //     expiration_time: _,
        //     delete_ref,
        // } = move_from(token_offer_addr);

        let ObjectInfo {
            extend_ref: _,
            delete_ref,
        } = move_from<ObjectInfo>(obj_address);

        object::delete(delete_ref);
    }

    public entry fun create_obj_and_resource(creator: &signer) acquires ObjectInfo {
        let obj_address = create(creator);
        add_resource(obj_address);
    }

    public entry fun update_resource(obj_address: address, new_value: u64) acquires TestResource {
        borrow_global_mut<TestResource>(obj_address).value = new_value;
    }

    public entry fun create_obj(creator: &signer) {
        create(creator);
    }

    public fun create(creator: &signer): address {
        let constructor_ref = object::create_object_from_account(creator);
        let obj_signer = object::generate_signer(&constructor_ref);
        move_to(
            &obj_signer,
            ObjectInfo {
                extend_ref: object::generate_extend_ref(&constructor_ref),
                delete_ref: object::generate_delete_ref(&constructor_ref),
            },
        );
        object::address_from_constructor_ref(&constructor_ref)
    }

    public entry fun add_resource(obj_address: address) acquires ObjectInfo {
        let extend_ref = &borrow_global<ObjectInfo>(obj_address).extend_ref;
        let obj_signer = object::generate_signer_for_extending(extend_ref);
        move_to(
            &obj_signer,
            TestResource {
                value: 0,
            },
        );
    }

    public entry fun delete_resource(obj_address: address) acquires TestResource {
        let TestResource {
            value: _,
        } = move_from<TestResource>(obj_address);
    }

    #[test(creator = @0xfa)]
    fun test(creator: &signer) acquires ObjectInfo {
        init(creator);
    }

}
