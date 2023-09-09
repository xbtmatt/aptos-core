module pond::address_manager {
    use aptos_std::smart_table::{Self, SmartTable};
    use std::string::String;

    friend pond::toad_v2;

    /// Stores the addresses for tracking for a contract
    struct Addresses has key {
        /// Track the addresses created by the modules in this package.
        addresses: SmartTable<String, address>,
    }

    /// Initialize the Addresses resource to the deployer.
    /// This function is invoked only when this package is deployed the first time.
    fun init_module(deployer: &signer) {
        move_to(deployer, Addresses {
            addresses: smart_table::new<String, address>(),
        });
    }

    /// Can be called by friended modules to keep track of a named address.
    public(friend) fun add_address(name: String, object: address) acquires Addresses {
        let addresses = &mut borrow_global_mut<Addresses>(@pond).addresses;
        smart_table::add(addresses, name, object);
    }

    public fun address_exists(name: String): bool acquires Addresses {
        smart_table::contains(&safe_permission_config().addresses, name)
    }

    public fun get_address(name: String): address acquires Addresses {
        let addresses = &borrow_global<Addresses>(@pond).addresses;
        *smart_table::borrow(addresses, name)
    }

    inline fun safe_permission_config(): &Addresses acquires Addresses {
        borrow_global<Addresses>(@pond)
    }
}
