module mint_nft_v2_part3::create_nft_with_resource_and_admin_accounts {
    use std::bcs;
    use std::error;
    use std::signer;
    use std::object;
    use std::string::{Self, String};
    use std::timestamp;
    use aptos_framework::account::{Self, SignerCapability};

    use aptos_token_objects::aptos_token::{Self, AptosToken};

    // This struct stores an NFT collection's relevant information
    struct MintConfiguration has key {
        signer_capability: SignerCapability,
        collection_name: String,
        token_name: String,
        token_uri: String,
        expiration_timestamp: u64,
        minting_enabled: bool,
    }
    /// Action not authorized because the signer is not the admin of this module
    const ENOT_AUTHORIZED: u64 = 1;
    /// The collection minting is expired
    const ECOLLECTION_EXPIRED: u64 = 2;
    /// The collection minting is disabled
    const EMINTING_DISABLED: u64 = 3;

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

    public entry fun initialize_collection(
        owner: &signer,
        collection_name: String,
        collection_uri: String,
        maximum_supply: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        token_name: String,
        token_uri: String,
        expiration_timestamp: u64,
    ) {
        // ensure the signer of this function call is also the owner of the contract
        let owner_addr = signer::address_of(owner);
        assert!(owner_addr == @mint_nft_v2_part3, error::permission_denied(ENOT_AUTHORIZED));

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
            expiration_timestamp,
            minting_enabled: false,
        });
    }

    /// Mint an NFT to a receiver who requests it.
    public entry fun mint(receiver: &signer, resource_addr: address) acquires MintConfiguration {
        // access the configuration resources stored on-chain at resource_addr's address
        let mint_configuration = borrow_global<MintConfiguration>(resource_addr);

        // throw an error if this function is called after the expiration_timestamp
        assert!(timestamp::now_seconds() < mint_configuration.expiration_timestamp, error::permission_denied(ECOLLECTION_EXPIRED));
        // throw an ereror if minting is disabled
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
            string::utf8(b"mint_timestamp"),
            mint_configuration.token_uri,
            vector<String> [ string::utf8(b"mint_timestamp") ],
            vector<String> [ string::utf8(b"u64") ],
            vector<vector<u8>> [ bcs::to_bytes(&timestamp::now_seconds()) ],
        );

        // TODO: Parallelize later; right now this is non-parallelizable due to using the resource_signer's GUID.
        let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(resource_addr, token_creation_num));
        object::transfer(resource_signer, token_object, signer::address_of(receiver));
    }

    // set admin?

    // ensure admin is owner of the signercapability for the collection creator
    
    public entry fun set_minting_enabled(admin: &signer, minting_enabled: bool) acquires MintConfiguration {
        let admin_addr = signer::address_of(admin);
        let mint_configuration = borrow_global_mut<MintConfiguration>(@mint_nft_v2_part3);
    }

    #[view]
    public fun get_resource_address(collection_name: String): address {
        account::create_resource_address(&@mint_nft_v2_part2, *string::bytes(&collection_name))
    }
}
