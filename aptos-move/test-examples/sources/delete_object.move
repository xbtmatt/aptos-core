module test_examples::delete_object {
    use aptos_framework::object::{Self, DeleteRef};
    use aptos_framework::aptos_account;

    struct ObjectInfo has key {
        delete_ref: DeleteRef,
    }

    fun init(creator: &signer) acquires ObjectInfo {
        aptos_account::create_account(std::signer::address_of(creator));
        let constructor_ref = object::create_object_from_account(creator);
        let obj_signer = object::generate_signer(&constructor_ref);
        let obj_address = object::address_from_constructor_ref(&constructor_ref);
        move_to(
            &obj_signer,
            ObjectInfo {
                delete_ref: object::generate_delete_ref(&constructor_ref),
            },
        );

        let ObjectInfo {
            delete_ref,
        } = move_from<ObjectInfo>(obj_address);

        object::delete(delete_ref);
    }

    #[test(creator = @0xfa)]
    fun test(creator: &signer) acquires ObjectInfo {
        init(creator);
    }

}
