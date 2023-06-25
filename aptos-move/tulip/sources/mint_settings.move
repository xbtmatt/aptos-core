module pond::mint_settings {

	friend pond::reroller;

   use std::signer;
	use pond::bucket_table::{Self, BucketTable};
	use std::vector::{Self};
	use aptos_std::table::{Self, Table};
	use aptos_std::type_info::{Self, TypeInfo};

   use aptos_framework::timestamp;

	use aptos_framework::coin;
	use aptos_framework::event::{Self, EventHandle};

	use std::account::{Self};

	//use aptos_framework::aptos_coin::AptosCoin;

	// if user passes in seconds instead of milliseconds, their time will show as very low, we use YEAR_THREE_THOUSAND
	//		to ensure that any user attempting to do this up to the year 3000
	//		will see an error suggesting they check their timestamp unit
	const YEAR_THREE_THOUSAND: u64 = 32503680000;

	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	const U64_MAX: u64 = 18446744073709551615;

	//			the intention with this module is to make the minting/mint settings/config aspect of our minting contracts modular.
	//			we often repeat the logic for this- whitelisting, minting, disabling mints, launch times, end times, tiered mint prices, etc
	//				but the logic for mutating these functions is scattered across the mint module.
	//
	//			I'd like to pack all of these functions into a single module so it's reusable in different types of minting contracts
	//
	//			It's agnostic to the creator, collection, and any details of why we're minting or what metadata to use, it just mints the token with the metadata it's
	//						given so long as the price/# of mints/launch time conditions are satisfied
	//
	//			Supports and enforces:
	//				- Different coins for different Tiers, ensures `treasury_address` is registered with the coin
	//				- Different prices for different Tiers, handles the coin transfer
	//				- Tiered prices, handles the coin transfer,
	//				- Tiered launch times
	//				- keeps track of # of Tiered mints per address
	//				- max # of Tiered mints a single address can mint
	//
	//			And it handles the minting by being passed TokenData. Upon mint it increments the user's # of mints and either lets the
	//				resource_signer hold the token or has it transfer the token to the user


	// 	To mitigate paranoia over free mints, create a GUI to visualize the # of mints and their respective Tiers for which they are minted.
	//			since you are going to be emitting Events of type Tier for each mint event, just visualize this with a bar chart in js and use that to monitor with
	// 	some sort of hard disable.


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								ERROR CODES		  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	const GLOBAL_MINT_SETTINGS_ALREADY_EXIST: u64 =  0;
	const GLOBAL_MINT_SETTINGS_DO_NOT_EXIST: u64 =  1;
	const USER_DOES_NOT_HAVE_ACCESS_TO_TIER: u64 =  2;
	const NOT_YET_LAUNCH_TIME: u64 =  3;
	const PAST_END_TIME: u64 =  4;
	const MINTING_IS_DISABLED: u64 =  5;
	const TREASURY_ADDRESS_NOT_REGISTERED_FOR_COIN: u64 =  6;
	const MINT_SETTINGS_FOR_TIER_AND_COIN_TYPE_ALREADY_EXIST: u64 =  7;
	const MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST: u64 = 8;
	const MINT_SETTINGS_FOR_TIER_ALREADY_EXISTS: u64 = 9;
	const MINT_PRICE_FOR_TIER_AND_COIN_TYPE_DOES_NOT_EXIST: u64 = 10;
	const COIN_NOT_INITIALIZED: u64 =  11;
	const NOT_ENOUGH_COIN: u64 =  12;
	const MINTER_DID_NOT_PAY: u64 =  13;
	const TREASURY_DID_NOT_GET_PAID: u64 = 14;
	//const MINTER_DID_NOT_GET_TOKEN: u64 = 15;
	const USER_HAS_NO_MINTS_LEFT_FOR_TIER: u64 = 16;
	const CANNOT_ENABLE_MINT_WITH_NO_MINT_SETTINGS: u64 = 17;
	const FCFS_MINT_CANNOT_BE_FREE: u64 = 18;
	const ENSURE_TIMESTAMP_IS_IN_MILLISECONDS: u64 = 19;
	const LAUNCH_TIME_MUST_BE_BEFORE_END_TIME: u64 = 20;
	const END_TIME_MUST_BE_AFTER_LAUNCH_TIME: u64 = 21;
	const FCFS_DOES_NOT_USE_WHITELIST: u64 = 22;
	const PAST_GLOBAL_END_TIME: u64 = 23;
	const ENO_DEFAULT_FOR_MINT_TIER: u64 = 24;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      						   DATA STRUCTURES	  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	struct GlobalMintSettings has key {
		enabled: bool,
		treasury_address: address,									// used when initialize/updating TieredMintSettings
		has_at_least_one_mint_setting: bool,
		global_end_time_ms: u64,
	}

	// first come first serve Mint Tier, this is used to differentiate between Tiered Mints and a basic, untiered Mint
	struct FCFS has store { }

	struct TieredMintSettings<phantom Tier> has key {
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,							// this is per Tier + CoinType, meaning a user could mint from 1a `max_mints_per_user` * 2 times if there's 2 CoinTypes set up for it
		access_list: BucketTable<address, bool>, 		// see Note: ACCESS_LIST
	}

	struct TieredMintPrice<phantom Tier, phantom CoinType> has key {
		inner: u64,
	}
	/*
		Note: ACCESS_LIST
		this does not track the number of mints. We could- but since we are not tracking basic mints
		due to a potentially rapidly increasing bucket table on FCFS mints, it's easier to just track them
		by storing a PurchaseHistory struct onto the user's account, like what we did in lilypad_v2
	*/

	struct PurchaseHistory<phantom Tier> has key {
		inner: Table<address, u64>,
	}

	struct PurchaseEvent has drop, store {
		creator: address,
		buyer: address,
		tier: TypeInfo,
		price: u64,
		coin: TypeInfo,
	}

	struct PurchaseEventStore has key {
		purchase_events: EventHandle<PurchaseEvent>,
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      							INITIALIZATION  				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	public(friend) fun initialize_all<Tier, CoinType>(
		resource_signer: &signer,
		treasury_address: address,
		global_end_time_ms: u64,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
		mint_price: u64,
	) acquires GlobalMintSettings {
		initialize_global_mint_settings(resource_signer, treasury_address, global_end_time_ms);
		initialize_tiered_mint_setting_and_price<Tier, CoinType>(
			resource_signer,
			launch_time_ms,
			end_time_ms,
			max_mints_per_user,
			mint_price
		);
	}


	public(friend) fun initialize_global_mint_settings(
		resource_signer: &signer,
		treasury_address: address,
		global_end_time_ms: u64,
	) {
		let resource_address = signer::address_of(resource_signer);

		assert!(global_end_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);
		assert!(!exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_ALREADY_EXIST);
		//assert!(global_end_time_ms > timestamp::now_seconds)
		move_to(
			resource_signer,
			GlobalMintSettings {
				enabled: false,
				treasury_address: treasury_address,
				has_at_least_one_mint_setting: false,
				global_end_time_ms: global_end_time_ms,
			},
		);
	}

	public(friend) fun initialize_tiered_mint_setting_and_price<Tier, CoinType>(
		resource_signer: &signer,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
		mint_price: u64,
	) acquires GlobalMintSettings {
		initialize_tiered_mint_setting<Tier>(resource_signer, launch_time_ms, end_time_ms, max_mints_per_user);
		initialize_tiered_mint_price<Tier, CoinType>(resource_signer, mint_price);
	}

	// creating a MintSetting for <Tier, Cointype> will always go through here, even the upsert function below.
	//		ensure that the treasury_address stored in `GlobalMintSettings` is registered with the CoinType set in here
	public(friend) fun initialize_tiered_mint_setting<Tier>(
		resource_signer: &signer,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
	) {
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST);
		assert!(!exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_ALREADY_EXISTS);
		assert!(launch_time_ms > YEAR_THREE_THOUSAND && end_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);

		move_to(
			resource_signer,
			TieredMintSettings<Tier> {
				launch_time_ms: launch_time_ms,
				end_time_ms: end_time_ms,
				//max_total_mints: max_total_mints,
				max_mints_per_user: max_mints_per_user,
				//aggregate_mints: 0,
				access_list: bucket_table::new<address, bool>(300), // TODO: FIGURE OUT THE RIGHT NUMBER FOR THIS DEPENDING ON WHITELIST SIZE
			}
		);
	}

	public(friend) fun initialize_tiered_mint_price<Tier, CoinType>(
		resource_signer: &signer,
		mint_price: u64,
	) acquires GlobalMintSettings {
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST);
		assert!(exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST);
		let is_fcfs_mint = type_info::type_of<Tier>() == type_info::type_of<FCFS>();
		// FCFS mint cannot be free because there is no limit on mints per wallet. The potential for abuse is too high.
		assert!(!is_fcfs_mint || mint_price > 0, FCFS_MINT_CANNOT_BE_FREE);

		move_to(
			resource_signer,
			TieredMintPrice<Tier, CoinType> {
				inner: mint_price,
			}
		);

		let global_mint_settings = borrow_global_mut<GlobalMintSettings>(resource_address);
		global_mint_settings.has_at_least_one_mint_setting = true;
		let treasury_address = global_mint_settings.treasury_address;

		assert!(check_coin_registered_and_valid<CoinType>(treasury_address), TREASURY_ADDRESS_NOT_REGISTERED_FOR_COIN);
	}

	fun check_coin_registered_and_valid<CoinType>(
		treasury_address: address,
	): bool {
		assert!(coin::is_coin_initialized<CoinType>(), COIN_NOT_INITIALIZED);
		let is_registered = coin::is_account_registered<CoinType>(treasury_address);
		is_registered
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      							GETTERS/SETTERS  				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	public(friend) fun enable_global_mint(
		resource_signer: &signer,
	) acquires GlobalMintSettings {
		internal_set_global_mint_enabled(signer::address_of(resource_signer), true);
	}

	public(friend) fun disable_global_mint(
		resource_signer: &signer,
	) acquires GlobalMintSettings {
		internal_set_global_mint_enabled(signer::address_of(resource_signer), false);
	}

	public(friend) fun set_launch_time_ms<Tier>(
		resource_signer: &signer,
		new_launch_time_ms: u64,
	) acquires TieredMintSettings {
		assert!(new_launch_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST);
		assert!(exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST);
		let tiered_mint_settings = borrow_global_mut<TieredMintSettings<Tier>>(resource_address);
		assert!(new_launch_time_ms < tiered_mint_settings.end_time_ms, LAUNCH_TIME_MUST_BE_BEFORE_END_TIME);
		tiered_mint_settings.launch_time_ms = new_launch_time_ms;
	}

	public(friend) fun set_end_time_ms<Tier>(
		resource_signer: &signer,
		new_end_time_ms: u64,
	) acquires TieredMintSettings {
		assert!(new_end_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST);
		assert!(exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST);
		let tiered_mint_settings = borrow_global_mut<TieredMintSettings<Tier>>(resource_address);
		assert!(new_end_time_ms > tiered_mint_settings.launch_time_ms, END_TIME_MUST_BE_AFTER_LAUNCH_TIME);
		tiered_mint_settings.end_time_ms = new_end_time_ms;
	}

	public(friend) fun set_global_end_time_ms(
		resource_signer: &signer,
		new_global_end_time_ms: u64,
	) acquires GlobalMintSettings {
		assert!(new_global_end_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST);
		borrow_global_mut<GlobalMintSettings>(resource_address).global_end_time_ms = new_global_end_time_ms;
	}

	public(friend) fun upsert_tiered_mint_settings<Tier>(
		resource_signer: &signer,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
	) acquires TieredMintSettings {
		let resource_address = signer::address_of(resource_signer);
		assert!(launch_time_ms > YEAR_THREE_THOUSAND && end_time_ms > YEAR_THREE_THOUSAND, ENSURE_TIMESTAMP_IS_IN_MILLISECONDS);
		if (!exists<TieredMintSettings<Tier>>(resource_address)) {
			initialize_tiered_mint_setting<Tier>(
				resource_signer,
				launch_time_ms,
				end_time_ms,
				max_mints_per_user,
			);
		} else {
			let mint_setting = borrow_global_mut<TieredMintSettings<Tier>>(resource_address);
			mint_setting.launch_time_ms = launch_time_ms;
			mint_setting.end_time_ms = end_time_ms;
			mint_setting.max_mints_per_user = max_mints_per_user;
		};
	}

	public(friend) fun upsert_mint_price<Tier, CoinType>(
		resource_signer: &signer,
		mint_price: u64,
	) acquires GlobalMintSettings, TieredMintPrice {
		let resource_address = signer::address_of(resource_signer);
		assert!(exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST);

		let is_fcfs_mint = type_info::type_of<Tier>() == type_info::type_of<FCFS>();
		assert!(!is_fcfs_mint || mint_price > 0, FCFS_MINT_CANNOT_BE_FREE);

		if (!exists<TieredMintPrice<Tier, CoinType>>(resource_address)) {
			initialize_tiered_mint_price<Tier, CoinType>(resource_signer, mint_price);
		} else {
			let tiered_mint_price = borrow_global_mut<TieredMintPrice<Tier, CoinType>>(resource_address);
			tiered_mint_price.inner = mint_price;
		}
	}

	public(friend) fun add_addresses_to_tier<Tier>(
		resource_signer: &signer,
		addresses: vector<address>,
	) acquires TieredMintSettings {
		assert!(type_info::type_of<Tier>() != type_info::type_of<FCFS>(), FCFS_DOES_NOT_USE_WHITELIST);
		let resource_address = signer::address_of(resource_signer);
		let mint_settings = borrow_global_mut<TieredMintSettings<Tier>>(resource_address);
		while(vector::length(&addresses) > 0) {
			bucket_table::add(
				&mut mint_settings.access_list,
				vector::pop_back(&mut addresses),
				true
			);
		}
	}


	// TODO:
	// The below function SHOULD PROBABLY NOT EVEN BE HERE.
	// Why?:
	//		It's agnostic to the minting aspect of it- that can be handled by the calling parent contract.
	//		This means the use of token metadata to mint an NFT should be gated by the parent contract,
	//			not this one.
	//		This function is merely meant to provide setters/getters for restricting access to
	//			doing a specific action a # of times.
	//		In our previous cases, that's minting.
	//		However, since we will be doing the reroll contract, it makes *much* more sense to gate
	//			the initial action of buying the right to mint an NFT, not actually doing it.
	//			This allows us to extract the non-logistical aspects of minting out of this contract
	//			and handle the gating of them in the parent contract.

	// minting, transferring, and paying should always occur atomically + sequentially
	// --
	// this function is agnostic to why/how the user gets here,
	//	it merely enforces launch time, mint price, max # mints, whitelists, and then mints/transfers the token
	//		- asserts that now > launch_time_ms
	//		- asserts that now < end_time_ms
	//		- uses metadata for 1 token to mint
	// 	- asserts the user has enough CoinType to pay for it
	//			- facilitates the exchange of coin
	//		- asserts the user has mints left in their Tier
	//			- increments num minted by 1
	//			- mints token to resource_signer
	//			- transfers it to user
	public(friend) fun purchase_one<Tier, CoinType>(
		resource_signer: &signer,
		minter: &signer,
	) acquires TieredMintSettings, TieredMintPrice, GlobalMintSettings, PurchaseHistory, PurchaseEventStore {
		let resource_address = signer::address_of(resource_signer);
		let minter_address = signer::address_of(minter);

		assert!(exists<TieredMintSettings<Tier>>(resource_address), MINT_SETTINGS_FOR_TIER_DOES_NOT_EXIST);
		assert!(exists<TieredMintPrice<Tier, CoinType>>(resource_address), MINT_PRICE_FOR_TIER_AND_COIN_TYPE_DOES_NOT_EXIST);

		let is_fcfs_mint = type_info::type_of<Tier>() == type_info::type_of<FCFS>();
		let mint_settings = borrow_global_mut<TieredMintSettings<Tier>>(resource_address);
		let launch_time_ms = mint_settings.launch_time_ms;
		let end_time_ms = mint_settings.end_time_ms;
		let mint_price = borrow_global<TieredMintPrice<Tier, CoinType>>(resource_address).inner;
		let (treasury_address, global_end_time_ms) = {
			let global_mint_settings = borrow_global<GlobalMintSettings>(resource_address);
			(global_mint_settings.treasury_address, global_mint_settings.global_end_time_ms)
		};

		// /////////////////////
		// /////////////////////
		//   CHECK LAUNCH TIME
		// /////////////////////
		// /////////////////////
		let now = timestamp::now_seconds()*MILLI_CONVERSION_FACTOR;
		assert!(now < global_end_time_ms, PAST_GLOBAL_END_TIME);
		assert!(now > launch_time_ms, NOT_YET_LAUNCH_TIME);
		assert!(now < end_time_ms, PAST_END_TIME);
		assert!(borrow_global<GlobalMintSettings>(resource_address).enabled, MINTING_IS_DISABLED);

		// /////////////////////
		// /////////////////////
		// 	  SEND COIN
		// /////////////////////
		// /////////////////////
		assert!(coin::balance<CoinType>(minter_address) >= mint_price, NOT_ENOUGH_COIN);
		let pre_mint_balance_minter = coin::balance<CoinType>(minter_address);
		let pre_mint_balance_treasury = coin::balance<CoinType>(treasury_address);
		coin::transfer<CoinType>(minter, treasury_address, mint_price);
		assert!(coin::balance<CoinType>(minter_address) == (pre_mint_balance_minter - (mint_price)), MINTER_DID_NOT_PAY);
		assert!(coin::balance<CoinType>(treasury_address) == (pre_mint_balance_treasury + (mint_price)), TREASURY_DID_NOT_GET_PAID);
		/*
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
			bash_colors::print_key_value_as_string(b"treasury before:  ", bash_colors::u64_to_string(pre_mint_balance_treasury));
			bash_colors::print_key_value_as_string(b"treasury  after:  ", bash_colors::u64_to_string(coin::balance<CoinType>(treasury_address)));
		};
		*/

		// //////////////////////////////////////////
		// //////////////////////////////////////////
		//		CHECK IF MINTER IS IN REQUESTED TIER
		// //////////////////////////////////////////
		// //////////////////////////////////////////
		let minter_in_tier = if (is_fcfs_mint) {
			true
		} else {
			bucket_table::contains(&mint_settings.access_list, &minter_address)
		};

		// user must either be in the Tier or is requesting to mint as FCFS tier
		assert!(minter_in_tier || is_fcfs_mint, USER_DOES_NOT_HAVE_ACCESS_TO_TIER);


		// //////////////////////////////////////////
		// //////////////////////////////////////////
		// 	  		 INCREMENT MINT COUNT
		// //////////////////////////////////////////
		// //////////////////////////////////////////
		possibly_initialize_purchase_history<Tier>(minter, resource_address);
		increment_num_minted<Tier, CoinType>(minter_address, resource_address);

		// //////////////////////////////////////////
		// //////////////////////////////////////////
		//					EMIT PURCHASE EVENT
		// //////////////////////////////////////////
		// //////////////////////////////////////////
		possibly_initialize_event_store(minter);
		let purchase_event_store = borrow_global_mut<PurchaseEventStore>(minter_address);
		event::emit_event<PurchaseEvent>(
			&mut purchase_event_store.purchase_events,
			PurchaseEvent {
				creator: resource_address,
				buyer: minter_address,
				tier: type_info::type_of<Tier>(),
				price: mint_price,
				coin: type_info::type_of<CoinType>(),
			},
		);
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////                                  											 //////////////////////
///////////////////////      								INTERNAL    				       		 	 //////////////////////
///////////////////////                                  											 //////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	// if the user doesn't have a mint history for <Tier> create a table indexed against the resource_address (essentially creator+collection name)
	// and initialize the number of mints to 0
	fun possibly_initialize_purchase_history<Tier>(
		minter: &signer,
		resource_address: address,
	) {
		if (!exists<PurchaseHistory<Tier>>(signer::address_of(minter))) {
			let new_table = table::new<address, u64>();
			table::add(&mut new_table, resource_address, 0);
			move_to(
				minter,
				PurchaseHistory<Tier> {
					inner: new_table,
				}
			);
		};
	}

	fun increment_num_minted<Tier, CoinType>(
		minter_address: address,
		resource_address: address,
	) acquires PurchaseHistory, TieredMintSettings {
		let max_mints_per_user = borrow_global<TieredMintSettings<Tier>>(resource_address).max_mints_per_user;
		let purchase_history = borrow_global_mut<PurchaseHistory<Tier>>(minter_address);
		// if table doesn't contain resource_address for collection_name+creator combo, init #_mints to 0
		if (!table::contains(&purchase_history.inner, resource_address)) {
			table::add(&mut purchase_history.inner, resource_address, 0);
		};

		let num_mints = table::borrow_mut(&mut purchase_history.inner, resource_address);
		*num_mints = *num_mints + 1;

		assert!(*num_mints <= max_mints_per_user, USER_HAS_NO_MINTS_LEFT_FOR_TIER);
	}

	fun internal_set_global_mint_enabled(
		resource_address: address,
		enabled: bool,
	) acquires GlobalMintSettings {
		assert!(exists<GlobalMintSettings>(resource_address), GLOBAL_MINT_SETTINGS_DO_NOT_EXIST); 	// inline candidate, this and above

		// the mint cannot be enabled unless
		let global_mint_settings = borrow_global_mut<GlobalMintSettings>(resource_address);
		assert!(!enabled || global_mint_settings.has_at_least_one_mint_setting, CANNOT_ENABLE_MINT_WITH_NO_MINT_SETTINGS);
		global_mint_settings.enabled = enabled;
	}

	fun possibly_initialize_event_store(minter: &signer) {
		if (!exists<PurchaseEventStore>(signer::address_of(minter))) {
			move_to(
				minter,
				PurchaseEventStore {
					purchase_events: account::new_event_handle<PurchaseEvent>(minter),
				},
			);
		};
	}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////                                  											 //////////////////////
///////////////////////      							 UNIT TESTS    				       		 	 //////////////////////
///////////////////////                                  											 //////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#[test_only]
	public(friend) fun default_initialize_all_for_test<Tier>(
		resource_signer: &signer,
		treasury: &signer,
	) acquires GlobalMintSettings {
		initialize_all<Tier, coin::FakeMoney>(
			resource_signer,
			signer::address_of(treasury),
			TEST_GLOBAL_END_TIME_MILLISECONDS,
			TEST_LAUNCH_TIME_MILLISECONDS,
			TEST_END_TIME_MILLISECONDS,
			test_get_max_mints<Tier>(),
			test_get_mint_price<Tier>(),
		);
	}

	#[test_only]
	fun init_for_test_minter<Tier>(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
		initial_coin: u64,
	) acquires GlobalMintSettings {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		default_initialize_all_for_test<Tier>(resource_signer, treasury);
		enable_global_mint(resource_signer);
		pond::utils::register_acc_and_fill(aptos_framework, minter, initial_coin);
	}

	#[test(resource_signer = @test_resource_signer, minter_1 = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = CANNOT_ENABLE_MINT_WITH_NO_MINT_SETTINGS), location = Self]
	fun test_attempt_to_enable_mint_with_no_mint_settings(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires GlobalMintSettings {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		initialize_global_mint_settings(
			resource_signer,
			signer::address_of(treasury),
			TEST_GLOBAL_END_TIME_MILLISECONDS,
		);
		enable_global_mint(resource_signer);
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = GLOBAL_MINT_SETTINGS_DO_NOT_EXIST), location = Self]
	fun test_initialize_mint_settings_with_no_global_mint_settings(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		initialize_tiered_mint_setting<FCFS>(resource_signer, TEST_LAUNCH_TIME_MILLISECONDS, TEST_END_TIME_MILLISECONDS, test_get_max_mints<FCFS>());
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = ENSURE_TIMESTAMP_IS_IN_MILLISECONDS), location = Self]
	fun test_launch_time_in_seconds_instead_of_milliseconds(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires GlobalMintSettings, TieredMintSettings {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		default_initialize_all_for_test<FCFS>(resource_signer, treasury);
		set_launch_time_ms<FCFS>(resource_signer, TEST_LAUNCH_TIME_SECONDS);
		//set_end_time_ms(resource_signer, TEST_END_TIME_SECONDS); 		// this will work too
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = ENSURE_TIMESTAMP_IS_IN_MILLISECONDS), location = Self]
	fun test_global_end_time_ms_in_seconds_instead_of_milliseconds(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires GlobalMintSettings {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		default_initialize_all_for_test<FCFS>(resource_signer, treasury);
		set_global_end_time_ms(resource_signer, TEST_GLOBAL_END_TIME_SECONDS);
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = MINTING_IS_DISABLED), location = Self]
	fun test_try_mint_with_mint_disabled(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		pond::utils::setup_test_environment(resource_signer, aptos_framework, treasury, TEST_LAUNCH_TIME_SECONDS + 1);
		default_initialize_all_for_test<FCFS>(resource_signer, treasury);
		purchase_one<FCFS, coin::FakeMoney>(resource_signer, minter);
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = USER_HAS_NO_MINTS_LEFT_FOR_TIER), location = Self]
	fun test_mint_too_many(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		init_for_test_minter<FCFS>(
			resource_signer, aptos_framework, treasury, minter, TEST_INITIAL_COIN_AMOUNT);

		let i = 0;
		while (i < test_get_max_mints<FCFS>() + 1) {
			purchase_one<FCFS, coin::FakeMoney>(resource_signer, minter);
			i = i + 1;
		};
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = PAST_GLOBAL_END_TIME), location = Self]
	fun test_mint_after_global_end_time_ms(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		init_for_test_minter<FCFS>(
			resource_signer, aptos_framework, treasury, minter, TEST_INITIAL_COIN_AMOUNT);
		timestamp::update_global_time_for_test(TEST_GLOBAL_END_TIME_MICROSECONDS);
		//timestamp::update_global_time_for_test_secs(TEST_GLOBAL_END_TIME_SECONDS); // equivalent to above

		// below is only necessary if `now < end_time_ms` comes befoer `now < global_end_time_ms`
		//set_end_time_ms<FCFS>(resource_signer, TEST_GLOBAL_END_TIME_MILLISECONDS + 1);
		purchase_one<FCFS, coin::FakeMoney>(resource_signer, minter);
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = USER_DOES_NOT_HAVE_ACCESS_TO_TIER), location = Self]
	fun test_whitelist_mint_when_not_on_whitelist(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		use pond::mint_tiers::{Tier1A};
		init_for_test_minter<Tier1A>(
			resource_signer, aptos_framework, treasury, minter, TEST_INITIAL_COIN_AMOUNT);

		let i = 0;
		while (i < test_get_max_mints<Tier1A>()) {
			purchase_one<Tier1A, coin::FakeMoney>(resource_signer, minter);
			i = i + 1;
		};
	}

	#[test_only] const PROPERTY_VERSION_ZERO: u64 = 0;

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	fun test_whitelist_mint(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		use pond::mint_tiers::{Tier1A};

		init_for_test_minter<Tier1A>(
			resource_signer, aptos_framework, treasury, minter, TEST_INITIAL_COIN_AMOUNT);

		let minter_address = signer::address_of(minter);
		let treasury_address = signer::address_of(treasury);
		add_addresses_to_tier<Tier1A>(resource_signer, vector<address> [minter_address]);

		let minter_pre_balance = coin::balance<coin::FakeMoney>(minter_address);
		let treasury_pre_balance = coin::balance<coin::FakeMoney>(treasury_address);

		let i = 0;
		while (i < test_get_max_mints<Tier1A>()) {
			purchase_one<Tier1A, coin::FakeMoney>(resource_signer, minter);
			i = i + 1;
		};

		let total_mint_cost = test_get_max_mints<Tier1A>() * test_get_mint_price<Tier1A>();

		let minter_post_balance = coin::balance<coin::FakeMoney>(minter_address);
		let treasury_post_balance = coin::balance<coin::FakeMoney>(treasury_address);
		assert!(minter_pre_balance - minter_post_balance == total_mint_cost, MINTER_DID_NOT_PAY);
		assert!(treasury_post_balance - treasury_pre_balance == total_mint_cost, TREASURY_DID_NOT_GET_PAID);
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = USER_HAS_NO_MINTS_LEFT_FOR_TIER), location = Self]
	fun test_whitelist_mint_more_than_alotted(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		use pond::mint_tiers::{Tier1A};
		init_for_test_minter<Tier1A>(
			resource_signer, aptos_framework, treasury, minter, TEST_INITIAL_COIN_AMOUNT);

		add_addresses_to_tier<Tier1A>(resource_signer, vector<address> [signer::address_of(minter)]);

		let i = 0;
		while (i < test_get_max_mints<Tier1A>() + 1) {
			purchase_one<Tier1A, coin::FakeMoney>(resource_signer, minter);
			i = i + 1;
		};
	}

	#[test(resource_signer = @test_resource_signer, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = NOT_ENOUGH_COIN), location = Self]
	fun test_user_not_enough_coin(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		minter: &signer,
	) acquires GlobalMintSettings, TieredMintSettings, TieredMintPrice, PurchaseHistory, PurchaseEventStore {
		use pond::mint_tiers::{Tier1A};
		init_for_test_minter<Tier1A>(
			resource_signer, aptos_framework, treasury, minter, 0);

		add_addresses_to_tier<Tier1A>(resource_signer, vector<address> [signer::address_of(minter)]);
		purchase_one<Tier1A, coin::FakeMoney>(resource_signer, minter);
	}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////                                  											 //////////////////////
///////////////////////      						UNIT TEST HELPERS/SETUP			       		 	 //////////////////////
///////////////////////                                  											 //////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	//	946684800 = Jan 01 2000 00:00:00 UTC
	// 946688400 = Jan 01 2000 01:00:00 UTC
	#[test_only] const TEST_LAUNCH_TIME_SECONDS: u64 = 946684800;
	#[test_only] const TEST_LAUNCH_TIME_MILLISECONDS: u64 = 946684800 * 1000;
	#[test_only] const TEST_LAUNCH_TIME_MICROSECONDS: u64 = 946684800 * 1000000;
	#[test_only] const TEST_GLOBAL_END_TIME_SECONDS: u64 = 1675728000;
	#[test_only] const TEST_GLOBAL_END_TIME_MILLISECONDS: u64 = 1675728000 * 1000;
	#[test_only] const TEST_GLOBAL_END_TIME_MICROSECONDS: u64 = 1675728000 * 1000000;
	#[test_only] const TEST_END_TIME_SECONDS: u64 = 946688400;
	#[test_only] const TEST_END_TIME_MILLISECONDS: u64 = 946688400 * 1000;
	#[test_only] const TEST_END_TIME_MICROSECONDS: u64 = 946688400 * 1000000;
	#[test_only] const TEST_MINT_PRICE: u64 = 1000;

	#[test_only] const TEST_INITIAL_COIN_AMOUNT: u64 = 10000;

	#[test_only]
	public(friend) fun test_get_max_mints<T>(): u64 {
		if (type_info::type_of<T>() == type_info::type_of<FCFS>()) { 1 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier1A>()) { 2 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier1B>()) { 3 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier1C>()) { 4 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier1D>()) { 5 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier2>()) { 6 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier3>()) { 7 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::Tier4>()) { 8 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::TestTierSmall>()) { 10 }
		else if (type_info::type_of<T>() == type_info::type_of<pond::mint_tiers::TestTierLarge>()) { 2000 }
		else { abort ENO_DEFAULT_FOR_MINT_TIER }
	}

	#[test_only]
	fun test_get_mint_price<T>(): u64 {
		test_get_max_mints<T>() * 1000
	}
}
