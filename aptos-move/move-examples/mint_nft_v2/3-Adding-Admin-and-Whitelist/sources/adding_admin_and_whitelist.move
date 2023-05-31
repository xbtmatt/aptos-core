module mint_nft_v2_part3::adding_admin_and_whitelist {
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

    use mint_nft_v2_part3::whitelist;

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
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 2;
    /// The requested admin account does not exist
    const ENOT_FOUND: u64 = 3;

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

        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part3);
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
        // access the configuration resources stored on-chain at @mint_nft_v2_part3's address
        let mint_configuration = borrow_global<MintConfiguration>(@mint_nft_v2_part3);

        // abort if minting is disabled
        assert!(mint_configuration.minting_enabled, error::permission_denied(EMINTING_DISABLED));

        whitelist::deduct_one_from_tier(receiver, tier_name, @mint_nft_v2_part3);

        let signer_cap = &mint_configuration.signer_capability;
        let resource_signer: &signer = &account::create_signer_with_capability(signer_cap);
        // store next GUID to derive object address later
        let token_creation_num = account::get_guid_next_creation_num(@mint_nft_v2_part3);

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
        let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(@mint_nft_v2_part3, token_creation_num));
        object::transfer(resource_signer, token_object, signer::address_of(receiver));
    }

    public entry fun set_admin(
        requesting_admin: &signer,
        new_admin_addr: address,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part3);
        let requesting_admin_addr = signer::address_of(requesting_admin);
        // assert the requesting admin is the admin of the contract
        assert!(requesting_admin_addr == mint_configuration.admin, error::permission_denied(ENOT_AUTHORIZED));
        // ensure the new admin address is an account that's been initialized so we don't accidentally lock ourselves out
        assert!(account::exists_at(new_admin_addr), error::not_found(ENOT_FOUND));
        mint_configuration.admin = new_admin_addr;
    }

    public entry fun set_minting_enabled(
        admin: &signer,
        minting_enabled: bool,
    ) acquires MintConfiguration {
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part3);
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
}
