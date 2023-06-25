module pond::utils {

	use std::string::{String};
	use std::vector::{Self};
	use aptos_token::token::{Self, TokenId};

   public fun u64_to_string(value: u64): String {
		if (value == 0) {
			return std::string::utf8(b"0")
		};
		let buffer = vector::empty<u8>();
		while (value != 0) {
			vector::push_back(&mut buffer, ((48 + value % 10) as u8));
			value = value / 10;
		};
		vector::reverse(&mut buffer);
		std::string::utf8(buffer)
	}

	public fun append_u64_to_string(
		base: String,
		number: u64,
	): String {
		std::string::append(&mut base, u64_to_string(number));
		base
	}

	#[test_only]
	public fun get_last_minted_token_name(
		creator_address: address,
	): String {
		let supply = *std::option::borrow(&token::get_collection_supply(creator_address, test_get_collection_name())) - 1;
		pond::bash_colors::join(
			vector<String> [
				test_get_token_name_base(),
				u64_to_string(supply),
			],
			std::string::utf8(b""),
		)
	}

	#[test_only]
	public fun get_last_minted_token_id(
		creator_address: address,
	): (String, TokenId) {
		let token_name = get_last_minted_token_name(creator_address);
		let token_id = token::create_token_id_raw(
			creator_address,
			test_get_collection_name(),
			token_name,
			0
		);
		(token_name, token_id)
	}

	#[test_only]
	public fun get_last_minted_token_uri(
		creator_address: address,
	): String {
		let (_, token_id) = get_last_minted_token_id(creator_address);
		token::get_tokendata_uri(creator_address, token::get_tokendata_id(token_id))
	}

	#[test_only] public fun test_get_token_name(n: u64): String { append_u64_to_string(std::string::utf8(b"Token #"), n) }
	#[test_only] public fun test_get_token_uri(n: u64): String { append_u64_to_string(std::string::utf8(b"https://arweave.net/uri_number_"), n) }

	#[test_only] public fun test_get_token_name_base(): String { std::string::utf8(b"Token #") }
	#[test_only] public fun test_get_token_description(): String { std::string::utf8(b"Token #") }
	#[test_only] public fun test_get_token_uri_base(): String { std::string::utf8(b"https://arweave.net/") }
	#[test_only] public fun test_get_token_mutability_config(): vector<bool> { vector<bool> [true, true, true, true, true] }
	#[test_only] public fun test_get_royalty_payee_address(): address { @test_royalty }
	#[test_only] public fun test_get_royalty_points_denominator(): u64 { 100 }
	#[test_only] public fun test_get_royalty_points_numerator(): u64 { 5 }
	#[test_only] public fun test_get_max_rerolls_per_mint(): u64 { 5 }
	#[test_only] public fun test_get_reroll_cost(): u64 { 1000 }
	#[test_only] public fun test_get_intended_pool_size(): u64 { 50000 }
	#[test_only] public fun test_get_smallest_possible_pool_size(): u64 { test_get_collection_maximum() + 1 }
	#[test_only] public fun test_get_2x_collection_size(): u64 { test_get_collection_maximum() * 2 }
	#[test_only] public fun test_get_treasury_address(): address { @test_treasury }
	#[test_only] public fun test_get_global_end_time(): u64 { TEST_GLOBAL_END_TIME_SECONDS }
	#[test_only] public fun test_get_global_end_time_ms(): u64 { TEST_GLOBAL_END_TIME_MILLISECONDS }
	#[test_only] public fun test_get_global_end_time_us(): u64 { TEST_GLOBAL_END_TIME_MICROSECONDS }
	#[test_only] public fun test_get_launch_time(): u64 { TEST_LAUNCH_TIME_SECONDS }
	#[test_only] public fun test_get_launch_time_ms(): u64 { TEST_LAUNCH_TIME_MILLISECONDS }
	#[test_only] public fun test_get_launch_time_us(): u64 { TEST_LAUNCH_TIME_MICROSECONDS }
	#[test_only] public fun test_get_end_time(): u64 { TEST_END_TIME_SECONDS }
	#[test_only] public fun test_get_end_time_ms(): u64 { TEST_END_TIME_MILLISECONDS }
	#[test_only] public fun test_get_end_time_us(): u64 { TEST_END_TIME_MICROSECONDS }
	//#[test_only] public fun test_get_max_mints_per_user(): u64 { 5 }
	#[test_only] public fun test_get_mint_price(): u64 { 5000 }


	#[test_only] const TEST_LAUNCH_TIME_SECONDS: u64 = 946684800;
	#[test_only] const TEST_LAUNCH_TIME_MILLISECONDS: u64 = 946684800 * 1000;
	#[test_only] const TEST_LAUNCH_TIME_MICROSECONDS: u64 = 946684800 * 1000000;
	#[test_only] const TEST_GLOBAL_END_TIME_SECONDS: u64 = 1675728000;
	#[test_only] const TEST_GLOBAL_END_TIME_MILLISECONDS: u64 = 1675728000 * 1000;
	#[test_only] const TEST_GLOBAL_END_TIME_MICROSECONDS: u64 = 1675728000 * 1000000;
	#[test_only] const TEST_END_TIME_SECONDS: u64 = 946688400;
	#[test_only] const TEST_END_TIME_MILLISECONDS: u64 = 946688400 * 1000;
	#[test_only] const TEST_END_TIME_MICROSECONDS: u64 = 946688400 * 1000000;

	#[test_only] public fun test_get_collection_name(): String { std::string::utf8(b"Collection") }
	#[test_only] public fun test_get_collection_description(): String { std::string::utf8(TEST_COLLECTION_DESCRIPTION) }
	#[test_only] public fun test_get_collection_uri(): String { std::string::utf8(TEST_COLLECTION_URI) }
	#[test_only] public fun test_get_collection_maximum(): u64 { TEST_COLLECTION_MAXIMUM }
	#[test_only] public fun test_get_collection_mutability(): vector<bool> { TEST_COLLECTION_MUTABILITY }

	#[test_only] const TEST_COLLECTION_DESCRIPTION: vector<u8> = b"Collection Description";
	#[test_only] const TEST_COLLECTION_URI: vector<u8> = b"Collection Uri";
	#[test_only] const TEST_COLLECTION_MAXIMUM: u64 = 100;
	#[test_only] const TEST_COLLECTION_MUTABILITY: vector<bool> = vector<bool> [ true, true, true ];

   #[test_only]
	public fun register_coin<CoinType>(
		account: &signer,
	) {
		aptos_framework::coin::register<CoinType>(account);
	}

   #[test_only]
	public fun register_acc_and_fill(
		bank: &signer,
		destination: &signer,
		amount: u64,
	) {
		use std::account;
		use aptos_framework::coin;
		use std::signer;

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
	public fun setup_test_environment(
		resource_signer: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		time: u64,
	) {
		use std::account::{Self};
		use std::coin;
		use std::timestamp;
		use std::signer;
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test_secs(time);
		account::create_account_for_test(signer::address_of(resource_signer));
		account::create_account_for_test(signer::address_of(treasury));
		account::create_account_for_test(signer::address_of(aptos_framework));
		coin::create_fake_money(aptos_framework, aptos_framework, 100000000);
		coin::register<coin::FakeMoney>(resource_signer);
		coin::register<coin::FakeMoney>(treasury);
	}

	/*
  use std::string;
  use std::vector;
  use std::bcs;

  #[test_only]
  use std::debug;

  const EINVALID_INPUT: u64 = 0;

  fun addressToString(input: address): string::String {
    let bytes = bcs::to_bytes<address>(&input);
    let i = 0;
    let result = vector::empty<u8>();
    while (i < vector::length<u8>(&bytes)) {
      vector::append(&mut result, u8toHexStringu8(*vector::borrow<u8>(&bytes, i)));
      i = i + 1;
    };
    string::utf8(result)
  }

  fun u8toHexStringu8(input: u8): vector<u8> {
    let result = vector::empty<u8>();
    vector::push_back(&mut result, u4toHexStringu8(input / 16));
    vector::push_back(&mut result, u4toHexStringu8(input % 16));
    //string::utf8(result)
    result
  }

  fun u4toHexStringu8(input: u8): u8 {
    assert!(input<=15, EINVALID_INPUT);
    if (input<=9) (48 + input) // 0 - 9 => ASCII 48 to 57
    else (55 + input) //10 - 15 => ASCII 65 to 70
  }

  #[test]
  public entry fun test_it() {
    let test_addr = @0x1234567890ABCDEF;
    debug::print<string::String>(&addressToString(test_addr));
  }
  */
}
