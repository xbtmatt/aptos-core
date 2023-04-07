/// This module is used to create ambassador tokens. Ambassador tokens are
/// soulbound tokens that are minted by the creator of a collection.
module ambassador_token::ambassador {
    use std::error;
    use std::option;
    use std::string::{Self, String};
    use std::signer;

    use aptos_framework::object::{Self, Object};
    use aptos_token_objects::collection;
    use aptos_token_objects::token;
    use aptos_token_objects::property_map;
    use aptos_framework::event;

    /// The token does not exist
    const ETOKEN_DOES_NOT_EXIST: u64 = 1;
    /// The provided signer is not the creator
    const ENOT_CREATOR: u64 = 2;
    /// Attempted to mutate an immutable field
    const EFIELD_NOT_MUTABLE: u64 = 3;
    /// Attempted to burn a non-burnable token
    const ETOKEN_NOT_BURNABLE: u64 = 4;
    /// Attempted to mutate a property map that is not mutable
    const EPROPERTIES_NOT_MUTABLE: u64 = 5;
    // The collection does not exist
    const ECOLLECTION_DOES_NOT_EXIST: u64 = 6;

    /// The ambassador token collection name
    const COLLECTION_NAME: vector<u8> = b"Ambassador Collection Name";
    /// The ambassador token collection description
    const COLLECTION_DESCRIPTION: vector<u8> = b"Ambassador Collection Description";
    /// The ambassador token collection URI
    const COLLECTION_URI: vector<u8> = b"Ambassador Collection URI";

    /// The ambassador rank
    const RANK_GOLD: vector<u8> = b"Gold";
    const RANK_SILVER: vector<u8> = b"Silver";
    const RANK_BRONZE: vector<u8> = b"Bronze";

    /// The ambassador token
    struct AmbassadorToken has key {
        /// Used to burn.
        burn_ref: token::BurnRef,
        /// Used to mutate properties
        property_mutator_ref: property_map::MutatorRef,
        /// Used to emit LevelUpdateEvent
        level_update_events: event::EventHandle<LevelUpdateEvent>,
    }

    /// The ambassador level
    struct AmbassadorLevel has key {
        ambassador_level: u64,
    }

    /// The ambassador level update event
    struct LevelUpdateEvent has drop, store {
        old_level: u64,
        new_level: u64,
    }

    /// Initializes the module, creating the ambassador collection
    fun init_module(sender: &signer) {
        create_ambassador_collection(sender);
    }

    #[view]
    /// Returns the ambassador level of the token
    public fun ambassador_level(token: Object<AmbassadorToken>): u64 acquires AmbassadorLevel {
        let ambassador_level = borrow_global<AmbassadorLevel>(object::object_address(&token));
        ambassador_level.ambassador_level
    }

    #[view]
    /// Returns the ambassador rank of the token
    public fun ambassador_rank(token: Object<AmbassadorToken>): String {
        property_map::read_string(&token, &string::utf8(b"Rank"))
    }

    /// Creates the ambassador collection
    fun create_ambassador_collection(creator: &signer) {
        let description = string::utf8(COLLECTION_DESCRIPTION);
        let name = string::utf8(COLLECTION_NAME);
        let uri = string::utf8(COLLECTION_URI);

        collection::create_unlimited_collection(
            creator,
            description,
            name,
            option::none(),
            uri,
        );
    }

    /// Mints an ambassador token
    public entry fun mint_ambassador_token(
        creator: &signer,
        description: String,
        name: String,
        uri: String,
        soul_bound_to: address,
    ) {
        let collection = string::utf8(COLLECTION_NAME);
        // Creates the ambassador token
        let constructor_ref = token::create_named_token(
            creator,
            collection,
            description,
            name,
            option::none(),
            uri,
        );

        // Generates the refs.
        let object_signer = object::generate_signer(&constructor_ref);
        let transfer_ref = object::generate_transfer_ref(&constructor_ref);
        let burn_ref = token::generate_burn_ref(&constructor_ref);
        let property_mutator_ref = property_map::generate_mutator_ref(&constructor_ref);
        let linear_transfer_ref = object::generate_linear_transfer_ref(&transfer_ref);

        // Transfers the token to the `soul_bound_to` address
        object::transfer_with_ref(linear_transfer_ref, soul_bound_to);

        // Disables ungated transfer, thus making the token soulbound
        object::disable_ungated_transfer(&transfer_ref);

        // Initializes the ambassador level
        move_to(&object_signer, AmbassadorLevel { ambassador_level: 0 });

        // Initialize the property map and the ambassador rank
        let properties = property_map::prepare_input(vector[], vector[], vector[]);
        property_map::init(&constructor_ref, properties);
        property_map::add_typed(
            &property_mutator_ref,
            string::utf8(b"Rank"),
            string::utf8(RANK_BRONZE)
        );

        // Initialize the ambassador token
        let ambassador_token = AmbassadorToken {
            burn_ref,
            property_mutator_ref,
            level_update_events: object::new_event_handle(&object_signer),
        };
        move_to(&object_signer, ambassador_token);
    }

    /// Burns an ambassador token
    public entry fun burn(creator: &signer, token: Object<AmbassadorToken>) acquires AmbassadorToken {
        authorize_creator(creator, &token);
        let ambassador_token = move_from<AmbassadorToken>(object::object_address(&token));
        let AmbassadorToken {
            burn_ref,
            property_mutator_ref,
            level_update_events,
        } = ambassador_token;
        event::destroy_handle(level_update_events);
        property_map::burn(property_mutator_ref);
        token::burn(burn_ref);
    }

    /// Sets the ambassador level of the token
    public entry fun set_ambassador_level(
        creator: &signer,
        token: Object<AmbassadorToken>,
        new_ambassador_level: u64
    ) acquires AmbassadorLevel, AmbassadorToken {
        authorize_creator(creator, &token);
        let token_address = object::object_address(&token);
        let ambassador_level = borrow_global_mut<AmbassadorLevel>(token_address);
        event::emit_event(
            &mut borrow_global_mut<AmbassadorToken>(token_address).level_update_events,
            LevelUpdateEvent {
                old_level: ambassador_level.ambassador_level,
                new_level: new_ambassador_level,
            }
        );
        ambassador_level.ambassador_level = new_ambassador_level;
        update_ambassador_rank(token, new_ambassador_level);
    }

    /// Updates the ambassador rank of the token based on the new level
    fun update_ambassador_rank(
        token: Object<AmbassadorToken>,
        new_ambassador_level: u64
    ) acquires AmbassadorToken {
        let token_address = object::object_address(&token);
        let ambassador_token = borrow_global_mut<AmbassadorToken>(token_address);
        let property_mutator_ref = &ambassador_token.property_mutator_ref;
        let new_rank = if (new_ambassador_level < 10) {
            RANK_BRONZE
        } else if (new_ambassador_level < 20) {
            RANK_SILVER
        } else {
            RANK_GOLD
        };
        property_map::update_typed(property_mutator_ref, &string::utf8(b"Rank"), string::utf8(new_rank));
    }

    /// Authorizes the creator of the token
    inline fun authorize_creator<T: key>(creator: &signer, token: &Object<T>) {
        let token_address = object::object_address(token);
        assert!(
            exists<T>(token_address),
            error::not_found(ETOKEN_DOES_NOT_EXIST),
        );
        assert!(
            token::creator(*token) == signer::address_of(creator),
            error::permission_denied(ENOT_CREATOR),
        );
    }

    /// Authorizes and borrows the ambassador token
    inline fun authorized_borrow<T: key>(creator: &signer, token: &Object<T>): &AmbassadorToken {
        authorize_creator(creator, token);
        borrow_global<AmbassadorToken>(object::object_address(token))
    }

    #[test(creator = @0x123, user1 = @0x456)]
    fun test_mint_burn(creator: &signer, user1: &signer) acquires AmbassadorToken, AmbassadorLevel {
        // ------------------------------------------
        // Creator creates the Ambassador Collection.
        // ------------------------------------------
        create_ambassador_collection(creator);

        // -------------------------------------------
        // Creator mints a Ambassador token for User1.
        // -------------------------------------------
        let token_name = string::utf8(b"Ambassador Token #1");
        let token_description = string::utf8(b"Ambassador Token #1 Description");
        let token_uri = string::utf8(b"Ambassador Token #1 URI");
        let user1_addr = signer::address_of(user1);
        mint_ambassador_token(
            creator,
            token_description,
            token_name,
            token_uri,
            user1_addr,
        );
        let collection_name = string::utf8(COLLECTION_NAME);
        let token_address = token::create_token_address(
            &signer::address_of(creator),
            &collection_name,
            &token_name
        );
        let token = object::address_to_object<AmbassadorToken>(token_address);
        assert!(object::owner(token) == user1_addr, 1);

        // -----------------------
        // Creator sets the level.
        // -----------------------
        assert!(ambassador_level(token) == 0, 2);
        assert!(ambassador_rank(token) == string::utf8(RANK_BRONZE), 3);
        set_ambassador_level(creator, token, 15);
        assert!(ambassador_level(token) == 15, 4);
        assert!(ambassador_rank(token) == string::utf8(RANK_SILVER), 5);

        // ------------------------
        // Creator burns the token.
        // ------------------------
        let token_addr = object::object_address(&token);
        assert!(exists<AmbassadorToken>(token_addr), 6);
        burn(creator, token);
        assert!(!exists<AmbassadorToken>(token_addr), 7);
    }
}
