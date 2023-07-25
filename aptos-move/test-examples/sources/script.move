script {
    use aptos_framework::object::{Self};
    use std::vector;

    const WIZZY: address = @0xffc117086980d34dc3b5a42cb407ed888f60623f46021f35c2ca522ea13cc961;

    fun init(creator: &signer) {
        let constructor_ref = object::create_object_from_account(creator);
        let _constructor_ref2 = object::create_object_from_account(creator);
        //let delete_ref = object::generate_delete_ref(&constructor_ref);
        let obj_addresses = vector<address> [
            object::address_from_constructor_ref(&constructor_ref)
        ];
        vector::for_each(obj_addresses, |obj_addr| {
            object::transfer_raw(creator, obj_addr, WIZZY);
        });
    }
}
