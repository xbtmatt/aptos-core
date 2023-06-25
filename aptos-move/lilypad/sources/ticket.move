module pond::ticket {
	use aptos_framework::coin::{Self};
	use aptos_framework::managed_coin::{Self};
   use aptos_framework::account::{Self, SignerCapability};
   use aptos_framework::event::{Self, EventHandle};
   use std::signer;
	use std::string::{Self};
	use aptos_std::type_info::{Self, TypeInfo};
	use aptos_std::table::{Self, Table};
   //use aptos_framework::timestamp;
	//use pond::steak::{FlyCoin};


	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	const U64_MAX: u64 = 18446744073709551615;

	const TICKET_FLY_COST: u64 = 100;

	const												  SIGNER_IS_NOT_CONTRACT_OWNER: u64 =  0;	/*  0x0 */
	const											BUYER_NOT_REGISTERED_WITH_FLYCOIN: u64 =  1;	/*  0x1 */
	const											BUYER_DOES_NOT_HAVE_ENOUGH_FLY: u64 =  2;	/*  0x2 */
	const											BUYER_DID_NOT_PAY: u64 =  3;	/*  0x3 */
	const											POND_DID_NOT_RECEIVE_FLY: u64 =  4;	/*  0x4 */
	const											AMOUNT_LESS_THAN_ONE: u64 =  5;	/*  0x5 */
	const	  										TEST_BASIC_PURCHASE_FAIL: u64 =  6;	/*  0x6 */
	const											USER_NOT_REGISTERED_WITH_FLYCOIN7: u64 =  7;	/*  0x7 */
	const											USER_NOT_REGISTERED_WITH_FLYCOIN8: u64 =  8;	/*  0x8 */
	const											USER_NOT_REGISTERED_WITH_FLYCOIN9: u64 =  9;	/*  0x9 */


	struct TicketResourceSigner has key {
		resource_signer_cap: SignerCapability,
	}

	struct TicketData has key {
		ticket_purchase_events: EventHandle<TicketPurchaseEvent>,
		current_tickets_total: u64,
	}

	// owned per user, each index represents the current raffle_number
	struct UserData<phantom CoinType> has key {
		ticket_table: Table<u64, u64>,
	}

	struct TicketPurchaseEvent has drop, store {
		buyer: address,
		amount: u64,
		raffle_number: u64,
		coin_type_info: TypeInfo,
	}

	struct RaffleConfiguration<phantom CoinType> has key {
		raffle_number: u64,
		price: u64,
	}

///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////       OWNER INITIALIZATION       ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///
   fun init_module(
		contract_owner: &signer,
	) {
		assert!(signer::address_of(contract_owner) == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);

		let seed_string = string::utf8(b"raffle_ticket");
		let seed = *string::bytes(&seed_string);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(contract_owner, copy seed);
		let resource_address = signer::address_of(&resource_signer);

		assert!(&resource_address == &account::get_signer_capability_address(&resource_signer_cap), 0);
		assert!(&resource_signer == &account::create_signer_with_capability(&resource_signer_cap), 0);

		move_to(
			contract_owner,
			TicketResourceSigner {
					resource_signer_cap: resource_signer_cap,
				}
		);

		move_to(
			&resource_signer,
			TicketData {
				ticket_purchase_events: account::new_event_handle<TicketPurchaseEvent>(&resource_signer),
				current_tickets_total: 0,
			}
		);


	}

	public entry fun initialize<CoinType>(
		contract_owner: &signer,
	) acquires TicketResourceSigner {
		assert!(signer::address_of(contract_owner) == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);
		let (resource_signer, _) = safe_get_resource_signer_and_addr(contract_owner);

		move_to(
			&resource_signer,
			RaffleConfiguration<CoinType> {
				raffle_number: 0,
				price: TICKET_FLY_COST,
			}
		);
	}

	public entry fun create_new_default_raffle<CoinType>(
		contract_owner: &signer,
	) acquires TicketData, RaffleConfiguration, TicketResourceSigner {
		create_new_raffle<CoinType>(contract_owner, TICKET_FLY_COST);
	}

	// remove current ticket data
	// and increment the raffle number
	// ticket data is indexed to each user's account so that it's always available on-chain, even when new raffle starts
	public entry fun create_new_raffle<CoinType>(
		contract_owner: &signer,
		price: u64,
	) acquires TicketData, RaffleConfiguration, TicketResourceSigner {
		assert!(signer::address_of(contract_owner) == @pond, SIGNER_IS_NOT_CONTRACT_OWNER);
		let (_, resource_address) = safe_get_resource_signer_and_addr(contract_owner);

		let ticket_data = borrow_global_mut<TicketData>(resource_address);
		ticket_data.current_tickets_total = 0;

		let raffle_configuration = borrow_global_mut<RaffleConfiguration<CoinType>>(resource_address);
		raffle_configuration.raffle_number = raffle_configuration.raffle_number + 1;
		raffle_configuration.price = price;
	}


	public entry fun purchase_tickets<CoinType>(
		buyer: &signer,
		amount: u64,
	) acquires TicketData, RaffleConfiguration, TicketResourceSigner, UserData {
		assert!(amount >= 1, AMOUNT_LESS_THAN_ONE);

		let (_, resource_address) = internal_get_resource_signer_and_addr(@pond);
		let raffle_configuration = borrow_global<RaffleConfiguration<CoinType>>(resource_address);
		let price = raffle_configuration.price;
		let raffle_number = raffle_configuration.raffle_number;

		let buyer_address = signer::address_of(buyer);

		assert!(coin::is_account_registered<CoinType>(buyer_address), BUYER_NOT_REGISTERED_WITH_FLYCOIN);
		let buyer_pre_balance = coin::balance<CoinType>(buyer_address);
		let coin_to_pay = amount * price;
		assert!(buyer_pre_balance >= coin_to_pay, BUYER_DOES_NOT_HAVE_ENOUGH_FLY);

		let pond_pre_balance = coin::balance<CoinType>(@pond);
		// transfer fly from user to steak? account or some default account to hold the flycoin
		coin::transfer<CoinType>(buyer, @pond, coin_to_pay);
		assert!(buyer_pre_balance - coin::balance<CoinType>(buyer_address) == coin_to_pay, BUYER_DID_NOT_PAY);
		assert!(coin::balance<CoinType>(@pond) - coin_to_pay == pond_pre_balance, POND_DID_NOT_RECEIVE_FLY);

		let ticket_data = borrow_global_mut<TicketData>(resource_address);
		ticket_data.current_tickets_total = ticket_data.current_tickets_total + amount;

		let ticket_purchase_events = &mut ticket_data.ticket_purchase_events;
		event::emit_event<TicketPurchaseEvent>(
			ticket_purchase_events,
			TicketPurchaseEvent {
				buyer: buyer_address,
				amount: amount,
				raffle_number: raffle_number,
				coin_type_info: type_info::type_of<CoinType>(),
			},
		);

		update_user_data<CoinType>(buyer, buyer_address, amount, raffle_number);
	}

	fun update_user_data<CoinType>(
		buyer: &signer,
		buyer_address: address,
		amount: u64,
		raffle_number: u64,
	) acquires UserData {
		if (!exists<UserData<CoinType>>(buyer_address)) {
			move_to(
				buyer,
				UserData<CoinType> {
					ticket_table: table::new<u64, u64>(),
				}
			);
		};
		let user_data = borrow_global_mut<UserData<CoinType>>(buyer_address);
		let ticket_table = &mut user_data.ticket_table;

		if (!table::contains(ticket_table, raffle_number)) {
			table::add(ticket_table, raffle_number, amount);
		} else {
			let ticket_table_data = table::borrow_mut(ticket_table, raffle_number);
			*ticket_table_data = *ticket_table_data + amount;
		};
	}

	fun internal_get_resource_signer_and_addr(
		owner_addr: address,
	): (signer, address) acquires TicketResourceSigner {
		let resource_signer_cap = &borrow_global<TicketResourceSigner>(owner_addr).resource_signer_cap;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_address = signer::address_of(&resource_signer);

		(resource_signer, resource_address)
	}

	fun safe_get_resource_signer_and_addr(
		deployer: &signer,
	): (signer, address) acquires TicketResourceSigner {
		internal_get_resource_signer_and_addr(signer::address_of(deployer))
	}

   fun safe_register_user_for_coin<CoinType>(
		user: &signer,
	) {
		let user_address = signer::address_of(user);
		if (!coin::is_account_registered<CoinType>(user_address)) {
			managed_coin::register<CoinType>(user);
		};
	}


///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////       USER ENTRY FUNCTIONS       ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////
///////////////////////////////////////                                  ////////////////////////////////////////


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

	#[test(owner = @pond, buyer = @0xAAAA, bank = @0x1)]
	fun test_ticket_basic_purchase(
		owner: &signer,
		buyer: &signer,
		bank: &signer,
	) acquires TicketData, RaffleConfiguration, TicketResourceSigner, UserData {
		let bank_address = signer::address_of(bank);
		let _owner_address = signer::address_of(owner);
		let buyer_address = signer::address_of(buyer);

		account::create_account_for_test(bank_address);

		register_acc_and_fill(owner, bank);
		register_acc_and_fill(buyer, bank);

		safe_register_user_for_coin<coin::FakeMoney>(owner);
		safe_register_user_for_coin<coin::FakeMoney>(buyer);

		init_module(owner);
		initialize<coin::FakeMoney>(owner);

		create_new_default_raffle<coin::FakeMoney>(owner);

		print_key_value_as_string(b"pre purchase coin amount: ", u64_to_string(coin::balance<coin::FakeMoney>(buyer_address)));

		let num_tickets = 71;
		purchase_tickets<coin::FakeMoney>(buyer, num_tickets);

		let (_, resource_address) = safe_get_resource_signer_and_addr(owner);

		let user_data = borrow_global<UserData<coin::FakeMoney>>(buyer_address);
		let ticket_table = &user_data.ticket_table;
		let raffle_configuration = borrow_global<RaffleConfiguration<coin::FakeMoney>>(resource_address);
		let tickets = *table::borrow(ticket_table, raffle_configuration.raffle_number);
		print_key_value_as_string(b"tickets purchased: ", u64_to_string(tickets));
		print_key_value_as_string(b"post purchase coin amount: ", u64_to_string(coin::balance<coin::FakeMoney>(buyer_address)));
		assert!(tickets == num_tickets, TEST_BASIC_PURCHASE_FAIL);
	}

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

	#[test_only] fun get_default_entry_cost(): 				u64 { 100 }

}
