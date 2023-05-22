module mint_nft_v2_part4::create_nft_with_public_phase_and_events {
    use std::bcs;
    use std::error;
    use std::signer;
    use std::object;
    use std::string::{Self, String};
    use std::timestamp;
    use std::vector;
    use std::table::{Self, Table};
    use aptos_framework::account::{Self, SignerCapability};

    use aptos_token_objects::aptos_token::{Self, AptosToken};

    // This struct stores an NFT collection's relevant information
    struct MintConfiguration has key {
        signer_capability: SignerCapability,
        collection_name: String,
        token_name: String,
        token_uri: String,
        whitelist: Table<address, bool>,
        expiration_timestamp: u64,
        minting_enabled: bool,
        admin: address,
        start_timestamp_public: u64,
        start_timestamp_whitelist: u64,
    }
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;
    /// The requested admin account does not exist
    const ENOT_FOUND: u64 = 4;
    /// Whitelist minting hasn't begun yet
    const EWHITELIST_MINT_NOT_STARTED: u64 = 5;
    /// Public minting hasn't begun yet
    const EPUBLIC_MINT_NOT_STARTED: u64 = 6;
    /// The public time must be after the whitelist time
    const EPUBLIC_NOT_AFTER_WHITELIST: u64 = 7;

    const COLLECTION_DESCRIPTION: vector<u8> = b"Your collection description here!";
    const TOKEN_DESCRIPTION: vector<u8> = b"Your token description here!";
    const MUTABLE_COLLECTION_DESCRIPTION: bool = false;
    const MUTABLE_ROYALTY: bool = false;
    const MUTABLE_URI: bool = false;
    const MUTABLE_TOKEN_DESCRIPTION: bool = false;
    const MUTABLE_TOKEN_NAME: bool = false;
    const MUTABLE_TOKEN_PROPERTIES: bool = true;
    const MUTABLE_TOKEN_URI: bool = false;
    const TOKENS_BURNABLE_BY_CREATOR: bool = false;
    const TOKENS_FREEZABLE_BY_CREATOR: bool = false;
    const U64_MAX: u64 = 18446744073709551615;

    public entry fun initialize_collection(
        owner: &signer,
        collection_name: String,
        collection_uri: String,
        maximum_supply: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        token_name: String,
        token_uri: String,
    ) {
        // ensure the signer of this function call is also the owner of the contract
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @mint_nft_v2_part4, error::permission_denied(ENOT_AUTHORIZED));

        let seed = *string::bytes(&collection_name);
        let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, seed);

        aptos_token::create_collection(
            &resource_signer,
            string::utf8(COLLECTION_DESCRIPTION),
            maximum_supply,
            collection_name,
            collection_uri,
            MUTABLE_COLLECTION_DESCRIPTION,
            MUTABLE_ROYALTY,
            MUTABLE_URI,
            MUTABLE_TOKEN_DESCRIPTION,
            MUTABLE_TOKEN_NAME,
            MUTABLE_TOKEN_PROPERTIES,
            MUTABLE_TOKEN_URI,
            TOKENS_BURNABLE_BY_CREATOR,
            TOKENS_FREEZABLE_BY_CREATOR,
            royalty_numerator,
            royalty_denominator,
        );
        move_to(&resource_signer, MintConfiguration {
            signer_capability: resource_signer_cap,
            collection_name,
            token_name,
            token_uri,
            whitelist: table::new<address, bool>(),
            expiration_timestamp: timestamp::now_seconds() - 1,
            minting_enabled: false,
            admin: owner_addr,
            start_timestamp_whitelist: U64_MAX,
            start_timestamp_public: U64_MAX,
        });
    }

    /// Mint an NFT to a receiver who requests it.
    public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
        // access the configuration resources stored on-chain at resource_addr's address
        let mint_configuration = borrow_global<MintConfiguration>(resource_addr);

        assert!(timestamp::now_seconds() >= mint_configuration.start_timestamp_whitelist, error::permission_denied(EWHITELIST_MINT_NOT_STARTED));
        // we are at least past the whitelist start. Now check for if the user is in the whitelist
        if (!table::contains(&mint_configuration.whitelist, signer::address_of(receiver))) {
            // user address is not in the whitelist, assert public minting has begun
            assert!(timestamp::now_seconds() >= mint_configuration.start_timestamp_public, error::permission_denied(EPUBLIC_MINT_NOT_STARTED));
        };

        // abort if this function is called after the expiration_timestamp
        assert!(timestamp::now_seconds() < mint_configuration.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        // abort if minting is disabled
        assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

        let signer_cap = &mint_configuration.signer_capability;
        let resource_signer: &signer = &account::create_signer_with_capability(signer_cap);
        // store next GUID to derive object address later
        let token_creation_num = account::get_guid_next_creation_num(resource_addr);

        // mint token to the receiver
        aptos_token::mint(
            resource_signer,
            mint_configuration.collection_name,
            string::utf8(TOKEN_DESCRIPTION),
            mint_configuration.token_name,
            mint_configuration.token_uri,
            vector<String> [ string::utf8(b"mint_timestamp") ],
            vector<String> [ string::utf8(b"u64") ],
            vector<vector<u8>> [ bcs::to_bytes(&timestamp::now_seconds()) ],
        );

        // TODO: Parallelize later; right now this is non-parallelizable due to using the resource_signer's GUID.
        let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(resource_addr, token_creation_num));
        object::transfer(resource_signer, token_object, signer::address_of(receiver));
    }

    public entry fun set_admin(
        current_admin: &signer,
        new_admin_addr: address,
        resource_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        let current_admin_addr = signer::address_of(current_admin);
        // ensure the signer attempting to change the admin is the current admin
        assert!(current_admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        // ensure the new admin address is an account that's been initialized so we don't accidentally lock ourselves out
        assert!(account::exists_at(new_admin_addr), error::not_found(ENOT_FOUND));
        mint_configuration.admin = new_admin_addr;
    }

    public entry fun add_to_whitelist(
        admin: &signer,
        addresses: vector<address>,
        resource_addr: address
    ) acquires MintConfiguration {
        let admin_addr = signer::address_of(admin);
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));

        vector::for_each(addresses, |user_addr| {
            // note that this will abort in `table` if the address exists already- use `upsert` to ignore this
            table::add(&mut mint_configuration.whitelist, user_addr, true);
        });
    }

    public entry fun remove_from_whitelist(
        admin: &signer,
        addresses: vector<address>,
        resource_addr: address
    ) acquires MintConfiguration {
        let admin_addr = signer::address_of(admin);
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));

        vector::for_each(addresses, |user_addr| {
            // note that this will abort in `table` if the address is not found
            table::remove(&mut mint_configuration.whitelist, user_addr);
        });
    }

    public entry fun set_minting_enabled(
        admin: &signer,
        minting_enabled: bool,
        resource_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        let admin_addr = signer::address_of(admin);
        // abort if the signer is not the admin
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        mint_configuration.minting_enabled = minting_enabled;
    }

    public entry fun set_expiration_timestamp(
        admin: &signer,
        expiration_timestamp: u64,
        resource_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        let admin_addr = signer::address_of(admin);
        // abort if the signer is not the admin
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        mint_configuration.expiration_timestamp = expiration_timestamp;
    }

    public entry fun set_start_timestamp_public(
        admin: &signer,
        start_timestamp_public: u64,
        resource_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        let admin_addr = signer::address_of(admin);
        // abort if the signer is not the admin
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        assert!(mint_configuration.start_timestamp_whitelist <= start_timestamp_public, error::invalid_state(EPUBLIC_NOT_AFTER_WHITELIST));
        mint_configuration.start_timestamp_public = start_timestamp_public;
    }

    public entry fun set_start_timestamp_whitelist(
        admin: &signer,
        start_timestamp_whitelist: u64,
        resource_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(resource_addr);
        let admin_addr = signer::address_of(admin);
        // abort if the signer is not the admin
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        assert!(mint_configuration.start_timestamp_public >= start_timestamp_whitelist, error::invalid_state(EPUBLIC_NOT_AFTER_WHITELIST));
        mint_configuration.start_timestamp_whitelist = start_timestamp_whitelist;
    }

    #[view]
    public fun get_resource_address(collection_name: String): address {
        account::create_resource_address(&@mint_nft_v2_part4, *string::bytes(&collection_name))
    }

    // dependencies only used in test, if we link without #[test_only], the compiler will warn us
    #[test_only]
    use aptos_token_objects::collection::{Self, Collection};
    #[test_only]
    use aptos_token_objects::token::{Self};
    #[test_only]
    use aptos_token_objects::royalty::{Self};
    #[test_only]
    use aptos_token_objects::property_map::{Self};
    #[test_only]
    use std::option::{Self};

    #[test_only]
    public fun setup_test(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
        timestamp: u64,
    ) {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(timestamp);
        account::create_account_for_test(signer::address_of(owner));
        account::create_account_for_test(signer::address_of(nft_receiver));
        account::create_account_for_test(signer::address_of(aptos_framework));
        initialize_collection(
            owner,
            get_collection_name(),
            get_collection_uri(),
            MAXIMUM_SUPPLY,
            ROYALTY_NUMERATOR,
            ROYALTY_DENOMINATOR,
            get_token_name(),
            get_token_uri(),
        );
    }

    #[test_only]
    public fun set_default_timestamps(
        admin: &signer,
        resource_addr: address,
    ) acquires MintConfiguration {
        set_start_timestamp_whitelist(admin, START_TIMESTAMP_WHITELIST, resource_addr);
        set_start_timestamp_public(admin, START_TIMESTAMP_PUBLIC, resource_addr);
        set_expiration_timestamp(admin, EXPIRATION_TIMESTAMP, resource_addr);
    }

    // The happy path tests 4 positive conditions:
    // 1. When the collection is initialized, all on-chain resources are initialized in the resource account.
    // 2. When the admin is changed, the next admin can successfully call admin-only functions.
    // 3. When any functions that mutate resources are called, the resource on-chain is updated accordingly.
    // 4. When a user mints successfully, they actually receive the NFT.
    #[test(owner = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, nft_receiver2 = @0xFC, aptos_framework = @0x1)]
    public fun test_happy_path(
        owner: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        account::create_account_for_test(signer::address_of(new_admin));
        setup_test(owner,  nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC);
        let resource_addr = get_resource_address(get_collection_name());
        let collection_object_addr = collection::create_collection_address(&resource_addr, &get_collection_name());
        let collection_object = object::address_to_object<Collection>(collection_object_addr);

        // positive condition #1
        assert!(collection::creator(collection_object) == resource_addr, 1);
        assert!(object::owner(collection_object) == resource_addr, 2);
        assert!(collection::name(collection_object) == get_collection_name(), 3);
        assert!(collection::uri(collection_object) == get_collection_uri(), 4);

        let new_admin_addr = signer::address_of(new_admin);
        let nft_receiver_addr = signer::address_of(nft_receiver);
        let nft_receiver2_addr = signer::address_of(nft_receiver2);

        // positive condition #2
        set_admin(owner, new_admin_addr, resource_addr);
        assert!(borrow_global<MintConfiguration>(resource_addr).admin == new_admin_addr, 5);

        // positive condition #3
        add_to_whitelist(new_admin, vector<address> [nft_receiver_addr, nft_receiver2_addr], resource_addr);
        assert!(table::contains(&borrow_global<MintConfiguration>(resource_addr).whitelist, nft_receiver_addr), 6);
        assert!(table::contains(&borrow_global<MintConfiguration>(resource_addr).whitelist, nft_receiver2_addr), 7);

        remove_from_whitelist(new_admin, vector<address> [nft_receiver2_addr], resource_addr);
        assert!(!table::contains(&borrow_global<MintConfiguration>(resource_addr).whitelist, nft_receiver2_addr), 8);

        set_minting_enabled(new_admin, true, resource_addr);
        assert!(borrow_global<MintConfiguration>(resource_addr).minting_enabled, 9);
        set_expiration_timestamp(new_admin, EXPIRATION_TIMESTAMP, resource_addr);
        assert!(borrow_global<MintConfiguration>(resource_addr).expiration_timestamp == EXPIRATION_TIMESTAMP, 10);
        set_start_timestamp_whitelist(new_admin, START_TIMESTAMP_WHITELIST, resource_addr);
        assert!(borrow_global<MintConfiguration>(resource_addr).start_timestamp_whitelist == START_TIMESTAMP_WHITELIST, 12);
        set_start_timestamp_public(new_admin, START_TIMESTAMP_PUBLIC, resource_addr);
        assert!(borrow_global<MintConfiguration>(resource_addr).start_timestamp_public == START_TIMESTAMP_PUBLIC, 11);


        // positive condition #4
        let token_creation_num = account::get_guid_next_creation_num(resource_addr);
        mint(nft_receiver, resource_addr);
        let token_object_addr = object::create_guid_object_address(resource_addr, token_creation_num);
        let token_object = object::address_to_object<AptosToken>(token_object_addr);
        assert!(token::creator(token_object) == resource_addr, 13);
        assert!(token::collection_name(token_object) == get_collection_name(), 14);
        assert!(token::collection_object(token_object) == collection_object, 15);
        assert!(token::name(token_object) == get_token_name(), 16);
        assert!(token::uri(token_object) == get_token_uri(), 17);
        assert!(object::owner(token_object) == nft_receiver_addr, 18);

        let token_mint_timestamp = property_map::read_u64(&token_object, &string::utf8(b"mint_timestamp"));
        assert!(token_mint_timestamp == timestamp::now_seconds(), 19);

        let royalty_object = option::extract(&mut token::royalty(token_object));
        assert!(royalty::numerator(&royalty_object) == ROYALTY_NUMERATOR, 20);
        assert!(royalty::denominator(&royalty_object) == ROYALTY_DENOMINATOR, 21);
    }

    #[test(owner = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50001, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_incorrect_admin(
        owner: &signer,
        nft_receiver: &signer,
        new_admin: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC);
        let resource_addr = get_resource_address(get_collection_name());
        account::create_account_for_test(signer::address_of(new_admin));
        set_admin(owner, signer::address_of(new_admin), resource_addr);
        add_to_whitelist(owner, vector<address> [signer::address_of(nft_receiver)], resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50002, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_expired_mint(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_WHITELIST);
        let resource_addr = get_resource_address(get_collection_name());
        set_start_timestamp_whitelist(owner, START_TIMESTAMP_WHITELIST - 2, resource_addr);
        set_start_timestamp_public(owner, START_TIMESTAMP_WHITELIST - 2, resource_addr);
        set_expiration_timestamp(owner, START_TIMESTAMP_WHITELIST - 1, resource_addr);
        mint(nft_receiver, resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50003, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_disabled_mint(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC);
        let resource_addr = get_resource_address(get_collection_name());
        set_default_timestamps(owner, resource_addr);
        set_minting_enabled(owner, false, resource_addr);
        mint(nft_receiver, resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x60004, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_admin_doesnt_exist(
        owner: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC);
        // intentionally do not call account::create_account_for_test(signer::address_of(new_admin));
        let resource_addr = get_resource_address(get_collection_name());
        set_admin(owner, signer::address_of(new_admin), resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50005, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_whitelist_mint_too_early(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_WHITELIST - 1);
        let resource_addr = get_resource_address(get_collection_name());
        add_to_whitelist(owner, vector<address> [signer::address_of(nft_receiver)], resource_addr);
        set_start_timestamp_whitelist(owner, START_TIMESTAMP_WHITELIST, resource_addr);
        mint(nft_receiver, resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50006, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_public_mint_too_early(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC - 1);
        let resource_addr = get_resource_address(get_collection_name());
        set_start_timestamp_whitelist(owner, START_TIMESTAMP_PUBLIC - 2, resource_addr);
        mint(nft_receiver, resource_addr);
    }

    #[test(owner = @mint_nft_v2_part4, nft_receiver = @0xFB, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x30007, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_setting_public_mint_after_whitelist(
        owner: &signer,
        nft_receiver: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, nft_receiver, aptos_framework, START_TIMESTAMP_PUBLIC);
        let resource_addr = get_resource_address(get_collection_name());
        set_default_timestamps(owner, resource_addr);
        set_start_timestamp_whitelist(owner, START_TIMESTAMP_PUBLIC + 1, resource_addr);
    }

    #[test_only]
    const COLLECTION_NAME: vector<u8> = b"Krazy Kangaroos";
    #[test_only]
    const TOKEN_NAME: vector<u8> = b"Krazy Kangaroo #1";
    #[test_only]
    const TOKEN_URI: vector<u8> = b"https://www.link-to-your-token-image.com";
    #[test_only]
    const COLLECTION_URI: vector<u8> = b"https://www.link-to-your-collection-image.com";
    #[test_only]
    const ROYALTY_NUMERATOR: u64 = 5;
    #[test_only]
    const ROYALTY_DENOMINATOR: u64 = 100;
    #[test_only]
    const MAXIMUM_SUPPLY: u64 = 3;
    #[test_only]
    const START_TIMESTAMP_PUBLIC: u64 = 100000000;
    #[test_only]
    const START_TIMESTAMP_WHITELIST: u64 = 100000000 - 1;
    #[test_only]
    const EXPIRATION_TIMESTAMP: u64 = 100000000 + 1;

    #[test_only]
    public fun get_collection_name(): String { string::utf8(COLLECTION_NAME) }
    #[test_only]
    public fun get_collection_uri(): String { string::utf8(COLLECTION_URI) }
    #[test_only]
    public fun get_token_name(): String { string::utf8(TOKEN_NAME) }
    #[test_only]
    public fun get_token_uri(): String { string::utf8(TOKEN_URI) }
}
