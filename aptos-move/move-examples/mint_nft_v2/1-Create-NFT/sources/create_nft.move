module mint_nft_v2_part1::create_nft {
    use std::bcs;
    use std::signer;
    use std::object;
    use std::string::{Self, String};
    use std::timestamp;
    use aptos_framework::account;

    use aptos_token_objects::aptos_token::{Self, AptosToken};

    // This struct stores an NFT collection's relevant information
    struct MintConfiguration has key {
        collection_name: String,
        token_name: String,
        token_uri: String,
    }

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
        creator: &signer,
        collection_name: String,
        collection_uri: String,
        maximum_supply: u64,
        royalty_numerator: u64,
        royalty_denominator: u64,
        token_name: String,
        token_uri: String,
    ) {

        aptos_token::create_collection(
            creator,
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
        move_to(creator, MintConfiguration {
            collection_name,
            token_name,
            token_uri,
        });
    }

    /// Mint an NFT to an arbitrary receiver.
    public entry fun mint(
        creator: &signer,
        receiver_address: address
    ) acquires MintConfiguration {
        let creator_addr = signer::address_of(creator);
        // store next GUID to derive object address later
        let token_creation_num = account::get_guid_next_creation_num(creator_addr);

        // access the configuration resources stored on-chain at creator_addr
        let mint_configuration = borrow_global<MintConfiguration>(creator_addr);

        // mint token to the receiver
        aptos_token::mint(
            creator,
            mint_configuration.collection_name,
            string::utf8(TOKEN_DESCRIPTION),
            mint_configuration.token_name,
            mint_configuration.token_uri,
            vector<String> [ string::utf8(b"mint_timestamp") ],
            vector<String> [ string::utf8(b"u64") ],
            vector<vector<u8>> [ bcs::to_bytes(&timestamp::now_seconds()) ],
        );

        // TODO: Parallelize later; right now this is non-parallelizable due to using the creator's GUID.
        let token_object = object::address_to_object<AptosToken>(object::create_guid_object_address(creator_addr, token_creation_num));
        object::transfer(creator, token_object, receiver_address);
    }

    /// generates the next token name by concatenating the supply onto the base token name
    fun next_token_name_from_supply(
        creator: &signer,
        base_token_name: String,
        collection_name: String,
    ): String {
        let collection_addr = collection::create_collection_address(&signer::address_of(creator), &collection_name);
        let collection_object = object::address_to_object<Collection>(collection_addr);
        let current_supply = option::borrow(&collection::count(collection_object));
        let format_string = base_token_name;
        // if base_token_name == Token Name
        string::append_utf8(&mut format_string, b" #{}");
        // 'Token Name #1' when supply == 0
        string_utils::format1(string::bytes(&format_string), *current_supply + 1)
    }
}
