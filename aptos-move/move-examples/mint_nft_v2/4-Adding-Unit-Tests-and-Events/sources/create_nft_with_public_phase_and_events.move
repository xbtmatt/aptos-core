module mint_nft_v2_part4::create_nft_with_public_phase_and_events {
    use std::bcs;
    use std::error;
    use std::signer;
    use std::object;
    use std::option;
    use std::string::{Self, String};
    use std::timestamp;
    use std::string_utils;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::resource_account;

    use aptos_token_objects::aptos_token::{Self, AptosToken};
    use aptos_token_objects::collection::{Self, Collection};

    use mint_nft_v2_part4::whitelist;

    // This struct stores an NFT collection's relevant information
    struct MintConfiguration has key {
        signer_capability: SignerCapability,
        collection_name: String,
        base_token_name: String,
        token_uri: String,
        minting_enabled: bool,
        admin: address,
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

    const COLLECTION_DESCRIPTION: vector<u8> = b"A bunch of krazy kangaroos.";
    const TOKEN_DESCRIPTION: vector<u8> = b"A krazy kangaroo!";
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

    fun init_module(resource_signer: &signer) {
        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_signer, @owner);
        move_to(resource_signer, MintConfiguration {
            signer_capability: resource_signer_cap,
            collection_name: string::utf8(b""),
            base_token_name: string::utf8(b""),
            token_uri: string::utf8(b""),
            minting_enabled: false,
            admin: @owner,
        });
    }

    public entry fun initialize_collection(
        admin: &signer,
        collection_name: String,
        collection_uri: String,
        maximum_supply: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        base_token_name: String,
        token_uri: String,
    ) acquires MintConfiguration {
        assert!(signer::address_of(admin) == @owner, error::permission_denied(ENOT_AUTHORIZED));

        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part4);
        mint_configuration.collection_name = collection_name;
        mint_configuration.base_token_name = base_token_name;
        mint_configuration.token_uri = token_uri;

        let resource_signer = &account::create_signer_with_capability(&mint_configuration.signer_capability);

        aptos_token::create_collection(
            resource_signer,
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

        whitelist::init_tiers(resource_signer);

        whitelist::upsert_tier_config(
            resource_signer,
            string::utf8(b"whitelist"),
            true, // open_to_public
            0, // price
            0, // start_time
            U64_MAX, // end_time
            1, // per_user_limit
        );

        whitelist::upsert_tier_config(
            resource_signer,
            string::utf8(b"public"),
            true, // open_to_public
            1, // price
            0, // start_time
            U64_MAX, // end_time
            10, // per_user_limit
        );
    }

    /// Mint an NFT to a receiver who requests it.
    public entry fun mint(receiver: &signer, tier_name: String) acquires MintConfiguration {
        // access the configuration resources stored on-chain at @mint_nft_v2_part4's address
        let mint_configuration = borrow_global<MintConfiguration>(@mint_nft_v2_part4);

        // abort if minting is disabled
        assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

        whitelist::deduct_one_from_tier(receiver, tier_name, @mint_nft_v2_part4);

        let signer_cap = &mint_configuration.signer_capability;
        let resource_signer: &signer = &account::create_signer_with_capability(signer_cap);
        // store next GUID to derive object address later
        let token_creation_num = account::get_guid_next_creation_num(@mint_nft_v2_part4);

        let token_name = next_token_name_from_supply(
            signer::address_of(resource_signer),
            mint_configuration.base_token_name,
            mint_configuration.collection_name,
        );

        // mint token to the receiver
        aptos_token::mint(
            resource_signer,
            mint_configuration.collection_name,
            string::utf8(TOKEN_DESCRIPTION),
            token_name,
            mint_configuration.token_uri,
            vector<String> [ string::utf8(b"mint_timestamp") ],
            vector<String> [ string::utf8(b"u64") ],
            vector<vector<u8>> [ bcs::to_bytes(&timestamp::now_seconds()) ],
        );

        // TODO: Parallelize later; right now this is non-parallelizable due to using the resource_signer's GUID.
        let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(@mint_nft_v2_part4, token_creation_num));
        object::transfer(resource_signer, token_object, signer::address_of(receiver));
    }

    public entry fun set_admin(
        requesting_admin: &signer,
        new_admin_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part4);
        let requesting_admin_addr = signer::address_of(requesting_admin);
        // assert the requesting admin is the admin of the contract
        assert!(requesting_admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        // ensure the new admin address is an account that's been initialized so we don't accidentally lock ourselves out
        assert!(account::exists_at(new_admin_addr), error::not_found(ENOT_FOUND));
        mint_configuration.admin = new_admin_addr;
    }

    public entry fun add_addresses_to_tier(
        admin: &signer,
        tier_name: String,
        addresses: vector<address>,
    ) acquires MintConfiguration {
        let admin_addr = signer::address_of(admin);
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part4);
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        let resource_signer = &account::create_signer_with_capability(&mint_configuration.signer_capability);
        whitelist::add_addresses_to_tier(resource_signer, tier_name, addresses);
    }

    public entry fun remove_addresses_from_tier(
        admin: &signer,
        tier_name: String,
        addresses: vector<address>,
    ) acquires MintConfiguration {
        let admin_addr = signer::address_of(admin);
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part4);
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        let resource_signer = &account::create_signer_with_capability(&mint_configuration.signer_capability);
        whitelist::remove_addresses_from_tier(resource_signer, tier_name, addresses);
    }

    public entry fun set_minting_enabled(
        admin: &signer,
        minting_enabled: bool,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part4);
        let admin_addr = signer::address_of(admin);
        // abort if the signer is not the admin
        assert!(admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        mint_configuration.minting_enabled = minting_enabled;
    }

    /// generates the next token name by concatenating the supply onto the base token name
    fun next_token_name_from_supply(
        creator_address: address,
        base_token_name: String,
        collection_name: String,
    ): String {
        let collection_addr = collection::create_collection_address(&creator_address, &collection_name);
        let collection_object = object::address_to_object<Collection>(collection_addr);
        let current_supply = option::borrow(&collection::count(collection_object));
        let format_string = base_token_name;
        // if base_token_name == Token Name
        string::append_utf8(&mut format_string, b" #{}");
        // 'Token Name #1' when supply == 0
        string_utils::format1(string::bytes(&format_string), *current_supply + 1)
    }

    // dependencies only used in test, if we link without #[test_only], the compiler will warn us
    #[test_only]
    use aptos_token_objects::token::{Self};
    #[test_only]
    use aptos_token_objects::royalty::{Self};
    #[test_only]
    use aptos_token_objects::property_map::{Self};
    #[test_only]
    use std::coin::{Self, MintCapability};
    #[test_only]
    use std::vector;
    #[test_only]
    use std::aptos_coin::{AptosCoin};

    #[test_only]
    const COLLECTION_NAME: vector<u8> = b"Krazy Kangaroos";
    #[test_only]
    const BASE_TOKEN_NAME: vector<u8> = b"Krazy Kangaroo";
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
    public fun setup_account<CoinType>(
        acc: &signer,
        num_coins: u64,
        mint: &MintCapability<CoinType>,
    ) {
        let addr = signer::address_of(acc);
        account::create_account_for_test(addr);
        coin::register<CoinType>(acc);
        coin::deposit<CoinType>(addr, coin::mint<CoinType>(num_coins, mint));
    }

    #[test_only]
    public fun setup_test(
        owner: &signer,
        resource_account: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
        timestamp: u64,
    ) acquires MintConfiguration {
        timestamp::set_time_has_started_for_testing(aptos_framework);
        timestamp::update_global_time_for_test_secs(timestamp);
        let (burn, mint) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);


        account::create_account_for_test(signer::address_of(owner));
        resource_account::create_resource_account(owner, vector::empty<u8>(), vector::empty<u8>());
        init_module(resource_account);

        account::create_account_for_test(signer::address_of(new_admin));
        setup_account<AptosCoin>(nft_receiver, 5, &mint);
        setup_account<AptosCoin>(nft_receiver2, 3, &mint);
        coin::destroy_burn_cap(burn);
        coin::destroy_mint_cap(mint);

        initialize_collection(
            owner,
            get_collection_name(),
            get_collection_uri(),
            MAXIMUM_SUPPLY,
            ROYALTY_NUMERATOR,
            ROYALTY_DENOMINATOR,
            get_base_token_name(),
            get_token_uri(),
        );
    }

    // The happy path tests 4 positive conditions:
    // 1. When the collection is initialized, all on-chain resources are initialized in the resource account.
    // 2. When the admin is changed, the next admin can successfully call admin-only functions.
    // 3. When minting is enabled, the minting_enabled field is changed to true
    // 4. The nft_receiver account mints 1 token as a whitelisted user successfully. They also receive the NFT.
    // 5. The property map was updated correctly and the royalty data is set correctly
    // 6. The second token minted's token name is 'base_token_name #2' and is owned by nft_receiver2
    #[test(owner = @owner, resource_account = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, nft_receiver2 = @0xFC, aptos_framework = @0x1)]
    public fun test_happy_path(
        owner: &signer,
        resource_account: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, resource_account, new_admin, nft_receiver, nft_receiver2, aptos_framework, 1000000000);
        let collection_object_addr = collection::create_collection_address(&@mint_nft_v2_part4, &get_collection_name());
        let collection_object = object::address_to_object<Collection>(collection_object_addr);

        // positive condition #1
        assert!(collection::creator(collection_object) == @mint_nft_v2_part4, 1);
        assert!(object::owner(collection_object) == @mint_nft_v2_part4, 2);
        assert!(collection::name(collection_object) == get_collection_name(), 3);
        assert!(collection::uri(collection_object) == get_collection_uri(), 4);

        let new_admin_addr = signer::address_of(new_admin);
        let nft_receiver_addr = signer::address_of(nft_receiver);
        let nft_receiver2_addr = signer::address_of(nft_receiver2);

        // positive condition #2
        set_admin(owner, new_admin_addr);
        assert!(borrow_global<MintConfiguration>(@mint_nft_v2_part4).admin == new_admin_addr, 5);

        add_addresses_to_tier(new_admin, string::utf8(b"whitelist"), vector<address> [nft_receiver_addr, nft_receiver2_addr]);
        remove_addresses_from_tier(new_admin, string::utf8(b"whitelist"), vector<address> [nft_receiver2_addr]);

        // positive condition #3
        set_minting_enabled(new_admin, true);
        assert!(borrow_global<MintConfiguration>(@mint_nft_v2_part4).minting_enabled, 9);

        // positive condition #4
        let token_creation_num = account::get_guid_next_creation_num(@mint_nft_v2_part4);
        mint(nft_receiver, string::utf8(b"whitelist"));
        let token_object_addr = object::create_guid_object_address(@mint_nft_v2_part4, token_creation_num);
        let token_object = object::address_to_object<AptosToken>(token_object_addr);
        assert!(token::creator(token_object) == @mint_nft_v2_part4, 10);
        assert!(token::collection_name(token_object) == get_collection_name(), 11);
        assert!(token::collection_object(token_object) == collection_object, 12);
        let token_name = get_base_token_name();
        string::append_utf8(&mut token_name, b" #1");
        assert!(token::name(token_object) == token_name, 13);
        assert!(token::uri(token_object) == get_token_uri(), 14);
        assert!(object::owner(token_object) == nft_receiver_addr, 15);

        // positive condition #5
        let token_mint_timestamp = property_map::read_u64(&token_object, &string::utf8(b"mint_timestamp"));
        assert!(token_mint_timestamp == timestamp::now_seconds(), 16);

        let royalty_object = option::extract(&mut token::royalty(token_object));
        assert!(royalty::numerator(&royalty_object) == ROYALTY_NUMERATOR, 17);
        assert!(royalty::denominator(&royalty_object) == ROYALTY_DENOMINATOR, 18);

        // positive condition #6
        let token_creation_num = account::get_guid_next_creation_num(@mint_nft_v2_part4);
        mint(nft_receiver2, string::utf8(b"public"));
        let token_object_addr = object::create_guid_object_address(@mint_nft_v2_part4, token_creation_num);
        let token_object = object::address_to_object<AptosToken>(token_object_addr);
        let token_name = get_base_token_name();
        string::append_utf8(&mut token_name, b" #2");
        assert!(token::name(token_object) == token_name, 19);
        assert!(object::owner(token_object) == nft_receiver2_addr, 20);
    }

    #[test(owner = @owner, resource_account = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, nft_receiver2 = @0xFC, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50001, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_incorrect_admin(
        owner: &signer,
        resource_account: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, resource_account, new_admin, nft_receiver, nft_receiver2, aptos_framework, 1000000000);
        set_admin(owner, signer::address_of(new_admin));
        add_addresses_to_tier(owner, string::utf8(b"public"), vector<address> [signer::address_of(nft_receiver)]);
    }

    #[test(owner = @owner, resource_account = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, nft_receiver2 = @0xFC, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x50003, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_disabled_mint(
        owner: &signer,
        resource_account: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, resource_account, new_admin, nft_receiver, nft_receiver2, aptos_framework, 1000000000);
        set_minting_enabled(owner, false);
        mint(nft_receiver, string::utf8(b"public"));
    }

    #[test(owner = @owner, resource_account = @mint_nft_v2_part4, new_admin = @0xFA, nft_receiver = @0xFB, nft_receiver2 = @0xFC, aptos_framework = @0x1)]
    #[expected_failure(abort_code = 0x60004, location = mint_nft_v2_part4::create_nft_with_public_phase_and_events)]
    public fun test_admin_doesnt_exist(
        owner: &signer,
        resource_account: &signer,
        new_admin: &signer,
        nft_receiver: &signer,
        nft_receiver2: &signer,
        aptos_framework: &signer,
    ) acquires MintConfiguration {
        setup_test(owner, resource_account, new_admin, nft_receiver, nft_receiver2, aptos_framework, 1000000000);
        set_admin(owner, signer::address_of(new_admin));
        // intentionally do not call account::create_account_for_test(signer::address_of(@0x1234));
        set_admin(new_admin, @0x1234);
    }

    #[test_only]
    public fun get_collection_name(): String { string::utf8(COLLECTION_NAME) }
    #[test_only]
    public fun get_collection_uri(): String { string::utf8(COLLECTION_URI) }
    #[test_only]
    public fun get_base_token_name(): String { string::utf8(BASE_TOKEN_NAME) }
    #[test_only]
    public fun get_token_uri(): String { string::utf8(TOKEN_URI) }
}
