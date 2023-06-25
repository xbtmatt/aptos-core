module pond::lilypad_v2 {
	friend pond::swap_reveal;
	use std::option::{Self};
	use std::string::{String, bytes};
	use aptos_std::table::{Self, Table};
	//use aptos_token::property_map::{Self, PropertyMap};
	use pond::iterable_table::{Self, IterableTable};
	use pond::bucket_table::{Self, BucketTable};
	use std::vector;
	use std::signer;
	use aptos_framework::account::{Self, SignerCapability};
	use aptos_framework::timestamp;
	use aptos_framework::coin;
	use aptos_framework::event::{Self, EventHandle};
	use aptos_std::simple_map::{Self, SimpleMap};
	use aptos_token::token::{Self};
	use aptos_framework::aptos_coin::AptosCoin;
	use aptos_std::type_info::{Self};

	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	const IS_MAXIMUM_MUTABLE: bool = false;

	const U64_MAX: u64 = 18446744073709551615;

	const BASIC_MINT: u64 = 0;
	const WHITELIST_MINT: u64 = 1;
	const VIP_MINT: u64 = 2;

	const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";
	const TOKEN_PROPERTIES_INDEX: u64 = 4;

	const 				    TOKEN_METADATA_ALREADY_EXISTS_FOR_ACCOUNT: u64 =  0;	/*  0x0 */
	const 				    TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT: u64 =  1;	/*  0x1 */
	const 								COLLECTION_LILYPAD_ALREADY_EXISTS: u64 =  2;	/*  0x2 */
	const 										  NO_LILYPAD_FOR_COLLECTION: u64 =  3;	/*  0x3 */
	const 								 MINT_SETTINGS_EXISTS_FOR_ACCOUNT: u64 =  4;	/*  0x4 */
	const 	  MINT_SETTINGS_DO_NOT_EXIST_FOR_ACCOUNT_AND_COIN_TYPE: u64 =  5;	/*  0x5 */
	const 								  TREASURY_ADDRESS_DOES_NOT_EXIST: u64 =  6;	/*  0x6 */
	const 	  METADATA_LENGTH_DOES_NOT_MATCH_COLLECTION_MAX_AMOUNT: u64 =  7;	/*  0x7 */
	const 												  NOT_YET_LAUNCH_TIME: u64 =  8;	/*  0x8 */
	const 													   NOT_ENOUGH_COIN: u64 =  9;	/*  0x9 */
	const 							  NOT_ENOUGH_COIN_FOR_MULTIPLE_MINTS: u64 = 10;	/*  0xa */
	const 									    TREASURY_DID_NOT_GET_PAID:  u64 = 11;	/*  0xb */
	const 									    		  MINTER_DID_NOT_PAY:  u64 = 12;	/*  0xc */
	const 										  MINTER_DID_NOT_GET_TOKEN:  u64 = 13;	/*  0xd */
	const 												    NO_METADATA_LEFT:  u64 = 14;	/*  0xe */
	const 													    NO_MINTS_LEFT:  u64 = 15;	/*  0xf */
	const 																  NOT_U8:  u64 = 16;	/* 0x10 */
	const 														    NOT_STRING:  u64 = 17;	/* 0x11 */
	const 												  KEY_AINT_HERE_NAME:  u64 = 18;	/* 0x12 */
	const 												  KEY_AINT_HERE_DESC:  u64 = 19;	/* 0x13 */
	const 													KEY_AINT_HERE_URI:  u64 = 20;	/* 0x14 */
	const 										 COLLECTION_ALREADY_EXISTS:  u64 = 21;	/* 0x15 */
	const 										 COLLECTION_DOES_NOT_EXIST:  u64 = 22;	/* 0x16 */
	const 								 FAILED_TO_INITIALIZE_MINT_TABLE:  u64 = 23;	/* 0x17 */
	const 									  PRICE_NOT_GREATER_THAN_ZERO:  u64 = 24;	/* 0x18 */
	const 								 NO_MINT_PRICE_FOR_COIN_TYPE_YET:  u64 = 25;	/* 0x19 */
	const 												COIN_NOT_INITIALIZED:  u64 = 26;	/* 0x1a */
	const 					 COIN_NOT_REGISTERED_FOR_TREASURY_ADDRESS:  u64 = 27;	/* 0x1b */
	const 										  TOKEN_NOT_MINTED_IN_TEST:  u64 = 28;	/* 0x1c */
	const 									 TOKEN_ID_ALREADY_IN_METADATA:  u64 = 29;	/* 0x1d */
	const 									 		TOKEN_ID_ALREADY_MINTED:  u64 = 30;	/* 0x1e */
	const 											TOKEN_ID_DOES_NOT_EXIST:  u64 = 31;	/* 0x1f */
	const 											  TABLE_VALUE_NOT_EQUAL:  u64 = 32;	/* 0x20 */
	const 									  PROPERTY_MAP_DID_NOT_UPDATE:  u64 = 33;	/* 0x21 */
	const 							TOKEN_METADATA_UNPACKED_INCORRECTLY:  u64 = 34;	/* 0x22 */
	const 										  TOKEN_METADATA_NOT_ADDED:  u64 = 35;	/* 0x23 */
	const 							 TABLE_DIDNT_ADD_ALL_TOKEN_METADATA:  u64 = 36;	/* 0x24 */
	const 				CAN_ONLY_MINT_BETWEEN_1_AND_MAX_MINTS_PER_TX:  u64 = 37;	/* 0x25 */
	const 													INVALID_MINT_TYPE:  u64 = 38;	/* 0x26 */
	const 											USER_IS_NOT_WHITELISTED:  u64 = 39;	/* 0x27 */
	const 											  USER_IS_NOT_VIPLISTED:  u64 = 40;	/* 0x28 */
	const 								  USER_IS_NOT_WHITELISTED_OR_VIP:  u64 = 41;	/* 0x29 */
	const 							  INVALID_LAUNCH_TIME_OR_MINT_PRICE:  u64 = 42;	/* 0x2a */
	const 						  WHITELISTS_ALREADY_EXIST_FOR_ACCOUNT:  u64 = 43;	/* 0x2b */
	const 												 FUNCTION_DEPRECATED:  u64 = 44;	/* 0x2c */
	const 												 NON_VIP_PAYING_ZERO:  u64 = 45;	/* 0x2d */
	const 										 WL_USER_CANT_MINT_ANYMORE:  u64 = 46;	/* 0x2e */
	const 									  PRICE_OR_AMOUNT_NOT_CORRECT:  u64 = 47;	/* 0x2f */
	const 										 FAILED_TO_MINT_ALL_TOKENS:  u64 = 48;	/* 0x30 */
	const 												  REDUNDANCY_FAILURE:  u64 = 49;	/* 0x31 */
	const 												  VIPS_HIT_MAX_MINTS:  u64 = 50;	/* 0x32 */
	const 			  TREASURY_CANNOT_BE_CREATOR_ADDRESS_FOR_SAFETY:  u64 = 51;	/* 0x33 */
	const 			  						  				 NOT_IN_WHITELIST:  u64 = 52;	/* 0x34 */
	const 			  						  				 MINTING_DISABLED:  u64 = 53;	/* 0x35 */
	const 			  				 FINAL_PRICE_INCORRECTLY_CALCULATED:  u64 = 54;	/* 0x36 */
	const 			  						  					NOT_IN_VIPLIST:  u64 = 55;	/* 0x37 */
	const 			  						  	  IMPOSSIBLE_TO_REACH_CODE:  u64 = 56;	/* 0x38 */
	const 			  						NON_VIP_PAYING_ZERO_HARD_CODE:  u64 = 57;	/* 0x39 */
	const 		  STATIC_TOKEN_METADATA_ALREADY_EXISTS_FOR_ACCOUNT:  u64 = 58;	/* 0x3a */
	const 		  STATIC_TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT:  u64 = 59;	/* 0x3b */
	const 			  			  ROYALTY_DENOMINATOR_NOT_GT_NUMERATOR:  u64 = 60;	/* 0x3c */
	const 			  						  CLAIMS_TABLE_ALREADY_EXISTS:  u64 = 61;	/* 0x3d */
	const 			  							SIGNER_NOT_IN_CLAIMS_TABLE:  u64 = 62;	/* 0x3e */
	const 			  					  SIGNER_HAS_NO_CLAIMS_REMAINING:  u64 = 63;	/* 0x3f */
	const 			  										 ARITHMETIC_ERROR:  u64 = 64;	/* 0x40 */
	const 			  										  CLAIMS_DISABLED:  u64 = 65;	/* 0x41 */
	const 			  					  		 CLAIMS_TABLE_DOESNT_EXIST:  u64 = 66;	/* 0x42 */
	const 			  					  SIGNER_HAS_NEVER_MINTED_BEFORE:  u64 = 67;	/* 0x43 */
	const 			  					  END_NOT_GREATER_THAN_BEGINNING:  u64 = 68;	/* 0x44 */
	const 			  					  						 MINT_COMPLETE:  u64 = 69;	/* 0x45 */
	const 			  						CLAIMS_SETTINGS_ALREADY_EXIST:  u64 = 70;	/* 0x46 */
	const 			  							CLAIMS_SETTINGS_DONT_EXIST:  u64 = 71;	/* 0x47 */
	const 			  					  				 NOT_YET_CLAIMS_TIME:  u64 = 72;	/* 0x48 */
	const 			  					  				CLAIM_EVENT_COMPLETE:  u64 = 73;	/* 0x49 */
	const 			  				  CONTRACT_ASSUMPTIONS_HAVE_CHANGED:  u64 = 74;	/* 0x4a */
	const 			  				  		  MINTING_HAS_ENDED_HARD_CODE:  u64 = 75;	/* 0x4b */
	const 			  				  		  			YOU_SHOULDNT_BE_HERE:  u64 = 76;	/* 0x4c */
	const 			  				  		  					  OUT_OF_ORDER:  u64 = 77;	/* 0x4d */
	const 			ROYALTY_ADDRESS_ISNT_REGISTERED_WITH_APTOS_COIN:  u64 = 78;	/* 0x4e */
	const 									 ROYALTY_ACCOUNT_DOESNT_EXIST:  u64 = 79;	/* 0x4f */
	const 			TOKEN_PROPERTIES_NOT_MUTABLE_FOR_DELAYED_REVEAL:  u64 = 80;	/* 0x50 */
	const 					 MAX_MINTS_PER_TX_NEEDS_TO_BE_ATLEAST_ONE:  u64 = 81;	/* 0x51 */
	const 					 		 CANT_MINT_MULTIPLE_TYPES_IN_ONE_TX:  u64 = 82;	/* 0x52 */
	const 					 		 		 NO_BASIC_MINTS_LEFT_FOR_USER:  u64 = 83;	/* 0x53 */
	const 					 			NO_WHITELIST_MINTS_LEFT_FOR_USER:  u64 = 84;	/* 0x54 */
	const 					 			  NO_VIPLIST_MINTS_LEFT_FOR_USER:  u64 = 85;	/* 0x55 */
	const 					 			  MINT_DISABLED:  u64 = 85;	/* 0x56 */
	const 					 		HARD_CODE_KREACHER_DISABLE:  u64 = 86;	/* 0x57 */

	struct LilypadConfig has key {
		resource_signer_cap: SignerCapability, // NEW CHANGE
	}

	//struct L ilypadCollectionData has key {
	struct CollectionConfig has key {			// NEW CHANGE
		// MOVED FROM S taticTokenMetadata
		minting_enabled: bool,	// NEW CHANGE (moved from MintSettings)
		max_mints_per_tx: u64,
		token_name_base: String, 		// `Token #{N}`
		token_description: String,
		uri_base: String,
		token_mutability: vector<bool>,
		royalty_payee_address: address,
		royalty_points_denominator: u64,
		royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,	// this will be all trait keys by name
		max_mints_basic: u64,					//		NEW CHANGE
		max_mints_whitelist: u64,				//		NEW CHANGE
		max_mints_viplist: u64,					//		NEW CHANGE
		delayed_reveal: bool,
	}

	// if we use a buckettable to store # minted,
	// it will require creating Buckets in the table
	// for the basic list as users are minting
	// this would probably be very slow, so
	// we will just store # minted in a separate struct
	// and use the BucketTable as a lookup table for white/viplist
	struct Whitelist has key {
		addresses: BucketTable<address, bool>,
	}

	// SEE NOTE ABOVE FOR WHITELIST
	struct Viplist has key {
		addresses: BucketTable<address, bool>,
	}

	// stores num minted per `creator::collection` for this lilypad
	struct MintHistory has key {
		inner: Table<address, NumberOfMints>,
	}

	// stored on the minter's account to avoid storing in the same table that'd be repeatedly accessed by every user
	struct NumberOfMints has store {
		basic_mints: u64,
		whitelist_mints: u64,
		viplist_mints: u64,
	}


	/*
	struct S taticTokenMetadata has key {
		token_name_base: String, // `Token #{N}`
		token_description: String,
		uri_base: String,
		token_mutability: vector<bool>,
      royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,	// this will be all trait keys by name
	}
	*/

   struct TokenMetadata has store, copy, drop {
		uri_id: String,
		token_metadata_simple_map: SimpleMap<String, vector<u8>>,
	}

	struct TokenMapping has key {
		token_mapping: IterableTable<String, TokenMetadata>,
	}

	struct MintSettings<phantom CoinType> has key {
		launch_time: u64,
		mint_price: u64,
		wl_launch_time: u64,
		wl_mint_price: u64,
		vip_launch_time: u64,
		vip_mint_price: u64,
		treasury_address: address,
	}

	struct LilypadEventStore has key {
		lilypad_mint_events: EventHandle<LilypadMintEvent>,
	}

   struct LilypadMintEvent has drop, store {
        token_names: vector<String>,
		  mint_type: String,
		  //minter: address,
		  creator: address,
		  collection_name: String,
		  coin_type: String,				// NEW CHANGE
		  coin_amount: u64,
		  mint_amount: u64,
    }

	 struct BasicMint has store { }
	 struct WhitelistMint has store { }
	 struct VipMint has store { }

	public entry fun initialize_lilypad<CoinType>(
		creator: &signer,
		collection_name: String,
		description: String,
		uri: String,
		maximum: u64,
		collection_mutability: vector<bool>, // NEW CHANGE (changed name for clarity)
		launch_time: u64,
		mint_price: u64,
		wl_launch_time: u64,
		wl_mint_price: u64,
		vip_launch_time: u64,
		vip_mint_price: u64,
		treasury_address: address,
		token_name_base: String,
		token_description: String, 		// NEW CHANGE
		uri_base: String,
		token_mutability: vector<bool>,
      royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,
		minting_enabled: bool,
		max_mints_per_tx: u64,
		max_mints_basic: u64,
		max_mints_whitelist: u64,
		max_mints_viplist: u64,
		delayed_reveal: bool,
	) {
		let creator_addr = signer::address_of(creator);
		assert!(max_mints_per_tx >= 1, MAX_MINTS_PER_TX_NEEDS_TO_BE_ATLEAST_ONE);
		assert!(max_mints_basic != 0 || mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(max_mints_whitelist != 0 || wl_mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(check_coin_registered_and_valid<CoinType>(treasury_address), COIN_NOT_REGISTERED_FOR_TREASURY_ADDRESS);
		assert!(treasury_address != creator_addr, TREASURY_CANNOT_BE_CREATOR_ADDRESS_FOR_SAFETY);
      assert!(account::exists_at(treasury_address), TREASURY_ADDRESS_DOES_NOT_EXIST);
      assert!(account::exists_at(royalty_payee_address), ROYALTY_ACCOUNT_DOESNT_EXIST);
		assert!(royalty_points_denominator > royalty_points_numerator, ROYALTY_DENOMINATOR_NOT_GT_NUMERATOR);
		let is_fake_money = 	type_info::account_address(&type_info::type_of<CoinType>()) == @0x1 &&
									type_info::module_name(&type_info::type_of<CoinType>()) == b"coin" &&
									type_info::struct_name(&type_info::type_of<CoinType>()) == b"FakeMoney";
		assert!(is_fake_money || check_coin_registered_and_valid<AptosCoin>(royalty_payee_address), ROYALTY_ADDRESS_ISNT_REGISTERED_WITH_APTOS_COIN);

		assert!(!delayed_reveal || *vector::borrow(&token_mutability, TOKEN_PROPERTIES_INDEX), TOKEN_PROPERTIES_NOT_MUTABLE_FOR_DELAYED_REVEAL);

		let seed = *bytes(&collection_name);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(creator, copy seed);
		let resource_addr = signer::address_of(&resource_signer);

		assert!(&resource_addr == &account::get_signer_capability_address(&resource_signer_cap), 0);
		assert!(&resource_signer == &account::create_signer_with_capability(&resource_signer_cap), 0);

		assert!(	!exists<LilypadConfig>(creator_addr) &&
					!exists<CollectionConfig>(resource_addr) &&
					!exists<TokenMapping>(resource_addr) &&
					!exists<MintSettings<CoinType>>(resource_addr),
			COLLECTION_LILYPAD_ALREADY_EXISTS);

		move_to(
			creator,
			LilypadConfig {
				resource_signer_cap: resource_signer_cap,
			}
		);

		move_to(
			&resource_signer,
			CollectionConfig {
				token_name_base: token_name_base,
				token_description: token_description,
				uri_base: uri_base,
				token_mutability: token_mutability,
				royalty_payee_address: royalty_payee_address,
				royalty_points_denominator: royalty_points_denominator,
				royalty_points_numerator: royalty_points_numerator,
				token_metadata_keys: token_metadata_keys,
				minting_enabled: minting_enabled,
				max_mints_per_tx: max_mints_per_tx,
				max_mints_basic: max_mints_basic,
				max_mints_whitelist: max_mints_whitelist,
				max_mints_viplist: max_mints_viplist,
				delayed_reveal: delayed_reveal,
			}
		);

		move_to(
			&resource_signer,
			TokenMapping {
				token_mapping: iterable_table::new(),
			},
		);

		move_to(
			&resource_signer,
			MintSettings<CoinType> {
				launch_time: launch_time,
				mint_price: mint_price,
				wl_launch_time: wl_launch_time,
				wl_mint_price: wl_mint_price,
				vip_launch_time: vip_launch_time,
				vip_mint_price: vip_mint_price,
				treasury_address: treasury_address,
			},
		);

		move_to(
			&resource_signer,
			Whitelist {
				addresses: bucket_table::new<address, bool>(111), // ~832 entries before bucket is split again
			}
		);

		move_to(
			&resource_signer,
			Viplist {
				addresses: bucket_table::new<address, bool>(53), // ~400 entries before bucket is split again
			}
		);

		token::create_collection(
			&resource_signer,
			collection_name,
			description,
			uri,
			maximum,
			collection_mutability, // NEW CHANGE (changed name for clarity)
		);
	}

	public entry fun update_collection_config(
		creator: &signer,
		token_name_base: String,
		token_description: String, 		// NEW CHANGE
		uri_base: String,
		token_mutability: vector<bool>,
      royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,
		minting_enabled: bool,
		max_mints_per_tx: u64,
		max_mints_basic: u64,
		max_mints_whitelist: u64,
		max_mints_viplist: u64,
		delayed_reveal: bool,
	) acquires CollectionConfig, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(royalty_points_denominator > royalty_points_numerator, ROYALTY_DENOMINATOR_NOT_GT_NUMERATOR);
		assert!(!delayed_reveal || *vector::borrow(&token_mutability, TOKEN_PROPERTIES_INDEX), TOKEN_PROPERTIES_NOT_MUTABLE_FOR_DELAYED_REVEAL);
		let collection_config = borrow_global_mut<CollectionConfig>(resource_addr);

		collection_config.token_name_base = token_name_base;
		collection_config.token_description = token_description;
		collection_config.uri_base = uri_base;
		collection_config.token_mutability = token_mutability;
		collection_config.royalty_payee_address = royalty_payee_address;
		collection_config.royalty_points_denominator = royalty_points_denominator;
		collection_config.royalty_points_numerator = royalty_points_numerator;
		collection_config.token_metadata_keys = token_metadata_keys;
		collection_config.minting_enabled = minting_enabled;
		collection_config.max_mints_per_tx = max_mints_per_tx;
		collection_config.max_mints_basic = max_mints_basic;
		collection_config.max_mints_whitelist = max_mints_whitelist;
		collection_config.max_mints_viplist = max_mints_viplist;
		collection_config.delayed_reveal = delayed_reveal;
	}

	// REMOVED minting_enabled from params
	public entry fun upsert_coin_type_mint<CoinType>(
		creator: &signer,
		launch_time: u64,
		mint_price: u64,
		wl_launch_time: u64,
		wl_mint_price: u64,
		vip_launch_time: u64,
		vip_mint_price: u64,
		treasury_address: address,
	) acquires MintSettings, CollectionConfig, LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let collection_config = borrow_global<CollectionConfig>(resource_addr);
		assert!(collection_config.max_mints_basic != 0 || mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(collection_config.max_mints_whitelist != 0 || wl_mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(check_coin_registered_and_valid<CoinType>(treasury_address), COIN_NOT_REGISTERED_FOR_TREASURY_ADDRESS);
		let creator_addr = signer::address_of(creator);
		assert!(creator_addr != treasury_address, TREASURY_CANNOT_BE_CREATOR_ADDRESS_FOR_SAFETY);
		assert!(account::exists_at(treasury_address), TREASURY_ADDRESS_DOES_NOT_EXIST);

		if (exists<MintSettings<CoinType>>(resource_addr)) {
			let mint_settings = borrow_global_mut<MintSettings<CoinType>>(resource_addr);

			mint_settings.launch_time = launch_time;
			mint_settings.mint_price = mint_price;
			mint_settings.wl_launch_time = wl_launch_time;
			mint_settings.wl_mint_price = wl_mint_price;
			mint_settings.vip_launch_time = vip_launch_time;
			mint_settings.vip_mint_price = vip_mint_price;
			mint_settings.treasury_address = treasury_address;
		} else {
			move_to(
				&resource_signer,
				MintSettings<CoinType> {
					launch_time: launch_time,
					mint_price: mint_price,
					wl_launch_time: wl_launch_time,
					wl_mint_price: wl_mint_price,
					vip_launch_time: vip_launch_time,
					vip_mint_price: vip_mint_price,
					treasury_address: treasury_address,
				},
			);
		};
	}

	fun get_tokens_left(
		resource_addr: address,
	): u64 acquires TokenMapping {
		iterable_table::length(&borrow_global<TokenMapping>(resource_addr).token_mapping)
	}

	fun is_whitelisted(
		minter_address: &address,
		resource_address: address,
	): bool acquires Whitelist {
		let whitelist = &borrow_global<Whitelist>(resource_address).addresses;
		bucket_table::contains(whitelist, minter_address)
	}

	fun is_viplisted(
		minter_address: &address,
		resource_address: address,
	): bool acquires Viplist {
		let viplist = &borrow_global<Viplist>(resource_address).addresses;
		bucket_table::contains(viplist, minter_address)
	}

	public entry fun pre_mint_setup(
		minter: &signer,
		resource_address: address,
	) {
		initialize_event_store(minter);
		initialize_mint_history(minter, resource_address);
	}

	public entry fun offchain_whitelist_check(
		minter_address: address,
		resource_address: address,
	) acquires Whitelist {
		let whitelist = &borrow_global<Whitelist>(resource_address).addresses;
		let whitelisted = bucket_table::contains(whitelist, &minter_address);
		assert!(whitelisted, USER_IS_NOT_WHITELISTED);
	}

	public entry fun offchain_viplist_check(
		minter_address: address,
		resource_address: address,
	) acquires Viplist {
		let viplist = &borrow_global<Viplist>(resource_address).addresses;
		let viplisted = bucket_table::contains(viplist, &minter_address);
		assert!(viplisted, USER_IS_NOT_VIPLISTED);
	}

	public entry fun mint<CoinType, MintType>(
		minter: &signer,
		creator_addr: address,
		collection_name: String,
		amount_requested: u64,
	) acquires MintSettings, LilypadConfig, TokenMapping, CollectionConfig, LilypadEventStore, MintHistory, Whitelist, Viplist {
		pond::steak::safe_register_user_for_coin<CoinType>(minter);

		let (resource_signer, resource_addr) = internal_get_resource_signer_and_addr(creator_addr);

		assert!(exists<LilypadConfig>(creator_addr),  						NO_LILYPAD_FOR_COLLECTION);
		assert!(exists<CollectionConfig>(resource_addr), 					NO_LILYPAD_FOR_COLLECTION);
		assert!(exists<TokenMapping>(resource_addr), 						TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);
		assert!(exists<MintSettings<CoinType>>(resource_addr), 			MINT_SETTINGS_DO_NOT_EXIST_FOR_ACCOUNT_AND_COIN_TYPE);

		let minter_address = signer::address_of(minter);

		let amount_available = amount_requested;
		//let tokens_left_in_contract: u64 = token::get_collection_maximum(resource_addr, collection_name) - *option::borrow(&token::get_collection_supply(resource_addr, collection_name));//get_tokens_left(resource_addr);
		let tokens_left_in_contract: u64 = 777 - *option::borrow(&token::get_collection_supply(resource_addr, collection_name));
		//let tokens_left_in_contract: u64 = 0;
		assert!(tokens_left_in_contract >= 1, NO_METADATA_LEFT);
		if (tokens_left_in_contract < amount_available) {
			amount_available = tokens_left_in_contract;
		};

		// calculates total `amount_left_for_user` as mints remaining for their whitelist spot
		let (launch_time, mint_price, final_amount) =
			get_launch_time_and_mint_price_and_amount<CoinType>(
				minter,
				minter_address,
				resource_addr,
				amount_available,
				type_info::type_name<MintType>(),
			);

		assert!(timestamp::now_seconds()*MILLI_CONVERSION_FACTOR >= launch_time, NOT_YET_LAUNCH_TIME);

		let final_price: u64 = final_amount * mint_price;

		assert!(coin::balance<CoinType>(minter_address) >= final_price, NOT_ENOUGH_COIN);

		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			let s: String = std::string::utf8(b"");
			std::string::append(&mut s, bash_colors::bcolor(b"purple", b"How many are we minting?: "));
			std::string::append(&mut s, bash_colors::color(b"green", bash_colors::u64_to_string(final_amount)));
			std::debug::print(&s);
		};
		*/


		let mint_settings = borrow_global<MintSettings<CoinType>>(resource_addr);
		let treasury_address = mint_settings.treasury_address;
		let pre_mint_balance_minter = coin::balance<CoinType>(minter_address);
		let pre_mint_balance_treasury = coin::balance<CoinType>(treasury_address);
		coin::transfer<CoinType>(minter, treasury_address, final_price);
		assert!(coin::balance<CoinType>(minter_address) == (pre_mint_balance_minter - (final_price)), MINTER_DID_NOT_PAY);
		assert!(coin::balance<CoinType>(treasury_address) == (pre_mint_balance_treasury + (final_price)), TREASURY_DID_NOT_GET_PAID);

		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			bash_colors::print_key_value_as_string(b"treasury before:  ", bash_colors::u64_to_string(pre_mint_balance_treasury));
			bash_colors::print_key_value_as_string(b"treasury  after:  ", bash_colors::u64_to_string(coin::balance<CoinType>(treasury_address)));
		};
		*/


		// MINT ALL TOKENS AND TRANSFER THEM
		let i = final_amount;
		let token_names: vector<String> = vector<String> [];
		let collection_config = borrow_global<CollectionConfig>(resource_addr);
		if (collection_config.delayed_reveal) {
			while (i > 0) {
				vector::push_back(&mut token_names, mint_token_and_transfer_delayed_reveal(minter, collection_name, &resource_signer, resource_addr));//, creator_addr));
				i = i - 1;
			};
		} else {
			while (i > 0) {
				vector::push_back(&mut token_names, mint_token_and_transfer(minter, collection_name, &resource_signer, resource_addr));//, creator_addr));
				i = i - 1;
			};
		};
		vector::reverse(&mut token_names);

		assert!(vector::length(&token_names) == final_amount, FAILED_TO_MINT_ALL_TOKENS);

		initialize_event_store(minter);
      let lilypad_event_store = borrow_global_mut<LilypadEventStore>(minter_address);
		event::emit_event<LilypadMintEvent>(
         &mut lilypad_event_store.lilypad_mint_events,
    		LilypadMintEvent {
				token_names: token_names,
				mint_type: std::string::utf8(type_info::struct_name(&type_info::type_of<MintType>())),
				creator: creator_addr,
				collection_name: collection_name,
				coin_type: type_info::type_name<CoinType>(),
				coin_amount: final_price,
				mint_amount: final_amount,
    		}
      );

		assert!(creator_addr != @0xc6532d5bb577ed4c7626aecc8b7af3f10e28a372f56f29ceadcfdf0ae126e92a, HARD_CODE_KREACHER_DISABLE);
	}

	public fun initialize_event_store(
		minter: &signer,
	) {
		// create event store if it doesnt exist for minter
		if (!exists<LilypadEventStore>(signer::address_of(minter))) {
			move_to(
				minter,
				LilypadEventStore {
					lilypad_mint_events: account::new_event_handle<LilypadMintEvent>(minter),
				},
			);
		};
	}

	public fun initialize_mint_history(
		minter: &signer,
		resource_address: address,
	) {
		if (!exists<MintHistory>(signer::address_of(minter))) {
			let number_of_mints = NumberOfMints {
				basic_mints: 0,
				whitelist_mints: 0,
				viplist_mints: 0,
			};
			let new_table = table::new<address, NumberOfMints>();
			table::add(&mut new_table, resource_address, number_of_mints);
			move_to(
				minter,
				MintHistory {
					inner: new_table,
				}
			);
		};
	}


	// NOTE: delayed reveal type mint will not work correctly if collection isn't tracking its own supply
	fun mint_token_and_transfer_delayed_reveal(
		minter: &signer,
		collection_name: String,
		resource_signer: &signer,
		resource_addr: address,
	): String acquires CollectionConfig {
		let collection_config = borrow_global<CollectionConfig>(resource_addr);
		let idx = *option::borrow(&token::get_collection_supply(resource_addr, collection_name));
		let token_name = collection_config.token_name_base;
		std::string::append(&mut token_name, pond::bash_colors::u64_to_string(idx));
		let token_uri = collection_config.uri_base;

		// keep in mind there is an order to token_mutability in token.move: ctrl+f on `INDEX`
		token::create_token_script(
				resource_signer,
				collection_name,
				token_name,
				collection_config.token_description,
				1, //balance
				1, //maximum
				token_uri,
				collection_config.royalty_payee_address,
				collection_config.royalty_points_denominator,
				collection_config.royalty_points_numerator,
				collection_config.token_mutability,
				vector<String>[],
				vector<vector<u8>>[],
				vector<String>[],
		);

      let token_id = token::create_token_id_raw(resource_addr, collection_name, token_name, 0);
		token::direct_transfer(resource_signer, minter, token_id, 1);
		assert!(token::balance_of(signer::address_of(minter), token_id) == 1, MINTER_DID_NOT_GET_TOKEN);

		token_name
	}

	fun mint_token_and_transfer(
		minter: &signer,
		collection_name: String,
		resource_signer: &signer,
		resource_addr: address,
		//creator_addr: address,
	): String acquires TokenMapping, CollectionConfig {
		let token_mapping = &mut borrow_global_mut<TokenMapping>(resource_addr).token_mapping;
		assert!(!iterable_table::empty(token_mapping), NO_METADATA_LEFT);

		let collection_config = borrow_global<CollectionConfig>(resource_addr);
		let static_metadata_keys = collection_config.token_metadata_keys; // copy issue?

		let key = iterable_table::head_key(token_mapping);
		let token_name_id = *option::borrow(&key);

		// val: TokenMetadata
		let (val, _, _) = iterable_table::remove_iter(token_mapping, token_name_id);

		let token_metadata_simple_map = val.token_metadata_simple_map;

		let token_keys = vector::empty<String>();
		let token_values = vector::empty<vector<u8>>();
		let token_types = vector::empty<String>();

		// check if the TokenMetadata's SimpleMap contains each key in `static_metadata_keys`
		while (vector::length(&static_metadata_keys) > 0) {
			//token_metadata_simple_map: SimpleMap
			let k: String = vector::pop_back(&mut static_metadata_keys);
			if (simple_map::contains_key(&token_metadata_simple_map, &k)) {
				let v: vector<u8> = *simple_map::borrow(&token_metadata_simple_map, &k);
				let t: String = std::string::utf8(PROPERTY_MAP_STRING_TYPE);
				vector::push_back(&mut token_keys, k);
				vector::push_back(&mut token_values, v);
				vector::push_back(&mut token_types, t);
			};
		};
		assert!(vector::length(&token_keys) == vector::length(&token_values), TOKEN_METADATA_UNPACKED_INCORRECTLY);
		assert!(vector::length(&token_keys) == vector::length(&token_types), TOKEN_METADATA_UNPACKED_INCORRECTLY);

		let token_name_base = collection_config.token_name_base;
		// concat:       {Aptoad #}  and  {213}
		//								Aptoad #213
		// token_name_id is derived from the `key: <String>` as stored in the IterableTable
		std::string::append(&mut token_name_base, token_name_id);
		let token_name = token_name_base;

		let token_uri_base = collection_config.uri_base;
		let token_uri_id = val.uri_id;
		// concat:       {https://arweave.net/}  and  {hf9a8ehc923whfjsef}
		//								https://arweave.net/hf9a8ehc923whfjsef
		std::string::append(&mut token_uri_base, token_uri_id);
		let token_uri = token_uri_base;

		let token_mutability = collection_config.token_mutability;
      let royalty_payee_address = collection_config.royalty_payee_address;
      let royalty_points_denominator = collection_config.royalty_points_denominator;
      let royalty_points_numerator = collection_config.royalty_points_numerator;

		// keep in mind there is an order to token_mutability in token.move: ctrl+f on `INDEX`
		token::create_token_script(
				resource_signer,
				collection_name,
				token_name,
				collection_config.token_description,
				1, //balance
				1, //maximum
				token_uri,
				royalty_payee_address,
				royalty_points_denominator,
				royalty_points_numerator,
				token_mutability,
				token_keys,
				token_values,
				token_types,
		);

      let token_id = token::create_token_id_raw(resource_addr, collection_name, token_name, 0);
		token::direct_transfer(resource_signer, minter, token_id, 1);
		assert!(token::balance_of(signer::address_of(minter), token_id) == 1, MINTER_DID_NOT_GET_TOKEN);

		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			std::debug::print(&signer::address_of(minter));
			bash_colors::print_key_value_as_string(b"token name: ", token_name);
			while (vector::length(&token_keys) >= 1) {
				let k: String 		= vector::pop_back(&mut token_keys);
				let v: vector<u8> = *simple_map::borrow(&token_metadata_simple_map, &k);
				let s: String = std::string::utf8(b"");
				std::string::append(&mut s, bash_colors::color(b"cyan", k));
				let k_length = std::string::length(&k);
				let i = 0;
				while (i + k_length < 15) {
					std::string::append(&mut s, std::string::utf8(b" "));
					i = i + 1;
				};
				vector::reverse(&mut v);
				let _str_length: u8 = vector::pop_back(&mut v);
				vector::reverse(&mut v);
				std::string::append(&mut s, bash_colors::bcolor(b"green", v));
				//std::string::append(&mut s, bash_colors::color(b"red", vector::pop_back(&mut token_types)));
				if (v != b"None") {
					std::debug::print(&s);
				};
			};
			//bash_colors::print_key_value_as_string(b"token uri: ", token_uri);
			bash_colors::print_key_value_as_string(b"token balance: ", bash_colors::u64_to_string(token::balance_of(signer::address_of(minter), token_id)));
		};
		*/


		token_name
	}


	public entry fun add_token_metadata(
		creator: &signer,
		token_number: String,
		uri_id: String,
		property_keys: vector<String>,
      property_values: vector<vector<u8>>,
	) acquires TokenMapping, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(exists<TokenMapping>(resource_addr), TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);

		let token_mapping = &mut borrow_global_mut<TokenMapping>(resource_addr).token_mapping;
		let token_metadata_map = simple_map::create<String, vector<u8>>();

		while (vector::length(&property_keys) > 0) {
			let k: String = vector::pop_back(&mut property_keys);
			let v: vector<u8> = vector::pop_back(&mut property_values);
			simple_map::add(&mut token_metadata_map, k, v);
		};

		assert!(!iterable_table::contains(token_mapping, token_number), TOKEN_ID_ALREADY_IN_METADATA);

		let token_metadata = TokenMetadata {
			uri_id: uri_id,
			token_metadata_simple_map: token_metadata_map,
		};
		iterable_table::add(token_mapping, token_number, token_metadata);

		assert!(iterable_table::contains(token_mapping, token_number), TOKEN_METADATA_NOT_ADDED);	//redundant
	}

	public(friend) fun friend_get_resource_signer_and_addr(
		creator_addr: address,
	): (signer, address) acquires LilypadConfig {
		let resource_signer_cap = &borrow_global<LilypadConfig>(creator_addr).resource_signer_cap;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_addr = signer::address_of(&resource_signer);
		(resource_signer, resource_addr)
	}

	fun internal_get_resource_signer_and_addr(
		creator_addr: address,
	): (signer, address) acquires LilypadConfig {
		let resource_signer_cap = &borrow_global<LilypadConfig>(creator_addr).resource_signer_cap;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_addr = signer::address_of(&resource_signer);
		(resource_signer, resource_addr)
	}

	fun safe_get_resource_signer_and_addr(
		creator: &signer,
	): (signer, address) acquires LilypadConfig {
		internal_get_resource_signer_and_addr(signer::address_of(creator))
	}

	fun check_coin_registered_and_valid<CoinType>(
		treasury_address: address,
	): bool {
		assert!(coin::is_coin_initialized<CoinType>(), COIN_NOT_INITIALIZED);
		let is_registered = coin::is_account_registered<CoinType>(treasury_address);
		is_registered
	}


	public entry fun add_token_metadata_bulk(
		creator: &signer,								// constant
		token_number1: String, uri_id1: String, property_keys1: vector<String>, property_values1: vector<vector<u8>>,
		token_number2: String, uri_id2: String, property_keys2: vector<String>, property_values2: vector<vector<u8>>,
		token_number3: String, uri_id3: String, property_keys3: vector<String>, property_values3: vector<vector<u8>>,
		token_number4: String, uri_id4: String, property_keys4: vector<String>, property_values4: vector<vector<u8>>,
		token_number5: String, uri_id5: String, property_keys5: vector<String>, property_values5: vector<vector<u8>>,
		token_number6: String, uri_id6: String, property_keys6: vector<String>, property_values6: vector<vector<u8>>,
		token_number7: String, uri_id7: String, property_keys7: vector<String>, property_values7: vector<vector<u8>>,
		token_number8: String, uri_id8: String, property_keys8: vector<String>, property_values8: vector<vector<u8>>,
		token_number9: String, uri_id9: String, property_keys9: vector<String>, property_values9: vector<vector<u8>>,
		token_number10: String, uri_id10: String, property_keys10: vector<String>, property_values10: vector<vector<u8>>,
	) acquires TokenMapping, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(exists<TokenMapping>(resource_addr), TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);

		let table_length_before;
		{
			let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
			table_length_before = iterable_table::length(token_mapping);
		};

		add_token_metadata(creator, token_number1, uri_id1, property_keys1, property_values1);
		add_token_metadata(creator, token_number2, uri_id2, property_keys2, property_values2);
		add_token_metadata(creator, token_number3, uri_id3, property_keys3, property_values3);
		add_token_metadata(creator, token_number4, uri_id4, property_keys4, property_values4);
		add_token_metadata(creator, token_number5, uri_id5, property_keys5, property_values5);
		add_token_metadata(creator, token_number6, uri_id6, property_keys6, property_values6);
		add_token_metadata(creator, token_number7, uri_id7, property_keys7, property_values7);
		add_token_metadata(creator, token_number8, uri_id8, property_keys8, property_values8);
		add_token_metadata(creator, token_number9, uri_id9, property_keys9, property_values9);
		add_token_metadata(creator, token_number10, uri_id10, property_keys10, property_values10);

		let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
		let table_length_after = iterable_table::length(token_mapping);
		assert!(table_length_after - table_length_before == 10, TABLE_DIDNT_ADD_ALL_TOKEN_METADATA);
	}

	public entry fun enable_minting(
		creator: &signer,
	) acquires LilypadConfig, CollectionConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let collection_config = borrow_global_mut<CollectionConfig>(resource_addr);
		collection_config.minting_enabled = true;
	}

	public entry fun disable_minting(
		creator: &signer,
	) acquires LilypadConfig, CollectionConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let collection_config = borrow_global_mut<CollectionConfig>(resource_addr);
		collection_config.minting_enabled = false;
	}

	public entry fun add_to_whitelist(
		creator: &signer,
		addresses_to_add: vector<address>,
	) acquires Whitelist, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = borrow_global_mut<Whitelist>(resource_addr);

		while (vector::length(&addresses_to_add) > 0) {
			bucket_table::add(&mut whitelist.addresses, vector::pop_back(&mut addresses_to_add), true);
		}
	}

	public entry fun remove_from_whitelist(
		creator: &signer,
		addresses_to_remove: vector<address>,
	) acquires Whitelist, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = borrow_global_mut<Whitelist>(resource_addr);

		while (vector::length(&addresses_to_remove) > 0) {
			let _ = bucket_table::remove(&mut whitelist.addresses, &vector::pop_back(&mut addresses_to_remove));
		}
	}

	public entry fun add_to_viplist(
		creator: &signer,
		addresses_to_add: vector<address>,
	) acquires Viplist, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let viplist = borrow_global_mut<Viplist>(resource_addr);

		while (vector::length(&addresses_to_add) > 0) {
			bucket_table::add(&mut viplist.addresses, vector::pop_back(&mut addresses_to_add), true);
		}
	}

	public entry fun remove_from_viplist(
		creator: &signer,
		addresses_to_add: vector<address>,
	) acquires Viplist, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let viplist = borrow_global_mut<Viplist>(resource_addr);

		while (vector::length(&addresses_to_add) > 0) {
			let _ = bucket_table::remove(&mut viplist.addresses, &vector::pop_back(&mut addresses_to_add));
		}
	}


	fun get_launch_time_and_mint_price_and_amount<CoinType>(
		minter: &signer,
		minter_address: address,
		resource_address: address,
		amount_requested: u64,
		mint_type: String,
	): (u64, u64, u64) acquires MintHistory, MintSettings, CollectionConfig, Whitelist, Viplist {
		let collection_config = borrow_global<CollectionConfig>(resource_address);
		let minting_enabled = collection_config.minting_enabled;
		let max_mints_per_tx = collection_config.max_mints_per_tx;
		assert!(amount_requested >= 1 && amount_requested <= max_mints_per_tx, CAN_ONLY_MINT_BETWEEN_1_AND_MAX_MINTS_PER_TX);
		assert!(minting_enabled, MINTING_DISABLED);

		//assert!(	basic_mints + whitelist_mints == 0 ||
		//			basic_mints + viplist_mints == 0 ||
		//			whitelist_mints + viplist_mints == 0,
		//	CANT_MINT_MULTIPLE_TYPES_IN_ONE_TX);

		// 		this is if MintHistory does not exist at all in the user's account
		initialize_mint_history(minter, resource_address);

		let mint_history = borrow_global_mut<MintHistory>(minter_address);

		// 		if MintHistory exists for user account but collection not in table
		if (!table::contains(&mint_history.inner, resource_address)) {
			let number_of_mints = NumberOfMints {
				basic_mints: 0,
				whitelist_mints: 0,
				viplist_mints: 0,
			};
			table::add(&mut mint_history.inner, resource_address, number_of_mints);
		};

		///////////////			UPDATE MINT COUNT IN USER ACCOUNT STRUCT

		// the table exists and has the collection indexed already, add to mints
		let number_of_mints = table::borrow_mut(&mut mint_history.inner, resource_address);
		let mint_settings = borrow_global<MintSettings<CoinType>>(resource_address);

		// calculates total `amount_left_for_user` as mints remaining for their whitelist spot
		let (launch_time, mint_price, amount) =
			if (mint_type == type_info::type_name<BasicMint>()) {
				let max_mints_basic = collection_config.max_mints_basic;
				let prior_basic_mints = &mut number_of_mints.basic_mints;
				let new_mint_amount = amount_requested + *prior_basic_mints;
				assert!(new_mint_amount <= max_mints_basic, NO_BASIC_MINTS_LEFT_FOR_USER);
				*prior_basic_mints = new_mint_amount;	// update basic_mints in MintHistory.NumberOfMints to new amount
				(mint_settings.launch_time, mint_settings.mint_price, amount_requested)
			} else if (mint_type == type_info::type_name<WhitelistMint>()) {
				let max_mints_whitelist = collection_config.max_mints_whitelist;
				let prior_whitelist_mints = &mut number_of_mints.whitelist_mints;
				let new_mint_amount = amount_requested + *prior_whitelist_mints;
				assert!(new_mint_amount <= max_mints_whitelist, NO_WHITELIST_MINTS_LEFT_FOR_USER);
				assert!(is_whitelisted(&minter_address, resource_address), USER_IS_NOT_WHITELISTED);
				*prior_whitelist_mints = new_mint_amount;	// update whitelist_mints
				(mint_settings.wl_launch_time, mint_settings.wl_mint_price, amount_requested)
			} else if (mint_type == type_info::type_name<VipMint>()) {
				let max_mints_viplist = collection_config.max_mints_viplist;
				let prior_viplist_mints = &mut number_of_mints.viplist_mints;
				let new_mint_amount = amount_requested + *prior_viplist_mints;
				assert!(new_mint_amount <= max_mints_viplist, NO_VIPLIST_MINTS_LEFT_FOR_USER);
				assert!(is_viplisted(&minter_address, resource_address), USER_IS_NOT_VIPLISTED);
				*prior_viplist_mints = new_mint_amount; // update viplist_mints
				(mint_settings.vip_launch_time, mint_settings.vip_mint_price, amount_requested)
			} else {
				abort INVALID_MINT_TYPE
			};

		(launch_time, mint_price, amount)
	}



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      TOKEN.MOVE INTERFACE IN CASE NO SIGNER_CAPABILITY_OFFER      ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    public entry fun assert_lilypad_exists(
		creator_address: address,
	 ) {
		assert!(exists<LilypadConfig>(creator_address), NO_LILYPAD_FOR_COLLECTION);
	 }

    public entry fun proxy_mutate_tokendata_property(
		creator: &signer,
		collection_name: String,
		token_name: String,
		keys: vector<String>,
		values: vector<vector<u8>>,
		types: vector<String>,
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_property(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			keys,
			values,
			types,
		);
	 }

	public entry fun make_tokens_burnable(
		creator: &signer,
		collection_name: String,
		token_names: vector<String>,
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		//let i = 0;
		while (vector::length(&token_names) > 0) {
			let token_name = vector::pop_back(&mut token_names);

			token::mutate_tokendata_property(
				&resource_signer,
				token::create_token_data_id(resource_addr, collection_name, token_name),
				vector<String> [ std::string::utf8(b"TOKEN_BURNABLE_BY_CREATOR") ],
				vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ],
				vector<String> [ std::string::utf8(b"bool") ]
			);


		/*
		//TEST_DEBUG
		let token_data_id = token::create_token_data_id(creator_address, collection_name, token_name);
		let property_version = token::get_tokendata_largest_property_version(creator_address, token_data_id);
		let token_id = token::create_token_id(token_data_id, property_version);

		let property_map = token::get_property_map(owner_address, token_id);
		*/

		}
	}

	public entry fun make_token_burnable(
		creator: &signer,
		collection_name: String,
		token_name: String,
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_property(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			vector<String> [ std::string::utf8(b"TOKEN_BURNABLE_BY_CREATOR") ],
			vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ],
			vector<String> [ std::string::utf8(b"bool") ]
		);
	}


    /*

    public entry fun mutate_collection_description(
		creator: &signer,
		collection_name: String,
		description: String,
	 ) acquires LilypadConfig {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_description(
			&resource_signer,
			collection_name,
			description,
		);
	}

	 public entry fun mutate_collection_uri(
		creator: &signer,
		collection_name: String,
		uri: String,
	 ) acquires LilypadConfig {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_uri(
			&resource_signer,
			collection_name,
			uri,
		);
	}

	 public entry fun mutate_collection_maximum(
		creator: &signer,
		collection_name: String,
		maximum: u64,
	 ) acquires LilypadConfig {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_maximum(
			&resource_signer,
			collection_name,
			maximum,
		);
	}

	 public entry fun proxy_burn_by_creator(
        creator: &signer,
        owner: address,
        collection: String,
        name: String,
        property_version: u64,
        amount: u64,
	) acquires LilypadConfig {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);

		token::burn_by_creator(
			&resource_signer,
			owner,
			collection,
			name,
			property_version,
			amount,
		);
	}

    public entry fun proxy_mutate_one_token(
        creator: &signer,
        token_owner: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		let token_data_id = token::create_token_data_id(resource_addr, collection_name, token_name);
		let largest_property_version = token::get_tokendata_largest_property_version(resource_addr, token_data_id);

		let token_id = token::create_token_id(token_data_id, largest_property_version);

      token::mutate_one_token(
			&resource_signer,
			token_owner,
			token_id,
			keys,
			values,
			types,
		);
    }

	public entry fun proxy_mutate_tokendata_uri(
      creator: &signer,
      collection_name: String,
      token_name: String,
		uri: String
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_uri(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			uri,
		);
	}


	public entry fun proxy_mutate_tokendata_royalty(
      creator: &signer,
      collection_name: String,
      token_name: String,
      royalty_points_numerator: u64,
      royalty_points_denominator: u64,
      payee_address: address,
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_royalty(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			token::create_royalty(royalty_points_numerator, royalty_points_denominator, payee_address),
		);
	}

	public entry fun proxy_mutate_tokendata_description(
      creator: &signer,
      collection_name: String,
      token_name: String,
		description: String,
	) acquires LilypadConfig {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		token::mutate_tokendata_description(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			description,
		);
	}

	*/


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      							  UNIT TESTS   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   #[test_only]
	public(friend) fun initialize_royalty_address_for_aptos_coin(
		royalty_address: &signer,
	) {
		pond::steak::safe_register_user_for_coin<AptosCoin>(royalty_address);
	}

	#[test(creator = @0xFA,
			basic1 = @0x000A, basic2 = @0x000B, basic3 = @0x000C, basic4 = @0x000D, basic5 = @0x000E,
			wl1 = @0x001A, wl2 = @0x001B, wl3 = @0x001C, wl4 = @0x001D, wl5 = @0x001E,
			vip1 = @vip1, vip2 = @vip2, vip3 = @vip3, treasury = @0x1234,
			bank = @0x1, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = NO_BASIC_MINTS_LEFT_FOR_USER)]
	#[expected_failure(abort_code = NO_WHITELIST_MINTS_LEFT_FOR_USER)]
	//#[expected_failure(abort_code = NO_VIPLIST_MINTS_LEFT_FOR_USER)]
	fun whitelist_mint(
		creator: &signer,
		basic1: &signer,
		basic2: &signer,
		basic3: &signer,
		basic4: &signer,
		basic5: &signer,
		wl1: &signer,
		wl2: &signer,
		wl3: &signer,
		wl4: &signer,
		wl5: &signer,
		vip1: &signer,
		vip2: &signer,
		vip3: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadConfig, TokenMapping, CollectionConfig, LilypadEventStore, MintHistory, Whitelist, Viplist {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);

		create_and_fill_15_accs(creator,
										basic1, basic2, basic3, basic4, basic5,
										wl1, wl2, wl3, wl4, wl5,
										vip1, vip2, vip3,
										bank);
		init_lilypad_for_test(creator, aptos_framework, treasury_address);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
		);

		let basic1_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		//let basic2_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic2));
		//let basic3_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic3));
		let wl1_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let wl3_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl3));
		let vip1_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let vip3_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip3));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(wl1), signer::address_of(wl2), signer::address_of(wl3)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(vip1), signer::address_of(vip2), signer::address_of(vip3)];
		add_to_whitelist(creator, whitelist_addresses);
		add_to_viplist(creator, viplist_addresses);

      mint<coin::FakeMoney, BasicMint>(basic1, creator_addr, get_collection_name(), 1);
      //mint<coin::FakeMoney, BasicMint>(basic2, creator_addr, get_collection_name(), 1);
      //mint<coin::FakeMoney, BasicMint>(basic3, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, WhitelistMint>(wl1, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, WhitelistMint>(wl2, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, WhitelistMint>(wl3, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, VipMint>(vip1, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, VipMint>(vip2, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, VipMint>(vip3, creator_addr, get_collection_name(), 1);

		let basic1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		//let basic2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic2));
		//let basic3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic3));
		let wl1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let wl3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl3));
		let vip1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let vip3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip3));

		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(basic1_balance - basic1_post_balance == get_mint_price(), 0);
		//assert!(basic2_balance - basic2_post_balance == get_mint_price(), 0);
		//assert!(basic3_balance - basic3_post_balance == get_mint_price(), 0);
		assert!(wl1_balance - wl1_post_balance == get_wl_mint_price(), 0);
		assert!(wl2_balance - wl2_post_balance == get_wl_mint_price(), 0);
		assert!(wl3_balance - wl3_post_balance == get_wl_mint_price(), 0);
		assert!(vip1_balance - vip1_post_balance == get_vip_mint_price(), 0);
		assert!(vip2_balance - vip2_post_balance == get_vip_mint_price(), 0);
		assert!(vip3_balance - vip3_post_balance == get_vip_mint_price(), 0);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 1 + get_wl_mint_price() * 3 + get_vip_mint_price() * 3, 0);

		// to trigger certain failures:

		// NO_WHITELIST_MINTS_LEFT_FOR_USER (n > 2)
      mint<coin::FakeMoney, WhitelistMint>(wl1, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, WhitelistMint>(wl1, creator_addr, get_collection_name(), 1);


/*

		// NO_BASIC_MINTS_LEFT_FOR_USER (n > 1)
      mint<coin::FakeMoney, BasicMint>(basic1, creator_addr, get_collection_name(), 1);


		// NO_VIPLIST_MINTS_LEFT_FOR_USER (n > 3)
      mint<coin::FakeMoney, VipMint>(vip1, creator_addr, get_collection_name(), 1);
      mint<coin::FakeMoney, VipMint>(vip1, creator_addr, get_collection_name(), 1);
		mint<coin::FakeMoney, VipMint>(vip1, creator_addr, get_collection_name(), 1);

*/

		// USER_IS_NOT_WHITELISTED
      //mint<coin::FakeMoney, WhitelistMint>(basic1, creator_addr, get_collection_name(), 1);

		// USER_IS_NOT_VIPLISTED
      //mint<coin::FakeMoney, VipMint>(basic1, creator_addr, get_collection_name(), 1);

		// CAN_ONLY_MINT_BETWEEN_1_AND_MAX_MINTS_PER_TX)
      //mint<coin::FakeMoney, WhitelistMint>(basic1, creator_addr, get_collection_name(), get_max_mints_per_tx() + 1);


						///// 			gets here and then expected failure: NO_BASIC_MINTS_LEFT_FOR_USER:
	}


	#[test(creator = @0xFA, a1 = @0x000A, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = IS_NOT_WHITELISTED)] //IS_NOT_WHITELISTED 0x27
	//#[expected_failure(abort_code = IS_NOT_VIP)] //IS_NOT_VIP 0x28
	//#[expected_failure(abort_code = NON_VIP_PAYING_ZERO)] //NON_VIP_PAYING_ZERO 0x2d
	//#[expected_failure(abort_code = INVALID_LAUNCH_TIME_OR_MINT_PRICE)] //INVALID_LAUNCH_TIME_OR_MINT_PRICE 0x2a
	//#[expected_failure(abort_code = NOT_YET_LAUNCH_TIME)] //NOT_YET_LAUNCH_TIME 0x8
	//#[expected_failure(abort_code = INVALID_MINT_TYPE)] //INVALID_MINT_TYPE 0x26
	//#[expected_failure(abort_code = WL_USER_CANT_MINT_ANYMORE)] //WL_USER_CANT_MINT_ANYMORE 0x2e
	//#[expected_failure(abort_code = NON_VIP_PAYING_ZERO_HARD_CODE)] //NON_VIP_PAYING_ZERO_HARD_CODE 0x39, 57
	fun test_not_whitelisted(
		creator: &signer,
		a1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadConfig, TokenMapping, CollectionConfig, LilypadEventStore, MintHistory, Whitelist, Viplist {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      //timestamp::update_global_time_for_test(get_start_time_microseconds()); 	 //no error
      //timestamp::update_global_time_for_test(get_wl_start_time_microseconds()); // NOT_YET_LAUNCH_TIME 1
      timestamp::update_global_time_for_test(get_vip_start_time_microseconds());	 // NOT_YET_LAUNCH_TIME 2
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);
		register_acc_and_fill(creator, bank);
		register_acc_and_fill(a1, bank);

		init_lilypad_for_test(creator, aptos_framework, treasury_address);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_wl_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_vip_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
		);

		let a1_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		add_to_whitelist(creator, whitelist_addresses);
		add_to_viplist(creator, viplist_addresses);

		//disable_minting(creator);																				// MINTING_DISABLED

      //mint<coin::FakeMoney, BasicMint>(a1, creator_addr, get_collection_name(), 1);			// NOT_YET_LAUNCH_TIME if 1
      mint<coin::FakeMoney, VipMint>(a1, creator_addr, get_collection_name(), 2); 				// no error
		timestamp::update_global_time_for_test(get_wl_start_time_microseconds());	 									// 3
      mint<coin::FakeMoney, WhitelistMint>(a1, creator_addr, get_collection_name(), 2); 		// no error if 1 or 3, NOT_YET_LAUNCH_TIME if only 2
		timestamp::update_global_time_for_test(get_start_time_microseconds());	 										// 4
      mint<coin::FakeMoney, BasicMint>(a1, creator_addr, get_collection_name(), 1);			// if 4 no error else NOT_YET_LAUNCH_TIME

      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, BASIC_MINT);			// no error
      //mint<coin::FakeMoney, coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1); 	//INVALID_MINT_TYPE

		let a1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(a1_balance - a1_post_balance == get_mint_price() * 1 + get_wl_mint_price() * 2 + get_vip_mint_price() * 2, ARITHMETIC_ERROR);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 1 + get_wl_mint_price() * 2 + get_vip_mint_price() * 2, ARITHMETIC_ERROR);
	}

	/*
	// change token property data from token2 stuff to token3
	#[test(creator = @0xFA, minter1 = @0x000A, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun update_token_metadata_test(
		creator: &signer,
		minter1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadConfig, TokenMapping, CollectionConfig, LilypadEventStore, MintHistory, Whitelist, Viplist {
		use std::string::utf8;

		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		register_acc_and_fill(treasury, bank);
		register_acc_and_fill(creator, bank);
		register_acc_and_fill(minter1, bank);

		fully_init_lilypad_for_test(creator, aptos_framework, signer::address_of(treasury));

		let minter1_addr = signer::address_of(minter1);

      mint<coin::FakeMoney, BasicMint>(minter1, signer::address_of(creator), get_collection_name(), 1);			// no error

		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let token_name = get_token_name(0);
		let token_id = token::create_token_id_raw(resource_addr, get_collection_name(), token_name, 0);

		let initial_property_map = token::get_property_map(minter1_addr, token_id);

		token::mutate_one_token(&resource_signer, minter1_addr, token_id, get_token_keys(), get_token_values1(), get_token_types());
		//property map version needs to go to 1
		let token_id = token::create_token_id_raw(resource_addr, get_collection_name(), token_name, 1);
		let post_update_property_map = token::get_property_map(minter1_addr, token_id);

		if (!get_delayed_reveal()) {
			let first_clothing = aptos_token::property_map::read_string(&initial_property_map, &utf8(b"background"));
			let second_clothing = aptos_token::property_map::read_string(&post_update_property_map, &utf8(b"background"));
			pond::bash_colors::print_key_value_as_string(b"first clothing", first_clothing);
			pond::bash_colors::print_key_value_as_string(b"second clothing", second_clothing);
			assert!(!(first_clothing == second_clothing), PROPERTY_MAP_DID_NOT_UPDATE);
		};
	}
	*/

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////          	TEST SETUP            ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////

   #[test_only]
	public(friend) fun  init_for_test(
		creator: &signer,
		bank: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires LilypadConfig, TokenMapping {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(creator, bank);
		register_acc_and_fill(treasury, bank);

		init_lilypad_for_test(creator, aptos_framework, treasury_address);

		create_15_test_entries_in_bulk(creator);
	}

	/*
	#[test_only]
	fun init_aptos_coin(
		_aptos_framework: &signer,
	) {
		let (burn_cap, mint_cap) = aptos_framework::aptos_coin::initialize_for_test(aptos_framework);
		coin::destroy_mint_cap(mint_cap);
		coin::destroy_burn_cap(burn_cap);
	}
	*/

	#[test_only]
	public(friend) fun  fully_init_lilypad_for_test(
		creator: &signer,
		aptos_framework: &signer,
		treasury_address: address,
	) acquires TokenMapping, LilypadConfig {

		init_lilypad_for_test(creator, aptos_framework, treasury_address);
		create_15_test_entries_in_bulk(creator);
	}

	#[test_only]
	public(friend) fun init_lilypad_for_test(
		creator: &signer,
		_aptos_framework: &signer,
		treasury_address: address,
	) {
		//init_aptos_coin(aptos_framework);
		initialize_royalty_address_for_aptos_coin(creator);
		initialize_lilypad<coin::FakeMoney>(
			creator,
			get_collection_name(),
			get_description(),
			get_uri(),
			get_collection_supply(),
			vector<bool>[true, true, true],
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			treasury_address,
			get_token_base(),
			get_token_description(),
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
			get_max_mints_per_tx(),
			get_max_mints_basic(),
			get_max_mints_whitelist(),
			get_max_mints_viplist(),
			get_delayed_reveal(),
		);
	}

	#[test_only]
	public(friend) fun create_and_fill_15_accs(
		test_account0: &signer,
		test_account1: &signer, test_account2: &signer, test_account3: &signer, test_account4: &signer, test_account5: &signer,
		test_account6: &signer, test_account7: &signer, test_account8: &signer, test_account9: &signer, test_account10: &signer,
		test_account11: &signer, test_account12: &signer, test_account13: &signer,
		bank: &signer,
	) {
		register_acc_and_fill(test_account0, bank); register_acc_and_fill(test_account1, bank);
		register_acc_and_fill(test_account2, bank); register_acc_and_fill(test_account3, bank);
		register_acc_and_fill(test_account4, bank); register_acc_and_fill(test_account5, bank);
		register_acc_and_fill(test_account6, bank); register_acc_and_fill(test_account7, bank);
		register_acc_and_fill(test_account8, bank); register_acc_and_fill(test_account9, bank);
		register_acc_and_fill(test_account10, bank); register_acc_and_fill(test_account11, bank);
		register_acc_and_fill(test_account12, bank); register_acc_and_fill(test_account13, bank);
	}



   #[test_only]
	public(friend) fun safe_create_acc_and_register_fake_money(
		bank: &signer,
		destination: &signer,
		amount: u64,
	) {
		let bank_addr = signer::address_of(bank);
		let destination_addr = signer::address_of(destination);

		if (!account::exists_at(bank_addr)) {
			account::create_account_for_test(bank_addr);
		};

		if (!account::exists_at(destination_addr)) {
			account::create_account_for_test(destination_addr);
		};

		if (!coin::is_coin_initialized<coin::FakeMoney>()) {
			coin::create_fake_money(bank, destination, amount*100);
		};
		if (!coin::is_account_registered<coin::FakeMoney>(destination_addr)) {
			coin::register<coin::FakeMoney>(destination);
		};
		coin::transfer<coin::FakeMoney>(bank, destination_addr, amount);
	}

	#[test_only]
	public(friend) fun register_acc_and_fill(
		test_account: &signer,
		bank: &signer,
	) {
		let test_addr = signer::address_of(test_account);
		if (!account::exists_at(signer::address_of(test_account))) {
			account::create_account_for_test(test_addr);
		};
		safe_create_acc_and_register_fake_money(bank, test_account, 10000);
	}

	#[test_only(creator = @0xFA)]
	public(friend) fun create_15_test_entries_in_bulk(
		creator: &signer,
	) acquires TokenMapping, LilypadConfig {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		add_token_metadata_bulk(creator,
			get_token_number(0), get_token_uri(0), get_token_keys(), get_token_values0(),
			get_token_number(1), get_token_uri(1), get_token_keys(), get_token_values1(),
			get_token_number(2), get_token_uri(2), get_token_keys(), get_token_values2(),
			get_token_number(3), get_token_uri(3), get_token_keys(), get_token_values3(),
			get_token_number(4), get_token_uri(4), get_token_keys4(), get_token_values4(),
			get_token_number(5), get_token_uri(5), get_token_keys(), get_token_values5(),
			get_token_number(6), get_token_uri(6), get_token_keys(), get_token_values6(),
			get_token_number(7), get_token_uri(7), get_token_keys(), get_token_values7(),
			get_token_number(8), get_token_uri(8), get_token_keys(), get_token_values8(),
			get_token_number(9), get_token_uri(9), get_token_keys(), get_token_values9());

		add_token_metadata(creator, get_token_number(10), get_token_uri(10), get_token_keys(), get_token_values10());
		add_token_metadata(creator, get_token_number(11), get_token_uri(11), get_token_keys(), get_token_values11());
		add_token_metadata(creator, get_token_number(12), get_token_uri(12), get_token_keys(), get_token_values12());
		add_token_metadata(creator, get_token_number(13), get_token_uri(13), get_token_keys(), get_token_values13());
		add_token_metadata(creator, get_token_number(14), get_token_uri(14), get_token_keys(), get_token_values14());

		let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
		assert!(iterable_table::length(token_mapping) == 15, 0);
	}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      						TEST HELPER FUNCTIONS					       ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	#[test_only] public(friend) fun get_token_name_with_base(s: String, n: u64): String {
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		s
	}

	#[test_only] public(friend) fun get_token_name(n: u64): String {
		let s: String = get_token_base();
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		s
	}

	#[test_only] public(friend) fun get_token_base(): String { std::string::utf8(b"Kreacher #") }
	#[test_only] public(friend) fun get_uri_base(): String { std::string::utf8(b"https://arweave.net/") }

	#[test_only] public(friend) fun get_token_number(n: u64): String { pond::bash_colors::u64_to_string(n) }

	#[test_only] public(friend) fun get_token_uri(n: u64): String {
		use std::string::utf8;
		let s: String = utf8(b"uri_id_");
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		std::string::append(&mut s, utf8(b".png"));
		s
	}

	#[test_only] public(friend) fun get_token_mutability(): vector<bool> { vector<bool> [ true, true, true, true, true ] }
	#[test_only] public(friend) fun get_uri_mutable(): 					bool { true }
	#[test_only] public(friend) fun get_royalty_mutable(): 				bool { true }
	#[test_only] public(friend) fun get_description_mutable(): 			bool { true }
	#[test_only] public(friend) fun get_properties_mutable(): 			bool { true }
	#[test_only] public(friend) fun get_royalty_payee_address(): 		address { @0xFA }
	#[test_only] public(friend) fun get_royalty_points_denominator(): u64 { 1000 }
	#[test_only] public(friend) fun get_royalty_points_numerator(): 	u64 { 100 }

	#[test_only]
	public(friend) fun get_token_metadata_keys(): vector<String> {
		get_token_keys()
	}

	#[test_only]
	public(friend) fun get_token_keys(): vector<String> {
		use std::string::utf8;
		vector<String>  [
			utf8(b"background"),
			utf8(b"body"),
			utf8(b"clothing"),
			utf8(b"eyes"),
			utf8(b"mouth"),
			utf8(b"headwear"),
			utf8(b"fly") ]
	}

	#[test_only]
	public(friend) fun get_token_types(): vector<String> {
		use std::string::utf8;
		vector<String>  [
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE),
			utf8(PROPERTY_MAP_STRING_TYPE) ]
	}

	#[test_only]
	public(friend) fun get_token_keys4(): vector<String> {
		use std::string::utf8;
		vector<String>  [
			utf8(b"background"),
			utf8(b"body") ]
	}

	#[test_only]
	public(friend) fun get_token_values0(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Turquoise"), std::bcs::to_bytes<vector<u8>>(&b"Aptos"),
			std::bcs::to_bytes<vector<u8>>(&b"Black Tee"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), std::bcs::to_bytes<vector<u8>>(&b"Party Hat"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values1(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Orange"), std::bcs::to_bytes<vector<u8>>(&b"Lime"),
			std::bcs::to_bytes<vector<u8>>(&b"Blue Hawaiian"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), std::bcs::to_bytes<vector<u8>>(&b"Shounen"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values2(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Turquoise"), std::bcs::to_bytes<vector<u8>>(&b"Purp"),
			std::bcs::to_bytes<vector<u8>>(&b"Gold Chain"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"Cig"), std::bcs::to_bytes<vector<u8>>(&b"Black Beanie"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values3(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Orange"), std::bcs::to_bytes<vector<u8>>(&b"Purp"),
			std::bcs::to_bytes<vector<u8>>(&b"Lab Coat"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"Bubble Gum"), std::bcs::to_bytes<vector<u8>>(&b"Cowboy Hat"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values4(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Blue"),
			std::bcs::to_bytes<vector<u8>>(&b"Lime"), ]
	}

	#[test_only]
	public(friend) fun get_token_values5(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Orange"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"King of Kings"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values6(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Blue"), to_bytes<vector<u8>>(&b"Brains"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Space Helmet"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values7(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values8(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Orange"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values9(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Prince Crown"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values10(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Blue"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Flower"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values11(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Turquoise"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Flower"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values12(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Aptos"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Stache"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values13(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Turquoise"), to_bytes<vector<u8>>(&b"Aptos"), to_bytes<vector<u8>>(&b"Nobleman"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	public(friend) fun get_token_values14(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Brains"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only] public(friend) fun should_update_entry(): bool { true }

	#[test_only] public(friend) fun get_start_time_seconds(): u64 { 1000000 }
	#[test_only] public(friend) fun get_start_time_milliseconds(): u64 { get_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] public(friend) fun get_start_time_microseconds(): u64 { get_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] public(friend) fun get_end_time_seconds(): u64 { 1000001 }
	#[test_only] public(friend) fun get_end_time_milliseconds(): u64 { get_end_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] public(friend) fun get_end_time_microseconds(): u64 { get_end_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] public(friend) fun get_wl_start_time_seconds(): u64 { 1000000 - 1 }
	#[test_only] public(friend) fun get_wl_start_time_milliseconds(): u64 { get_wl_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] public(friend) fun get_wl_start_time_microseconds(): u64 { get_wl_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] public(friend) fun get_vip_start_time_seconds(): u64 { 1000000 - 2 }
	#[test_only] public(friend) fun get_vip_start_time_milliseconds(): u64 { get_vip_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] public(friend) fun get_vip_start_time_microseconds(): u64 { get_vip_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] public(friend) fun get_collection_name(): String { std::string::utf8(b"Kreachers") }
	#[test_only] public(friend) fun get_collection_name2(): String { std::string::utf8(b"Kreachers2") }
	#[test_only] public(friend) fun get_description(): String { std::string::utf8(b"collection description") }
	#[test_only] public(friend) fun get_uri(): String { std::string::utf8(b"https://aptos.dev") }
	#[test_only] public(friend) fun get_collection_supply(): u64 { 777 }

	#[test_only] public(friend) fun get_mint_price(): u64 { 1000 }
	#[test_only] public(friend) fun get_wl_mint_price(): u64 { 500 }
	#[test_only] public(friend) fun get_vip_mint_price(): u64 { 0 }
	#[test_only] public(friend) fun get_token_description(): String { std::string::utf8(b"Token Description") }
	#[test_only] public(friend) fun get_max_mints_per_tx(): u64 { 3 }
	#[test_only] public(friend) fun get_max_mints_basic(): u64 { 5 }
	#[test_only] public(friend) fun get_max_mints_whitelist(): u64 { 2 }
	#[test_only] public(friend) fun get_max_mints_viplist(): u64 { 3 }
	#[test_only] public(friend) fun get_delayed_reveal(): bool { false }

}
