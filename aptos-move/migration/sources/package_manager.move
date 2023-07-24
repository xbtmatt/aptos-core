module migration::package_manager {
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::resource_account;
    use aptos_std::smart_table::{Self, SmartTable};
    use std::string::String;
    use std::error;
    use std::code;
    use std::signer;

    friend migration::migration_tool;
    friend migration::unit_tests;

    /// You are not authorized to upgrade this module.
    const ENOT_AUTHORIZED: u64 = 0;

    /// Stores permission config such as SignerCapability for controlling the resource account.
    struct PermissionConfig has key {
        /// Required to obtain the resource account signer.
        signer_cap: SignerCapability,
        /// Track the addresses created by the modules in this package.
        addresses: SmartTable<String, address>,
    }

    /// Initialize PermissionConfig to establish control over the resource account.
    /// This function is invoked only when this package is deployed the first time.
    fun init_module(resource_signer: &signer) {
        let signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @deployer);
        move_to(resource_signer, PermissionConfig {
            addresses: smart_table::new<String, address>(),
            signer_cap,
        });
    }

    public entry fun upgrade_module(
        deployer: &signer,
        package_metadata: vector<u8>,
        code: vector<vector<u8>>,
    ) acquires PermissionConfig {
        // NOTE: If we leave this line out, anyone can upgrade the contract and potentially hijack its functionality.
        assert!(signer::address_of(deployer) == @deployer, error::permission_denied(ENOT_AUTHORIZED));
        code::publish_package_txn(&get_signer(), package_metadata, code);
    }

    /// Can be called by friended modules to obtain the resource account signer.
    public(friend) fun get_signer(): signer acquires PermissionConfig {
        let signer_cap = &borrow_global<PermissionConfig>(@migration).signer_cap;
        account::create_signer_with_capability(signer_cap)
    }

    /// Can be called by friended modules to keep track of a system address.
    public(friend) fun add_name(name: String, object: address) acquires PermissionConfig {
        let addresses = &mut borrow_global_mut<PermissionConfig>(@migration).addresses;
        smart_table::add(addresses, name, object);
    }

    public fun name_exists(name: String): bool acquires PermissionConfig {
        smart_table::contains(&safe_permission_config().addresses, name)
    }

    public fun get_name(name: String): address acquires PermissionConfig {
        let addresses = &borrow_global<PermissionConfig>(@migration).addresses;
        *smart_table::borrow(addresses, name)
    }

    inline fun safe_permission_config(): &PermissionConfig acquires PermissionConfig {
        borrow_global<PermissionConfig>(@migration)
    }

    #[test_only]
    public(friend) fun init_module_for_test(resource_account: &signer) {
        init_module(resource_account);
    }
}
