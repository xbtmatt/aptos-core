module pond::swap_reveal {

	use pond::lilypad_v2::{friend_get_resource_signer_and_addr, assert_lilypad_exists};

	use pond::big_vector::{Self, BigVector};
	use pond::bucket_table::{Self, BucketTable};
	//use aptos_framework::aptos_coin::AptosCoin;
	use std::option::{Self};
	use std::string::{String, bytes};
	//use aptos_token::property_map::{PropertyMap};
    use std::signer;
   use aptos_framework::timestamp;
	use std::vector;
	use aptos_token::token::{Self};
	use aptos_framework::account::{Self, SignerCapability};



	// we want new collection to be owned by lilypad_v2 to make things easier in the end
	// easier to interface things through there than to try to somehow insert the collection
	// into lilypad/lilypad_v2 afterwards

	// so we will actually call initialize_lilypad from `creator2` so that we have access to
	// the resource_account for it within this module

	// we load the Metadata into the metadata struct by table

	// then we initialize the config for the entangler
	//	where we will assert that the two collections have the same names, are both lilypad_v2 resources
	//	both have the same collection max supply

	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;
	const IS_MAXIMUM_MUTABLE: bool = false;

	const U64_MAX: u64 = 18446744073709551615;

	const COLLECTION_NAME: vector<u8> = b"Kreachers";
	const TOKEN_NAME_BASE: vector<u8> = b"Kreacher #";
	const TOKEN_URI_BASE: vector<u8> = b"https://arweave.net/";
	const TOKEN_DESCRIPTION: vector<u8> = b"A mystic Kreacher known to inhabit the lands of InSilva.";
	const COLLECTION_IMAGE: vector<u8> = b"https://image.com";
	const COLLECTION_MUTABILITY: vector<bool> = vector<bool> [true, true, true];
	const TOKEN_MUTABILITY: vector<bool> = vector<bool> [ false, true, true, true, true ];
	const ROYALTY_ADDRESS: address = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0;
	const TREASURY_ADDRESS: address = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0;
	const ROYALTY_POINTS_DENOMINATOR: u64 = 100;
	const ROYALTY_POINTS_NUMERATOR: u64 = 7;
	const KREACHERS_TOTAL_SUPPLY_ACROSS_BOTH_COLLECTIONS: u64 = 824;

	const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";
	const BURNABLE_BY_OWNER: vector<u8> = b"TOKEN_BURNABLE_BY_OWNER";

	const ASSUMED_MAXIMUM_NOT_ACCURATE: u64 =  0;	/*  0x0 */
	const SWAP_REVEAL_CONFIG_ALREADY_EXISTS: u64 =  1;	/*  0x1 */
	const BASE_COLLECTION_MAXIMUM_NEQ_SUPPLY: u64 =  2;	/*  0x2 */
	const NUM_TOKEN_METADATA_GREATER_THAN_COLLECTION_SUPPLY: u64 =  3;	/*  0x3 */
	const DUPLICATE_TOKEN_URI: u64 =  4;	/*  0x4 */
	const VECTORS_NOT_SAME_LENGTH: u64 =  5;	/*  0x5 */
	const STRINGS_AND_VECTOR_U_EIGHT_NOT_EQUAL: u64 =  6;	/*  0x6 */
	const SWAPPER_DID_NOT_GET_TOKEN: u64 =  7;	/*  0x7 */
	const SWAPPER_DID_NOT_BURN_TOKEN: u64 =  8;	/*  0x8 */
	const SWAP_REVEAL_CONFIG_DOES_NOT_EXIST: u64 =  9;	/*  0x9 */
	const COLLECTION_NAMES_DO_NOT_MATCH: u64 =  10;	/*  0xa */
	const NO_METADATA_LEFT: u64 =  11;	/*  0xb */
	const SWAPPER_DOES_NOT_OWN_TOKEN_TO_BURN: u64 =  12;	/*  0xc */
	const NOT_YET_LAUNCH_TIME: u64 =  13;	/*  0xd */
	const DEPRECATED_FUNCTION: u64 =  14;	/*  0xe */
	const PROP_VECTORS_NOT_SAME_LENGTH: u64 =  15;	/*  0xf */
	const GOT_TO_END_OF_SWAP_FUNCTION: u64 =  16;	/*  0x10 */
	const INVALID_TOKEN_NAME: u64 =  17;	/*  0x11 */
	const TOKEN_NAME_BASE_CANNOT_BE_EMPTY: u64 =  18;	/*  0x12 */
	const PLEASE_TRY_AGAIN: u64 =  19;	/*  0x13 */
	const WRONG_KREACHERS_TOTAL_SUPPLY_ACROSS_BOTH_COLLECTIONS: u64 =  20;	/*  0x14 */
	const SWAP_REVEAL_CONFIG_DOES_NOT_EXIST7: u64 =  21;	/*  0x15 */
	const SWAP_REVEAL_CONFIG_DOES_NOT_EXIST8: u64 =  22;	/*  0x16 */
	const SWAP_REVEAL_CONFIG_DOES_NOT_EXIST9: u64 =  23;	/*  0x17 */
	const SWAP_REVEAL_CONFIG_DOES_NOT_EXIST1: u64 =  24;	/*  0x18 */

	struct NewResourceSigner has key {
		resource_signer_cap: SignerCapability,
	}

	struct SwapRevealConfig has key {
		collection_name: String,
		description: String,
		maximum: u64,
		uri: String,
		collection_mutability: vector<bool>,
		token_name_base: String,						// HARD-CODED
		token_metadata: BigVector<TokenMetadata>,
		token_metadata_keys: vector<String>,		// HARD-CODED
		launch_time: u64,
		deduped_tokens: BucketTable<String, bool>,
	}

	//struct Metadata has key {
		//inner: BigVector<TokenMetadata>,
	//}

   struct TokenMetadata has store, drop {
		token_uri: String,
		property_keys: vector<String>,
		property_values: vector<vector<u8>>,
		//property_types: vector<String>,
	}

	public entry fun update_launch_time(
		owner: &signer,
		launch_time: u64,
	) acquires SwapRevealConfig, NewResourceSigner {
		let owner_address = signer::address_of(owner);
		assert_lilypad_exists(owner_address);
		let (_, new_resource_address) = safe_get_resource_signer_and_addr(owner);
		let swap_reveal_config = borrow_global_mut<SwapRevealConfig>(new_resource_address);
		swap_reveal_config.launch_time = launch_time;
	}

	// this could be a script later idk
	public entry fun initialize_collection_clone(
		owner: &signer,
		collection_name: String,
		collection_description: String,
		collection_uri: String,
		assumed_maximum: u64,
		token_name_base: String,
		_token_metadata_keys: vector<String>,
		launch_time: u64,
	) {
		let owner_address = signer::address_of(owner);
		assert_lilypad_exists(owner_address);

		let (_, og_resource_addr) = friend_get_resource_signer_and_addr(owner_address);

		let maximum = *option::borrow(&token::get_collection_supply(og_resource_addr, collection_name));

		assert!(assumed_maximum == maximum, ASSUMED_MAXIMUM_NOT_ACCURATE);


		let clone_supply = *option::borrow(&token::get_collection_supply(og_resource_addr,	collection_name));
		let clone_description = collection_description;
		let clone_uri = collection_uri;
		let clone_maximum = maximum;
		//let clone_description = token::get_collection_description(og_resource_addr, collection_name);
		//let clone_maximum = token::get_collection_maximum(og_resource_addr, collection_name);
		//let clone_uri = token::get_collection_uri(og_resource_addr,	collection_name);
		let clone_collection_mutability = get_collection_mutability();

		let seed_string = copy collection_name;
		std::string::append_utf8(&mut seed_string, b"::clone");
		let seed = *bytes(&seed_string);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, copy seed);
		let resource_address = signer::address_of(&resource_signer);

		assert!( !exists<NewResourceSigner>(resource_address) &&
					!exists<SwapRevealConfig>(resource_address), SWAP_REVEAL_CONFIG_ALREADY_EXISTS);

		move_to(
			owner,
			NewResourceSigner {
				resource_signer_cap: resource_signer_cap,
			}
		);

		assert!(clone_supply == clone_maximum, BASE_COLLECTION_MAXIMUM_NEQ_SUPPLY);

		assert!(token_name_base != std::string::utf8(b""), TOKEN_NAME_BASE_CANNOT_BE_EMPTY);
		move_to(
			&resource_signer,
			SwapRevealConfig {
				collection_name: collection_name,
				description: clone_description,
				maximum: clone_maximum,
				uri: clone_uri,
				collection_mutability: clone_collection_mutability,
				token_name_base: token_name_base,//std::string::utf8(b""),
				token_metadata: big_vector::empty<TokenMetadata>(128),
				token_metadata_keys: vector<String> [],
				launch_time: launch_time,
				deduped_tokens: bucket_table::new<String, bool>(111),
			}
		);

		token::create_collection(
			&resource_signer,
			collection_name,
			clone_description,
			clone_uri,
			clone_maximum,
			clone_collection_mutability,
		);

		// need to add burn capability to all tokens of that collection first?
		// assert above?

	}

	public entry fun add_metadata(
		owner: &signer,
		//token_names: vector<String>,
		token_uris: vector<String>,
		property_keys: vector<vector<String>>,
		property_values: vector<vector<vector<u8>>>,
		//token_types: vector<String>,
	) acquires NewResourceSigner, SwapRevealConfig {
		//let owner_address = signer::address_of(owner);
		let (_, resource_addr) = safe_get_resource_signer_and_addr(owner);

		let swap_reveal_config = borrow_global_mut<SwapRevealConfig>(resource_addr);

		let metadata_length = big_vector::length(&swap_reveal_config.token_metadata);
		assert!(vector::length(&token_uris) + metadata_length <= swap_reveal_config.maximum,
			NUM_TOKEN_METADATA_GREATER_THAN_COLLECTION_SUPPLY);
		assert!(vector::length(&token_uris) == vector::length(&property_keys) &&
			vector::length(&token_uris) == vector::length(&property_values), VECTORS_NOT_SAME_LENGTH);

		let i = 0;
		while (i < vector::length(&token_uris)) {
			let token_uri = vector::borrow(&token_uris, i);
			assert!(!bucket_table::contains(&swap_reveal_config.deduped_tokens, token_uri), DUPLICATE_TOKEN_URI);
			let property_keys = *vector::borrow(&property_keys, i);
			let property_values = *vector::borrow(&property_values, i);
			assert!(vector::length(&property_keys) == vector::length(&property_values), PROP_VECTORS_NOT_SAME_LENGTH);
			big_vector::push_back(&mut swap_reveal_config.token_metadata, TokenMetadata {
				token_uri: *token_uri,
				property_keys: property_keys,
				property_values: property_values,
			});


			bucket_table::add(&mut swap_reveal_config.deduped_tokens, *token_uri, true);
			//assert!(all keys in property_values[i])

			// //TEST_DEBUG
			// {
			// 	use pond::bash_colors::{Self};
			// 	let collection_index = metadata_length + i;
			// 	let token_name = std::string::utf8(b"Kreacher #");
			// 	std::string::append(&mut token_name, u64_to_string(collection_index));
			// 	bash_colors::print_key_value_as_string(b"token_name: ", token_name);
			// 	bash_colors::print_key_value_as_string(b"token_uri: ", *token_uri);
			// 	//bash_colors::print_key_value_as_string(b"collection_index", bash_colors::u64_to_string(collection_index));
			// };


			i = i + 1;
		};

		//assert burn capability exists on token, if not, add it!
	}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      					FIX FOR EXTRA SUPPLY   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      					FIX FOR EXTRA SUPPLY   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	public entry fun new_swap_token(
		swapper: &signer,
		old_token_name: String,
		new_token_number: u64,
		//collection_name: String,
		owner_address: address,
	) acquires SwapRevealConfig, NewResourceSigner {
		let swapper_address = signer::address_of(swapper);
		let (old_resource_signer, old_resource_address) = friend_get_resource_signer_and_addr(owner_address);
		let (new_resource_signer, new_resource_address) = internal_get_resource_signer_and_addr(owner_address);

		assert!(exists<SwapRevealConfig>(new_resource_address), SWAP_REVEAL_CONFIG_DOES_NOT_EXIST);
		assert_lilypad_exists(owner_address);

		let (launch_time, token_name_base, maximum, collection_name) = {
			let swap_reveal_config = borrow_global<SwapRevealConfig>(new_resource_address);
			//assert!(collection_name == swap_reveal_config.collection_name, COLLECTION_NAMES_DO_NOT_MATCH);
			(swap_reveal_config.launch_time, swap_reveal_config.token_name_base, swap_reveal_config.maximum, swap_reveal_config.collection_name)
		};

		let now = timestamp::now_seconds()*MILLI_CONVERSION_FACTOR;
		// og creator gets free pass to mint whenever
		assert!(now >= launch_time || swapper_address == @0xa8cf1462e4901b4385373f0676cd7aa22cf9ecdb28a5d0924d8aaa56d0d41d1f, NOT_YET_LAUNCH_TIME);

		/*				ENSURE TOKEN NAME IS CORRECT 					 */
		assert!((new_token_number < maximum) && (new_token_number >= 0), INVALID_TOKEN_NAME);

		let old_supply = *option::borrow(&token::get_collection_supply(old_resource_address, collection_name));
		let new_supply = *option::borrow(&token::get_collection_supply(new_resource_address, collection_name));
		// if this is for the kreachers mint, we need to ensure that the token name is correct.
		let token_name_base = if (token_name_base == std::string::utf8(b"")) {
			// let's do a check here to make sure kreachers supply is 824
			if (owner_address == @0xa8cf1462e4901b4385373f0676cd7aa22cf9ecdb28a5d0924d8aaa56d0d41d1f) {
				assert!((old_supply + new_supply) == KREACHERS_TOTAL_SUPPLY_ACROSS_BOTH_COLLECTIONS, WRONG_KREACHERS_TOTAL_SUPPLY_ACROSS_BOTH_COLLECTIONS);
			};
			std::string::utf8(TOKEN_NAME_BASE)
		} else {
			assert!((old_supply + new_supply) == maximum, WRONG_KREACHERS_TOTAL_SUPPLY_ACROSS_BOTH_COLLECTIONS);
			token_name_base
		};

		let new_token_name = token_name_base;
		std::string::append(&mut new_token_name, u64_to_string(new_token_number));

		// redundant check mainly to give the user a more useful error, because this is an expected error
		assert!( ! token::check_tokendata_exists(new_resource_address, collection_name, new_token_name) , PLEASE_TRY_AGAIN);
		/*				ENSURE TOKEN NAME IS CORRECT 					 */

		new_burn_then_swap(
			swapper,
			swapper_address,
			&new_resource_signer,
			new_resource_address,
			&old_resource_signer,
			old_resource_address,
			old_token_name,
			new_token_name,
			collection_name,
			get_royalty_payee_address(),
			get_royalty_points_denominator(),
			get_royalty_points_numerator(),
			now,
		);

	}

	fun new_burn_then_swap(
		swapper: &signer,
		swapper_address: address,
		new_resource_signer: &signer,
		new_resource_address: address,
		old_resource_signer: &signer,
		old_resource_address: address,
		old_token_name: String,
		new_token_name: String,
		collection_name: String,
		royalty_payee_address: address,
		royalty_points_denominator: u64,
		royalty_points_numerator: u64,
		now: u64,
	) acquires SwapRevealConfig {
		let burned_token_data_id = token::create_token_data_id(old_resource_address, collection_name, old_token_name);
		let burned_property_version = token::get_tokendata_largest_property_version(old_resource_address, burned_token_data_id);
		let burned_token_id = token::create_token_id(burned_token_data_id, burned_property_version);
		assert!(token::balance_of(swapper_address, burned_token_id) == 1, SWAPPER_DOES_NOT_OWN_TOKEN_TO_BURN);

		//TEST_DEBUG
		// {
		// 	pond::bash_colors::print_key_value_as_string(b"--------------------------------OLD--------------------------------", old_token_name);
		// 	print_property_map(swapper_address, old_resource_address, collection_name, old_token_name);
		// };

		token::burn_by_creator(
			old_resource_signer,
			swapper_address,
			collection_name,
			old_token_name,
			burned_property_version,
			1,
		);

		let swap_reveal_config = borrow_global_mut<SwapRevealConfig>(new_resource_address);

		//let token_name_base = swap_reveal_config.token_name_base;
		//let token_metadata = &swap_reveal_config.token_metadata;

		assert!(big_vector::length(&swap_reveal_config.token_metadata) > 0, NO_METADATA_LEFT);

		let index = now % big_vector::length(&swap_reveal_config.token_metadata);
		let one_token_metadata = big_vector::swap_remove(&mut swap_reveal_config.token_metadata, index);
		bucket_table::remove(&mut swap_reveal_config.deduped_tokens, &one_token_metadata.token_uri);

		let property_keys = one_token_metadata.property_keys;
		let property_values = one_token_metadata.property_values;

		let property_types = vector<String> [];
		let i = 0;
		while (i < vector::length(&property_keys)) {
			vector::push_back(&mut property_types, std::string::utf8(PROPERTY_MAP_STRING_TYPE));
			i = i + 1;
		};

		token::create_token_script(
			new_resource_signer,
			collection_name,
			new_token_name,
			get_token_description(),
			1,
			1,
			one_token_metadata.token_uri,
			royalty_payee_address,
			royalty_points_denominator,
			royalty_points_numerator,
			get_token_mutability(),
			property_keys,
			property_values,
			property_types,
		);

      let token_id = token::create_token_id_raw(new_resource_address, collection_name, new_token_name, 0);
		token::direct_transfer(new_resource_signer, swapper, token_id, 1);

		assert!(token::balance_of(swapper_address, token_id) == 1, SWAPPER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(swapper_address, burned_token_id) == 0, SWAPPER_DID_NOT_BURN_TOKEN);

//
		//TEST_DEBUG
		{
			use pond::bash_colors::{Self};
//
			//bash_colors::print_key_value_as_string(b"keys length: ", u64_to_string(vector::length(&property_keys)));
			//bash_colors::print_key_value_as_string(b"values length: ", u64_to_string(vector::length(&property_values)));
			//bash_colors::print_key_value_as_string(b"types length: ", u64_to_string(vector::length(&property_types)));
//
			//bash_colors::print_key_value(b"debug?", b"--------------------------------");
			//print_raw_property_map(property_keys, property_values, property_types);
//
			std::debug::print(&signer::address_of(swapper));
			bash_colors::print_key_value_as_string(b"old token name: ", old_token_name);
			bash_colors::print_key_value_as_string(b"new token name: ", new_token_name);
			vector::reverse(&mut property_keys);
			vector::reverse(&mut property_values);
			while (vector::length(&property_keys) >= 1) {
				let k: String 		= vector::pop_back(&mut property_keys);
				let v: vector<u8> = vector::pop_back(&mut property_values);
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
			bash_colors::print_key_value_as_string(b"old token balance: ", bash_colors::u64_to_string(token::balance_of(signer::address_of(swapper), burned_token_id)));
			bash_colors::print_key_value_as_string(b"new token balance: ", bash_colors::u64_to_string(token::balance_of(signer::address_of(swapper), token_id)));

			pond::bash_colors::print_key_value_as_string(b"--------------------------------NEW--------------------------------   ", new_token_name);
			//print_property_map(swapper_address, new_resource_address, collection_name, new_token_name);

			//bash_colors::print_key_value(b"--------------------------------", b"--------------------------------");
		};

	}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								END FIX	   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								END FIX	   				       		 ///////////////////
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
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								END FIX	   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								END FIX	   				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////




	// user calls this function
	public entry fun swap_multiple_tokens(
		_swapper: &signer,
		_token_names: vector<String>,
		_collection_name: String,
		_owner_address: address, // address that owns both collections
	) {
		assert!(false, DEPRECATED_FUNCTION);
	}

	public entry fun swap_token(
		_: &signer,
		__: address,
		___: String,
		____: String,
	) {
		assert!(false, DEPRECATED_FUNCTION);
	}

	fun burn_then_swap(
		_swapper: &signer,
		_swapper_address: address,
		_new_resource_signer: &signer,
		_new_resource_address: address,
		_old_resource_signer: &signer,
		_old_resource_address: address,
		_token_name: String,
		_collection_name: String,
		_royalty_payee_address: address,
		_royalty_points_denominator: u64,
		_royalty_points_numerator: u64,
		_now: u64,
		//property_version: u64,
	) {
		assert!(false, DEPRECATED_FUNCTION);
	}

   fun u64_to_string(value: u64): String {
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

	fun internal_get_resource_signer_and_addr(
		owner_addr: address,
	): (signer, address) acquires NewResourceSigner {
		let resource_signer_cap = &borrow_global<NewResourceSigner>(owner_addr).resource_signer_cap;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_addr = signer::address_of(&resource_signer);
		(resource_signer, resource_addr)
	}

	fun safe_get_resource_signer_and_addr(
		owner: &signer,
	): (signer, address) acquires NewResourceSigner {
		internal_get_resource_signer_and_addr(signer::address_of(owner))
	}

	fun get_collection_mutability(): vector<bool> { COLLECTION_MUTABILITY }
	fun get_token_mutability(): vector<bool> { TOKEN_MUTABILITY }
	fun get_token_description(): String { std::string::utf8(TOKEN_DESCRIPTION) }
	fun get_royalty_payee_address(): address { ROYALTY_ADDRESS }
	fun get_treasury_payee_address(): address { TREASURY_ADDRESS }
	fun get_token_name_base(): String { std::string::utf8(TOKEN_NAME_BASE) }
	fun get_royalty_points_denominator(): u64 { ROYALTY_POINTS_DENOMINATOR }
	fun get_royalty_points_numerator(): u64 { ROYALTY_POINTS_NUMERATOR }

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
	fun print_property_map(
		owner_address: address,
		creator: address,
		collection_name: String,
		token_name: String,
	) {
		use aptos_token::property_map::{Self};
		use std::string::utf8;

		let token_data_id = token::create_token_data_id(
			creator,
			collection_name,
			token_name,
		);
		let property_version = token::get_tokendata_largest_property_version(creator, token_data_id);
		let token_id = token::create_token_id(
			token_data_id,
			property_version,
		);

		let property_map = token::get_property_map(owner_address, token_id);
		let keys = vector<String> [
			utf8(b"property_key_1"),
			utf8(b"property_key_2"),
			utf8(b"property_key_3"),
			utf8(b"background"),
			utf8(b"body"),
			utf8(b"clothing"),
			utf8(b"eyes"),
			utf8(b"mouth"),
			utf8(b"headwear"),
			utf8(b"fly") ];

		vector::reverse(&mut keys);
		while (vector::length(&keys) > 0) {
			let key = vector::pop_back(&mut keys);
			if (property_map::contains_key(&property_map, &key)) {
				//pond::bash_colors::print_key_value(b"key: ", *bytes(&key));
				let value = property_map::read_string(&property_map, &key);
				//std::debug::print(&value);
				let k = copy key;
				std::string::append(&mut k, utf8(b" "));
				pond::bash_colors::print_key_value_as_string(*bytes(&k), value);
			};
		};

		let maximum = token::get_tokendata_maximum(token_data_id);
		let uri = token::get_tokendata_uri(creator, token_data_id);
		let description = token::get_tokendata_description(token_data_id);
		let royalty = token::get_tokendata_royalty(token_data_id);
		let royalty_payee = token::get_royalty_payee(&royalty);
		let royalty_denominator = token::get_royalty_denominator(&royalty);
		let royalty_numerator = token::get_royalty_numerator(&royalty);

		pond::bash_colors::print_key_value_as_string(b"maximum: ", u64_to_string(maximum));
		pond::bash_colors::print_key_value_as_string(b"uri: ", uri);
		pond::bash_colors::print_key_value_as_string(b"description: ", description);

		std::debug::print(&royalty_payee);
		pond::bash_colors::print_key_value_as_string(b"royalty_denominator: ", u64_to_string(royalty_denominator));
		pond::bash_colors::print_key_value_as_string(b"royalty_numerator: ", u64_to_string(royalty_numerator));

	}

	#[test_only]
	fun print_raw_property_map(
		keys: vector<String>,
		values: vector<vector<u8>>,
		types: vector<String>,
	) {
		use aptos_token::property_map::{Self};

		{
			let keys2 = copy keys;
			let values2 = copy values;
			let types2 = copy types;
			vector::reverse(&mut keys2);
			while (vector::length(&keys2) > 0) {
				let key = vector::pop_back(&mut keys2);
				let value = vector::pop_back(&mut values2);
				let type = vector::pop_back(&mut types2);
				pond::bash_colors::print_key_value(b"key: ", *bytes(&key));
				pond::bash_colors::print_key_value(b"value: ", value);
				pond::bash_colors::print_key_value(b"type: ", *bytes(&type));
			};
			pond::bash_colors::print_key_value(b"--------------sdfsfd--------------", b"--------------------------------");
		};

		//use std::string::utf8;
		let test_property_map = property_map::new(keys, values, types);
		vector::reverse(&mut keys);
		while (vector::length(&keys) > 0) {
			let key = vector::pop_back(&mut keys);
			if (property_map::contains_key(&test_property_map, &key)) {
				pond::bash_colors::print_key_value(b"key: ", *bytes(&key));
				let value = property_map::read_string(&test_property_map, &key);
				std::debug::print(&value);
				//pond::bash_colors::print_key_value_as_string(*bytes(&key), value);
			};
		};
	}


	#[test_only]
	fun create_accounts(
		test_accounts: vector<address>,
	) {
		if (!account::exists_at(TREASURY_ADDRESS)) {	account::create_account_for_test(TREASURY_ADDRESS); };
		if (!account::exists_at(ROYALTY_ADDRESS)) {	account::create_account_for_test(ROYALTY_ADDRESS); };

		while (vector::length(&test_accounts) > 0) {
			let test_account = vector::pop_back(&mut test_accounts);
				if (!account::exists_at(test_account)) {
					account::create_account_for_test(test_account);
			};
		}
	}

	#[test_only]
	fun init_test(
		creator: &signer,
		aptos_framework: &signer,
		swapper_1: &signer,
		swapper_2: &signer,
		swapper_3: &signer,
		treasury_account: &signer,
		royalty_account: &signer,
	) {
		use pond::lilypad_v2::{Self};
		use aptos_framework::coin;

		let creator_address = signer::address_of(creator);

		lilypad_v2::register_acc_and_fill(creator, aptos_framework);
		lilypad_v2::register_acc_and_fill(swapper_1, aptos_framework);
		lilypad_v2::register_acc_and_fill(swapper_2, aptos_framework);
		lilypad_v2::register_acc_and_fill(swapper_3, aptos_framework);
		lilypad_v2::register_acc_and_fill(treasury_account, aptos_framework);
		lilypad_v2::register_acc_and_fill(royalty_account, aptos_framework);

		lilypad_v2::initialize_royalty_address_for_aptos_coin(treasury_account);
		lilypad_v2::initialize_royalty_address_for_aptos_coin(royalty_account);

		lilypad_v2::init_lilypad_for_test(creator, aptos_framework, TREASURY_ADDRESS);
		lilypad_v2::create_15_test_entries_in_bulk(creator);

		lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_1, creator_address, get_collection_name(), 1);
		lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_1, creator_address, get_collection_name(), 1);
		lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_1, creator_address, get_collection_name(), 1);
		lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_1, creator_address, get_collection_name(), 1);
		lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_1, creator_address, get_collection_name(), 1);
		if (signer::address_of(swapper_1) != signer::address_of(swapper_2)) {
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_2, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_2, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_2, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_2, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_2, creator_address, get_collection_name(), 1);
		};
		if (signer::address_of(swapper_1) != signer::address_of(swapper_3) && signer::address_of(swapper_2) != signer::address_of(swapper_3)) {
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_3, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_3, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_3, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_3, creator_address, get_collection_name(), 1);
			lilypad_v2::mint<coin::FakeMoney, lilypad_v2::BasicMint>(swapper_3, creator_address, get_collection_name(), 1);
		};
	}


	#[test(creator = @0xFA, swapper_1 = @0x000A, aptos_framework = @0x1, treasury_account = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0, royalty_account = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0)]
	fun test_swaps(
		creator: &signer,
		swapper_1: &signer,
		aptos_framework: &signer,
		treasury_account: &signer,
		royalty_account: &signer,
	//) {
	) acquires NewResourceSigner, SwapRevealConfig {
		timestamp::set_time_has_started_for_testing(aptos_framework);
      timestamp::update_global_time_for_test(get_start_time_microseconds());

		let creator_address = signer::address_of(creator);
		//let swapper_1_address = signer::address_of(swapper_1);
		//let aptos_framework_address = signer::address_of(aptos_framework);

		//create_accounts(vector<address>[ creator_address, swapper_1_address, aptos_framework_address ]);
		init_test(creator, aptos_framework, swapper_1, swapper_1, swapper_1, treasury_account, royalty_account);

		// have minted 5 tokens

		let (_, old_resource_address) = friend_get_resource_signer_and_addr(creator_address);

		let current_supply = get_actual_collection_supply_for_test(old_resource_address, get_collection_name());

		initialize_collection_clone(
			creator,
			get_collection_name(),
			get_collection_description(),
			get_collection_uri(),
			current_supply, // assumed_maximum
			std::string::utf8(TOKEN_NAME_BASE),
			vector<String> [std::string::utf8(b"")],
			get_start_time_milliseconds(),
		);

		// have created collection clone with max supply 5, no mints yet

		// ADD TEST FOR DIFFERENT CURRENT SUPPLY? SHOULD FAIL

		let num_tokens_to_swap = current_supply - 1;

		let i = 0;
		let keys = vector<vector<String>> [];
		let values = vector<vector<vector<u8>>> [];
		let token_names = vector<String> [];
		while (i < num_tokens_to_swap) {
			vector::push_back(&mut keys, get_token_keys());
			vector::push_back(&mut values, get_token_values());
			vector::push_back(&mut token_names, pond::lilypad_v2::get_token_name_with_base(std::string::utf8(TOKEN_NAME_BASE), i));
			i = i + 1;
		};
		vector::reverse(&mut token_names);

		add_metadata(
			creator,
			get_token_uris(num_tokens_to_swap),
			keys,
			values,
		);

		pond::lilypad_v2::make_tokens_burnable(
			creator,
			get_collection_name(),
			token_names,
		);
		let i = 0;
		while (i < num_tokens_to_swap) {
		// ECREATOR_CANNOT_BURN_TOKEN error here if the below isn't run
			new_swap_token(
				swapper_1,
				pond::lilypad_v2::get_token_name_with_base(std::string::utf8(TOKEN_NAME_BASE), i),
				i,
				creator_address
			);
			 i = i + 1;
		};
	}

	#[test_only] fun get_actual_collection_supply_for_test(
		og_resource_addr: address,
		collection_name: String,
	): u64 { *option::borrow(&token::get_collection_supply(og_resource_addr, collection_name)) }

	#[test_only] fun get_start_time_seconds(): u64 { 1000000 }
	#[test_only] fun get_start_time_milliseconds(): u64 { get_start_time_seconds() * MILLI_CONVERSION_FACTOR }
	#[test_only] fun get_start_time_microseconds(): u64 { get_start_time_seconds() * MICRO_CONVERSION_FACTOR }
	#[test_only] fun get_collection_name(): String { std::string::utf8(COLLECTION_NAME) }
	#[test_only] fun get_collection_description(): String { std::string::utf8(b"This is the collection description.") }
	#[test_only] fun get_collection_uri(): String { std::string::utf8(b"This is the collection uri.") }
	#[test_only] fun get_assumed_maximum_for_test(): u64 { 777 }

	#[test_only]
	fun get_token_types(): vector<String> {
		vector<String> [	std::string::utf8(PROPERTY_MAP_STRING_TYPE),
								std::string::utf8(PROPERTY_MAP_STRING_TYPE),
								std::string::utf8(PROPERTY_MAP_STRING_TYPE),
		]
	}

	#[test_only]
	fun get_token_keys(): vector<String> {
		vector<String> [
			std::string::utf8(b"property_key_1"),
			std::string::utf8(b"property_key_2"),
			std::string::utf8(b"property_key_3"),
		]
	}

	#[test_only]
	fun get_token_values(): vector<vector<u8>> {
		vector<vector<u8>> [
			std::bcs::to_bytes<vector<u8>>(&b"property_value_1"),
			std::bcs::to_bytes<vector<u8>>(&b"property_value_2"),
			std::bcs::to_bytes<vector<u8>>(&b"property_value_3"),
		]
	}


	#[test_only] fun get_token_uris(num: u64): vector<String> {
		let token_uris = vector<String> [];
		let i = 0;
		while (i < num) {
			let s = std::string::utf8(b"https://arweave.net/");
			std::string::append(&mut s, std::string::utf8(b"token_"));
			std::string::append(&mut s, u64_to_string(i));
			vector::push_back(&mut token_uris, s);
			i = i + 1;
		};

		token_uris
	}
}
