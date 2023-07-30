module test_examples::property_map_utils{
    use std::string::{String, utf8 as str};
    use std::object;
    use std::from_bcs;
    use std::vector;
    use std::simple_map::{Self, SimpleMap};
    use aptos_token_objects::property_map::{Self, PropertyMap};
    use no_code_mint::package_manager;
    use std::error;
    use std::type_info;

    /// That key doesn't exist in the property map.
    const EKEY_NOT_FOUND: u64 = 0;
    /// That isn't a valid property map type.
    const EINVALID_PROPERTY_TYPE: u64 = 1;

    struct Map<T: copy + drop + store> has key {
        values: SimpleMap<String, T>
    }

    struct Value<T> has key {
        value: T,
    }

    inline fun try_initialize<T: copy + drop + store>() {
        if (!exists<Map<T>>(@no_code_mint)) {
            let package_signer = package_manager::get_signer();
            move_to(
                &package_signer,
                Map {
                    values: simple_map::create<String, T>(),
                }
            );
        };
    }

    public entry fun add<T: copy + drop + store>(
        keys: vector<String>,
        values: vector<T>,
    ) acquires Map {
        vector::enumerate_ref(&keys, |i, key| {
            add_key(*key, *vector::borrow(&values, i));
        });
    }

    public entry fun add_key<T: copy + drop + store>(
        key: String,
        value: T,
    ) acquires Map {
        try_initialize<T>();
        let simple_maps = borrow_global_mut<Map<T>>(@no_code_mint);
        simple_map::add(&mut simple_maps.values, key, value);
    }

    #[view]
    public fun read_key<T: copy + drop + store>(
        key: String,
    ): T acquires Map {
        try_initialize<T>();
        let simple_maps = borrow_global<Map<T>>(@no_code_mint);
        assert!(simple_map::contains_key(&simple_maps.values, &key), error::invalid_argument(EKEY_NOT_FOUND));
        *simple_map::borrow(&simple_maps.values, &key)
    }

    fun try_initialize_value<T: copy + drop + store>(v: T) {
        if (!exists<Value<T>>(@no_code_mint)) {
            let package_signer = package_manager::get_signer();
            move_to(
                &package_signer,
                Value {
                    value: v,
                }
            );
        };
    }

    fun update_val<T: copy + drop + store>(v: T) acquires Value {
        try_initialize_value<T>(v);        
        borrow_global_mut<Value<T>>(@no_code_mint).value = v;
    }

    fun read_val<T: copy + drop + store>(): T acquires Value {
        borrow_global<Value<T>>(@no_code_mint).value
    }

    #[view]
    public fun view_input_types<T0, T1, T2, T3, T4, T5, T6, T7, T8, T9>(): vector<String> {
        vector<String> [
            type_info::type_name<T0>(),
            type_info::type_name<T1>(),
            type_info::type_name<T2>(),
            type_info::type_name<T3>(),
            type_info::type_name<T4>(),
            type_info::type_name<T5>(),
            type_info::type_name<T6>(),
            type_info::type_name<T7>(),
            type_info::type_name<T8>(),
            type_info::type_name<T9>(),
        ]
    }

    #[view]
    public fun view_all_types(): vector<String> {
        vector<String> [
            type_info::type_name<bool>(),
            type_info::type_name<u8>(),
            type_info::type_name<u16>(),
            type_info::type_name<u32>(),
            type_info::type_name<u64>(),
            type_info::type_name<u128>(),
            type_info::type_name<u256>(),
            type_info::type_name<address>(),
            type_info::type_name<vector<u8>>(),
            type_info::type_name<String>(),
        ]
    }

    #[view]
    public fun read_string_property_map_key(
        obj_addr: address,
        key: String,
    ): String {
        let property_map_obj = object::address_to_object<PropertyMap>(obj_addr);
        property_map::read_string(&property_map_obj, &key)
    }

    #[view]
    public fun read_property_map_key<T: copy + drop + store>(
        obj_addr: address,
        key: String,
    ): T acquires Value {
        let property_map_obj = object::address_to_object<PropertyMap>(obj_addr);
        let type = type_info::type_name<T>();
        if (type == type_info::type_name<bool>()) {
            update_val<bool>(property_map::read_bool(&property_map_obj, &key));
        } else if (type == type_info::type_name<u8>()) {
            update_val<u8>(property_map::read_u8(&property_map_obj, &key));
        } else if (type == type_info::type_name<u16>()) {
            update_val<u16>(property_map::read_u16(&property_map_obj, &key));
        } else if (type == type_info::type_name<u32>()) {
            update_val<u32>(property_map::read_u32(&property_map_obj, &key));
        } else if (type == type_info::type_name<u64>()) {
            update_val<u64>(property_map::read_u64(&property_map_obj, &key));
        } else if (type == type_info::type_name<u128>()) {
            update_val<u128>(property_map::read_u128(&property_map_obj, &key));
        } else if (type == type_info::type_name<u256>()) {
            update_val<u256>(property_map::read_u256(&property_map_obj, &key));
        } else if (type == type_info::type_name<address>()) {
            update_val<address>(property_map::read_address(&property_map_obj, &key));
        } else if (type == type_info::type_name<vector<u8>>()) {
            update_val<vector<u8>>(property_map::read_bytes(&property_map_obj, &key));
        } else if (type == type_info::type_name<String>()) {
            update_val<String>(property_map::read_string(&property_map_obj, &key));
        } else {
            abort EINVALID_PROPERTY_TYPE
        };

        read_val<T>()
    }


    public entry fun try_many_bcs_serialization(
        key: vector<String>,
        value: vector<vector<u8>>,
        type: vector<String>,
    ) acquires Map {
        vector::enumerate_ref(&key, |i, key| {
            let value = vector::borrow(&value, i);
            let type = vector::borrow(&type, i);
            try_bcs_serialization(*key, *value, *type);
        });
    }

    public entry fun try_bcs_serialization(
        key: String,
        value: vector<u8>,
        type: String,
    ) acquires Map {
        if (type == str(b"bool")) {
            add_key<bool>(key, from_bcs::to_bool(value));
        } else if (type == str(b"u8")) {
            add_key<u8>(key, from_bcs::to_u8(value));
        } else if (type == str(b"u16")) {
            add_key<u16>(key, from_bcs::to_u16(value));
        } else if (type == str(b"u32")) {
            add_key<u32>(key, from_bcs::to_u32(value));
        } else if (type == str(b"u64")) {
            add_key<u64>(key, from_bcs::to_u64(value));
        } else if (type == str(b"u128")) {
            add_key<u128>(key, from_bcs::to_u128(value));
        } else if (type == str(b"u256")) {
            add_key<u256>(key, from_bcs::to_u256(value));
        } else if (type == str(b"address")) {
            add_key<address>(key, from_bcs::to_address(value));
        } else if (type == str(b"vector<u8>")) {
            add_key<vector<u8>>(key, from_bcs::to_bytes(value));
        } else if (type == str(b"0x1::string::String")) {
            add_key<String>(key, from_bcs::to_string(value));
        };
    }

    /// stores values on-chain to view later for verification purposes. We must store it and read later
    /// because view functions don't serialize, and the type checking in `property_map.move` doesn't
    /// verify that the value is readable later, only writable.
    public entry fun verify_valid_property_maps(
        outer_keys: vector<vector<String>>,
        outer_values: vector<vector<vector<u8>>>,
        outer_types: vector<vector<String>>,
    ) acquires Map {
        let package_signer = package_manager::get_signer();
        let constructor_ref = object::create_object_from_account(&package_signer);

        vector::enumerate_ref(&outer_keys, |i, keys| {
            let mutator_ref = property_map::create_mutator_ref(&constructor_ref);
            let values = vector::borrow(&outer_values, i);
            let types = vector::borrow(&outer_types, i);
            // create property map on our new object
            property_map::init(&constructor_ref, property_map::prepare_input(
                *keys,
                *types,
                *values,
            ));
            let property_map_obj = object::object_from_constructor_ref<PropertyMap>(&constructor_ref);
            property_map::burn(mutator_ref);
        });
    }

    /// stores values on-chain to view later for verification purposes. We must store it and read later
    /// because view functions don't serialize, and the type checking in `property_map.move` doesn't
    /// verify that the value is readable later, only writable.
    public entry fun verify_valid_property_map(
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires Map {
        let package_signer = package_manager::get_signer();
        let constructor_ref = object::create_object_from_account(&package_signer);

        property_map::init(&constructor_ref, property_map::prepare_input(
            keys,
            types,
            values,
        ));
        let property_map_obj = object::object_from_constructor_ref<PropertyMap>(&constructor_ref);
        vector::enumerate_ref(&keys, |i, key| {
            let type = *vector::borrow(&types, i);
                if (type == str(b"bool")) {
                    add_key<bool>(*key, property_map::read_bool(&property_map_obj, key));
                } else if (type == str(b"u8")) {
                    add_key<u8>(*key, property_map::read_u8(&property_map_obj, key));
                } else if (type == str(b"u16")) {
                    add_key<u16>(*key, property_map::read_u16(&property_map_obj, key));
                } else if (type == str(b"u32")) {
                    add_key<u32>(*key, property_map::read_u32(&property_map_obj, key));
                } else if (type == str(b"u64")) {
                    add_key<u64>(*key, property_map::read_u64(&property_map_obj, key));
                } else if (type == str(b"u128")) {
                    add_key<u128>(*key, property_map::read_u128(&property_map_obj, key));
                } else if (type == str(b"u256")) {
                    add_key<u256>(*key, property_map::read_u256(&property_map_obj, key));
                } else if (type == str(b"address")) {
                    add_key<address>(*key, property_map::read_address(&property_map_obj, key));
                } else if (type == str(b"vector<u8>")) {
                    add_key<vector<u8>>(*key, property_map::read_bytes(&property_map_obj, key));
                } else if (type == str(b"0x1::string::String")) {
                    add_key<String>(*key, property_map::read_string(&property_map_obj, key));
                } else {
                assert!(false, 77777777); // can never occur due to prepare_input type checking prior to this
            };
        });
    }
}
