module pond::steak {
	use aptos_framework::coin::{Self};
	use aptos_framework::managed_coin::{Self};
   use aptos_framework::account::{Self, SignerCapability};
   use aptos_framework::event::{Self, EventHandle};
	use std::vector;
   use std::signer;
	use std::string::{Self, String};
	use aptos_std::type_info::{Self, TypeInfo};
	use aptos_token::token::{Self, Token, TokenId, deposit_token, withdraw_token};
	use aptos_std::table::{Self, Table};
   use aptos_framework::timestamp;


	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	const U64_MAX: u64 = 18446744073709551615;

	const ONE_DAY: u64 = 24 * 60 * 60;
	const ONE_DAY_MICRO_SECONDS: u64 = 24 * 60 * 60 * 1000000; //MICRO_CONVERSION_FACTOR;

	const MAX_COIN_SUPPLY: u64 = 100000000000; // 100 billion, i.e., 100,000,000,000

	const												PAYOUT_NOT_GREATER_THAN_ZERO: u64 =  0;	/*  0x0 */
	const									PERIOD_DURATION_NOT_GREATER_THAN_ZERO: u64 =  1;	/*  0x1 */
	const										  			COLLECTION_DOES_NOT_EXIST: u64 =  2;	/*  0x2 */
	const									RESOURCE_ADDRESS_DOESNT_OWN_COIN_TYPE: u64 =  3;	/*  0x3 */
	const		 SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION: u64 =  4;	/*  0x4 */
	const					SUPPLIED_CREATOR_DOESNT_MATCH_STAKE_CONFIGURATION: u64 =  5;	/*  0x5 */
	const	  								  					 USER_DOESNT_OWN_TOKEN: u64 =  6;	/*  0x6 */
	const															TOKEN_NOT_IN_ESCROW: u64 =  7;	/*  0x7 */
	const									 TOKEN_STILL_IN_INITIAL_LOCKUP_PERIOD: u64 =  8;	/*  0x8 */
	const																ARITHMETIC_ERROR: u64 =  9;	/*  0x9 */
	const										 			  NO_FULL_PERIODS_ELAPSED: u64 = 10;	/*  0xa */
	const												  USER_DID_NOT_RECEIVE_COIN:  u64 = 11;	/*  0xb */

	const													COIN_TYPE_DOES_NOT_EXIST:  u64 = 12;	/*  0xc */
	const											  SIGNER_IS_NOT_CONTRACT_OWNER:  u64 = 13;	/*  0xd */
	const 											  USER_DIDNT_GET_TOKEN_BACK:  u64 = 14;	/*  0xe */
	const 											  		USER_DIDNT_GIVE_TOKEN:  u64 = 15;	/*  0xf */
	const 										TEST_INCORRECT_REWARDS_CLAIMED:  u64 = 16;	/*  0x10 */
	const 											 USER_SHOULD_NOT_HAVE_TOKEN:  u64 = 17;	/*  0x11 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1b:  u64 = 18;	/*  0x12 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1c:  u64 = 19;	/*  0x13 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1d:  u64 = 20;	/*  0x14 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1e:  u64 = 21;	/*  0x15 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1f:  u64 = 22;	/*  0x16 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1g:  u64 = 23;	/*  0x17 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1h:  u64 = 24;	/*  0x18 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1i:  u64 = 25;	/*  0x19 */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1j:  u64 = 26;	/*  0x1a */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1k:  u64 = 27;	/*  0x1b */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1l:  u64 = 28;	/*  0x1c */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1m:  u64 = 29;	/*  0x1d */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1n:  u64 = 30;	/*  0x1e */
	const 										TEST_INCORRECT_REWARDS_CLAIMED1o:  u64 = 31;	/*  0x1f */

	struct StakeResourceSigner has key {
		resource_signer_cap: SignerCapability,
	}

	struct TokensStaked has key {
		tokens_staked: Table<TokenId, TokenStake>,
		token_stake_events: EventHandle<TokenStakeEvent>,
		token_unstake_events: EventHandle<TokenUnstakeEvent>,
		claim_reward_events: EventHandle<DistributeRewardEvent>,
	}

	struct StakeConfiguration<phantom CoinType> has key {
		per_period_payout_amount: u64,
		minimum_lockup_periods: u64,
		period_duration: u64,
		collection_id: CollectionId,
	}

	struct TokenStakeEvent has drop, store {
		token_id: TokenId,
		initial_lockup_timestamp: u64,
		end_lockup_period: u64,
		coin_type_info: TypeInfo,
	}

	struct TokenUnstakeEvent has drop, store {
		token_id: TokenId,
		initial_lockup_timestamp: u64,
		stake_periods_accumulated: u64,
		coin_type_info: TypeInfo,
	}

	struct DistributeRewardEvent has drop, store {
		token_id: TokenId,
		reward: u64,
		coin_type_info: TypeInfo,
	}

	struct TokenStake has store {
		token: Token,
		token_stake_data: TokenStakeData,
	}

	struct TokenStakeData has copy, drop, store {
		initial_lockup_timestamp: u64,
		last_claim: u64,
		end_lockup_period: u64,
	}

	struct CollectionId has copy, drop, store {
		collection_name: String,
		creator_address: address,
	}

	struct FlyCoin {}

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////       OWNER INITIALIZATION       ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///
   fun init_module(
		contract_owner: &signer,
	) {
		let name = b"Fly";
		let symbol = b"FLY";
		let decimals = 0;
		let monitor_supply = true;

		managed_coin::initialize<FlyCoin>(
			contract_owner,
			name,
			symbol,
			decimals,
			monitor_supply,
		)
	}

	public entry fun initialize<CoinType>(
		owner: &signer,
		per_period_payout_amount: u64,
		minimum_lockup_periods: u64,
		period_duration: u64,
		creator_address: address,
		collection_name: String,
	) acquires StakeResourceSigner, StakeConfiguration {
		assert!(signer::address_of(owner) == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);
		assert!(per_period_payout_amount > 0, PAYOUT_NOT_GREATER_THAN_ZERO);
		assert!(period_duration > 0, PERIOD_DURATION_NOT_GREATER_THAN_ZERO);
		assert!(token::check_collection_exists(creator_address, collection_name), COLLECTION_DOES_NOT_EXIST);

		let seed_string = copy collection_name;
		string::append(&mut seed_string, string::utf8(b"steak"));
		let seed = *string::bytes(&seed_string);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, copy seed);
		let resource_address = signer::address_of(&resource_signer);

		assert!(&resource_address == &account::get_signer_capability_address(&resource_signer_cap), 0);
		assert!(&resource_signer == &account::create_signer_with_capability(&resource_signer_cap), 0);

		assert!(coin::is_coin_initialized<CoinType>(), COIN_TYPE_DOES_NOT_EXIST);
		managed_coin::register<CoinType>(&resource_signer);
		managed_coin::mint<CoinType>(
			owner,
			resource_address,
			MAX_COIN_SUPPLY,
		);

		move_to(
			owner,
			StakeResourceSigner {
					resource_signer_cap: resource_signer_cap,
				}
		);

		upsert_stake_config<CoinType>(
			owner,
			per_period_payout_amount,
			minimum_lockup_periods,
			period_duration,
			creator_address,
			collection_name,
		);
	}

	public entry fun send_test_coins_for_devnet(
		owner: &signer,
	) acquires StakeResourceSigner {
		let owner_address = signer::address_of(owner);
		assert!(owner_address == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		safe_register_user_for_coin<FlyCoin>(owner);
		coin::transfer<FlyCoin>(&resource_signer, owner_address, 100000000);
	}

	public entry fun upsert_stake_config<CoinType>(
		owner: &signer,
		per_period_payout_amount: u64,
		minimum_lockup_periods: u64,
		period_duration: u64,
		creator_address: address,
		collection_name: String,
	) acquires StakeResourceSigner, StakeConfiguration {
		assert!(signer::address_of(owner) == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);
		let (resource_signer, resource_address) = safe_get_resource_signer_and_addr(owner);

		let collection_id = CollectionId {
			collection_name: collection_name,
			creator_address: creator_address,
		};

		if (!exists<StakeConfiguration<CoinType>>(resource_address)) {
			move_to(
				&resource_signer,
				StakeConfiguration<CoinType> {
					per_period_payout_amount: per_period_payout_amount,
					minimum_lockup_periods: minimum_lockup_periods,
					period_duration: period_duration,
					collection_id: collection_id,
				}
			)
		} else {
			let stake_configuration = borrow_global_mut<StakeConfiguration<CoinType>>(resource_address);
			stake_configuration.per_period_payout_amount = per_period_payout_amount;
			stake_configuration.minimum_lockup_periods = minimum_lockup_periods;
			stake_configuration.period_duration = period_duration;
			stake_configuration.collection_id = collection_id;
		};
	}

	fun internal_get_resource_signer_and_addr(
		owner_addr: address,
	): (signer, address) acquires StakeResourceSigner {
		let resource_signer_cap = &borrow_global<StakeResourceSigner>(owner_addr).resource_signer_cap;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_address = signer::address_of(&resource_signer);

		(resource_signer, resource_address)
	}

	fun safe_get_resource_signer_and_addr(
		deployer: &signer,
	): (signer, address) acquires StakeResourceSigner {
		internal_get_resource_signer_and_addr(signer::address_of(deployer))
	}

	fun initialize_tokens_staked(
		token_owner: &signer,
	) {
		if (!exists<TokensStaked>(signer::address_of(token_owner))) {
			move_to(
				token_owner,
				TokensStaked {
						tokens_staked: table::new<TokenId, TokenStake>(),
						token_stake_events: account::new_event_handle<TokenStakeEvent>(token_owner),
						token_unstake_events: account::new_event_handle<TokenUnstakeEvent>(token_owner),
						claim_reward_events: account::new_event_handle<DistributeRewardEvent>(token_owner),
					}
			);
		};
	}

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////       USER ENTRY FUNCTIONS       ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////

   public entry fun safe_register_user_for_coin<CoinType>(
		user: &signer,
	) {
		let user_address = signer::address_of(user);
		if (!coin::is_account_registered<CoinType>(user_address)) {
			managed_coin::register<CoinType>(user);
		};
	}

	fun get_latest_token_id(
		creator_address: address,
		collection_name: String,
		token_name: String,
	): TokenId {
      let token_data_id = token::create_token_data_id(creator_address, collection_name, token_name);
		let largest_property_version = token::get_tokendata_largest_property_version(creator_address, token_data_id);
      let token_id = token::create_token_id_raw(creator_address, collection_name, token_name, largest_property_version);

		token_id
	}

   public entry fun user_stake_tokens<CoinType>(
		token_owner: &signer,
		deployer_address: address,
		token_names: vector<String>,
		collection_name: String,			// redundant, because it's stored in the owner_address resource_address
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		let token_owner_address = signer::address_of(token_owner);
		let (_, resource_address) = internal_get_resource_signer_and_addr(deployer_address);

		initialize_tokens_staked(token_owner);

		//unnecessary BEGIN
		let stake_configuration = borrow_global<StakeConfiguration<CoinType>>(resource_address);
		let collection_id = stake_configuration.collection_id;
		let creator_address = collection_id.creator_address;

		assert!(collection_name == collection_id.collection_name, SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION);
		//unnecessary END

		safe_register_user_for_coin<CoinType>(token_owner);

		while (vector::length(&token_names) > 0) {
			let token_name = vector::pop_back(&mut token_names);
			let token_id = get_latest_token_id(creator_address, collection_name, token_name);
			assert!(token::balance_of(token_owner_address, token_id) == 1, USER_DOESNT_OWN_TOKEN);

			stake_token<CoinType>(token_owner, token_id, resource_address);
			assert!(token::balance_of(token_owner_address, token_id) == 0, USER_DIDNT_GIVE_TOKEN); //redundant
		}
	}

	public entry fun user_unstake_tokens<CoinType>(
		token_owner: &signer,
		deployer_address: address,
		token_names: vector<String>,
		collection_name: String,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(deployer_address);

		initialize_tokens_staked(token_owner);

		//unnecessary BEGIN
		let stake_configuration = borrow_global<StakeConfiguration<CoinType>>(resource_address);
		let collection_id = stake_configuration.collection_id;
		let creator_address = collection_id.creator_address;

		assert!(collection_name == collection_id.collection_name, SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION);
		//unnecessary END

		safe_register_user_for_coin<CoinType>(token_owner);

		while (vector::length(&token_names) > 0) {
			let token_name = vector::pop_back(&mut token_names);
			let token_id = get_latest_token_id(creator_address, collection_name, token_name);
			unstake_token<CoinType>(token_owner, token_id, &resource_signer);
		}
	}

	public entry fun user_claim_rewards<CoinType>(
		token_owner: &signer,
		deployer_address: address,
		token_names: vector<String>,
		collection_name: String,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		let token_owner_address = signer::address_of(token_owner);
		let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(deployer_address);

		initialize_tokens_staked(token_owner);

		//unnecessary BEGIN
		let stake_configuration = borrow_global<StakeConfiguration<CoinType>>(resource_address);
		let collection_id = stake_configuration.collection_id;
		let creator_address = collection_id.creator_address;
		let period_duration = stake_configuration.period_duration;

		assert!(collection_name == collection_id.collection_name, SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION);
		//unnecessary END

		safe_register_user_for_coin<CoinType>(token_owner);

		while (vector::length(&token_names) > 0) {
			let token_name = vector::pop_back(&mut token_names);
			let token_id = get_latest_token_id(creator_address, collection_name, token_name);
			claim_reward<CoinType>(
				token_owner,
				&resource_signer,
				token_id,
				period_duration,
			);
			assert!(token::balance_of(token_owner_address, token_id) == 0, USER_SHOULD_NOT_HAVE_TOKEN); //redundant
		}
	}


	fun stake_token<CoinType>(
		token_owner: &signer,
		token_id: TokenId,
		resource_address: address,
	) acquires StakeConfiguration, TokensStaked {
		let token_owner_address = signer::address_of(token_owner);
		let token = withdraw_token(token_owner, token_id, 1);
		let tokens_staked = borrow_global_mut<TokensStaked>(token_owner_address);
		let tokens_staked_table = &mut tokens_staked.tokens_staked;
		let stake_configuration = borrow_global<StakeConfiguration<CoinType>>(resource_address);
		let period_duration = stake_configuration.period_duration;
		let minimum_lockup_periods = stake_configuration.minimum_lockup_periods;

		let initial_lockup_timestamp = timestamp::now_seconds();
		let end_lockup_period = timestamp::now_seconds() + (period_duration * minimum_lockup_periods);

		let token_stake = TokenStake {
			token: token,
			token_stake_data: TokenStakeData {
				initial_lockup_timestamp: initial_lockup_timestamp,
				last_claim: timestamp::now_seconds(),
				end_lockup_period: end_lockup_period,
			}
		};

		table::add(tokens_staked_table, token_id, token_stake);

		event::emit_event<TokenStakeEvent>(
			&mut tokens_staked.token_stake_events,
			TokenStakeEvent {
				token_id: token_id,
				initial_lockup_timestamp: initial_lockup_timestamp,
				end_lockup_period: end_lockup_period,
				coin_type_info: type_info::type_of<CoinType>(),
			}
		);
	}

	fun unstake_token<CoinType>(
		token_owner: &signer,
		token_id: TokenId,
		resource_signer: &signer,
	) acquires StakeConfiguration, TokensStaked {
		let resource_address = signer::address_of(resource_signer);
		let token_owner_address = signer::address_of(token_owner);
		let tokens_staked = borrow_global_mut<TokensStaked>(token_owner_address);
		let tokens_staked_table = &mut tokens_staked.tokens_staked;

		assert!(table::contains(tokens_staked_table, token_id), TOKEN_NOT_IN_ESCROW);

		let TokenStake {
			token: token,
			token_stake_data: token_stake_data,
		} = table::remove(tokens_staked_table, token_id);

		let initial_lockup_timestamp = token_stake_data.initial_lockup_timestamp;
		let last_claim = token_stake_data.last_claim;
		let end_lockup_period = token_stake_data.end_lockup_period;

		assert!(timestamp::now_seconds() >= end_lockup_period, TOKEN_STILL_IN_INITIAL_LOCKUP_PERIOD);

		let period_duration = borrow_global<StakeConfiguration<CoinType>>(resource_address).period_duration;
		let stake_periods_accumulated = (timestamp::now_seconds() - initial_lockup_timestamp) / period_duration;

		event::emit_event<TokenUnstakeEvent>(
			&mut tokens_staked.token_unstake_events,
			TokenUnstakeEvent {
				token_id: token_id,
				initial_lockup_timestamp: initial_lockup_timestamp,
				stake_periods_accumulated: stake_periods_accumulated,
				coin_type_info: type_info::type_of<CoinType>(),
			}
		);

		let is_unstaking = true;
		let (_, total_reward) = calculate_reward<CoinType>(resource_address, last_claim, is_unstaking);
		transfer_reward<CoinType>(token_owner, resource_signer, token_id, total_reward);

		deposit_token(token_owner, token);
		assert!(token::balance_of(token_owner_address, token_id) == 1, USER_DIDNT_GET_TOKEN_BACK);
	}

	fun claim_reward<CoinType>(
		token_owner: &signer,
		resource_signer: &signer,
		token_id: TokenId,
		period_duration: u64,
	) acquires TokensStaked, StakeConfiguration {
		let resource_address = signer::address_of(resource_signer);
		let token_owner_address = signer::address_of(token_owner);
		let tokens_staked_table = &mut borrow_global_mut<TokensStaked>(token_owner_address).tokens_staked;

		assert!(table::contains(tokens_staked_table, token_id), TOKEN_NOT_IN_ESCROW);
		let token_stake = table::borrow_mut(tokens_staked_table, token_id);
		let token_stake_data = &mut token_stake.token_stake_data;

		let last_claim_before_request_to_claim = token_stake_data.last_claim;

		let is_unstaking = false;
		// calculate reward based on the last reward claim time
		let (full_periods_elapsed, total_reward) = calculate_reward<CoinType>(resource_address, last_claim_before_request_to_claim, is_unstaking);

		// get mutable reference to claim time to update the claim time to the most recent period's end
		let last_claim = &mut token_stake_data.last_claim;

		// we don't want to punish user for claiming the reward,
		//	so we will make the last_claim round down to the time used to calculate the latest period duration
		// aka if the user is at 1.5 days staked, the last_claim will be set to the timestamp equivalent to 1 day staked
		// this means they could claim another reward in 0.5 days
		*last_claim = *last_claim + (full_periods_elapsed * period_duration);

		transfer_reward<CoinType>(token_owner, resource_signer, token_id, total_reward);
	}

	fun calculate_reward<CoinType>(
		resource_address: address,
		last_claim: u64,
		is_unstaking: bool,
	): (u64, u64) acquires StakeConfiguration {
		let stake_configuration = borrow_global<StakeConfiguration<CoinType>>(resource_address);
		let per_period_payout_amount = stake_configuration.per_period_payout_amount;
		let time_elapsed_since_last_claim = timestamp::now_seconds() - last_claim;
		let period_duration = stake_configuration.period_duration;

		let full_periods_elapsed = time_elapsed_since_last_claim / period_duration;
		let total_reward = full_periods_elapsed * per_period_payout_amount;

		// won't reset unless reward transfer succeeds, which means full_periods_elapsed >= 1
		assert!(full_periods_elapsed >= 1 || is_unstaking, NO_FULL_PERIODS_ELAPSED);

		(full_periods_elapsed, total_reward)
	}

	fun transfer_reward<CoinType>(
		token_owner: &signer,
		resource_signer: &signer,
		token_id: TokenId,
		total_reward: u64,
	) acquires TokensStaked {
		assert!(1001 / 1000 == 1, ARITHMETIC_ERROR);
		assert!(38741 / 1000 == 38, ARITHMETIC_ERROR);

		/////////////////////////////////        TRANSFER REWARD         ////////////////////////////////////////

		let token_owner_address = signer::address_of(token_owner);
		let pre_balance_owner = coin::balance<CoinType>(token_owner_address);
		safe_register_user_for_coin<CoinType>(token_owner);
		coin::transfer<CoinType>(resource_signer, signer::address_of(token_owner), total_reward);
		assert!(coin::balance<CoinType>(token_owner_address) == pre_balance_owner + total_reward, USER_DID_NOT_RECEIVE_COIN);

		let claim_reward_events = &mut borrow_global_mut<TokensStaked>(token_owner_address).claim_reward_events;
		event::emit_event<DistributeRewardEvent>(
			claim_reward_events,
			DistributeRewardEvent {
				token_id: token_id,
				reward: total_reward,
				coin_type_info: type_info::type_of<CoinType>(),
			},
		);
	}

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
	use pond::bash_colors::{Self, color, color_bg, bcolor, bcolor_bg, u64_to_string, bool_to_string, bool_to_string_bytes, print_key_value, print_key_value_as_string};

	#[test_only]
	use std::string::{utf8};

   #[test_only]
   use aptos_framework::aggregator_factory;

	#[test_only]
	fun use_functions() {
		let _ = bash_colors::u64_to_string(1);
		let use_bytes = b"use";
		let use_string = utf8(use_bytes);
		let _ = utf8(use_bytes);
		let _ = color(b"blue", use_string);
		let _ = bcolor(b"blue", use_bytes);
		let _ = color_bg(b"blue", use_string);
		let _ = bcolor_bg(b"blue", use_bytes);
		print_key_value(b"key", b"value");
		print_key_value_as_string(b"int", u64_to_string(1));
		print_key_value(b"bool", bool_to_string_bytes(true));
		print_key_value_as_string(b"bool", bool_to_string(true));
	}

	#[test_only]
	fun init_for_test(
		deployer: &signer,
		aptos_framework: &signer,
	) acquires StakeResourceSigner, StakeConfiguration {
		timestamp::set_time_has_started_for_testing(aptos_framework);
		timestamp::update_global_time_for_test(get_start_time_microseconds());
      aggregator_factory::initialize_aggregator_factory_for_test(aptos_framework);

		init_module(deployer);

		let deployer_address = signer::address_of(deployer);

		let bank = aptos_framework;
		let bank_address = signer::address_of(bank);
		account::create_account_for_test(bank_address);
		account::create_account_for_test(deployer_address);

		//print_key_value_as_string(b"coin type name: ", type_info::type_name<FlyCoin>());

		token::create_collection_script(
			deployer,
			get_collection_name(),
			get_description(),
			get_uri(),
			get_collection_supply(),
			vector<bool>[true, true, true],
		);

		create_tokens_for_test(deployer, get_default_num_tokens());

		initialize<FlyCoin>(
			deployer,
			get_default_reward(),
			get_default_lockup_periods(),
			get_default_period_duration(),
			deployer_address,
			get_collection_name(),
		);

		let (_, resource_address) = safe_get_resource_signer_and_addr(deployer);

		assert!(coin::balance<FlyCoin>(resource_address) == MAX_COIN_SUPPLY, 1337);
	}

	#[test_only]
	fun init_for_test_with_staker(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeResourceSigner, StakeConfiguration {
		init_for_test(deployer, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let staker_address = signer::address_of(staker);

		account::create_account_for_test(staker_address);

		let i = 0;
		while (i < get_default_num_tokens()) {
			transfer_token_to(deployer, staker, i);
			assert!(token::balance_of(staker_address, get_latest_token_id(deployer_address, get_collection_name(), get_token_name(i))) == 1, 0);
			i = i + 1;
		};
	}


		// test stake rewards for 0.9999 days, 1 day, 1.5 days, 2 days, 10 days, 1000 days
		// check reward amounts, assert expected value
		// check last_claim, assert expected value
		//
		//
		// do the same with unstaking

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////           		TEST               ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////

	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	fun test_basic_staking(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		//print_key_value_as_string(b"flycoin type: ", type_info::type_name<FlyCoin>());
		//std::debug::print(&type_info::account_address(&type_info::type_of<FlyCoin>()));
		//print_key_value(b"flycoin type: ", type_info::module_name(&type_info::type_of<FlyCoin>()));
		//print_key_value(b"flycoin type: ", type_info::struct_name(&type_info::type_of<FlyCoin>()));
		print_dividers(b"test_basic_staking");
		init_for_test_with_staker(deployer, staker, aptos_framework);

		let deployer_address = signer::address_of(deployer);
		let staker_address = signer::address_of(staker);


		let num_tokens_to_stake = 3;
		let token_names = get_token_names(num_tokens_to_stake);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration());
		print_key_value_as_string(b"time (us): ", u64_to_string(timestamp::now_microseconds()));
		print_key_value_as_string(b"time (s):  ", u64_to_string(timestamp::now_seconds()));

		print_user_balance<FlyCoin>(staker_address);

		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		assert!(get_user_balance<FlyCoin>(staker_address) == num_tokens_to_stake * get_default_reward(), TEST_INCORRECT_REWARDS_CLAIMED);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration() + 1);

		print_user_balance<FlyCoin>(staker_address);
	}

	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	#[expected_failure(abort_code = TOKEN_STILL_IN_INITIAL_LOCKUP_PERIOD)] //TOKEN_STILL_IN_INITIAL_LOCKUP_PERIOD, 8
	fun test_minimum_lockup_period(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_minimum_lockup_period");
		init_for_test_with_staker(deployer, staker, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let num_tokens_to_stake = 3;
		let token_names = get_token_names(num_tokens_to_stake);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration() - 1);

		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);
	}

	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	#[expected_failure(abort_code = USER_DOESNT_OWN_TOKEN)] //USER_DOESNT_OWN_TOKEN, 6
	fun test_double_deposit(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_double_deposit");
		init_for_test_with_staker(deployer, staker, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let num_tokens_to_stake = 3;
		let token_names = get_token_names(num_tokens_to_stake);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);
	}

	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	#[expected_failure(abort_code = TOKEN_NOT_IN_ESCROW)] //TOKEN_NOT_IN_ESCROW, 7
	fun test_double_withdraw(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_double_withdraw");
		init_for_test_with_staker(deployer, staker, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let num_tokens_to_stake = 3;
		let token_names = get_token_names(num_tokens_to_stake);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration());

		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);

		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			token_names,
			get_collection_name(),
		);
	}


	// stake 3 tokens for 12 hours
	// then start staking a 4th token
	// then claim rewards at 24 hours
	// then claim rewards at 36 hours
	// check/print balance each time
	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	fun test_separate_deposit_times(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_separate_deposit_times");
		init_for_test_with_staker(deployer, staker, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let staker_address = signer::address_of(staker);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			vector<String> [ get_token_name(1), get_token_name(2), get_token_name(3) ],
			get_collection_name(),
		);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration() * 1 / 2);
		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			vector<String> [ get_token_name(4) ],
			get_collection_name(),
		);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration() * 1);
		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			vector<String> [ get_token_name(1), get_token_name(2), get_token_name(3) ],
			get_collection_name(),
		);

		let asserted_user_balance = 3 * get_default_reward();
		assert!(get_user_balance<FlyCoin>(staker_address) == asserted_user_balance, TEST_INCORRECT_REWARDS_CLAIMED);
		print_user_balance<FlyCoin>(staker_address);

		set_elapsed_time_in_seconds(get_default_lockup_period_duration() * 3 / 2);
		user_unstake_tokens<FlyCoin>(
			staker,
			deployer_address,
			vector<String> [ get_token_name(4) ],
			get_collection_name(),
		);

		let asserted_user_balance = asserted_user_balance + 1 * get_default_reward();
		assert!(get_user_balance<FlyCoin>(staker_address) == asserted_user_balance, TEST_INCORRECT_REWARDS_CLAIMED);
		print_user_balance<FlyCoin>(staker_address);
	}

	#[test(deployer = @pond, staker = @0xAAAAAAAAAAAAAAAA, staker2 = @0xBBBBBBBBBBBBBBBB, aptos_framework = @0x1)]
	#[expected_failure(abort_code = NO_FULL_PERIODS_ELAPSED)] //NO_FULL_PERIODS_ELAPSED, 10
	fun test_convoluted_instructions(
		deployer: &signer,
		staker: &signer,
		staker2: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_convoluted_instructions");
		init_for_test_with_staker(deployer, staker, aptos_framework);
		let deployer_address = signer::address_of(deployer);
		let staker_address = signer::address_of(staker);
		let staker_address2 = signer::address_of(staker2);

		account::create_account_for_test(staker_address2);

		let token_id = get_latest_token_id(
			deployer_address,
			get_collection_name(),
			get_token_name(0),
		);
		token::direct_transfer(staker, staker2, token_id, 1);

		default_stake(staker2, vector<u64> [0]);								// 0 	user_b stake token_0
		default_stake(staker, vector<u64> [1]);								// a 	user_a stake token_1
		set_elapsed_periods(1);
		default_claim(staker, vector<u64> [1]);								// b	user_a claim
		assert_and_print_balance(staker_address, 1);

		default_unstake(staker, vector<u64> [1]);								// c	user_a unstake & claim
		assert_and_print_balance(staker_address, 1);

		default_stake(staker, vector<u64> [1]);								// d	user_a stake
		set_elapsed_periods_fraction(7, 2); // add 2.5 periods			// 3.5 periods have elapsed, 3 reward periods staked

		default_claim(staker, vector<u64> [1]);								// e	user_a claim
		assert_and_print_balance(staker_address, 3);

		default_unstake(staker, vector<u64> [1]);								// f	user_a unstake & claim
		assert_and_print_balance(staker_address, 3);

		default_stake(staker, vector<u64> [1]);								// g	user_a stake
		set_elapsed_periods_fraction(9, 2); // add 1 periods				// 4.5 periods total have elapsed, 4 reward periods staked

		default_claim(staker, vector<u64> [1]);								// h	user_a stake
		assert_and_print_balance(staker_address, 4);

		set_elapsed_periods_fraction(50, 4); // add 8 periods				// i	12.5 periods total have elapsed, 12 reward periods staked
		default_claim(staker, vector<u64> [1]);								// j	user_a claim
		assert_and_print_balance(staker_address, 12);

		set_elapsed_periods_fraction(52, 4); // add 0.5 periods			// k	13 periods total have elapsed, 13 reward periods staked USER_B
		default_claim(staker2, vector<u64> [0]);								// l	user_b claim
		assert_and_print_balance(staker_address2, 13);

		set_elapsed_periods_fraction(53, 4); // add 0.5 periods			// m	13.25 periods total have elapsed, 12.75 reward periods staked USER_A
		default_claim(staker, vector<u64> [1]);								// n	user_a claim
		assert_and_print_balance(staker_address, 12);

	}

	#[test(deployer = @pond, staker = @0xAAAA, aptos_framework = @0x1)]
	#[expected_failure(abort_code = SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION)] //SUPPLIED_COLLECTION_NAME_DOESNT_MATCH_STAKE_CONFIGURATION, 4
	fun test_wrong_collection_failure(
		deployer: &signer,
		staker: &signer,
		aptos_framework: &signer,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		print_dividers(b"test_wrong_collection_failure");
		init_for_test_with_staker(deployer, staker, aptos_framework);

		let deployer_address = signer::address_of(deployer);
		let different_collection_name = utf8(b"different collection name");

		token::create_collection_script(
			deployer,
			different_collection_name,
			get_description(),
			get_uri(),
			get_collection_supply(),
			vector<bool>[true, true, true],
		);

		token::create_token_script(
			deployer,
			different_collection_name,
			get_token_name(0),
			get_token_name(0),
			1,
			1,
			get_token_uri(0),
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			get_token_mutability(),
			vector<String>[ utf8(b"key") ],
			vector<vector<u8>>[ b"value" ],
			vector<String>[ utf8(b"0x1::String::string") ],
		);

		let token_id = get_latest_token_id(
			deployer_address,
			different_collection_name,
			get_token_name(0),
		);
		token::direct_transfer(deployer, staker, token_id, 1);

		user_stake_tokens<FlyCoin>(
			staker,
			deployer_address,
			vector<String>[ get_token_name(0) ],
			different_collection_name,
		);
	}

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////           TEST HELPERS           ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////


   #[test_only]
	fun assert_and_print_balance(
		staker_address: address,
		periods_elapsed: u64,
	) {
		assert!(get_user_balance<FlyCoin>(staker_address) == (periods_elapsed * get_default_reward()), TEST_INCORRECT_REWARDS_CLAIMED);
		print_user_balance<FlyCoin>(staker_address);
	}

   #[test_only]
	const STAKE_FUNCTION: u64 = 0;

   #[test_only]
	const UNSTAKE_FUNCTION: u64 = 1;

   #[test_only]
	const CLAIM_FUNCTION: u64 = 2;

   #[test_only]
	fun default_action(
		staker: &signer,
		token_numbers: vector<u64>,
		action: u64,
	) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		vector::reverse(&mut token_numbers);
		let token_names = vector<String> [];
		while (vector::length(&token_numbers) > 0) {
			let n = vector::pop_back(&mut token_numbers);
			vector::push_back(&mut token_names, get_token_name(n));
		};
		if (action == STAKE_FUNCTION) {
			user_stake_tokens<FlyCoin>( staker, @pond, token_names, get_collection_name());
		} else if (action == UNSTAKE_FUNCTION) {
			user_unstake_tokens<FlyCoin>( staker, @pond, token_names, get_collection_name());
		} else if (action == CLAIM_FUNCTION) {
			user_claim_rewards<FlyCoin>( staker, @pond, token_names, get_collection_name());
		} else {
			abort 0
		};
	}

	#[test_only]
	fun default_stake(staker: &signer, token_numbers: vector<u64>) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		default_action(staker, token_numbers, STAKE_FUNCTION);
	}

	#[test_only]
	fun default_unstake(staker: &signer, token_numbers: vector<u64>) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		default_action(staker, token_numbers, UNSTAKE_FUNCTION);
	}

	#[test_only]
	fun default_claim(staker: &signer, token_numbers: vector<u64>) acquires StakeConfiguration, StakeResourceSigner, TokensStaked {
		default_action(staker, token_numbers, CLAIM_FUNCTION);
	}

   #[test_only]
	fun print_dividers(
		text: vector<u8>,
	) {
		let s = utf8(b"--------------------------------");
		string::append(&mut s, bcolor(b"black", text));
		let s2 = bcolor_bg(b"yellow", b" --------------------------------");
		string::append(&mut s, s2);
		std::debug::print(&color_bg(b"yellow", s));
	}

   #[test_only]
	fun get_default_lockup_period_duration(): u64 {
		get_default_lockup_periods() * get_default_period_duration()
	}

   #[test_only]
	fun get_token_names(
		num_tokens: u64,
	): vector<String> {
		let token_names = vector<String> [];
		let i = 0;
		while (i < num_tokens) {
			vector::push_back(&mut token_names, get_token_name(i));
			i = i + 1;
		};

		token_names
	}

   #[test_only]
	fun get_user_balance<CoinType>(
		user_address: address,
	): u64 {
		coin::balance<CoinType>(user_address)
	}

   #[test_only]
	fun print_user_balance<CoinType>(
		user_address: address,
	) {
		std::debug::print(&user_address);
		print_key_value_as_string(b"$FLY balance: ", u64_to_string(coin::balance<CoinType>(user_address)));
	}

   #[test_only]
	fun set_elapsed_time_in_seconds(
		seconds: u64,
	) {
		timestamp::update_global_time_for_test(get_start_time_microseconds() + (seconds * MICRO_CONVERSION_FACTOR));
	}

   #[test_only]
	fun set_elapsed_periods(
		periods: u64,
	) {
		set_elapsed_time_in_seconds(periods * get_default_lockup_period_duration());
	}

   #[test_only]
	fun set_elapsed_periods_fraction(
		periods: u64,
		divisor: u64,
	) {
		set_elapsed_time_in_seconds((periods * get_default_lockup_period_duration()) / divisor);
	}

	#[test_only]
	fun create_tokens_for_test(
		owner: &signer,
		num_tokens: u64,
	) {
		let i = 0;
		while (i < num_tokens) {
			token::create_token_script(
				owner,
				get_collection_name(),
				get_token_name(i),
				get_token_name(i),
				1,
				1,
				get_token_uri(i),
				get_royalty_payee_address(),
				get_royalty_points_denominator(),
				get_royalty_points_numerator(),
				get_token_mutability(),
				vector<String>[ utf8(b"key") ],
				vector<vector<u8>>[ b"value" ],
				vector<String>[ utf8(b"0x1::String::string") ],
			);
			i = i + 1;
		};
	}

	#[test_only]
	fun transfer_token_to(
		contract_owner: &signer,
		receiver: &signer,
		token_number: u64,
	) {
		let token_id = get_latest_token_id(
			signer::address_of(contract_owner),
			get_collection_name(),
			get_token_name(token_number),
		);
		token::direct_transfer(contract_owner, receiver, token_id, 1);
	}

	#[test_only] fun get_start_time_seconds(): u64 { 1000000 }
	#[test_only] fun get_start_time_milliseconds(): u64 { get_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_start_time_microseconds(): u64 { get_start_time_seconds() * MICRO_CONVERSION_FACTOR }

	#[test_only] fun get_collection_name(): String { use std::string::utf8; utf8(b"collection name") }
	#[test_only] fun get_description(): String { use std::string::utf8; utf8(b"collection description") }
	#[test_only] fun get_uri(): String { use std::string::utf8; utf8(b"https://aptos.dev") }
	#[test_only] fun get_collection_supply(): u64 { 10000 }

	#[test_only] fun get_token_base(): String { std::string::utf8(b"Non-Fungible Token #") }

	#[test_only] fun get_token_name(n: u64): String {
		let s: String = get_token_base();
		std::string::append(&mut s, pond::bash_colors::u64_to_string(n));
		s
	}

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
	#[test_only] fun get_royalty_payee_address(): 		address { @pond }
	#[test_only] fun get_royalty_points_denominator(): u64 { 1000 }
	#[test_only] fun get_royalty_points_numerator(): 	u64 { 100 }
	#[test_only] fun get_default_num_tokens(): 			u64 { 10 }
	#[test_only] fun get_default_period_duration(): 	u64 { ONE_DAY }
	#[test_only] fun get_default_lockup_periods(): 		u64 { 1 }
	#[test_only] fun get_default_reward(): 				u64 { 100 }

}
