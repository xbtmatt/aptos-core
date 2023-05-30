module mint_nft_v2_part3::whitelist {
    use std::vector;
    use std::string::{String};
    use std::timestamp;
    use std::signer;
    use aptos_std::simple_map::{Self, SimpleMap};
    use std::smart_table::{Self, SmartTable};
    use std::coin;
    use std::error;
    use std::aptos_coin::{AptosCoin};

    /// Represents all the mint tiers available as a map<key: String, value: MintTier>
    /// Stored in the creator's account resources
    struct Tiers has key {
        map: SimpleMap<String, MintTier>,
    }

    /// The price, times, and per user limit for a specific tier; e.g. public, whitelist
    /// the `open_to_public` field indicates there is no restrictions for a requesting address. it is a public mint- it still tracks # of mints though
    struct MintTier has store {
        open_to_public: bool,
        addresses: SmartTable<address, u64>,
        price: u64,
        start_time: u64,
        end_time: u64,
        per_user_limit: u64,
    }

    /// The whitelist MintTier with name "tier_name" was not found
    const ETIER_NOT_FOUND: u64 = 0;
    /// The account requesting to mint is not in that whitelist tier
    const EACCOUNT_NOT_WHITELISTED: u64 = 1;
    /// The account requesting to mint has no mints left for that whitelist tier
    const EACCOUNT_HAS_NO_MINTS_LEFT: u64 = 2;
    /// The mint tier requested has not started yet
    const EMINT_NOT_STARTED: u64 = 3;
    /// The mint tier requested has already ended
    const EMINT_ENDED: u64 = 4;
    /// The account requesting to mint doesn't have enough coins to mint
    const ENOT_ENOUGH_COINS: u64 = 5;
    /// The requested start time is not before the end time
    const ESTART_TIME_AFTER_END_TIME: u64 = 6;

    public entry fun init_tiers(
        creator: &signer,
    ) {
        coin::register<AptosCoin>(creator);
        move_to(
            creator,
            Tiers {
                map: simple_map::create<String, MintTier>(),
            },
        );
    }

    /// Facilitates adding or updating tiers. If the whitelist tier already exists, update it's values- keep the addresses the same
    public entry fun upsert_tier_config(
        creator: &signer,
        tier_name: String,
        open_to_public: bool,
        price: u64,
        start_time: u64,
        end_time: u64,
        per_user_limit: u64,
    ) acquires Tiers {
        assert!(start_time < end_time, error::invalid_argument(ESTART_TIME_AFTER_END_TIME));
        let creator_addr = signer::address_of(creator);
        if (!exists<Tiers>(creator_addr)) {
            init_tiers(creator);
        };
        let tiers = borrow_global_mut<Tiers>(creator_addr);

        if (simple_map::contains_key(&tiers.map, &tier_name)) {
            let tier = simple_map::borrow_mut(&mut tiers.map, &tier_name);
            tier.open_to_public = open_to_public;
            tier.price = price;
            tier.start_time = start_time;
            tier.end_time = end_time;
            tier.per_user_limit = per_user_limit;
        } else {
            let mint_tier = MintTier {
                open_to_public,
                addresses: smart_table::new_with_config<address, u64>(4, 0, 0),
                price,
                start_time,
                end_time,
                per_user_limit,
            };
            simple_map::add(&mut tiers.map, tier_name, mint_tier);
        };
    }

    // Note that this module is agnostic to the existence of an 'admin', that is managed from the calling module.
    // we assume that the caller has gated access to this function correctly
    public entry fun add_addresses_to_tier(
        creator: &signer,
        tier_name: String,
        addresses: vector<address>,
    ) acquires Tiers {
        let map = &mut borrow_global_mut<Tiers>(signer::address_of(creator)).map;
        assert!(simple_map::contains_key(map, &tier_name), error::not_found(ETIER_NOT_FOUND));
        let mint_tier = simple_map::borrow_mut(map, &tier_name);
        vector::for_each(addresses, |user_addr| {
            // note that this will abort in `table` if the address exists already- use `upsert` to ignore this
            smart_table::add(&mut mint_tier.addresses, user_addr, 0);
        });
    }

    // Note that this module is agnostic to the existence of an 'admin', that is managed from the calling module.
    // we assume that the caller has gated access to this function correctly
    public entry fun remove_addresses_from_tier(
        creator: &signer,
        tier_name: String,
        addresses: vector<address>,
    ) acquires Tiers {
        let map = &mut borrow_global_mut<Tiers>(signer::address_of(creator)).map;
        assert!(simple_map::contains_key(map, &tier_name), error::not_found(ETIER_NOT_FOUND));
        let mint_tier = simple_map::borrow_mut(map, &tier_name);
        vector::for_each(addresses, |user_addr| {
            // note that this will abort in `table` if the address is not found
            smart_table::remove(&mut mint_tier.addresses, user_addr);
        });
    }

    public entry fun deduct_one_from_tier(
        minter: &signer,
        tier_name: String,
        creator_addr: address,
    ) acquires Tiers {
        let minter_addr = signer::address_of(minter);

        let map = &mut borrow_global_mut<Tiers>(creator_addr).map;
        assert!(simple_map::contains_key(map, &tier_name), error::not_found(ETIER_NOT_FOUND));
        let mint_tier = simple_map::borrow_mut(map, &tier_name);

        // assert not too early and not too late
        let now = timestamp::now_seconds();
        assert!(now > mint_tier.start_time, error::permission_denied(EMINT_NOT_STARTED));
        assert!(now < mint_tier.end_time, error::permission_denied(EMINT_ENDED));

        // if `addresses` doesn't contain the minter address, abort if the tier is not open to the public, otherwise add it
        if (!smart_table::contains(&mint_tier.addresses, minter_addr)) {
            if (mint_tier.open_to_public) {
                // open to public but address not in whitelist, add it to list with 0 mints
                smart_table::add(&mut mint_tier.addresses, minter_addr, 0);
            } else {
                // not open to public and address not in whitelist, abort
                abort error::permission_denied(EACCOUNT_NOT_WHITELISTED)
            };
        };

        // assert that the user has mints left
        let count = smart_table::borrow_mut(&mut mint_tier.addresses, minter_addr);
        assert!(*count < mint_tier.per_user_limit, error::permission_denied(EACCOUNT_HAS_NO_MINTS_LEFT));

        // mint the token and transfer `price` AptosCoin from minter to
        assert!(coin::balance<AptosCoin>(minter_addr) >= mint_tier.price, error::permission_denied(ENOT_ENOUGH_COINS));
        coin::transfer<AptosCoin>(minter, creator_addr, mint_tier.price);

        // update the value at the user's address in the smart table
        *count = *count + 1;
    }
}