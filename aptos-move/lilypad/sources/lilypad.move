module pond::lilypad {
    use std::option::{Self};
    use std::string::{String};
	 use std::string::bytes;
    use aptos_std::table::{Self, Table};
    //use aptos_token::property_map::{Self, PropertyMap};
	 use pond::iterable_table::{Self, IterableTable};
	 use std::vector;
    use std::signer;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::timestamp;
    use aptos_framework::coin;
    use aptos_framework::event::{Self, EventHandle};
    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_token::token::{Self};

    const MILLI_CONVERSION_FACTOR: u64 = 1000;
    const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	 const IS_MAXIMUM_MUTABLE: bool = false;

	 const BASIC_MINT: u64 = 0;
	 const WHITELIST_MINT: u64 = 1;
	 const VIP_MINT: u64 = 2;
	 const CLAIM_MINT: u64 = 3;

	 const U64_MAX: u64 = 18446744073709551615;

	 const MAX_MINTS_PER_TX: u64 = 3;
	 const MAX_MINTS_PER_WHITELIST_USER: u64 = 3;
	 const MAX_VIP_MINTS: u64 = 210;


	 const CLAIM_AMOUNT: u64 = 1;

	 const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";

    //const ED25519_SCHEME: u8 = 0;

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
    const 												  IS_NOT_WHITELISTED:  u64 = 39;	/* 0x27 */
    const 															 IS_NOT_VIP:  u64 = 40;	/* 0x28 */
    const 										 IS_NOT_WHITELISTED_OR_VIP:  u64 = 41;	/* 0x29 */
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
    const 			  				  		  MINTING_HAS_ENDED_HARD_CODE:  u64 = 74;	/* 0x4a */
    const 			  				  		  			YOU_SHOULDNT_BE_HERE:  u64 = 75;	/* 0x4b */
    const 			  				  		  					  OUT_OF_ORDER:  u64 = 75;	/* 0x4b */

	// key is the collection name
	struct LilypadCollectionData has key {
		resource_signer_cap: SignerCapability,
		vip_mints: u64,
	}

	struct LilypadEventStore has key {
		lilypad_mint_events: EventHandle<LilypadMintEvent>,
	}

	struct LilypadClaimsData has key {
		lilypad_claims: Table<address, u64>,
		claims_enabled: bool,
	}

	struct LilypadClaimsSettings has key {
		launch_time: u64,
		end_time: u64,
	}

	struct StaticTokenMetadata has key {
		token_name_base: String, // `Aptoad #`  then we append the {id} to it in the minting contract
		//description_base: String, // SPECIFICALLY FOR APTOADS, WE WILL NOT STORE A DESCRIPTION SINCE
											 //  ULTIMATELY WE ARE JUST GOING TO STORE THE TOKEN NAME AS DESCRIPTION
		uri_base: String,
		token_mutability: vector<bool>,
      royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,	// this will be all trait keys by name
															// we will use this to check if the SimpleMap
															// in TokenMetadata contains each key in this vector
	}

   struct TokenMetadata has store, copy, drop {
		//name: String,
		//description: String,
		uri_id: String,
		//uri_mutable: bool,
		//royalty_mutable: bool,
		//description_mutable: bool,
		//properties_mutable: bool,
      //royalty_payee_address: address,
      //royalty_points_denominator: u64,
      //royalty_points_numerator: u64,
		token_metadata_simple_map: SimpleMap<String, vector<u8>>,
	}

	// key is the name of the token
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
		minting_enabled: bool,
	}

	struct Whitelists<phantom CoinType> has key {
		whitelist: SimpleMap<address, u64>,
		viplist: SimpleMap<address, u64>,
	}

	// NOTE THAT WE EVENTUALLY NEED A FIELD FOR COIN TYPE IF YOU EVER DO MINTS WITH VARIOUS COIN TYPES
    struct LilypadMintEvent has drop, store {
        token_names: vector<String>,
		  mint_type: u64,
		  //minter: address,
		  creator: address,
		  collection_name: String,
		  coin_amount: u64,
		  mint_amount: u64,
    }

	public entry fun initialize_lilypad<CoinType>(
		creator: &signer,
		collection_name: String,
		description: String,
		uri: String,
		maximum: u64,
		mutate_setting: vector<bool>,
		launch_time: u64,
		mint_price: u64,
		wl_launch_time: u64,
		wl_mint_price: u64,
		vip_launch_time: u64,
		vip_mint_price: u64,
		treasury_address: address,
		token_name_base: String,
		uri_base: String,
		token_mutability: vector<bool>,
      royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,
		minting_enabled: bool,
	) acquires StaticTokenMetadata, LilypadCollectionData {
		assert!(mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(wl_mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(check_coin_registered_and_valid<CoinType>(treasury_address), COIN_NOT_REGISTERED_FOR_TREASURY_ADDRESS);

		// to only let deployer use
		//assert!(signer::address_of(creator) == @lilypad_address, 0);
		let creator_addr = signer::address_of(creator);

		// DONT rotate because we want user to have control over the collection still
		//I believe if we rotate to 0x0 aka ZERO_AUTH_KEY then only the resource would have the capability to manage the collection
		//resource_account::rotate_account_authentication_key_and_store_capability(&resource_signer2, ZERO_AUTH_KEY);

		//NOTE THE ABOVE IS THE DEFAULT, SO WE HAVE NO CONTROL OVER IT UNLESS WE OFFER_SIGNER_CAPABILITY TO THE CREATOR
		// OR JUST CREATE THINGS IN THE CREATOR'S NAME AND THEN OFFER_SIGNER_CAPABILITY TO THE SIGNER_CAP
		let seed = *bytes(&collection_name);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(creator, copy seed);
		let resource_addr = signer::address_of(&resource_signer);

		assert!(&resource_addr == &account::get_signer_capability_address(&resource_signer_cap), 0);
		assert!(&resource_signer == &account::create_signer_with_capability(&resource_signer_cap), 0);

		//////////pond::bash_colors::print_key_value(b"resource_addr here: ", b"not yet lol");
		//////////std::debug::print(&resource_addr);

		//      so we dont get frozen out of the collection down the road and dont have to deal with the jankiness
		//		of doing everything through a signer cap, let's create the collection in the name of the creator
		//		but leave all module resources in the resource_addr. Then the creator will offer_signer_capability
		//		to the resource_signer_cap for the mint?
		//		can revoke it after?


		/*
		let account_public_key_bytes = aptos_framework::account::get_authentication_key(creator_addr);
		let recipient_address = resource_addr;

		aptos_framework::account::offer_signer_capability(
			creator,
			get_creator_signer_capability_sig_bytes(creator, resource_addr),
			ED25519_SCHEME,
			account_public_key_bytes,
			recipient_address,
		);
		*/


		if (!exists<LilypadCollectionData>(creator_addr)) {
			move_to(
				creator,
				LilypadCollectionData {
					resource_signer_cap: resource_signer_cap,
					vip_mints: 0,
				}
			);
		};

		//if (creator_addr == @0xFA) {
		//	let sig = x"922d10f38995feba3a0c79e56555191b7a062d35bfe84d0ba0da2c1fec6bb8253e9311e2c1846826b8db6150bc23acdccf67f9ee9fa784a9c8296117e4403806";
		//	offer_signer_capability_to_lilypad_resource_account(creator, sig);
		//};


		assert!(!exists<TokenMapping>(resource_addr), TOKEN_METADATA_ALREADY_EXISTS_FOR_ACCOUNT);
		move_to(
			&resource_signer,
			TokenMapping {
				token_mapping: iterable_table::new(),
			},
		);

		assert!(!exists<StaticTokenMetadata>(resource_addr), STATIC_TOKEN_METADATA_ALREADY_EXISTS_FOR_ACCOUNT);
		upsert_static_token_metadata(
			creator,
			token_name_base,
			uri_base,
			token_mutability,
			royalty_payee_address,
			royalty_points_denominator,
			royalty_points_numerator,
			token_metadata_keys);

      assert!(account::exists_at(treasury_address), TREASURY_ADDRESS_DOES_NOT_EXIST);
		assert!(!exists<MintSettings<CoinType>>(resource_addr), MINT_SETTINGS_EXISTS_FOR_ACCOUNT);
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
				minting_enabled: minting_enabled,
			},
		);

		assert!(treasury_address != creator_addr, TREASURY_CANNOT_BE_CREATOR_ADDRESS_FOR_SAFETY);

		assert!(!exists<Whitelists<CoinType>>(resource_addr), WHITELISTS_ALREADY_EXIST_FOR_ACCOUNT);
		move_to(
			&resource_signer,
			Whitelists<CoinType> {
				whitelist: simple_map::create<address, u64>(),
				viplist: simple_map::create<address, u64>(),
			}
		);

		token::create_collection(
			//creator,
			&resource_signer,
			collection_name,
			description,
			uri,
			maximum,
			mutate_setting,
		);
		//assert!(token::check_collection_exists(creator_addr, collection_name), COLLECTION_DOES_NOT_EXIST);
		assert!(token::check_collection_exists(resource_addr, collection_name), COLLECTION_DOES_NOT_EXIST);

	}

	public entry fun upsert_static_token_metadata(
		creator: &signer,
		token_name_base: String,
		uri_base: String,
		token_mutability: vector<bool>,
		royalty_payee_address: address,
		royalty_points_denominator: u64,
		royalty_points_numerator: u64,
		token_metadata_keys: vector<String>,
	) acquires StaticTokenMetadata, LilypadCollectionData {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(royalty_points_denominator > royalty_points_numerator, ROYALTY_DENOMINATOR_NOT_GT_NUMERATOR);

		if (exists<StaticTokenMetadata>(resource_addr)) {
			let static_token_metadata = borrow_global_mut<StaticTokenMetadata>(resource_addr);
			 static_token_metadata.token_name_base = token_name_base;
			 static_token_metadata.uri_base = uri_base;
			 static_token_metadata.token_mutability = token_mutability;
			 static_token_metadata.royalty_payee_address = royalty_payee_address;
			 static_token_metadata.royalty_points_denominator = royalty_points_denominator;
			 static_token_metadata.royalty_points_numerator = royalty_points_numerator;
			 static_token_metadata.token_metadata_keys = token_metadata_keys;
		} else {
			move_to(
				&resource_signer,
				StaticTokenMetadata {
					token_name_base: token_name_base,
					//description_base: String,
					uri_base: uri_base,
					token_mutability: token_mutability,
					royalty_payee_address: royalty_payee_address,
					royalty_points_denominator: royalty_points_denominator,
					royalty_points_numerator: royalty_points_numerator,
					token_metadata_keys: token_metadata_keys,
				},
			);
		}
	}

	public entry fun upsert_coin_type_mint<CoinType>(
		creator: &signer,
		//collection_name: String,
		launch_time: u64,
		mint_price: u64,
		wl_launch_time: u64,
		wl_mint_price: u64,
		vip_launch_time: u64,
		vip_mint_price: u64,
		treasury_address: address,
		minting_enabled: bool,
	) acquires MintSettings, LilypadCollectionData {
		assert!(mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(wl_mint_price > 0, PRICE_NOT_GREATER_THAN_ZERO);
		assert!(check_coin_registered_and_valid<CoinType>(treasury_address), COIN_NOT_REGISTERED_FOR_TREASURY_ADDRESS);
		let creator_addr = signer::address_of(creator);
		assert!(creator_addr != treasury_address, TREASURY_CANNOT_BE_CREATOR_ADDRESS_FOR_SAFETY);
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		// if exists, update
		if (exists<MintSettings<CoinType>>(resource_addr)) {
			let mint_settings = borrow_global_mut<MintSettings<CoinType>>(resource_addr);

			mint_settings.launch_time = launch_time;
			mint_settings.mint_price = mint_price;
			mint_settings.wl_launch_time = wl_launch_time;
			mint_settings.wl_mint_price = wl_mint_price;
			mint_settings.vip_launch_time = vip_launch_time;
			mint_settings.vip_mint_price = vip_mint_price;
			mint_settings.treasury_address = treasury_address;
			mint_settings.minting_enabled = minting_enabled;
		} else { //otherwise add to account resources
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
					minting_enabled: minting_enabled,
				},
			);
		};
	}

	fun get_tokens_left(
		resource_addr: address,
	): u64 acquires TokenMapping {
		iterable_table::length(&borrow_global<TokenMapping>(resource_addr).token_mapping)
	}

	// check the length of the whitelist,
	// if it's not what is expected, throw an error with the value of the length of the whitelist vector

	public entry fun mint<CoinType>(
		minter: &signer,
		creator_addr: address,
		collection_name: String,
		amount_requested: u64,
		mint_type: u64,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		pond::steak::safe_register_user_for_coin<CoinType>(minter);
		assert!(amount_requested >= 1 && amount_requested <= MAX_MINTS_PER_TX, CAN_ONLY_MINT_BETWEEN_1_AND_MAX_MINTS_PER_TX);

		let (resource_signer, resource_addr) = internal_get_resource_signer_and_addr(creator_addr);

		assert!(exists<LilypadCollectionData>(creator_addr),  			NO_LILYPAD_FOR_COLLECTION);
		assert!(exists<TokenMapping>(resource_addr), 						TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);
		assert!(exists<MintSettings<CoinType>>(resource_addr), 			MINT_SETTINGS_DO_NOT_EXIST_FOR_ACCOUNT_AND_COIN_TYPE);

		// `mint_price` is just the basic, whitelisted, or vip mint_price
		// calculates total `amount_left_for_user` as mints remaining for their whitelist spot
		let (launch_time, mint_price, amount_left_for_user, minting_enabled) = get_launch_time_and_mint_price<CoinType>(minter,
																										resource_addr,
																										mint_type,
																										amount_requested);

		assert!(minting_enabled, MINTING_DISABLED);
		assert!(amount_left_for_user >= 1, WL_USER_CANT_MINT_ANYMORE);
		assert!(timestamp::now_seconds()*MILLI_CONVERSION_FACTOR >= launch_time, NOT_YET_LAUNCH_TIME);

		//														HARD CODED VALUE
		//														HARD CODED VALUE
		//														HARD CODED VALUE
		//			to be double triple extra sure!
		assert!(creator_addr != @0xfd14d1f504a3d4f6361b24700ba2f1ea913670bc4e3af2866a90eee4dd47bf96, MINTING_HAS_ENDED_HARD_CODE);
		//														HARD CODED VALUE
		//														HARD CODED VALUE
		//														HARD CODED VALUE

		let tokens_left_in_contract: u64 = get_tokens_left(resource_addr);

		assert!(tokens_left_in_contract >= 1, NO_METADATA_LEFT);
		if (tokens_left_in_contract < amount_left_for_user) {
			amount_left_for_user = tokens_left_in_contract;
		};

		let final_amount: u64 = amount_left_for_user;
		let final_price: u64 = final_amount * mint_price;


		let minter_address = signer::address_of(minter);
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

		let treasury_address = borrow_global<MintSettings<CoinType>>(resource_addr).treasury_address;
		let pre_mint_balance_minter = coin::balance<CoinType>(minter_address);
		let pre_mint_balance_treasury = coin::balance<CoinType>(treasury_address);
		exchange_coin<CoinType>(
			minter,
			treasury_address,
			final_price,
		);
		// ENSURE ACCURATE COIN EXCHANGE OCCURRED
		assert!(final_price == final_amount * mint_price, FINAL_PRICE_INCORRECTLY_CALCULATED);
		assert!(coin::balance<CoinType>(minter_address) == (pre_mint_balance_minter - (final_price)), MINTER_DID_NOT_PAY);
		assert!(coin::balance<CoinType>(treasury_address) == (pre_mint_balance_treasury + (final_price)), TREASURY_DID_NOT_GET_PAID);
		if (final_amount == 0) {
			assert!(final_price == 0, PRICE_OR_AMOUNT_NOT_CORRECT);
			assert!(coin::balance<CoinType>(minter_address) == pre_mint_balance_minter, PRICE_OR_AMOUNT_NOT_CORRECT);
		};

		// MINT ALL TOKENS AND TRANSFER THEM
		let i = final_amount;
		let token_names: vector<String> = vector<String> [];
		while (i > 0) {
			vector::push_back(&mut token_names, mint_token_and_transfer(minter, collection_name, &resource_signer, resource_addr));//, creator_addr));
			i = i - 1;
		};
		vector::reverse(&mut token_names);

		assert!(vector::length(&token_names) == final_amount, FAILED_TO_MINT_ALL_TOKENS);

		initialize_event_store(minter);
      let lilypad_event_store = borrow_global_mut<LilypadEventStore>(minter_address);
		event::emit_event<LilypadMintEvent>(
         &mut lilypad_event_store.lilypad_mint_events,
    		LilypadMintEvent {
				token_names: token_names,
				mint_type: mint_type,
				creator: creator_addr,
				collection_name: collection_name,
				coin_amount: final_price,
				mint_amount: final_amount,
    		}
      );

		if (mint_type == VIP_MINT || mint_price == 0 || (final_price == 0 && final_amount != 0)) {
			let signer_capability_by_collection = borrow_global_mut<LilypadCollectionData>(creator_addr);
			let vip_mints = &mut signer_capability_by_collection.vip_mints;
			*vip_mints = *vip_mints + final_amount;
			assert!(*vip_mints <= MAX_VIP_MINTS, VIPS_HIT_MAX_MINTS);
		};
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

	fun mint_token_and_transfer(
		minter: &signer,
		collection_name: String,
		resource_signer: &signer,
		resource_addr: address,
		//creator_addr: address,
	): String acquires TokenMapping, StaticTokenMetadata {
		let token_mapping = &mut borrow_global_mut<TokenMapping>(resource_addr).token_mapping;
		assert!(!iterable_table::empty(token_mapping), NO_METADATA_LEFT);

		let static_token_metadata = borrow_global<StaticTokenMetadata>(resource_addr);
		let static_metadata_keys = static_token_metadata.token_metadata_keys; // copy issue?

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

		let token_name_base = static_token_metadata.token_name_base;
		// concat:       {Aptoad #}  and  {213}
		//								Aptoad #213
		// token_name_id is derived from the `key: <String>` as stored in the IterableTable
		std::string::append(&mut token_name_base, token_name_id);
		let token_name = token_name_base;

		let token_uri_base = static_token_metadata.uri_base;
		let token_uri_id = val.uri_id;
		// concat:       {https://arweave.net/}  and  {hf9a8ehc923whfjsef}
		//								https://arweave.net/hf9a8ehc923whfjsef
		std::string::append(&mut token_uri_base, token_uri_id);
		let token_uri = token_uri_base;

		let token_mutability = static_token_metadata.token_mutability;
      let royalty_payee_address = static_token_metadata.royalty_payee_address;
      let royalty_points_denominator = static_token_metadata.royalty_points_denominator;
      let royalty_points_numerator = static_token_metadata.royalty_points_numerator;

		// keep in mind there is an order to token_mutability in token.move: ctrl+f on `INDEX`
		token::create_token_script(
				resource_signer,
				collection_name,
				token_name,
				token_name, // FOR APTOADS, WE ARE JUST MAKING THE TOKEN_DESCRIPTION == TOKEN_NAME
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

	// processes the swapping of the coins from buyer => treasury_address
	// at this point the token has already been created
	// and we're just facilitating the exchange of coins
	fun exchange_coin<CoinType>(
		buyer: &signer,
		treasury_address: address,
		coin_amount: u64,
	) {
		let buyer_addr = signer::address_of(buyer);
		let pre_mint_balance = coin::balance<CoinType>(treasury_address);
		coin::transfer<CoinType>(buyer, treasury_address, coin_amount);
		assert!(buyer_addr == treasury_address || ((coin::balance<CoinType>(treasury_address) - pre_mint_balance) == coin_amount), TREASURY_DID_NOT_GET_PAID);
		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			bash_colors::print_key_value_as_string(b"treasury before:  ", bash_colors::u64_to_string(pre_mint_balance));
			bash_colors::print_key_value_as_string(b"treasury  after:  ", bash_colors::u64_to_string(coin::balance<CoinType>(treasury_address)));
		};
		*/
	}


	fun get_launch_time_and_mint_price<CoinType>(
		buyer: &signer,
		resource_addr: address,
		mint_type: u64,
		amount: u64,
	): (u64, u64, u64, bool) acquires MintSettings, Whitelists {
		assert!(mint_type == BASIC_MINT || mint_type == WHITELIST_MINT || mint_type == VIP_MINT, INVALID_MINT_TYPE);

		let (launch_time, mint_price, mints_left_for_address) =
		if (mint_type == BASIC_MINT) {
			let calculated_launch_time = 				borrow_global<MintSettings<CoinType>>(resource_addr).launch_time;
			let calculated_mint_price = 				borrow_global<MintSettings<CoinType>>(resource_addr).mint_price;
			let calculated_mints_left_for_address = amount;
			(calculated_launch_time, calculated_mint_price, calculated_mints_left_for_address)
		} else if (mint_type == WHITELIST_MINT) {
			let (is_whitelisted, wl_mints_left) = internal_check_is_whitelisted<CoinType>(buyer, resource_addr, amount);
			assert!(is_whitelisted, IS_NOT_WHITELISTED);
			let calculated_launch_time = 				borrow_global<MintSettings<CoinType>>(resource_addr).wl_launch_time;
			let calculated_mint_price = 				borrow_global<MintSettings<CoinType>>(resource_addr).wl_mint_price;
			let calculated_mints_left_for_address = wl_mints_left;
			(calculated_launch_time, calculated_mint_price, calculated_mints_left_for_address)
		} else if (mint_type == VIP_MINT) {
			assert!(internal_check_is_vip<CoinType>(buyer, resource_addr, amount), IS_NOT_VIP);
			let calculated_launch_time = 				borrow_global<MintSettings<CoinType>>(resource_addr).vip_launch_time;
			let calculated_mint_price = 				borrow_global<MintSettings<CoinType>>(resource_addr).vip_mint_price;
			let calculated_mints_left_for_address = amount;
			(calculated_launch_time, calculated_mint_price, calculated_mints_left_for_address)
		} else {
			assert!(false, IMPOSSIBLE_TO_REACH_CODE);
			(0, 0, 0)
		};

		let minting_enabled = &borrow_global<MintSettings<CoinType>>(resource_addr).minting_enabled;
		//redundant check below
		//assert!(minting_enabled, MINTING_DISABLED); // is in mint(...) function
		(launch_time, mint_price, mints_left_for_address, *minting_enabled)
	}


	public entry fun add_token_metadata(
		creator: &signer,
		//collection_name: String,
		token_number: String, // e.g. 1423
		//token_name: String,
		//description: String,
		uri_id: String,
		//uri: String,
      //uri_mutable: bool,
      //royalty_mutable: bool,
      //description_mutable: bool,
      //properties_mutable: bool,
      //royalty_payee_address: address,
      //royalty_points_denominator: u64,
      //royalty_points_numerator: u64,
		property_keys: vector<String>,
      property_values: vector<vector<u8>>,
      //property_types: vector<String>, // hard-coded as 0x1::string::String, aka const PROPERTY_MAP_STRING_TYPE
	) acquires TokenMapping, LilypadCollectionData {
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

	//	NEVER make this publicentry!!!!!
	//	NEVER make this publicentry!!!!!
	// you could potentially give access to signers' collections if this is publicly exposed
	fun internal_get_resource_signer_and_addr(
		creator_addr: address,
		//collection_name: String,
	): (signer, address) acquires LilypadCollectionData {
		let resource_signer_cap = &borrow_global<LilypadCollectionData>(creator_addr).resource_signer_cap;
		//let resource_signer_cap = table::borrow(table_resource_signers, collection_name);
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_addr = signer::address_of(&resource_signer);

		(resource_signer, resource_addr)
	}

	// wraps the internal, unchecked version of the function above (internal_.get_resource_signer_and_addr)
	// into a safe, signed version of it. Ensures that we distinguish between explicit/unchecked vs safe
	fun safe_get_resource_signer_and_addr(
		creator: &signer,
		//collection_name: String,
	): (signer, address) acquires LilypadCollectionData {
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
		token_number1: String,						// variable
		uri_id1: String,								// variable
		property_keys1: vector<String>,			// variable
      property_values1: vector<vector<u8>>,	// variable
		token_number2: String,						// variable
		uri_id2: String,								// variable
		property_keys2: vector<String>,			// variable
      property_values2: vector<vector<u8>>,	// variable
		token_number3: String,						// variable
		uri_id3: String,								// variable
		property_keys3: vector<String>,			// variable
      property_values3: vector<vector<u8>>,	// variable
		token_number4: String,						// variable
		uri_id4: String,								// variable
		property_keys4: vector<String>,			// variable
      property_values4: vector<vector<u8>>,	// variable
		token_number5: String,						// variable
		uri_id5: String,								// variable
		property_keys5: vector<String>,			// variable
      property_values5: vector<vector<u8>>,	// variable
		token_number6: String,						// variable
		uri_id6: String,								// variable
		property_keys6: vector<String>,			// variable
      property_values6: vector<vector<u8>>,	// variable
		token_number7: String,						// variable
		uri_id7: String,								// variable
		property_keys7: vector<String>,			// variable
      property_values7: vector<vector<u8>>,	// variable
		token_number8: String,						// variable
		uri_id8: String,								// variable
		property_keys8: vector<String>,			// variable
      property_values8: vector<vector<u8>>,	// variable
		token_number9: String,						// variable
		uri_id9: String,								// variable
		property_keys9: vector<String>,			// variable
      property_values9: vector<vector<u8>>,	// variable
		token_number10: String,						// variable
		uri_id10: String,								// variable
		property_keys10: vector<String>,			// variable
      property_values10: vector<vector<u8>>,	// variable
	) acquires TokenMapping, LilypadCollectionData {
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

	// set is_valid = user is whitelisted?
	// set amount = amount_requested OR amount_left_for_wl_user, WHICHEVER IS LESS
	// return (is_valid, amount)
	fun internal_check_is_whitelisted<CoinType>(
		_buyer: &signer,
		_resource_addr: address,
		amount: u64,
	): (bool, u64) {// acquires Whitelists {
		/*
		let buyer_address: address = signer::address_of(buyer);
		let whitelist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).whitelist;
		let is_valid = simple_map::contains_key(whitelist, &buyer_address);
		assert!(is_valid, IS_NOT_WHITELISTED);

		let minted = simple_map::borrow_mut(whitelist, &buyer_address);
		if (*minted + amount > MAX_MINTS_PER_WHITELIST_USER) {
			amount = MAX_MINTS_PER_WHITELIST_USER - *minted;
		};

		*minted = *minted + amount;

		assert!(*minted <= MAX_MINTS_PER_WHITELIST_USER, WL_USER_CANT_MINT_ANYMORE);
		(is_valid, amount)
		*/
		(true, amount)
	}

	fun internal_check_is_vip<CoinType>(
		buyer: &signer,
		resource_addr: address,
		amount: u64,
	): bool acquires Whitelists {
		let buyer_address: address = signer::address_of(buyer);
		let viplist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).viplist;
		let is_valid = simple_map::contains_key(viplist, &buyer_address);
		assert!(is_valid, IS_NOT_VIP);

		//assert!(buyer_address == @vip1 || buyer_address == @vip2 || buyer_address == @vip3, NON_VIP_PAYING_ZERO_HARD_CODE);

		let minted = simple_map::borrow_mut(viplist, &buyer_address);
		*minted = *minted + amount;

		is_valid
	}

	public entry fun add_to_whitelist<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).whitelist;

		while (vector::length(&addresses) > 0) {
			let account_address = vector::pop_back(&mut addresses);
			if (!simple_map::contains_key(whitelist, &account_address)) {
				simple_map::add(whitelist, account_address, 0);
			};
		};
	}

	public entry fun remove_from_whitelist<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).whitelist;

		while (vector::length(&addresses) > 0) {
			let account_address = vector::pop_back(&mut addresses);
			if (simple_map::contains_key(whitelist, &account_address)) {
				let (_, _) = simple_map::remove(whitelist, &account_address);
			};
		};
	}

	public entry fun add_to_viplist<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr)  = safe_get_resource_signer_and_addr(creator);
		let viplist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).viplist;

		while (vector::length(&addresses) > 0) {
			let account_address = vector::pop_back(&mut addresses);
			if (!simple_map::contains_key(viplist, &account_address)) {
				simple_map::add(viplist, account_address, 0);
			};
		};
	}

	public entry fun remove_from_viplist<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr)  = safe_get_resource_signer_and_addr(creator);
		let viplist = &mut borrow_global_mut<Whitelists<CoinType>>(resource_addr).viplist;

		while (vector::length(&addresses) > 0) {
			let account_address = vector::pop_back(&mut addresses);
			if (simple_map::contains_key(viplist, &account_address)) {
				let (_, _) = simple_map::remove(viplist, &account_address);
			};
		};
	}

/*
	public entry fun revoke_signer_capability(
		creator: &signer,
		//collection_name: String,
	) acquires LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		aptos_framework::account::revoke_signer_capability(creator, resource_addr);

		pond::bash_colors::print_key_value(b"Removed signer capability from", b"resource_addr");
		std::debug::print(&resource_addr);

		// if amount_minted == collection_supply {
		//		offer_signer_capability(signer_capability => creator);?
		// }
	}

	public entry fun offer_signer_capability_to_lilypad_resource_account(
		creator: &signer,
		signer_capability_sig_bytes: vector<u8>,
	) acquires LilypadCollectionData {
		let creator_addr = signer::address_of(creator);
		std::debug::print(&creator_addr);
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		let account_public_key_bytes = aptos_framework::account::get_authentication_key(creator_addr);
		std::debug::print(&account_public_key_bytes);
		let pk = aptos_framework::ed25519::new_unvalidated_public_key_from_bytes(account_public_key_bytes);
		std::debug::print(&aptos_framework::ed25519::unvalidated_public_key_to_authentication_key(&pk));
		let recipient_address = resource_addr;

		aptos_framework::account::offer_signer_capability(
			creator,
			signer_capability_sig_bytes,
			ED25519_SCHEME,
			account_public_key_bytes,
			recipient_address,
		);
	}

	public entry fun test_add_function(
		creator: &signer,
	) {
		token::create_collection(
			creator,
			std::string::utf8(b"coll"),
			std::string::utf8(b"desc"),
			std::string::utf8(b"uri"),
			1,
			vector<bool> [true, true, true],
		);
	}
*/

	public entry fun public_check_whitelist_length<CoinType>(
		creator: &signer,
		expected_length: u64,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = &borrow_global<Whitelists<CoinType>>(resource_addr).whitelist;
		let whitelist_length = simple_map::length(whitelist);
		assert!(expected_length == whitelist_length, whitelist_length);
	}

	public entry fun public_check_viplist_length<CoinType>(
		creator: &signer,
		expected_length: u64,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let viplist = &borrow_global<Whitelists<CoinType>>(resource_addr).viplist;
		let viplist_length = simple_map::length(viplist);
		assert!(expected_length == viplist_length, viplist_length);
	}

	public entry fun public_check_all_addresses_whitelisted<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = &borrow_global<Whitelists<CoinType>>(resource_addr).whitelist;
		while (vector::length(&addresses) > 0) {
			let addr = vector::pop_back(&mut addresses);
			assert!(!simple_map::contains_key(whitelist, &addr), NOT_IN_WHITELIST);
		};
	}

	public entry fun public_check_all_addresses_viplisted<CoinType>(
		creator: &signer,
		addresses: vector<address>,
	) acquires Whitelists, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let viplist = &borrow_global<Whitelists<CoinType>>(resource_addr).viplist;
		while (vector::length(&addresses) > 0) {
			let addr = vector::pop_back(&mut addresses);
			assert!(!simple_map::contains_key(viplist, &addr), NOT_IN_VIPLIST);
		};
	}


	public entry fun disable_minting<CoinType>(
		creator: &signer,
	) acquires MintSettings, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let mint_settings = borrow_global_mut<MintSettings<CoinType>>(resource_addr);
		mint_settings.minting_enabled = false;
	}

	public entry fun enable_minting<CoinType>(
		creator: &signer,
	) acquires MintSettings, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let mint_settings = borrow_global_mut<MintSettings<CoinType>>(resource_addr);
		mint_settings.minting_enabled = true;
	}

	public entry fun disable_claims(
		creator: &signer,
	) acquires LilypadClaimsData, LilypadCollectionData {
		set_claims_enabled(creator, false);
	}

	public entry fun enable_claims(
		creator: &signer,
	) acquires LilypadClaimsData, LilypadCollectionData {
		set_claims_enabled(creator, true);
	}

	fun set_claims_enabled(
		creator: &signer,
		enable: bool,
	) acquires LilypadClaimsData, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(exists<LilypadClaimsData>(resource_addr), CLAIMS_TABLE_DOESNT_EXIST);
		let lilypad_claims = borrow_global_mut<LilypadClaimsData>(resource_addr);
		lilypad_claims.claims_enabled = enable;
	}

	public entry fun create_claims_table(
		creator: &signer,
	) acquires LilypadCollectionData {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		assert!(!exists<LilypadClaimsData>(resource_addr), CLAIMS_TABLE_ALREADY_EXISTS);
		assert!(!exists<LilypadClaimsSettings>(resource_addr), CLAIMS_SETTINGS_ALREADY_EXIST);
		move_to(
			&resource_signer,
			LilypadClaimsData {
				lilypad_claims: table::new<address, u64>(),
				claims_enabled: false,
			}
		);
		move_to(
			&resource_signer,
			LilypadClaimsSettings {
				launch_time: U64_MAX,
				end_time: 0,
			}
		);
	}

	public entry fun upsert_claims_settings(
		creator: &signer,
		claims_enabled: bool,
		launch_time: u64,
		end_time: u64,
	) acquires LilypadCollectionData, LilypadClaimsData, LilypadClaimsSettings {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		if (exists<LilypadClaimsData>(resource_addr)) {
			let claims_data = borrow_global_mut<LilypadClaimsData>(resource_addr);
				claims_data.claims_enabled = claims_enabled;
		} else {
			move_to(
				&resource_signer,
				LilypadClaimsData {
					lilypad_claims: table::new<address, u64>(),
					claims_enabled: claims_enabled,
				},
			);
		};

		if (exists<LilypadClaimsSettings>(resource_addr)) {
			let claims_settings = borrow_global_mut<LilypadClaimsSettings>(resource_addr);
				claims_settings.launch_time = launch_time;
				claims_settings.end_time = end_time;
		} else {
			move_to(
				&resource_signer,
				LilypadClaimsSettings {
					launch_time: launch_time,
					end_time: end_time,
				},
			);
		};


	}

	public entry fun add_addresses_to_claims(
		creator: &signer,
		addresses: vector<address>,
		claims_remaining_vector: vector<u64>,
		skip_signer_has_minted_check: bool,
	) acquires LilypadCollectionData, LilypadClaimsData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(exists<LilypadClaimsData>(resource_addr), CLAIMS_TABLE_DOESNT_EXIST);

		while(vector::length(&addresses) > 0) {
			let address = vector::pop_back(&mut addresses);
			assert!(skip_signer_has_minted_check || exists<LilypadEventStore>(address), SIGNER_HAS_NEVER_MINTED_BEFORE);
			let claims_remaining = vector::pop_back(&mut claims_remaining_vector);
			let lilypad_claims = &mut borrow_global_mut<LilypadClaimsData>(resource_addr).lilypad_claims;
			table::upsert(lilypad_claims, address, claims_remaining);
		};
	}

	public entry fun claim_mint(
		minter: &signer,
		creator_addr: address,
		collection_name: String,
	) acquires LilypadCollectionData, LilypadEventStore, TokenMapping, StaticTokenMetadata, LilypadClaimsData, LilypadClaimsSettings {
		let (resource_signer, resource_addr) = internal_get_resource_signer_and_addr(creator_addr);
		let minter_address = signer::address_of(minter);

		assert!(exists<LilypadClaimsData>(resource_addr), 					CLAIMS_TABLE_DOESNT_EXIST);
		assert!(exists<LilypadCollectionData>(creator_addr),  			NO_LILYPAD_FOR_COLLECTION);
		assert!(exists<TokenMapping>(resource_addr), 						TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);

		assert!(exists<LilypadClaimsSettings>(resource_addr), 			CLAIMS_SETTINGS_DONT_EXIST);
		let lilypad_claims_settings = borrow_global<LilypadClaimsSettings>(resource_addr);
		let launch_time = lilypad_claims_settings.launch_time;
		let end_time = lilypad_claims_settings.end_time;
		let time_now_ms = timestamp::now_seconds() * MILLI_CONVERSION_FACTOR;

		assert!(time_now_ms >= launch_time, NOT_YET_CLAIMS_TIME);
		assert!(time_now_ms <= end_time, CLAIM_EVENT_COMPLETE);

		let lilypad_claims_data = borrow_global_mut<LilypadClaimsData>(resource_addr);
		let lilypad_claims = &mut lilypad_claims_data.lilypad_claims;
		let claims_enabled = lilypad_claims_data.claims_enabled;

		assert!(table::contains(lilypad_claims, minter_address), SIGNER_NOT_IN_CLAIMS_TABLE);
		assert!(claims_enabled, CLAIMS_DISABLED);

		let claims_remaining = table::borrow_mut(lilypad_claims, minter_address);

		/*
		//TEST_DEBUG
		std::debug::print(&minter_address);
		pond::bash_colors::print_key_value_as_string(b"claims_remaining: ", pond::bash_colors::u64_to_string(*claims_remaining));
		*/

		assert!(*claims_remaining >= 1, SIGNER_HAS_NO_CLAIMS_REMAINING);

		//let tokens_left_in_contract: u64 = get_tokens_left(resource_addr);
		//assert!(tokens_left_in_contract >= 1, NO_MINTS_LEFT);

		assert!(CLAIM_AMOUNT == 1, CONTRACT_ASSUMPTIONS_HAVE_CHANGED);

		let token_name = mint_token_and_transfer(minter, collection_name, &resource_signer, resource_addr);

		initialize_event_store(minter);
      let lilypad_event_store = borrow_global_mut<LilypadEventStore>(minter_address);
		event::emit_event<LilypadMintEvent>(
         &mut lilypad_event_store.lilypad_mint_events,
    		LilypadMintEvent {
				token_names: vector<String> [ token_name ],
				mint_type: CLAIM_MINT,
				creator: creator_addr,
				collection_name: collection_name,
				coin_amount: 0,
				mint_amount: 0,
    		}
      );


		*claims_remaining = *claims_remaining - CLAIM_AMOUNT;


		/*
		//TEST_DEBUG
		pond::bash_colors::print_key_value_as_string(b"claimed         : ", pond::bash_colors::u64_to_string(CLAIM_AMOUNT));
		pond::bash_colors::print_key_value_as_string(b"claims_remaining: ", pond::bash_colors::u64_to_string(*claims_remaining));
		*/
	}

	public entry fun remove_metadata(
		creator: &signer,
	) acquires LilypadCollectionData, TokenMapping {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		let token_mapping = &mut borrow_global_mut<TokenMapping>(resource_addr).token_mapping;

		assert!(exists<TokenMapping>(resource_addr), TOKEN_METADATA_DOES_NOT_EXIST_FOR_ACCOUNT);
		assert!(!iterable_table::empty(token_mapping), NO_METADATA_LEFT);

		let key = iterable_table::head_key(token_mapping);
		let i = 0;
		while (option::is_some(&key) && i < 250) {
			let token_name_id = *option::borrow(&key);
			let (_, _, next) = iterable_table::remove_iter(token_mapping, token_name_id);
			key = next;
			i = i + 1;
		}
	}

	public entry fun finish_collection(
		creator: &signer,
		token_number: u64,
		full_token_uri: String,
		token_keys: vector<String>,
		token_values: vector<vector<u8>>,
		token_types: vector<String>,
	) acquires LilypadCollectionData, StaticTokenMetadata {
		let creator_address = signer::address_of(creator);
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		assert!(creator_address == @0xfd14d1f504a3d4f6361b24700ba2f1ea913670bc4e3af2866a90eee4dd47bf96, YOU_SHOULDNT_BE_HERE);

		let collection_name = std::string::utf8(b"Aptos Toad Overload");
		assert!(token_number >= 3914 && token_number <= 3999, TOKEN_ID_ALREADY_IN_METADATA);
		let actual_supply = *option::borrow(&token::get_collection_supply(resource_addr, collection_name));
		assert!(actual_supply < 4000, NO_MINTS_LEFT);

		// since you havent minted it yet, the actual_supply should equal token_number if you do the mints in order.
		assert!(token_number == actual_supply, OUT_OF_ORDER);
		let token_name_id = pond::bash_colors::u64_to_string(token_number);

		let static_token_metadata = borrow_global<StaticTokenMetadata>(resource_addr);
		let token_name_base = static_token_metadata.token_name_base;
		std::string::append(&mut token_name_base, token_name_id);
		let token_name = token_name_base;

		let token_mutability = static_token_metadata.token_mutability;
      let royalty_payee_address = static_token_metadata.royalty_payee_address;
      let royalty_points_denominator = static_token_metadata.royalty_points_denominator;
      let royalty_points_numerator = static_token_metadata.royalty_points_numerator;

		// keep in mind there is an order to token_mutability in token.move: ctrl+f on `INDEX`
		token::create_token_script(
				&resource_signer,
				collection_name,
				token_name,
				token_name, // FOR APTOADS, WE ARE JUST MAKING THE TOKEN_DESCRIPTION == TOKEN_NAME
				1, //balance
				1, //maximum
				full_token_uri,
				royalty_payee_address,
				royalty_points_denominator,
				royalty_points_numerator,
				token_mutability,
				token_keys,
				token_values,
				token_types,
		);

      let token_id = token::create_token_id_raw(resource_addr, collection_name, token_name, 0);
		token::direct_transfer(&resource_signer, creator, token_id, 1);
		assert!(token::balance_of(creator_address, token_id) == 1, MINTER_DID_NOT_GET_TOKEN);

		let actual_supply2 = *option::borrow(&token::get_collection_supply(resource_addr, collection_name));
		assert!(actual_supply2 <= 4000, NO_MINTS_LEFT);

		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			std::debug::print(&signer::address_of(creator));
			bash_colors::print_key_value_as_string(b"token name: ", token_name);
			while (vector::length(&token_keys) >= 1) {
				let k: String 		= vector::pop_back(&mut token_keys);
				let v: vector<u8> = vector::pop_back(&mut token_values);
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
				std::string::append(&mut s, std::string::utf8(b" "));
				std::string::append(&mut s, bash_colors::color(b"green", full_token_uri));
				//std::string::append(&mut s, bash_colors::color(b"red", vector::pop_back(&mut token_types)));
				if (v != b"None") {
					std::debug::print(&s);
				};
			};
			//bash_colors::print_key_value_as_string(b"token uri: ", token_uri);
			bash_colors::print_key_value_as_string(b"token balance: ", bash_colors::u64_to_string(token::balance_of(signer::address_of(creator), token_id)));
		};
		*/


	}

	/*
	#[test(creator = @0xfd14d1f504a3d4f6361b24700ba2f1ea913670bc4e3af2866a90eee4dd47bf96, bank = @0x1, aptos_framework = @0x1, treasury = @0x123)]
	fun test_finish(
		creator: &signer,
		bank: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires StaticTokenMetadata, LilypadCollectionData {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let treasury_address = signer::address_of(treasury);

		register_acc_and_fill(creator, bank);
		register_acc_and_fill(treasury, bank);

		initialize_lilypad<coin::FakeMoney>(
			creator,
			std::string::utf8(b"Aptos Toad Overload"),
			get_description(),
			get_uri(),
			4000,
			vector<bool>[true, true, true],
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			treasury_address,
			get_token_base(),
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		register_acc_and_fill(creator, bank); ///
		finish_collection(
			creator,
			0,
			std::string::utf8(b"https://arweave.net/f2378ashdikfhak39ifha=123"),
			get_token_keys(),
			get_token_values1(),
			get_token_types(),
		);

		finish_collection(
			creator,
			1,
			get_token_uri(5),
			get_token_keys5(),
			get_token_values5(),
			vector<String> [ std::string::utf8(PROPERTY_MAP_STRING_TYPE), std::string::utf8(PROPERTY_MAP_STRING_TYPE) ],
		);
	}
	*/


	//this *should* be named initialize coin but i made wrong function name
	public entry fun initialize_aptos_coin<CoinType>(
		creator: &signer,
	) acquires LilypadCollectionData {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);

		coin::register<CoinType>(&resource_signer);
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


    public entry fun mutate_collection_description(
		_creator: &signer,
		_collection_name: String,
		_description: String,
	) {
		abort FUNCTION_DEPRECATED
	}
	/*
	 ) acquires LilypadCollectionData {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_description(
			&resource_signer,
			collection_name,
			description,
		);
	 }
	*/

	 public entry fun mutate_collection_uri(
		_creator: &signer,
		_collection_name: String,
		_uri: String,
	) {
		abort FUNCTION_DEPRECATED
	}
	/*
	 ) acquires LilypadCollectionData {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_uri(
			&resource_signer,
			collection_name,
			uri,
		);
	 }
	*/

	 public entry fun mutate_collection_maximum(
		_creator: &signer,
		_collection_name: String,
		_maximum: u64,
	) {
		abort FUNCTION_DEPRECATED
	}
	/*
	 ) acquires LilypadCollectionData {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(creator);
		token::mutate_collection_maximum(
			&resource_signer,
			collection_name,
			maximum,
		);
	 }
	*/

    public entry fun proxy_mutate_one_token(
        creator: &signer,
        token_owner: address,
        collection_name: String,
        token_name: String,
        keys: vector<String>,
        values: vector<vector<u8>>,
        types: vector<String>,
    ) acquires LilypadCollectionData {
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

	 public entry fun proxy_burn_by_creator(
        creator: &signer,
        owner: address,
        collection: String,
        name: String,
        property_version: u64,
        amount: u64,
	) acquires LilypadCollectionData {
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

    public entry fun proxy_mutate_tokendata_property(
		creator: &signer,
		collection_name: String,
		token_name: String,
		keys: vector<String>,
		values: vector<vector<u8>>,
		types: vector<String>,
	) acquires LilypadCollectionData {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_property(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
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
	) acquires LilypadCollectionData {
		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);

		token::mutate_tokendata_uri(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			uri,
		);
	}


	public entry fun proxy_mutate_tokendata_royalty(
      creator: &signer,
      _collection_name: String,
      _token_name: String,
      _royalty_points_numerator: u64,
      _royalty_points_denominator: u64,
      _payee_address: address,
	) acquires LilypadCollectionData {
		//let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let (_, _) = safe_get_resource_signer_and_addr(creator); // leaving in for now so we can keep the acquires list in
		/*

		let token_data_id = token::create_token_data_id(resource_addr, collection_name, token_name);
		let royalty = &mut token::get_tokendata_royalty(token_data_id);

		royalty.royalty_points_numerator = royalty_points_numerator;
		royalty.royalty_points_denominator = royalty_points_denominator;
		royalty.payee_address = payee_address;

		token::mutate_tokendata_uri(
			&resource_signer,
			token_data_id,
			royalty,
		);
		*/
	}

	public entry fun proxy_mutate_tokendata_description(
      creator: &signer,
      _collection_name: String,
      _token_name: String,
		_description: String,
	) acquires LilypadCollectionData {
		//let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let (_, _) = safe_get_resource_signer_and_addr(creator); // leaving in for now so we can keep the acquires list in
		/*

		token::mutate_tokendata_description(
			&resource_signer,
			token::create_token_data_id(resource_addr, collection_name, token_name),
			description,
		);
		*/
	}

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////          	TEST SETUP            ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////

   #[test_only]
	fun init_for_test(
		creator: &signer,
		bank: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires LilypadCollectionData, StaticTokenMetadata, TokenMapping {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let treasury_address = signer::address_of(treasury);

		register_acc_and_fill(creator, bank);
		register_acc_and_fill(treasury, bank);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		create_15_test_entries_in_bulk(creator);
	}


	#[test_only]
	fun test_serialization() {

		// use `aptos move test` instead of your alias `move_test` to view a BCS serialization example for vectors of boolean values

		std::debug::print( & std::bcs::to_bytes(&vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] ));
		std::debug::print( & std::bcs::to_bytes(&vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true), std::bcs::to_bytes<bool>(&false), std::bcs::to_bytes<bool>(&false), std::bcs::to_bytes<bool>(&true)  ] ));
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true), std::bcs::to_bytes<bool>(&false), std::bcs::to_bytes<bool>(&false), std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
		std::debug::print( &vector<vector<u8>> [ std::bcs::to_bytes<bool>(&true) ] );
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
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////          CLAIMS TESTING          ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
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

	//SIGNER_NOT_IN_CLAIMS_TABLE 			0x3e  =>  62
	//SIGNER_HAS_NO_CLAIMS_REMAINING 	0x3f  =>  63
	//CLAIMS_DISABLED 						0x41  =>  65
	//CLAIMS_TABLE_DOESNT_EXIST 			0x42  =>  66
	//SIGNER_HAS_NEVER_MINTED_BEFORE 	0x43  =>  67

	#[test(creator = @0xFA, minter1=@0xa1, minter2=@0xa2, minter3=@0xa3, minter4=@0xa4, minter5=@0xa5, thief1=@0xa6, bank=@0x1, treasury=@0x3333, aptos_framework=@0x1)]
	//#[expected_failure(abort_code = SIGNER_NOT_IN_CLAIMS_TABLE)]
	fun claims_test(
		creator: &signer,
		minter1: &signer,
		minter2: &signer,
		minter3: &signer,
		minter4: &signer,
		minter5: &signer,
		thief1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	//) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
	) acquires LilypadCollectionData, TokenMapping, StaticTokenMetadata, Whitelists, MintSettings, LilypadClaimsData, LilypadEventStore, LilypadClaimsSettings {
		init_for_test(
			creator,
			bank,
			aptos_framework,
			treasury,
		);

		create_and_fill_accs(creator, minter1, minter2, minter3, minter4, minter5, bank);
		register_acc_and_fill(thief1, bank);

		let creator_addr = signer::address_of(creator);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(minter1), signer::address_of(minter2), signer::address_of(minter3), signer::address_of(minter4), signer::address_of(minter5)];
		add_to_whitelist<coin::FakeMoney>(creator, whitelist_addresses);

      mint<coin::FakeMoney>(minter1, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter2, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter3, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter4, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(minter5, creator_addr, get_collection_name(), 1, WHITELIST_MINT);

		create_claims_table(creator);
		upsert_claims_settings(creator, false, get_start_time_milliseconds(), get_end_time_milliseconds());
		enable_claims(creator);
		disable_claims(creator);
		enable_claims(creator);

		let skip_signer_has_minted_check = true;

		let minter1_address = signer::address_of(minter1);
		let minter2_address = signer::address_of(minter2);
		let minter3_address = signer::address_of(minter3);
		let minter4_address = signer::address_of(minter4);
		let minter5_address = signer::address_of(minter5);

		let claims_minter1 = 1;
		let claims_minter2 = 2;
		let claims_minter3 = 3;
		let claims_minter4 = 4;
		let claims_minter5 = 5;

		add_addresses_to_claims(
			creator,
			vector<address> [ minter1_address,
									minter2_address,
									minter3_address,
									minter4_address,
									minter5_address ],
			vector<u64> [ 	claims_minter1,
								claims_minter2,
								claims_minter3,
								claims_minter4,
								claims_minter5 ],
			skip_signer_has_minted_check
		);

		claim_mint(minter1, signer::address_of(creator), get_collection_name());

		claim_mint(minter2, signer::address_of(creator), get_collection_name());

		claim_mint(minter3, signer::address_of(creator), get_collection_name());
		claim_mint(minter3, signer::address_of(creator), get_collection_name());

		claim_mint(minter4, signer::address_of(creator), get_collection_name());
		claim_mint(minter4, signer::address_of(creator), get_collection_name());
		claim_mint(minter4, signer::address_of(creator), get_collection_name());
		claim_mint(minter4, signer::address_of(creator), get_collection_name());

		claim_mint(minter5, signer::address_of(creator), get_collection_name());
		claim_mint(minter5, signer::address_of(creator), get_collection_name());

		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		let lilypad_claims_data = borrow_global<LilypadClaimsData>(resource_addr);
		let lilypad_claims_settings = borrow_global<LilypadClaimsSettings>(resource_addr);
		let minter1_claims_remaining = *table::borrow(&lilypad_claims_data.lilypad_claims, minter1_address);
		let minter2_claims_remaining = *table::borrow(&lilypad_claims_data.lilypad_claims, minter2_address);
		let minter3_claims_remaining = *table::borrow(&lilypad_claims_data.lilypad_claims, minter3_address);
		let minter4_claims_remaining = *table::borrow(&lilypad_claims_data.lilypad_claims, minter4_address);
		let minter5_claims_remaining = *table::borrow(&lilypad_claims_data.lilypad_claims, minter5_address);
		let claims_enabled = lilypad_claims_data.claims_enabled;
		let launch_time = lilypad_claims_settings.launch_time;
		let end_time = lilypad_claims_settings.end_time;

		assert!(minter1_claims_remaining == claims_minter1 - 1, 1337);
		assert!(minter2_claims_remaining == claims_minter2 - 1, 1337);
		assert!(minter3_claims_remaining == claims_minter3 - 2, 1337);
		assert!(minter4_claims_remaining == claims_minter4 - 4, 1337);
		assert!(minter5_claims_remaining == claims_minter5 - 2, 1337);
		assert!(claims_enabled, 1337);
		assert!(launch_time == get_start_time_milliseconds(), 1337);
		assert!(end_time == get_end_time_milliseconds(), 1337);

		let token_id_1 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(1), 0);
		let token_id_2 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(2), 0);
		let token_id_3 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(3), 0);
		let token_id_4 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(4), 0);
		let token_id_5 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(5), 0);
		let token_id_6 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(6), 0);
		let token_id_7 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(7), 0);
		let token_id_8 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(8), 0);
		let token_id_9 =  token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(9), 0);
		let token_id_10 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(10), 0);
		let token_id_11 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(11), 0);
		let token_id_12 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(12), 0);
		let token_id_13 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(13), 0);
		let token_id_14 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(14), 0);
		let token_id_15 = token::create_token_id_raw(resource_addr, get_collection_name(), get_token_name(15), 0);

		assert!(token::balance_of(minter1_address, token_id_1) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter2_address, token_id_2) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter3_address, token_id_3) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter4_address, token_id_4) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter5_address, token_id_5) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter1_address, token_id_6) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter2_address, token_id_7) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter3_address, token_id_8) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter3_address, token_id_9) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter4_address, token_id_10) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter4_address, token_id_11) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter4_address, token_id_12) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter4_address, token_id_13) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter5_address, token_id_14) == 1, MINTER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(minter5_address, token_id_15) == 1, MINTER_DID_NOT_GET_TOKEN);

		//claim_mint(minter5, signer::address_of(creator), get_collection_name());
		//claim_mint(minter5, signer::address_of(creator), get_collection_name());

		//claim_mint(thief1, signer::address_of(creator), get_collection_name());

	}

   // const 			  						CLAIMS_SETTINGS_ALREADY_EXIST:  u64 = 70;	/* 0x46 */
   // const 			  							CLAIMS_SETTINGS_DONT_EXIST:  u64 = 71;	/* 0x47 */
   // const 			  					  				 NOT_YET_CLAIMS_TIME:  u64 = 72;	/* 0x48 */
   // const 			  					  				CLAIM_EVENT_COMPLETE:  u64 = 73;	/* 0x49 */
   // const 			  					  					 NO_METADATA_LEFT:  u64 = 14;	/*  0xe */
   // const 			  					  						 NO_MINTS_LEFT:  u64 = 15;	/*  0xf */


	#[test(creator = @0xFA, minter1=@0xa1, thief1=@0xa6, bank=@0x1, treasury=@0x3333, aptos_framework=@0x1)]
	#[expected_failure(abort_code = NO_METADATA_LEFT)]
	fun claims_test_time(
		creator: &signer,
		minter1: &signer,
		thief1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	//) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
	) acquires LilypadCollectionData, TokenMapping, StaticTokenMetadata, Whitelists, MintSettings, LilypadClaimsData, LilypadEventStore, LilypadClaimsSettings {
		init_for_test(
			creator,
			bank,
			aptos_framework,
			treasury,
		);

		register_acc_and_fill(creator, bank);
		register_acc_and_fill(treasury, bank);
		register_acc_and_fill(minter1, bank);
		register_acc_and_fill(thief1, bank);

		let creator_addr = signer::address_of(creator);

      mint<coin::FakeMoney>(minter1, creator_addr, get_collection_name(), 2, BASIC_MINT);

		// NOT_YET_CLAIMS_TIME
		//upsert_claims_settings(creator, true, get_start_time_milliseconds() + 1, get_end_time_milliseconds());

		// CLAIM_EVENT_COMPLETE
		//upsert_claims_settings(creator, true, get_start_time_milliseconds(), get_end_time_milliseconds() - 2 * MILLI_CONVERSION_FACTOR);
		//assert!(end_time == get_end_time_milliseconds() - 2 * MILLI_CONVERSION_FACTOR, 1337);

		upsert_claims_settings(creator, true, get_start_time_milliseconds(), get_end_time_milliseconds());


		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		let lilypad_claims_data = borrow_global<LilypadClaimsData>(resource_addr);
		let lilypad_claims_settings = borrow_global<LilypadClaimsSettings>(resource_addr);
		let claims_enabled = lilypad_claims_data.claims_enabled;
		let launch_time = lilypad_claims_settings.launch_time;
		let end_time = lilypad_claims_settings.end_time;
		assert!(claims_enabled, 1337);
		assert!(launch_time == get_start_time_milliseconds(), 1337);

		let time_now_ms = timestamp::now_seconds() * MILLI_CONVERSION_FACTOR;
		pond::bash_colors::print_key_value_as_string(b"time_now_ms: ", pond::bash_colors::u64_to_string(time_now_ms));
		pond::bash_colors::print_key_value_as_string(b"launch_time: ", pond::bash_colors::u64_to_string(launch_time));
		pond::bash_colors::print_key_value_as_string(b"end_time: ", pond::bash_colors::u64_to_string(end_time));
		pond::bash_colors::print_key_value(b"time_now_ms >= launch_time: ", pond::bash_colors::bool_to_string(time_now_ms >= launch_time));
		pond::bash_colors::print_key_value(b"time_now_ms <= end_time: ", pond::bash_colors::bool_to_string(time_now_ms <= end_time));

		//assert!(time_now_ms >= launch_time, NOT_YET_CLAIMS_TIME);
		//assert!(time_now_ms <= end_time, CLAIM_EVENT_COMPLETE);



		//upsert_claims_settings(creator, true, get_start_time_milliseconds(), get_end_time_milliseconds());

		let skip_signer_has_minted_check = false;

		add_addresses_to_claims(
			creator,
			vector<address> [ signer::address_of(minter1) ],
			vector<u64> [ 16 ],
			skip_signer_has_minted_check
		);

		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		claim_mint(minter1, signer::address_of(creator), get_collection_name());
		//claim_mint(minter1, signer::address_of(creator), get_collection_name());

		//claim_mint(thief1, signer::address_of(creator), get_collection_name());
	}

/*

	fun get_index(begin: u64, end: u64): u64 {
		if (end == begin) {
			begin
		} else {
			let now_us = timestamp::now_microseconds();
			let now_ms = now_us / 1000;

			let u = now_us % 10;
			let m = now_ms % 10;

			let x = if (u == 0) { 37 }
				else if (u == 1) { 73 }
				else if (u == 2) { 13 }
				else if (u == 3) { 71 }
				else if (u == 4) { 91 }
				else if (u == 5) { 41 }
				else if (u == 6) { 21 }
				else if (u == 7) { 61 }
				else if (u == 8) { 13 }
				else if (u == 9) { 28 }
				else { 0 };

			let y = if (m == 0) { 37 }
				else if (m == 1) { 73 }
				else if (m == 2) { 13 }
				else if (m == 3) { 71 }
				else if (m == 4) { 91 }
				else if (m == 5) { 41 }
				else if (m == 6) { 21 }
				else if (m == 7) { 61 }
				else if (m == 8) { 13 }
				else if (m == 9) { 28 }
				else { 0 };

			assert!(end >= begin, END_NOT_GREATER_THAN_BEGINNING);
			let range = end - begin;

			let prnd = begin + ((now_us + x + y) % range);
			assert!(prnd >= begin && prnd <= end, ARITHMETIC_ERROR);
			// instead of throwing an error in production, just use the head value. Dont need perfection rn
			if (prnd < begin || prnd > end) {
				begin
			} else {
				prnd
			}
		}
	}

	#[test(aptos_framework = @0x1)]
	fun zzzzzzzzzzzzzzzz_get_ms_and_s(
		aptos_framework: &signer,
	) {
		use pond::bash_colors::{string_to_u64, u64_to_string, print_key_value_as_string};
		use std::string::utf8;

		timestamp::set_time_has_started_for_testing(aptos_framework);

      timestamp::update_global_time_for_test(738628742682);
		print_key_value_as_string(b"microseconds: ", u64_to_string(timestamp::now_microseconds()));
		print_key_value_as_string(b"seconds:      ", u64_to_string(timestamp::now_seconds()));

		//let i = 0;
		//while (i < 100) {
			//print_key_value_as_string(b"i => ", u64_to_string(get_index(i, 4000)));
			//i = i + 1;
		//};

		let head = utf8(b"1231");
		let tail = utf8(b"6968");
		let head_num = string_to_u64(head);
		let tail_num = string_to_u64(tail);
		print_key_value_as_string(b"i => ", u64_to_string(get_index(head_num, tail_num)));
	}

	#[test]
	fun test_u64_to_string_10000() {
		let i = 0;
		while(i < 5) {
			std::debug::print(&pond::bash_colors::u64_to_string(i));
			//pond::bash_colors::print_key_value_as_string(b"i: ", pond::bash_colors::u64_to_string(i));
			i = i + 1;
		};
	}

	#[test]
	fun zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz_test_string_to_u64_100() {
		//use pond::bash_colors::{string_to_u64, u64_to_string, print_key_value_as_string};
		let i = 9001;
		while(i < 10000) {
			//print_key_value_as_string(b"u64 => string => u64 => string: ", u64_to_string(string_to_u64(u64_to_string(i))));
			i = i + 1;
		};

		//let s = std::string::utf8(b"348721");
		//let s_to_u64 = string_to_u64(s);

		//let s_plus_ten = s_to_u64 + 10;

		//print_key_value_as_string(b"s + 10:", u64_to_string(s_plus_ten));
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
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////        WHITELIST TESTING         ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
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


// Create
//		- addresses
//			basiclist of 5 addresses 0x000[A-E]
//			whitelist of 5 addresses 0x001[A-E]
//			viplist of 5 different addresses 0x002[A-E]
//		- add addresses to their corresponding vip/whitelists (or nothing if basic)
//		- lilypad
//			15 different tokens in metadata
//			each for FakeCoin type
//			prices =>
//				basic: get_mint_price(),
//				whitelist: 500,
//				viplist: 0,
//		- have each account mint 1 token with each of their corresponding mint_type parameters
//		- assert coin::balance(addr) for each address is what we expect (difference corresponding to mint type)

	#[test(creator = @0xFA,
			basic1 = @0x000A, basic2 = @0x000B, basic3 = @0x000C, basic4 = @0x000D, basic5 = @0x000E,
			wl1 = @0x001A, wl2 = @0x001B, wl3 = @0x001C, wl4 = @0x001D, wl5 = @0x001E,
			vip1 = @vip1, vip2 = @vip2, vip3 = @vip3, treasury = @0x1234,
			bank = @0x1, aptos_framework = @0x1)]
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
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
			true,
		);

		let basic1_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		let basic2_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic2));
		let basic3_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic3));
		let basic4_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic4));
		let basic5_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic5));
		let wl1_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let wl3_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl3));
		let wl4_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl4));
		let wl5_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl5));
		let vip1_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let vip3_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip3));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(wl1), signer::address_of(wl2), signer::address_of(wl3), signer::address_of(wl4), signer::address_of(wl5)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(vip1), signer::address_of(vip2), signer::address_of(vip3)];
		add_to_whitelist<coin::FakeMoney>(creator, whitelist_addresses);
		add_to_viplist<coin::FakeMoney>(creator, viplist_addresses);

		public_check_whitelist_length<coin::FakeMoney>(creator, 5);
		public_check_viplist_length<coin::FakeMoney>(creator, 3);

      mint<coin::FakeMoney>(basic1, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(basic2, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(basic3, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(basic4, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(basic5, creator_addr, get_collection_name(), 1, BASIC_MINT);

      mint<coin::FakeMoney>(wl1, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl3, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl4, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl5, creator_addr, get_collection_name(), 1, WHITELIST_MINT);

      mint<coin::FakeMoney>(vip1, creator_addr, get_collection_name(), 1, VIP_MINT);
      mint<coin::FakeMoney>(vip2, creator_addr, get_collection_name(), 1, VIP_MINT);
      mint<coin::FakeMoney>(vip3, creator_addr, get_collection_name(), 1, VIP_MINT);

		let basic1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		let basic2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic2));
		let basic3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic3));
		let basic4_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic4));
		let basic5_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic5));
		let wl1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let wl3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl3));
		let wl4_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl4));
		let wl5_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl5));
		let vip1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let vip3_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip3));

		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(basic1_balance - basic1_post_balance == get_mint_price(), 0);
		assert!(basic2_balance - basic2_post_balance == get_mint_price(), 0);
		assert!(basic3_balance - basic3_post_balance == get_mint_price(), 0);
		assert!(basic4_balance - basic4_post_balance == get_mint_price(), 0);
		assert!(basic5_balance - basic5_post_balance == get_mint_price(), 0);
		assert!(wl1_balance - wl1_post_balance == get_wl_mint_price(), 0);
		assert!(wl2_balance - wl2_post_balance == get_wl_mint_price(), 0);
		assert!(wl3_balance - wl3_post_balance == get_wl_mint_price(), 0);
		assert!(wl4_balance - wl4_post_balance == get_wl_mint_price(), 0);
		assert!(wl5_balance - wl5_post_balance == get_wl_mint_price(), 0);
		assert!(vip1_balance - vip1_post_balance == get_vip_mint_price(), 0);
		assert!(vip2_balance - vip2_post_balance == get_vip_mint_price(), 0);
		assert!(vip3_balance - vip3_post_balance == get_vip_mint_price(), 0);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 5 + get_wl_mint_price() * 5 + get_vip_mint_price() * 3, 0);
	}

	#[test(creator = @0xFA, basic1 = @0x000A, wl1 = @0x001A, wl2 = @0x001B, vip1 = @vip1, vip2 = @vip2, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]

	//#[expected_failure(abort_code = WL_USER_CANT_MINT_ANYMORE)] //WL_USER_CANT_MINT_ANYMORE 0x2e

	//CONTRACT DOESNT USE WHITELISTING RIGHT NOW SO THIS WONT FAIL
	fun small_whitelist_mint(
		creator: &signer,
		basic1: &signer,
		wl1: &signer,
		wl2: &signer,
		vip1: &signer,
		vip2: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);

		create_and_fill_accs(creator,	basic1, wl1, wl2, vip1, vip2,	bank);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
			true,
		);

		let basic1_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		let wl1_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let vip1_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(wl1), signer::address_of(wl2)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(vip1), signer::address_of(vip2)];
		add_to_whitelist<coin::FakeMoney>(creator, whitelist_addresses);
		add_to_viplist<coin::FakeMoney>(creator, viplist_addresses);

      mint<coin::FakeMoney>(vip2, creator_addr, get_collection_name(), 1, VIP_MINT);
      mint<coin::FakeMoney>(basic1, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(vip1, creator_addr, get_collection_name(), 1, VIP_MINT);

		std::debug::print(&std::string::utf8(b"-------------------------1-------------------------"));
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
		std::debug::print(&std::string::utf8(b"-------------------------2-------------------------"));
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
		std::debug::print(&std::string::utf8(b"-------------------------3-------------------------"));
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
		std::debug::print(&std::string::utf8(b"-------------------------4-------------------------"));
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
		std::debug::print(&std::string::utf8(b"------------------------wl2 minting 1 should fail--------------------------"));
		std::debug::print(&std::string::utf8(b"-------------------------5-------------------------"));
      mint<coin::FakeMoney>(wl2, creator_addr, get_collection_name(), 1, WHITELIST_MINT);


		std::debug::print(&std::string::utf8(b"------------------------wl1 minting 3--------------------------"));
      mint<coin::FakeMoney>(wl1, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl1, creator_addr, get_collection_name(), 1, WHITELIST_MINT);
      mint<coin::FakeMoney>(wl1, creator_addr, get_collection_name(), 1, WHITELIST_MINT);



		let basic1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(basic1));
		let wl1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl1));
		let wl2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(wl2));
		let vip1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip1));
		let vip2_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(vip2));
		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(basic1_balance - basic1_post_balance == get_mint_price(), 0);
		assert!(wl1_balance - wl1_post_balance == get_wl_mint_price() * 3, 0);
		assert!(wl2_balance - wl2_post_balance == get_wl_mint_price() * 5, 0);
		assert!(vip1_balance - vip1_post_balance == get_vip_mint_price(), 0);
		assert!(vip2_balance - vip2_post_balance == get_vip_mint_price(), 0);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 1 + get_wl_mint_price() * 8 + get_vip_mint_price() * 2, 0);

		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let whitelist = borrow_global<Whitelists<coin::FakeMoney>>(resource_addr).whitelist;
		pond::bash_colors::print_key_value_as_string(b"num minted wl1: ",
			pond::bash_colors::u64_to_string(*simple_map::borrow(&whitelist, &signer::address_of(wl1))));
		pond::bash_colors::print_key_value_as_string(b"num minted wl2: ",
			pond::bash_colors::u64_to_string(*simple_map::borrow(&whitelist, &signer::address_of(wl2))));
	}

	#[test(creator = @0xFA, v1 = @vip1, v2 = @vip2, v3 = @vip3, v4 = @0x4444, v5 = @0x5555, treasury = @0x1234, nonvip = @0xce99e7d9de2e608fea37438049b5bebd1eca77c35ebeb9fa7e4ca62956a1ce6, bank = @0x1, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = VIPS_HIT_MAX_MINTS)] //VIPS_HIT_MAX_MINTS 0x32, 50
	fun test_vip_functionality(
		creator: &signer,
		v1: &signer,
		v2: &signer,
		v3: &signer,
		v4: &signer,
		v5: &signer,
		nonvip: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_vip_start_time_microseconds());	 // NOT_YET_LAUNCH_TIME 2
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);

		register_acc_and_fill(creator, bank);
		create_and_fill_accs(v1, v2, v3, v4, v5, nonvip, bank);

		let collection_supply = 20;

		initialize_lilypad<coin::FakeMoney>(
			creator,
			get_collection_name(),
			get_description(),
			get_uri(),
			collection_supply,
			vector<bool>[true, true, true],
			get_start_time_milliseconds(),
			get_mint_price(),
			get_wl_start_time_milliseconds(),
			get_wl_mint_price(),
			get_vip_start_time_milliseconds(),
			get_vip_mint_price(),
			treasury_address,
			get_token_base(),
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		let viplist_addresses: vector<address> = vector<address> [signer::address_of(v1),
		signer::address_of(v2),
		signer::address_of(v3),
		signer::address_of(v4),
		signer::address_of(v5),
		];

		add_to_viplist<coin::FakeMoney>(creator, viplist_addresses);

		let i = 0;
		while (i < collection_supply) {
			//std::debug::print(&token_name);
			add_token_metadata(	creator, pond::bash_colors::u64_to_string(i), get_token_uri(i),
											 get_token_keys(), get_token_values1());
			i = i  + 1
		};

		let i = 0;

		while(i < collection_supply) {
			let num_to_mint = MAX_MINTS_PER_TX;
			let v = if (i % (MAX_MINTS_PER_TX * 2) == 0) { v1 } else { v2 };
			mint<coin::FakeMoney>(v, creator_addr, get_collection_name(), num_to_mint, VIP_MINT);
			i = i + num_to_mint
		};

		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let viplist = borrow_global<Whitelists<coin::FakeMoney>>(resource_addr).viplist;
		pond::bash_colors::print_key_value_as_string(b"num minted wl1: ",
			pond::bash_colors::u64_to_string(*simple_map::borrow(&viplist, &signer::address_of(v1))));
		pond::bash_colors::print_key_value_as_string(b"num minted wl2: ",
			pond::bash_colors::u64_to_string(*simple_map::borrow(&viplist, &signer::address_of(v2))));

	}

	//IS_NOT_WHITELISTED 0x27
	//IS_NOT_VIP 0x28
	//INVALID_LAUNCH_TIME_OR_MINT_PRICE 0x2a
	//NOT_YET_LAUNCH_TIME 0x8
	//INVALID_MINT_TYPE 0x26
	//NON_VIP_PAYING_ZERO 0x2d
	//WL_USER_CANT_MINT_ANYMORE 0x2e

	#[test(creator = @0xFA, a1 = @0x000A, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = IS_NOT_WHITELISTED)] //IS_NOT_WHITELISTED 0x27
	//#[expected_failure(abort_code = IS_NOT_VIP)] //IS_NOT_VIP 0x28
	//#[expected_failure(abort_code = NON_VIP_PAYING_ZERO)] //NON_VIP_PAYING_ZERO 0x2d
	//#[expected_failure(abort_code = INVALID_LAUNCH_TIME_OR_MINT_PRICE)] //INVALID_LAUNCH_TIME_OR_MINT_PRICE 0x2a
	//#[expected_failure(abort_code = NOT_YET_LAUNCH_TIME)] //NOT_YET_LAUNCH_TIME 0x8
	//#[expected_failure(abort_code = INVALID_MINT_TYPE)] //INVALID_MINT_TYPE 0x26
	//#[expected_failure(abort_code = WL_USER_CANT_MINT_ANYMORE)] //WL_USER_CANT_MINT_ANYMORE 0x2e
	//#[expected_failure(abort_code = NON_VIP_PAYING_ZERO_HARD_CODE)] //NON_VIP_PAYING_ZERO_HARD_CODE 0x39, 57
	fun zzz_test_not_whitelisted(
		creator: &signer,
		a1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_wl_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_vip_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
			true,
		);

		let a1_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		add_to_whitelist<coin::FakeMoney>(creator, whitelist_addresses);
		add_to_viplist<coin::FakeMoney>(creator, viplist_addresses);

      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, BASIC_MINT);			// NOT_YET_LAUNCH_TIME if 1
      mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 2, VIP_MINT); 				// no error
		timestamp::update_global_time_for_test(get_wl_start_time_microseconds());	 									// 3
      mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 2, WHITELIST_MINT); 		// no error if 1 or 3, NOT_YET_LAUNCH_TIME if 2
		timestamp::update_global_time_for_test(get_start_time_microseconds());	 										// 4
      mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, BASIC_MINT);			// if 4 no error
      mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 2, BASIC_MINT);			// if 4 no error

      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, BASIC_MINT);			// no error
      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, WHITELIST_MINT); 	//IS_NOT_WHITELISTED
      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, VIP_MINT); 			//IS_NOT_VIP
      //mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, 3); 						//INVALID_MINT_TYPE

		let a1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(a1_balance - a1_post_balance == get_mint_price() * 3 + get_wl_mint_price() * 2 + get_vip_mint_price() * 2, 0);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 3 + get_wl_mint_price() * 2 + get_vip_mint_price() * 2, 0);
		std::debug::print(&std::string::utf8(b"done"));
	}


	//IS_NOT_WHITELISTED 0x27
	//IS_NOT_VIP 0x28
	//INVALID_LAUNCH_TIME_OR_MINT_PRICE 0x2a
	//NOT_YET_LAUNCH_TIME 0x8
	//INVALID_MINT_TYPE 0x26
	//NON_VIP_PAYING_ZERO 0x2d
	//WL_USER_CANT_MINT_ANYMORE 0x2e
	//MINTING_DISABLED 0x35

	#[test(creator = @0xFA, a1 = @0x000A, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = IS_NOT_WHITELISTED)] //IS_NOT_WHITELISTED 0x27
	//#[expected_failure(abort_code = IS_NOT_VIP)] //IS_NOT_VIP 0x28
	//#[expected_failure(abort_code = NON_VIP_PAYING_ZERO)] //NON_VIP_PAYING_ZERO 0x2d
	//#[expected_failure(abort_code = INVALID_LAUNCH_TIME_OR_MINT_PRICE)] //INVALID_LAUNCH_TIME_OR_MINT_PRICE 0x2a
	//#[expected_failure(abort_code = NOT_YET_LAUNCH_TIME)] //NOT_YET_LAUNCH_TIME 0x8
	//#[expected_failure(abort_code = INVALID_MINT_TYPE)] //INVALID_MINT_TYPE 0x26
	#[expected_failure(abort_code = MINTING_DISABLED)] //MINTING_DISABLED 0x35
	fun zzz_test_minting_disable_and_whitelist_length(
		creator: &signer,
		a1: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds()); 	 //no error
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);
		register_acc_and_fill(creator, bank);
		register_acc_and_fill(a1, bank);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		create_15_test_entries_in_bulk(creator);

		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(), // basic start time
			get_mint_price(),
			get_wl_start_time_milliseconds(), // wl start time
			get_wl_mint_price(),
			get_vip_start_time_milliseconds(), // vip start time
			get_vip_mint_price(),
			treasury_address,
			true,
		);

		disable_minting<coin::FakeMoney>(
			creator,
		);

		enable_minting<coin::FakeMoney>(
			creator,
		);

		disable_minting<coin::FakeMoney>(
			creator,
		);

		//disable_minting<coin::FakeMoney>(
		//	a1,
		//);  //fails with VMError: MISSING_DATA

		let a1_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let whitelist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		let viplist_addresses: vector<address> = vector<address> [signer::address_of(a1)];
		add_to_whitelist<coin::FakeMoney>(creator, whitelist_addresses);
		add_to_viplist<coin::FakeMoney>(creator, viplist_addresses);

		public_check_whitelist_length<coin::FakeMoney>(creator, 1);

      mint<coin::FakeMoney>(a1, creator_addr, get_collection_name(), 1, BASIC_MINT); 				// throw MINTING_DISABLED 0x35

		let a1_post_balance = coin::balance<coin::FakeMoney>(signer::address_of(a1));
		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);

		assert!(a1_balance - a1_post_balance == get_mint_price() * 1, 0);
		assert!(treasury_post_balance - treasury_balance == get_mint_price() * 1, 0);
		std::debug::print(&std::string::utf8(b"done"));
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
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////               TEST               ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
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
	fun safe_create_acc_and_register_fake_money(
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

	#[test(creator = @0xFA, minter1 = @0x000A, minter2 = @0x000B, minter3 = @0x000C, minter4 = @0x000D, minter5 = @0x000E, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun aggregate_test(
		creator: &signer,
		minter1: &signer,
		minter2: &signer,
		minter3: &signer,
		minter4: &signer,
		minter5: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		test_metadata_mint(creator, minter1, minter2, minter3, minter4, minter5, treasury, bank, aptos_framework);
	}

	#[test_only]
	fun create_and_fill_accs(
		test_account1: &signer, test_account2: &signer, test_account3: &signer, test_account4: &signer, test_account5: &signer, test_account6: &signer,
		bank: &signer,
	) {
		register_acc_and_fill(test_account1, bank); register_acc_and_fill(test_account2, bank);
		register_acc_and_fill(test_account3, bank); register_acc_and_fill(test_account4, bank);
		register_acc_and_fill(test_account5, bank); register_acc_and_fill(test_account6, bank);
	}

	#[test_only]
	fun create_and_fill_15_accs(
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
	fun register_acc_and_fill(
		test_account: &signer,
		bank: &signer,
	) {
		let test_addr = signer::address_of(test_account);
		if (!account::exists_at(signer::address_of(test_account))) {
			account::create_account_for_test(test_addr);
		};
		safe_create_acc_and_register_fake_money(bank, test_account, 10000);
	}

	#[test(creator = @0xFA, minter1 = @0x000A, minter2 = @0x000B, minter3 = @0x000C, minter4 = @0x000D, minter5 = @0x000E, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun test_metadata_mint(
		creator: &signer,
		minter1: &signer,
		minter2: &signer,
		minter3: &signer,
		minter4: &signer,
		minter5: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);
		create_and_fill_accs(creator, minter1, minter2, minter3, minter4, minter5, bank);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		//create the metadata iterable_table entries in token_metadata, then consume them to mint with create_token_script()
		create_test_entries(creator);
		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			treasury_address,
			true,
		);
      mint<coin::FakeMoney>(minter1, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter2, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter3, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter4, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter5, creator_addr, get_collection_name(), 1, BASIC_MINT);
	}


	//#[test_only]
	#[test(creator = @0xFA, minter1 = @0x000A, minter2 = @0x000B, minter3 = @0x000C, minter4 = @0x000D, minter5 = @0x000E, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun test_metadata_mint_bulk(
		creator: &signer,
		minter1: &signer,
		minter2: &signer,
		minter3: &signer,
		minter4: &signer,
		minter5: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);
		create_and_fill_accs(creator, minter1, minter2, minter3, minter4, minter5, bank);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		//create the metadata iterable_table entries in token_metadata, then consume them to mint with create_token_script()
		create_test_entries_in_bulk(creator);
		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			treasury_address,
			true,
		);
      mint<coin::FakeMoney>(minter1, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter2, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter3, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter4, creator_addr, get_collection_name(), 1, BASIC_MINT);
      mint<coin::FakeMoney>(minter5, creator_addr, get_collection_name(), 1, BASIC_MINT);
	}

	//#[test_only]
	#[test(creator = @0xFA, minter = @0x000A, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun test_multiple_mints(
		creator: &signer,
		minter: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		use pond::bash_colors::{Self};

		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());
		let bank_addr = signer::address_of(bank);
		account::create_account_for_test(bank_addr);
		let creator_addr = signer::address_of(creator);
		let treasury_address = signer::address_of(treasury);
		register_acc_and_fill(treasury, bank);
		let minter_addr = signer::address_of(minter);

		let num_mints = 5;

		account::create_account_for_test(minter_addr);
		account::create_account_for_test(creator_addr);
		safe_create_acc_and_register_fake_money(bank, minter, get_mint_price() * num_mints);
		safe_create_acc_and_register_fake_money(bank, creator, 0);

		let minter_balance = coin::balance<coin::FakeMoney>(minter_addr);
		let s: String = bash_colors::bcolor(b"blue", b"Balance of minter account: ");
		std::string::append(&mut s, bash_colors::color(b"lightblue", bash_colors::u64_to_string(minter_balance)));
		std::debug::print(&s);

		s = bash_colors::bcolor(b"purple", b"Mint price: ");
		std::string::append(&mut s, bash_colors::color(b"yellow", bash_colors::u64_to_string(get_mint_price())));
		std::debug::print(&s);

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
			get_uri_base(),
			get_token_mutability(),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_metadata_keys(),
			true,
		);

		//create the metadata iterable_table entries in token_metadata, then consume them to mint with create_token_script()
		create_test_entries_in_bulk(creator);
		upsert_coin_type_mint<coin::FakeMoney>(
			creator,
			//get_collection_name(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			get_start_time_milliseconds(),
			get_mint_price(),
			treasury_address,
			true,
		);

		mint<coin::FakeMoney>(minter, creator_addr, get_collection_name(), 2, BASIC_MINT);
		std::debug::print(&(minter_balance - (2 * get_mint_price())));
		mint<coin::FakeMoney>(minter, creator_addr, get_collection_name(), 2, BASIC_MINT);
		std::debug::print(&(minter_balance - (4 * get_mint_price())));
		mint<coin::FakeMoney>(minter, creator_addr, get_collection_name(), 2, BASIC_MINT);
		std::debug::print(&(minter_balance - (5 * get_mint_price())));
		//mint<coin::FakeMoney>(minter, creator_addr, get_collection_name(), 3, BASIC_MINT);
		//std::debug::print(&(minter_balance - (5 * get_mint_price())));
		//mint<coin::FakeMoney>(minter, creator_addr, get_collection_name(), 1, BASIC_MINT);
		//std::debug::print(&(minter_balance - (5 * get_mint_price())));
	}

	// change token property data from token2 stuff to token3
	#[test(creator = @0xFA, minter1 = @0x000A, minter2 = @0x000B, minter3 = @0x000C, minter4 = @0x000D, minter5 = @0x000E, treasury = @0x1234, bank = @0x1, aptos_framework = @0x1)]
	fun update_token_metadata_test(
		creator: &signer,
		minter1: &signer,
		minter2: &signer,
		minter3: &signer,
		minter4: &signer,
		minter5: &signer,
		treasury: &signer,
		bank: &signer,
		aptos_framework: &signer,
	) acquires MintSettings, LilypadCollectionData, TokenMapping, Whitelists, StaticTokenMetadata, LilypadEventStore {
		use std::string::utf8;

		let _minter1_addr = signer::address_of(minter1);
		let minter2_addr = signer::address_of(minter2);
		let _minter3_addr = signer::address_of(minter3);
		let _minter4_addr = signer::address_of(minter4);
		let _minter5_addr = signer::address_of(minter5);
		test_metadata_mint(creator, minter1, minter2, minter3, minter4, minter5, treasury, bank, aptos_framework);

		let (resource_signer, resource_addr) = safe_get_resource_signer_and_addr(creator);
		let token_name = get_token_name(2);
		let token_id = token::create_token_id_raw(resource_addr, get_collection_name(), token_name, 0);

		let initial_property_map = token::get_property_map(minter2_addr, token_id);

		token::mutate_one_token(&resource_signer, minter2_addr, token_id, get_token_keys(), get_token_values3(), get_token_types());
		//property map version needs to go to 1
		let token_id = token::create_token_id_raw(resource_addr, get_collection_name(), token_name, 1);
		let post_update_property_map = token::get_property_map(minter2_addr, token_id);

		let first_clothing = aptos_token::property_map::read_string(&initial_property_map, &utf8(b"background"));
		let second_clothing = aptos_token::property_map::read_string(&post_update_property_map, &utf8(b"background"));
		//std::debug::print(&first_clothing);
		//std::debug::print(&second_clothing);
		assert!(!(first_clothing == second_clothing), PROPERTY_MAP_DID_NOT_UPDATE);
	}


	#[test_only(creator = @0xFA)]
	fun create_test_entries(
		creator: &signer,
	) acquires TokenMapping, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		add_token_metadata(creator, get_token_number(1), get_token_uri(1), get_token_keys(), get_token_values1());
		add_token_metadata(creator, get_token_number(2), get_token_uri(2), get_token_keys(), get_token_values2());
		add_token_metadata(creator, get_token_number(3), get_token_uri(3), get_token_keys(), get_token_values3());
		add_token_metadata(creator, get_token_number(4), get_token_uri(4), get_token_keys(), get_token_values4());
		add_token_metadata(creator, get_token_number(5), get_token_uri(5), get_token_keys5(), get_token_values5());

		let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
		assert!(iterable_table::length(token_mapping) == 5, 0);
	}

	#[test_only(creator = @0xFA)]
	fun create_test_entries_in_bulk(
		creator: &signer,
	) acquires TokenMapping, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		add_token_metadata(creator, get_token_number(1), get_token_uri(1), get_token_keys(), get_token_values1());
		add_token_metadata(creator, get_token_number(2), get_token_uri(2), get_token_keys(), get_token_values2());
		add_token_metadata(creator, get_token_number(3), get_token_uri(3), get_token_keys(), get_token_values3());
		add_token_metadata(creator, get_token_number(4), get_token_uri(4), get_token_keys(), get_token_values4());
		add_token_metadata(creator, get_token_number(5), get_token_uri(5), get_token_keys5(), get_token_values5());

		let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
		assert!(iterable_table::length(token_mapping) == 5, 0);
	}

	#[test_only(creator = @0xFA)]
	fun create_15_test_entries_in_bulk(
		creator: &signer,
	) acquires TokenMapping, LilypadCollectionData {
		let (_, resource_addr) = safe_get_resource_signer_and_addr(creator);

		add_token_metadata_bulk(creator,
			get_token_number(1), get_token_uri(1), get_token_keys(), get_token_values1(),
			get_token_number(2), get_token_uri(2), get_token_keys(), get_token_values2(),
			get_token_number(3), get_token_uri(3), get_token_keys(), get_token_values3(),
			get_token_number(4), get_token_uri(4), get_token_keys(), get_token_values4(),
			get_token_number(5), get_token_uri(5), get_token_keys5(), get_token_values5(),
			get_token_number(6), get_token_uri(6), get_token_keys(), get_token_values6(),
			get_token_number(7), get_token_uri(7), get_token_keys(), get_token_values7(),
			get_token_number(8), get_token_uri(8), get_token_keys(), get_token_values8(),
			get_token_number(9), get_token_uri(9), get_token_keys(), get_token_values9(),
			get_token_number(10), get_token_uri(10), get_token_keys(), get_token_values10());

		add_token_metadata(creator, get_token_number(11), get_token_uri(11), get_token_keys(), get_token_values11());
		add_token_metadata(creator, get_token_number(12), get_token_uri(12), get_token_keys(), get_token_values12());
		add_token_metadata(creator, get_token_number(13), get_token_uri(13), get_token_keys(), get_token_values13());
		add_token_metadata(creator, get_token_number(14), get_token_uri(14), get_token_keys(), get_token_values14());
		add_token_metadata(creator, get_token_number(15), get_token_uri(15), get_token_keys(), get_token_values15());

		let token_mapping = &borrow_global<TokenMapping>(resource_addr).token_mapping;
		assert!(iterable_table::length(token_mapping) == 15, 0);
	}

	#[test_only] fun get_token_name(n: u64): String {
		let s: String = get_token_base();
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		s
	}

	#[test_only] fun get_token_base(): String { std::string::utf8(b"Aptoad #") }
	#[test_only] fun get_uri_base(): String { std::string::utf8(b"https://arweave.net/") }

	#[test_only] fun get_token_number(n: u64): String { pond::bash_colors::u64_to_string(n) }

	#[test_only] fun get_token_uri(n: u64): String {
		use std::string::utf8;
		let s: String = utf8(b"uri_id_");
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		std::string::append(&mut s, utf8(b".png"));
		s
	}

	#[test_only] fun get_token_mutability(): vector<bool> { vector<bool> [ true, true, true, true, true ] }
	#[test_only] fun get_uri_mutable(): 					bool { true }
	#[test_only] fun get_royalty_mutable(): 				bool { true }
	#[test_only] fun get_description_mutable(): 			bool { true }
	#[test_only] fun get_properties_mutable(): 			bool { true }
	#[test_only] fun get_royalty_payee_address(): 		address { @0xFA }
	#[test_only] fun get_royalty_points_denominator(): u64 { 1000 }
	#[test_only] fun get_royalty_points_numerator(): 	u64 { 100 }

	#[test_only]
	fun get_token_metadata_keys(): vector<String> {
		get_token_keys()
	}

	#[test_only]
	fun get_token_keys(): vector<String> {
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
	fun get_token_types(): vector<String> {
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
	fun get_token_keys5(): vector<String> {
		use std::string::utf8;
		vector<String>  [
			utf8(b"background"),
			utf8(b"body") ]
	}

	#[test_only]
	fun get_token_values1(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Turquoise"), std::bcs::to_bytes<vector<u8>>(&b"Aptos"),
			std::bcs::to_bytes<vector<u8>>(&b"Black Tee"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), std::bcs::to_bytes<vector<u8>>(&b"Party Hat"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values2(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Orange"), std::bcs::to_bytes<vector<u8>>(&b"Lime"),
			std::bcs::to_bytes<vector<u8>>(&b"Blue Hawaiian"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), std::bcs::to_bytes<vector<u8>>(&b"Shounen"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values3(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Turquoise"), std::bcs::to_bytes<vector<u8>>(&b"Purp"),
			std::bcs::to_bytes<vector<u8>>(&b"Gold Chain"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"Cig"), std::bcs::to_bytes<vector<u8>>(&b"Black Beanie"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values4(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Orange"), std::bcs::to_bytes<vector<u8>>(&b"Purp"),
			std::bcs::to_bytes<vector<u8>>(&b"Lab Coat"), std::bcs::to_bytes<vector<u8>>(&b"None"),
			std::bcs::to_bytes<vector<u8>>(&b"Bubble Gum"), std::bcs::to_bytes<vector<u8>>(&b"Cowboy Hat"),
			std::bcs::to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values5(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"Blue"),
			std::bcs::to_bytes<vector<u8>>(&b"Lime"), ]
	}

	#[test_only]
	fun get_token_values6(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Orange"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"King of Kings"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values7(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Blue"), to_bytes<vector<u8>>(&b"Brains"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Space Helmet"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values8(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values9(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Orange"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values10(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Prince Crown"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values11(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Blue"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Flower"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values12(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Turquoise"), to_bytes<vector<u8>>(&b"Cyborg"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Flower"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values13(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Aptos"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Stache"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values14(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Turquoise"), to_bytes<vector<u8>>(&b"Aptos"), to_bytes<vector<u8>>(&b"Nobleman"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only]
	fun get_token_values15(): vector<vector<u8>> {
		use std::bcs::to_bytes;
		vector<vector<u8>> [ to_bytes<vector<u8>>(&b"Pink"), to_bytes<vector<u8>>(&b"Brains"), to_bytes<vector<u8>>(&b"None"),
			to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"None"), to_bytes<vector<u8>>(&b"Art of War"), to_bytes<vector<u8>>(&b"None"), ]
	}

	#[test_only] fun should_update_entry(): bool { true }

	#[test_only] fun get_start_time_seconds(): u64 { 1000000 }
	#[test_only] fun get_start_time_milliseconds(): u64 { get_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_start_time_microseconds(): u64 { get_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] fun get_end_time_seconds(): u64 { 1000001 }
	#[test_only] fun get_end_time_milliseconds(): u64 { get_end_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_end_time_microseconds(): u64 { get_end_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] fun get_wl_start_time_seconds(): u64 { 1000000 - 1 }
	#[test_only] fun get_wl_start_time_milliseconds(): u64 { get_wl_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_wl_start_time_microseconds(): u64 { get_wl_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] fun get_vip_start_time_seconds(): u64 { 1000000 - 2 }
	#[test_only] fun get_vip_start_time_milliseconds(): u64 { get_vip_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_vip_start_time_microseconds(): u64 { get_vip_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] fun get_collection_name(): String { use std::string::utf8; utf8(b"collection name") }
	#[test_only] fun get_collection_name2(): String { use std::string::utf8; utf8(b"collection name2") }
	#[test_only] fun get_description(): String { use std::string::utf8; utf8(b"collection description") }
	#[test_only] fun get_uri(): String { use std::string::utf8; utf8(b"https://aptos.dev") }
	#[test_only] fun get_collection_supply(): u64 { 10000 }

	#[test_only] fun get_mint_price(): u64 { 1000 }
	#[test_only] fun get_wl_mint_price(): u64 { 500 }
	#[test_only] fun get_vip_mint_price(): u64 { 0 }

}
