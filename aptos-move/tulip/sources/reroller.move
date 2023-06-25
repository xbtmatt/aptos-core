module pond::reroller {
	use pond::mint_settings::{Self};

	use std::string::{String, Self};
	use pond::bucket_table::{BucketTable, Self};
	use pond::big_vector::{BigVector, Self};
	use pond::utils;
	use std::option::{Self};
	use std::coin::{Self};
	use std::account::{Self, SignerCapability};
	use std::signer::{Self};
	use std::vector::{Self};
	use aptos_token::token::{Self};
	use aptos_framework::event::{Self, EventHandle};

	use aptos_std::timestamp::{Self};

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								ERROR CODES		  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	const ERESOURCE_SIGNER_ALREADY_EXISTS: u64 =  0;
	const ERESOURCE_SIGNER_DOES_NOT_EXIST: u64 =  1;
	const EREROLL_CONFIG_ALREADY_EXISTS: u64 =  2;
	const EREROLL_CONFIG_DOES_NOT_EXIST: u64 =  3;
	const ECOLLECTION_CONFIG_DOES_NOT_EXIST: u64 =  4;
	const ECOLLECTION_CONFIG_ALREADY_EXISTS: u64 =  5;
	const ETOKEN_METADATA_POOL_DOES_NOT_EXIST: u64 =  6;
	const EDEDUPED_METADATA_POOL_DOES_NOT_EXIST: u64 =  7;
	const ECOLLECTION_MUTABILITY_CONFIG_WRONG_SIZE: u64 =  8;
	const ETOKEN_MUTABILITY_CONFIG_WRONG_SIZE: u64 =  9;
	const ENUMERATOR_GT_DENOMINATOR: u64 = 10;
	const EROYALTY_ADDRESS_DOES_NOT_EXIST: u64 = 11;
	const EROYALTY_ADDRESS_NOT_REGISTERED_FOR_COIN: u64 = 12;
	const EDUPLICATE_KEY: u64 =  13;
	const EPOOL_SIZES_DO_NOT_MATCH: u64 =  14;
	const EPOOL_SIZE_DID_NOT_CHANGE: u64 =  15;
	const EPOOL_SIZE_NOT_LARGE_ENOUGH: u64 = 16;
	const ENO_METADATA_LEFT: u64 = 17;
	const EUSER_DID_NOT_GET_TOKEN: u64 = 18;
	const ETOKEN_BALANCE_GREATER_THAN_ONE: u64 = 19;
	const EURI_SWAP_DID_NOT_WORK: u64 = 20;
	const ENO_REROLLS_LEFT: u64 = 21;
	const ENOT_ENOUGH_COIN: u64 = 22;
	const EUSER_DID_NOT_PAY: u64 = 23;
	const ETREASURY_DID_NOT_GET_PAID: u64 = 24;
	const EREQUESTED_INDEX_OUT_OF_BOUNDS: u64 = 25;
	const EPOOL_SIZE_MUST_BE_LARGER_THAN_COLLECTION_MAXIMUM: u64 = 25;
	const MINTER_DID_NOT_GET_TOKEN: u64 = 26;

	// you need to set this file up so that:
	//		we initialize a Reroller  contract
	//			- creates resource signer that gates all functions listed below
	//				- interface for owner/creator for all `mint_certificate` functions
	//				- public(friend) fun
	//				- initializes reroll stuff. this includes `mint_certificate` initialization
	//				- initializes structs for metadata pool
	//				- functions to add to/remove from metadata gated by owner
	//				- internal function to PLUCK from metadata pool by user
	//				-

	//				we need to initialize reroll by initializing the collection to know its supply.
	//					its supply affects how MintCertificates discern the token_name field,
	//					floating_metadata.length + assigned_metadata.length = TOTAL_INITIAL_METADATA - collection_supply
	//																					ALSO
	//					floating_metadata.length + assigned_metadata.length = collection_maximum - collection_supply

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								CONSTANTS		  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	const TOKEN_BALANCE: u64 = 1;
	const TOKEN_MAXIMUM: u64 = 1;
	const MILLI_CONVERSION_FACTOR: u64 = 1000;
	const MICRO_CONVERSION_FACTOR: u64 = 1000000;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      						   DATA STRUCTURES	  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	struct RerollResourceSigner has key {
		inner: SignerCapability,
	}

	struct RerollConfig has key {
		max_rerolls_per_mint: u64,
		intended_pool_size: u64,		// it's ok if this isn't accurate- it's intended to avoid bucket table creating buckets while adding metadata
		treasury_address: address,
	}

	struct RerollCost<phantom Type> has key {
		inner: u64,
	}

	// only accessed when minting, (probably) not when rerolling
	// deduped_metadata may not need to be
	struct CollectionConfig has key {
		collection_name: String,
		collection_description: String,
		collection_uri: String,
		collection_maximum: u64,
		collection_mutability_config: vector<bool>,
		token_name_base: String,
		token_description: String,
		token_uri_base: String,
		token_mutability_config: vector<bool>,
		royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
	}

	struct RerollerEventStore has key {
		new_certificate_events: EventHandle<NewCertificateEvent>,
		reroll_events: EventHandle<RerollEvent>,
		mint_from_certificate_events: EventHandle<MintFromCertificateEvent>,
	}

	struct NewCertificateEvent has drop, store {
		owner: address,
		creator: address,
		collection_name: String,
		user: address,
		token_uri: String,
	}

	struct RerollEvent has drop, store {
		owner: address,
		creator: address,
		collection_name: String,
		reroller: address,
		old_token_uri: String,
		new_token_uri: String,
	}

	struct MintFromCertificateEvent has drop, store {
		owner: address,
		creator: address,
		collection_name: String,
		token_name: String,
		token_uri: String,
	}

	// user pays for this, this is their `right to mint` and the intent by the resource_signer to mint it (eventually).
	// the user can consume this certificate and the token_metadata inside of it to mint an NFT with its inner token metadata.
	// this MintCertificate can `reroll` the `token_metadata` using the reroll contract functions
	struct MintCertificate has store {
		token_metadata: TokenMetadata,
		rerolls: u64,
	}

	// struct where user holds their MintCertificates
	// 	this is what the user will hold while they're waiting to mint but haven't yet. This removes the MintCertificate
	//		from the pool of metadata while they hold it. However, it can be re-inserted into that pool later, which is why
	//		we ensure TokenMetadata has 0 duplicates and can't be dropped until it's minted (which would mean it can't be reinserted into the pool)
	struct UserMintCertificates has key {
		inner: vector<MintCertificate>,
	}

	// going to mirror the structure of `Token` in token.move
	//		`inner` will be a unique ID based on the Arweave URI generated for the token's metadata
	// these will only be dropped by deconstruction very intentionally when the user mints. We don't need to track the supply of them because
	//		it will be 1 : 1 of the collection supply which is being tracked by token.move
	struct TokenMetadata has store {
		token_uri: String,
	}

	// the bucket table that holds all unique TokenMetadata, intended to hold roughly (~collection.supply * 10) items
	// if `TokenMetadata` is `Token`, then `TokenMetadataPool` is `Collection` in terms of uniqueness. Although we store in a BigVector because we just want random metadata
	struct TokenMetadataPool has key {
		inner: BigVector<TokenMetadata>,
	}

	// I'm pretty this struct is not necessary once the TokenMetadataPool is finalized/immutable. You don't need to
	//  remove from this table like in `minting.move` in `post_mint_reveal_nft` because you wouldn't want your collection to use duplicate token_uris *ever*.
	// 	removing from this table implies that that token_uri would be free to use again, so it's pointless to remove it.
	//			...I think...
	struct DedupedMetadata has key {
		inner: BucketTable<String, bool>,
	}

	// BUCKET_SIZE_NOTE:
	// bucket size determined by load_factor(map) > SPLIT_THRESHOLD where:
	// 	load_factor => map.len * 100 / (map.num_buckets * TARGET_LOAD_PER_BUCKET);
	//			WHERE map.len = bucket table overall length
	//					map.num_buckets = buckets passed in in create function
	//					const TARGET_LOAD_PER_BUCKET = 10;
	//		const SPLIT_THRESHOLD: 75;
	//
	//		thus the formula for finding num_buckets for a collection of items of size N is:
	//			N * 100 / (num_buckets * 10) <= 75
	//			N * 10 / (num_buckets) <= 75
	//			num_buckets >= (N * 10) / 75
	//
	//			thus:
	//			num_buckets >= (items * 10) / 75
	//			num_buckets ~= ((items * 10) / 75) + 1



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      							INITIALIZATION  				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	public entry fun initialize_reroller<Tier, CoinType>(
		owner: &signer,
		collection_name: String,
		collection_description: String,
		collection_uri: String,
		collection_maximum: u64,
		collection_mutability_config: vector<bool>,
		token_name_base: String,
		token_description: String,
		token_uri_base: String,
		token_mutability_config: vector<bool>,
		royalty_payee_address: address,
      royalty_points_denominator: u64,
      royalty_points_numerator: u64,
		max_rerolls_per_mint: u64,
		reroll_cost: u64,
		intended_pool_size: u64,
		treasury_address: address,
		global_end_time_ms: u64,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
		mint_price: u64,
	) {
		let owner_address = signer::address_of(owner);
		assert!(!exists<RerollResourceSigner>(owner_address), ERESOURCE_SIGNER_ALREADY_EXISTS);
		assert!(intended_pool_size > collection_maximum, EPOOL_SIZE_MUST_BE_LARGER_THAN_COLLECTION_MAXIMUM);

		let seed_string = collection_name;
		string::append_utf8(&mut seed_string, b"::reroller");
		let seed = *string::bytes(&seed_string);
		let (resource_signer, resource_signer_cap) = account::create_resource_account(owner, seed);
		let resource_address = signer::address_of(&resource_signer);

		assert!(!exists<RerollConfig>(resource_address), EREROLL_CONFIG_ALREADY_EXISTS);
		assert!(!exists<CollectionConfig>(resource_address), ECOLLECTION_CONFIG_ALREADY_EXISTS);
		assert!(vector::length(&collection_mutability_config) == 3, ECOLLECTION_MUTABILITY_CONFIG_WRONG_SIZE);
		assert!(vector::length(&token_mutability_config) == 5, ETOKEN_MUTABILITY_CONFIG_WRONG_SIZE);

		move_to(
			owner,
			RerollResourceSigner {
				inner: resource_signer_cap,
			}
		);

		move_to(
			&resource_signer,
			CollectionConfig {
				collection_name: collection_name,
				collection_description: collection_description,
				collection_uri: collection_uri,
				collection_maximum: collection_maximum,
				collection_mutability_config: collection_mutability_config,
				token_name_base: token_name_base,
				token_description: token_description,
				token_uri_base: token_uri_base,
				token_mutability_config: token_mutability_config,
				royalty_payee_address: royalty_payee_address,
				royalty_points_denominator: royalty_points_denominator,
				royalty_points_numerator: royalty_points_numerator,
			}
		);

		move_to(
			&resource_signer,
			RerollConfig {
				max_rerolls_per_mint: max_rerolls_per_mint,
				intended_pool_size: intended_pool_size,
				treasury_address: treasury_address,
			}
		);

		move_to(
			&resource_signer,
			RerollCost<CoinType> {
				inner: reroll_cost,
			}
		);

		mint_settings::initialize_all<Tier, CoinType>(
			&resource_signer,
			treasury_address,
			global_end_time_ms,
			launch_time_ms,
			end_time_ms,
			max_mints_per_user,
			mint_price,
		);

		// see BUCKET_SIZE_NOTE
		let num_buckets = ((intended_pool_size * 10) / 75) + 1;
		move_to(
			&resource_signer,
			TokenMetadataPool {
				inner: big_vector::empty<TokenMetadata>(256),
			}
		);

		move_to(
			&resource_signer,
			DedupedMetadata {
				inner: bucket_table::new<String, bool>(num_buckets),
			}
		);
	}

	// creates the collection with CollectionConfig settings, runs checks on collection_maximum vs TokenMetadataPool size
	public entry fun initialize_collection(
		owner: &signer,
	) acquires RerollResourceSigner, CollectionConfig, TokenMetadataPool, DedupedMetadata {
		let (resource_signer, resource_address) = safe_get_resource_signer_and_addr(owner);
		let collection_config = borrow_global<CollectionConfig>(resource_address);

		token::create_collection_script(
			&resource_signer,
			collection_config.collection_name,
			collection_config.collection_description,
			collection_config.collection_uri,
			collection_config.collection_maximum,
			collection_config.collection_mutability_config,
		);

		assert!(exists<TokenMetadataPool>(resource_address), ETOKEN_METADATA_POOL_DOES_NOT_EXIST);
		assert!(exists<DedupedMetadata>(resource_address), EDEDUPED_METADATA_POOL_DOES_NOT_EXIST);
		let token_metadata_pool = borrow_global<TokenMetadataPool>(resource_address);
		let deduped_metadata = borrow_global<DedupedMetadata>(resource_address);
		assert!(big_vector::length(&token_metadata_pool.inner) == bucket_table::length(&deduped_metadata.inner), EPOOL_SIZES_DO_NOT_MATCH);
		assert!(big_vector::length(&token_metadata_pool.inner) > collection_config.collection_maximum, EPOOL_SIZE_NOT_LARGE_ENOUGH);
	}

	public entry fun add_metadata_to_pool(
		owner: &signer,
		token_uris: vector<String>,
	) acquires RerollResourceSigner, TokenMetadataPool, DedupedMetadata {
		let (_, resource_address) = safe_get_resource_signer_and_addr(owner);
		assert!(exists<TokenMetadataPool>(resource_address), ETOKEN_METADATA_POOL_DOES_NOT_EXIST);
		assert!(exists<DedupedMetadata>(resource_address), EDEDUPED_METADATA_POOL_DOES_NOT_EXIST);
		let token_metadata_pool = borrow_global_mut<TokenMetadataPool>(resource_address);
		let deduped_metadata = borrow_global_mut<DedupedMetadata>(resource_address);

		//vector::reverse(&mut token_uris); //really not necessary, can do in typescript/other move call
		let i = vector::length(&token_uris);
		let token_uris_length = i;
		let initial_pool_size = big_vector::length(&token_metadata_pool.inner);
		while(i > 0) {
			//assert!(!bucket_table::contains(&deduped_metadata.inner, token_uri), EDUPLICATE_KEY);
			let token_uri = vector::pop_back(&mut token_uris);
			big_vector::push_back(&mut token_metadata_pool.inner, TokenMetadata {
				token_uri: token_uri,
			});
			bucket_table::add(&mut deduped_metadata.inner, token_uri, true);
			i = i - 1;
		};
		let final_pool_size = big_vector::length(&token_metadata_pool.inner);
		let final_deduped_size = bucket_table::length(&deduped_metadata.inner);
		assert!(final_pool_size == final_deduped_size, EPOOL_SIZES_DO_NOT_MATCH);
		assert!(initial_pool_size + token_uris_length == final_pool_size, EPOOL_SIZE_DID_NOT_CHANGE);
	}

	public entry fun purchase_mint_certificate<Tier, CoinType>(
		user: &signer,
		owner_address: address,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig {
		let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(owner_address);
		let user_address = signer::address_of(user);

		// user sends coin to treasury, launch_time < now < end_time, user is in <Tier>, user has mints left
		mint_settings::purchase_one<Tier, CoinType>(&resource_signer, user);

		// ///////////////////////////////////////////////////////////////
		//						PULL TOKEN METADATA FROM POOL
		// ///////////////////////////////////////////////////////////////
		let token_metadata = internal_get_random_metadata_from_pool(resource_address);
		let token_uri = token_metadata.token_uri;

		// ///////////////////////////////////////////////////////////////
		//				CREATE MINT CERTIFICATE FROM TOKEN METADATA
		// ///////////////////////////////////////////////////////////////
		possibly_initialize_user_mint_certificates(user);

		let user_mint_certificates = borrow_global_mut<UserMintCertificates>(user_address);
		vector::push_back(&mut user_mint_certificates.inner, MintCertificate {
			token_metadata: token_metadata,
			rerolls: 0,
		});

		// //////////////////////////////////////////
		//			  EMIT NEW CERTIFICATE EVENT
		// //////////////////////////////////////////
		possibly_initialize_event_store(user);
		let reroller_event_store = borrow_global_mut<RerollerEventStore>(user_address);
		event::emit_event<NewCertificateEvent>(
			&mut reroller_event_store.new_certificate_events,
			NewCertificateEvent {
				owner: owner_address,
				creator: resource_address,
				collection_name: borrow_global<CollectionConfig>(resource_address).collection_name,
				user: user_address,
				token_uri: token_uri,
			},
		);
	}

	// the issue right now is that you can't just swap the things
	// you'd have to use option::extract I think like how david does in hero.move
	// 	could probably just alter the value in inner, and ONLY ever do that in a specific function where you swap token_uris

	public entry fun reroll<CoinType>(
		user: &signer,
		owner_address: address,
		requested_index: u64,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig, RerollConfig, RerollCost {
		let (_, resource_address) = internal_get_resource_signer_and_addr(owner_address);
		let user_address = signer::address_of(user);

		//////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////
		// 		TODO: gate this action by time somehow
		//////////////////////////////////////////////////////////
		//////////////////////////////////////////////////////////

		let user_mint_certificates = borrow_global_mut<UserMintCertificates>(user_address);
		assert!(requested_index < vector::length(&user_mint_certificates.inner), EREQUESTED_INDEX_OUT_OF_BOUNDS);
		let mint_certificate = vector::borrow_mut(&mut user_mint_certificates.inner, requested_index);

		// ///////////////////////////////////////////////////////////////////////////////
		//			MUTATE USER AND POOL TOKEN METADATA BY SWAPPING THEIR TOKEN URIS
		// ///////////////////////////////////////////////////////////////////////////////
		// pull the new value first, that way there's a 0% chance the user incidentally gets the metadata they just rerolled
		let (old_token_uri, new_token_uri) = internal_swap_uris_with_random_index_in_pool(
			&mut mint_certificate.token_metadata,
			resource_address,
			*&mint_certificate.rerolls + requested_index,
		);

		// ///////////////////////////////////////////////////////////////////////////////
		//					ENSURE USER PAYS AND THAT THEY HAVE REROLLS LEFT
		// ///////////////////////////////////////////////////////////////////////////////
		let reroll_config = borrow_global<RerollConfig>(resource_address);
		let reroll_cost = borrow_global<RerollCost<CoinType>>(resource_address).inner;
		let max_rerolls_per_mint = reroll_config.max_rerolls_per_mint;
		let treasury_address = reroll_config.treasury_address;

		let rerolls = &mut mint_certificate.rerolls;
		*rerolls = *rerolls + 1;
		assert!(*rerolls <= max_rerolls_per_mint, ENO_REROLLS_LEFT);

		assert!(coin::balance<CoinType>(user_address) >= reroll_cost, ENOT_ENOUGH_COIN);
		let pre_reroll_balance_user = coin::balance<CoinType>(user_address);
		let pre_reroll_balance_treasury = coin::balance<CoinType>(treasury_address);
		coin::transfer<CoinType>(user, treasury_address, reroll_cost);
		assert!(coin::balance<CoinType>(user_address) == (pre_reroll_balance_user - (reroll_cost)), EUSER_DID_NOT_PAY);
		assert!(coin::balance<CoinType>(treasury_address) == (pre_reroll_balance_treasury + (reroll_cost)), ETREASURY_DID_NOT_GET_PAID);
		// ///////////////////////////////////////////////////////////////////////////////
		//			MUTATE USER AND POOL TOKEN METADATA BY SWAPPING THEIR TOKEN URIS
		// ///////////////////////////////////////////////////////////////////////////////

		// //////////////////////////////////////////
		//					EMIT REROLL EVENT
		// //////////////////////////////////////////
		possibly_initialize_event_store(user);
		let reroller_event_store = borrow_global_mut<RerollerEventStore>(user_address);
		event::emit_event<RerollEvent>(
			&mut reroller_event_store.reroll_events,
			RerollEvent {
				owner: owner_address,
				creator: resource_address,
				collection_name: borrow_global<CollectionConfig>(resource_address).collection_name,
				reroller: user_address,
				old_token_uri: old_token_uri,
				new_token_uri: new_token_uri,
			},
		);
	}

	public entry fun mint_with_certificate(
		user: &signer,
		owner_address: address,
		index: u64,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, CollectionConfig {
		let (resource_signer, resource_address) = internal_get_resource_signer_and_addr(owner_address);
		let user_address = signer::address_of(user);

		// ///////////////////////////////////////////////////////////////////
		//		 			GET STATIC COLLECTION CONFIG METADATA
		// ///////////////////////////////////////////////////////////////////
		let collection_config = borrow_global<CollectionConfig>(resource_address);
		let collection_name = collection_config.collection_name;
		//let collection_maximum = collection_config.collection_maximum;
		let token_name = collection_config.token_name_base;

		let collection_supply = *option::borrow(&token::get_collection_supply(resource_address, collection_name));
		string::append(&mut token_name, utils::u64_to_string(collection_supply));

		// ///////////////////////////////////////////////////////////////////
		//		 	MINT TOKEN FROM METADATA IN MINT CERTIFICATE AT index
		// ///////////////////////////////////////////////////////////////////

		let user_mint_certificates = borrow_global_mut<UserMintCertificates>(user_address);

		let mint_certificate = vector::remove(&mut user_mint_certificates.inner, index);

		let token_uri = mint_certificate.token_metadata.token_uri;
		destroy_mint_certificate(mint_certificate);
		// this is normally where we removed the token_uri from the bucket_table but we don't intend on
		//		ever creating another token with that uri again, so we won't

		token::create_token_script(
			&resource_signer,
			collection_name,
			token_name,
			collection_config.token_description,
			TOKEN_BALANCE,
			TOKEN_MAXIMUM,
			token_uri,
			collection_config.royalty_payee_address,
			collection_config.royalty_points_denominator,
			collection_config.royalty_points_numerator,
			collection_config.token_mutability_config,
			vector<String> [],
			vector<vector<u8>> [],
			vector<String> [],
		);

		// ////////////////////////////////////////////////////
		//		 			TRANSFER TOKEN TO USER
		// ////////////////////////////////////////////////////
      let token_id = token::create_token_id_raw(resource_address, collection_name, token_name, 0);
		token::direct_transfer(&resource_signer, user, token_id, TOKEN_BALANCE);

		assert!(token::balance_of(user_address, token_id) == TOKEN_BALANCE, EUSER_DID_NOT_GET_TOKEN);
		assert!(token::balance_of(resource_address, token_id) == 0, ETOKEN_BALANCE_GREATER_THAN_ONE);

		// //////////////////////////////////////////
		//					EMIT REROLL EVENT
		// //////////////////////////////////////////
		possibly_initialize_event_store(user);
		let reroller_event_store = borrow_global_mut<RerollerEventStore>(user_address);
		event::emit_event<MintFromCertificateEvent>(
			&mut reroller_event_store.mint_from_certificate_events,
			MintFromCertificateEvent {
				owner: owner_address,
				creator: resource_address,
				collection_name: collection_name,
				token_name: token_name,
				token_uri: token_uri,
			},
		);

		//assert!(certificate_mints + 1 <= collection_maximum, ESUPPLY_CANNOT_EXCEED_MAXIMUM);
	}

	// Permanently destroy this certificate and remove this metadata from the pool.
	fun destroy_mint_certificate(mint_certificate: MintCertificate) {
		let MintCertificate {
			token_metadata: TokenMetadata {
				token_uri: _,
			},
			rerolls: _
		} = mint_certificate;
	}

	fun possibly_initialize_event_store(user: &signer) {
		if (!exists<RerollerEventStore>(signer::address_of(user))) {
			move_to(
				user,
				RerollerEventStore {
					new_certificate_events: account::new_event_handle<NewCertificateEvent>(user),
					reroll_events: account::new_event_handle<RerollEvent>(user),
					mint_from_certificate_events: account::new_event_handle<MintFromCertificateEvent>(user),
				},
			);
		};
	}

	fun possibly_initialize_user_mint_certificates(user: &signer) {
		if (!exists<UserMintCertificates>(signer::address_of(user))) {
			move_to(
				user,
				UserMintCertificates {
					inner: vector::empty<MintCertificate>(),
				}
			);
		};
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      							GETTERS/SETTERS  				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	fun internal_get_resource_signer_and_addr(
		owner_addr: address,
	): (signer, address) acquires RerollResourceSigner {
		let resource_signer_cap = &borrow_global<RerollResourceSigner>(owner_addr).inner;
		let resource_signer = account::create_signer_with_capability(resource_signer_cap);
		let resource_addr = signer::address_of(&resource_signer);
		(resource_signer, resource_addr)
	}

	fun safe_get_resource_signer_and_addr(
		owner: &signer,
	): (signer, address) acquires RerollResourceSigner {
		assert!(exists<RerollResourceSigner>(signer::address_of(owner)), EREROLL_CONFIG_DOES_NOT_EXIST);
		internal_get_resource_signer_and_addr(signer::address_of(owner))
	}


	// this facilitates the user swapping their MintCertificate's TokenMetadata.token_uri with a token_uri from the pool
	// this ensures that there are never any duplicate token_uris (ensured initially with bucket_table) and that
	// the MintCertificate cannot be destroyed until the user consumes the certificate.
	// if we wanted to be REALLY safe, we could create a table filled with token_uris used on MintCertificate consumption
	//		and it'd fail when a duplicate key is attempted to be added to the table. This (theoretically) should never happen
	//		if we code the initial add_to_metadatta() and swap...() functions right, but it would ensure another level of redundant safety.
	//	Most likely unnecessary since we could just mutate_tokendata_uri in the case of an error
	fun internal_swap_uris_with_random_index_in_pool(
		user_token_metadata: &mut TokenMetadata,
		resource_address: address,
		nonce: u64,
	): (String, String) acquires TokenMetadataPool {
		let token_metadata_pool = borrow_global_mut<TokenMetadataPool>(resource_address);
		let pseudo_random_number = if (nonce % 2 == 0) {
			timestamp::now_microseconds() + nonce * 54321
		} else {
			timestamp::now_seconds() + nonce * 111111
		};
		let pool_size = big_vector::length(&token_metadata_pool.inner);
		assert!(pool_size > 0, ENO_METADATA_LEFT);
		let index_to_swap = pseudo_random_number % pool_size;
		let pool_token_metadata = big_vector::borrow_mut(&mut token_metadata_pool.inner, index_to_swap);

		let old_token_uri = *&user_token_metadata.token_uri;
		let new_token_uri = *&pool_token_metadata.token_uri;
		*(&mut user_token_metadata.token_uri) = new_token_uri;
		*(&mut pool_token_metadata.token_uri) = old_token_uri;
		assert!(user_token_metadata.token_uri != pool_token_metadata.token_uri &&
					user_token_metadata.token_uri == new_token_uri &&
					pool_token_metadata.token_uri == old_token_uri, EURI_SWAP_DID_NOT_WORK);
		(old_token_uri, new_token_uri)
	}

	// this is the only function where the size of TokenMetadataPool decreases once minting has begun
	fun internal_get_random_metadata_from_pool(
		resource_address: address,
	): TokenMetadata acquires TokenMetadataPool {
		let token_metadata_pool = borrow_global_mut<TokenMetadataPool>(resource_address);
		let now_microseconds = timestamp::now_microseconds();
		let pool_size = big_vector::length(&token_metadata_pool.inner);
		assert!(pool_size > 0, ENO_METADATA_LEFT);
		let index_to_remove = now_microseconds % pool_size;
		(big_vector::swap_remove(&mut token_metadata_pool.inner, index_to_remove))
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      								UNIT TESTS  				       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#[test_only] use pond::mint_settings::{FCFS};
	#[test_only] use pond::mint_tiers::{Self};

	#[test(owner = @0xFA)]
	// #[expected_failure(abort_code = pond::bucket_table::ALREADY_EXIST), location = pond::bucket_table]
	fun test_ensure_token_metadata_cant_have_duplicate_keys(
		owner: &signer,
	) {
		let _ = owner;
		// add_metadata_to_pool(owner, vector<String> [ string::utf8(b"duplicate key"), string::utf8(b"duplicate key") ]);
	}

	#[test]
	#[expected_failure(abort_code = pond::bucket_table::ALREADY_EXIST), location = pond::bucket_table]
	fun test_ensure_bucket_table_cant_have_duplicate_keys() {
		let bucket_table = bucket_table::new<String, bool>(500);
		let key_1 = string::utf8(b"key_1");
		bucket_table::add(&mut bucket_table, key_1, true);
		bucket_table::add(&mut bucket_table, key_1, true); // errors out here

		bucket_table::remove(&mut bucket_table, &key_1); // only have this and below to humor compiler
		bucket_table::destroy_empty(bucket_table);
	}


	#[test(owner = @test_owner, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	#[expected_failure(abort_code = EPOOL_SIZE_NOT_LARGE_ENOUGH), location = Self]
	fun test_initialize_collection_without_pool(
		owner: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires RerollResourceSigner, CollectionConfig, TokenMetadataPool, DedupedMetadata {
		test_initialize_reroller<FCFS, coin::FakeMoney>(owner, aptos_framework, treasury);
		initialize_collection(owner);
	}

	#[test(owner = @test_owner, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	fun test_add_metadata_to_pool(
		owner: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires RerollResourceSigner, TokenMetadataPool, DedupedMetadata {
		test_initialize_reroller<FCFS, coin::FakeMoney>(owner, aptos_framework, treasury);
		let token_uris = vector<String> [];
		let pool_size = 20;
		let i = pool_size;
		while(i > 0) {
			let token_uri = utils::append_u64_to_string(utils::test_get_token_uri_base(), pool_size - i);
			vector::push_back(&mut token_uris, token_uri);
			i = i - 1;
			if (i < 3 || i >= (pool_size - 3)) {
				pond::bash_colors::print_key_value_as_string(b"added to pool: ", token_uri);
			}
		};
		add_metadata_to_pool(
			owner,
			token_uris,
		);
	}

	// if DEBUG ONLY
	#[test(owner = @test_owner, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = mint_settings::NOT_YET_LAUNCH_TIME), location = mint_settings] 	// TO WITNESS, UNCOMMENT ALL ERROR 1
	//#[expected_failure(abort_code = ENO_REROLLS_LEFT), location = Self] 	// TO WITNESS, UNCOMMENT ALL ERROR 2

	//#[expected_failure(abort_code = mint_settings::NOT_YET_LAUNCH_TIME), location = mint_settings]
	fun test_many_rerolls(
		owner: &signer,
		minter: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig, RerollConfig, RerollCost, DedupedMetadata {
		let pool_size = utils::test_get_2x_collection_size();
		test_initialize_reroller_with_pool_size<mint_tiers::TestTierSmall, coin::FakeMoney>(
			owner,
			aptos_framework,
			treasury,
			utils::test_get_collection_maximum(),
			pool_size
		);
		let token_uris = vector<String> [];
		let i = pool_size; // pool_size needs to be greater than collection max or there is no metadata left to reroll with
		while(i > 0) {
			let token_uri = utils::append_u64_to_string(utils::test_get_token_uri_base(), pool_size - i);
			vector::push_back(&mut token_uris, token_uri);
			i = i - 1;
		};
		add_metadata_to_pool(
			owner,
			token_uris,
		);
		initialize_collection(owner);
		timestamp::update_global_time_for_test_secs(utils::test_get_launch_time() + 3);
		let owner_address = signer::address_of(owner);
		enable_global_mint(owner);
		add_addresses_to_tier<mint_tiers::TestTierSmall>(owner, vector<address> [@test_minter_1]);
		let num_certificates = mint_settings::test_get_max_mints<mint_tiers::TestTierSmall>();
		utils::register_acc_and_fill(aptos_framework, minter, utils::test_get_mint_price() * num_certificates);
		//set_launch_time<mint_tiers::TestTierSmall>(owner, utils::test_get_launch_time() + 3); // TO WITNESS, UNCOMMENT ALL ERROR 1
		while (num_certificates > 0) {
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter, owner_address);
			num_certificates = num_certificates - 1;
		};

		let minter_address = signer::address_of(minter);
		print_user_mint_certificates(minter_address, string::utf8(b"minter"));

		let num_rerolls = utils::test_get_max_rerolls_per_mint();
		reroll_and_print(minter, string::utf8(b"minter_1"), minter_address, num_rerolls, owner_address, aptos_framework);

		let (_, resource_address) = safe_get_resource_signer_and_addr(owner);
		print_and_mint(minter, minter_address, owner_address, resource_address);
	}

	#[test(owner = @test_owner, minter_1 = @test_minter_1, minter_2 = @test_minter_2, minter_3 = @test_minter_3, minter_4 = @test_minter_4, minter_5 = @test_minter_5, treasury = @test_treasury, aptos_framework = @0x1)]
	//#[expected_failure(abort_code = mint_settings::NOT_YET_LAUNCH_TIME), location = mint_settings]
	fun test_multiple_users_many_rerolls(
		owner: &signer,
		minter_1: &signer,
		minter_2: &signer,
		minter_3: &signer,
		minter_4: &signer,
		minter_5: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig, RerollConfig, RerollCost, DedupedMetadata {
		let pool_size = utils::test_get_2x_collection_size() * 5;
		test_initialize_reroller_with_pool_size<mint_tiers::TestTierSmall, coin::FakeMoney>(
			owner,
			aptos_framework,
			treasury,
			utils::test_get_collection_maximum(),
			pool_size
		);
		let token_uris = vector<String> [];
		let i = pool_size; // pool_size needs to be greater than collection max or there is no metadata left to reroll with
		while(i > 0) {
			let token_uri = utils::append_u64_to_string(utils::test_get_token_uri_base(), pool_size - i);
			vector::push_back(&mut token_uris, token_uri);
			i = i - 1;
		};
		add_metadata_to_pool(
			owner,
			token_uris,
		);
		initialize_collection(owner);
		timestamp::update_global_time_for_test_secs(utils::test_get_launch_time() + 3);
		let owner_address = signer::address_of(owner);
		enable_global_mint(owner);
		add_addresses_to_tier<mint_tiers::TestTierSmall>(owner, vector<address> [@test_minter_1, @test_minter_2, @test_minter_3, @test_minter_4, @test_minter_5]);
		let num_certificates = mint_settings::test_get_max_mints<mint_tiers::TestTierSmall>();
		utils::register_acc_and_fill(aptos_framework, minter_1, utils::test_get_mint_price() * num_certificates);
		utils::register_acc_and_fill(aptos_framework, minter_2, utils::test_get_mint_price() * num_certificates);
		utils::register_acc_and_fill(aptos_framework, minter_3, utils::test_get_mint_price() * num_certificates);
		utils::register_acc_and_fill(aptos_framework, minter_4, utils::test_get_mint_price() * num_certificates);
		utils::register_acc_and_fill(aptos_framework, minter_5, utils::test_get_mint_price() * num_certificates);
		//set_launch_time<mint_tiers::TestTierSmall>(owner, utils::test_get_launch_time() + 3); // TO WITNESS, UNCOMMENT ALL ERROR 1
		while (num_certificates > 0) {
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter_1, owner_address);
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter_2, owner_address);
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter_3, owner_address);
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter_4, owner_address);
			purchase_mint_certificate<mint_tiers::TestTierSmall, coin::FakeMoney>(minter_5, owner_address);
			num_certificates = num_certificates - 1;
		};

		let minter_1_address = signer::address_of(minter_1);
		let minter_2_address = signer::address_of(minter_2);
		let minter_3_address = signer::address_of(minter_3);
		let minter_4_address = signer::address_of(minter_4);
		let minter_5_address = signer::address_of(minter_5);
		print_user_mint_certificates(minter_1_address, string::utf8(b"minter_1"));
		print_user_mint_certificates(minter_2_address, string::utf8(b"minter_2"));
		print_user_mint_certificates(minter_3_address, string::utf8(b"minter_3"));
		print_user_mint_certificates(minter_4_address, string::utf8(b"minter_4"));
		print_user_mint_certificates(minter_5_address, string::utf8(b"minter_5"));

		let num_rerolls = utils::test_get_max_rerolls_per_mint();
		reroll_and_print(minter_1, string::utf8(b"minter_1"), minter_1_address, num_rerolls, owner_address, aptos_framework);
		reroll_and_print(minter_2, string::utf8(b"minter_2"), minter_2_address, num_rerolls, owner_address, aptos_framework);
		reroll_and_print(minter_3, string::utf8(b"minter_3"), minter_3_address, num_rerolls, owner_address, aptos_framework);
		reroll_and_print(minter_4, string::utf8(b"minter_4"), minter_4_address, num_rerolls, owner_address, aptos_framework);
		reroll_and_print(minter_5, string::utf8(b"minter_5"), minter_5_address, num_rerolls, owner_address, aptos_framework);

		let (_, resource_address) = safe_get_resource_signer_and_addr(owner);
		print_and_mint(minter_1, minter_1_address, owner_address, resource_address);
		print_and_mint(minter_2, minter_2_address, owner_address, resource_address);
		print_and_mint(minter_3, minter_3_address, owner_address, resource_address);
		print_and_mint(minter_4, minter_4_address, owner_address, resource_address);
		print_and_mint(minter_5, minter_5_address, owner_address, resource_address);
	}

	#[test(owner = @test_owner, minter = @test_minter_1, treasury = @test_treasury, aptos_framework = @0x1)]
	fun test_50k_rerolls(
		owner: &signer,
		minter: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig, RerollConfig, RerollCost, DedupedMetadata {
		let pool_size = 2001;
		let collection_maximum = 2000;
		test_initialize_reroller_with_pool_size<mint_tiers::TestTierLarge, coin::FakeMoney>(
			owner,
			aptos_framework,
			treasury,
			collection_maximum,
			pool_size
		);
		let token_uris = vector<String> [];
		let i = pool_size; // pool_size needs to be greater than collection max or there is no metadata left to reroll with
		while(i > 0) {
			let token_uri = utils::append_u64_to_string(utils::test_get_token_uri_base(), pool_size - i);
			vector::push_back(&mut token_uris, token_uri);
			i = i - 1;
		};
		add_metadata_to_pool(
			owner,
			token_uris,
		);
		initialize_collection(owner);
		timestamp::update_global_time_for_test_secs(utils::test_get_launch_time() + 3);
		let owner_address = signer::address_of(owner);
		enable_global_mint(owner);
		add_addresses_to_tier<mint_tiers::TestTierLarge>(owner, vector<address> [@test_minter_1]);
		let num_certificates = mint_settings::test_get_max_mints<mint_tiers::TestTierLarge>();
		utils::register_acc_and_fill(aptos_framework, minter, utils::test_get_mint_price() * num_certificates);

		while (num_certificates > 0) {
			purchase_mint_certificate<mint_tiers::TestTierLarge, coin::FakeMoney>(minter, owner_address);
			num_certificates = num_certificates - 1;
		};
		let minter_address = signer::address_of(minter);
		let num_rerolls = utils::test_get_max_rerolls_per_mint();
		let reroll = num_rerolls;
		while (reroll > 0) {
			let i = 0;
			// //////////////////////////////////////////////////
			//				REROLL AND RE-PRINT MINT CERTIFICATE #i DATA
			// //////////////////////////////////////////////////
			utils::register_acc_and_fill(aptos_framework, minter, utils::test_get_reroll_cost());
			reroll<coin::FakeMoney>(minter, owner_address, i);
			reroll = reroll - 1;
		};

		let (_, resource_address) = safe_get_resource_signer_and_addr(owner);

		let num_certificates = vector::length(&borrow_global<UserMintCertificates>(minter_address).inner);
		let i = 0;
		while (i < num_certificates) {
			//let last_index_in_vector = vector::length(&borrow_global<UserMintCertificates>(minter_address).inner) - 1;
			mint_with_certificate(
				minter,
				owner_address,
				0,
			);
			let (_, token_id) = utils::get_last_minted_token_id(resource_address);
			let has_token = token::balance_of(minter_address, token_id) == 1;
			assert!(has_token, MINTER_DID_NOT_GET_TOKEN);
			i = i + 1;
		};
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      					UNIT TEST INITIALIZATION  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#[test_only]
	fun test_initialize_reroller<Tier, CoinType>(
		owner: &signer,
		aptos_framework: &signer,
		treasury: &signer,
	) {
		use pond::utils::{Self};
		pond::utils::setup_test_environment(owner, aptos_framework, treasury, pond::utils::test_get_launch_time() + 1);
		initialize_reroller<Tier, CoinType>(
			owner,
			pond::utils::test_get_collection_name(),
			utils::test_get_collection_description(),
			utils::test_get_collection_uri(),
			utils::test_get_collection_maximum(),
			utils::test_get_collection_mutability(),
			utils::test_get_token_name_base(),
			utils::test_get_token_description(),
			utils::test_get_token_uri_base(),
			utils::test_get_token_mutability_config(),
			utils::test_get_royalty_payee_address(),
			utils::test_get_royalty_points_denominator(),
			utils::test_get_royalty_points_numerator(),
			utils::test_get_max_rerolls_per_mint(),
			utils::test_get_reroll_cost(),
			utils::test_get_intended_pool_size(),
			utils::test_get_treasury_address(),
			utils::test_get_global_end_time_ms(),
			utils::test_get_launch_time_ms(),
			utils::test_get_end_time_ms(),
			mint_settings::test_get_max_mints<Tier>(),
			utils::test_get_mint_price(),
		);
		//let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		//pond::mint_settings::default_initialize_all_for_test<Tier>(&resource_signer, treasury); // this is already called in initialize_reroller
		//set_launch_time_ms<Tier>(owner, pond::utils::test_get_launch_time_ms());
	}

	#[test_only]
	fun test_initialize_reroller_with_pool_size<Tier, CoinType>(
		owner: &signer,
		aptos_framework: &signer,
		treasury: &signer,
		collection_maximum: u64,
		pool_size: u64,
	) {
		use pond::utils::{Self};
		pond::utils::setup_test_environment(owner, aptos_framework, treasury, pond::utils::test_get_launch_time() + 1);
		initialize_reroller<Tier, CoinType>(
			owner,
			pond::utils::test_get_collection_name(),
			utils::test_get_collection_description(),
			utils::test_get_collection_uri(),
			collection_maximum,
			utils::test_get_collection_mutability(),
			utils::test_get_token_name_base(),
			utils::test_get_token_description(),
			utils::test_get_token_uri_base(),
			utils::test_get_token_mutability_config(),
			utils::test_get_royalty_payee_address(),
			utils::test_get_royalty_points_denominator(),
			utils::test_get_royalty_points_numerator(),
			utils::test_get_max_rerolls_per_mint(),
			utils::test_get_reroll_cost(),
			pool_size,
			utils::test_get_treasury_address(),
			utils::test_get_global_end_time_ms(),
			utils::test_get_launch_time_ms(),
			utils::test_get_end_time_ms(),
			mint_settings::test_get_max_mints<Tier>(),
			utils::test_get_mint_price(),
		);
		//let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		//pond::mint_settings::default_initialize_all_for_test<Tier>(&resource_signer, treasury); // this is already called in initialize_reroller
		//set_launch_time_ms<Tier>(owner, pond::utils::test_get_launch_time_ms());
	}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      						UNIT TEST HELPERS		  			       		 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#[test_only]
	fun print_user_mint_certificates(
		minter_address: address,
		minter_name: String,
	) acquires UserMintCertificates {
		use pond::bash_colors::{print_bytes, bcolor, color, print_key_value_as_string, join};
		let user_mint_certificates = borrow_global<UserMintCertificates>(minter_address);
		let i = 0;
		while (i < vector::length(&user_mint_certificates.inner)) {
			print_key_value_as_string(b"	", join( vector<String> [
				color(b"white", minter_name),
				bcolor(b"blue", b" certificate: "),
				color(b"green", utils::u64_to_string(i)),
				bcolor(b"blue", b"	rerolls: "),
				color(b"green", utils::u64_to_string(vector::borrow(&user_mint_certificates.inner, i).rerolls)),
				string::utf8(b"	"),
				color(b"green", (&vector::borrow(&user_mint_certificates.inner, i).token_metadata).token_uri),
			],
			string::utf8(b"")));
			i = i + 1;
		};
		print_bytes(b"");
	}

	#[test_only]
	fun reroll_and_print(
		minter: &signer,
		minter_name: String,
		minter_address: address,
		num_rerolls: u64,
		owner_address: address,
		aptos_framework: &signer,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, TokenMetadataPool, CollectionConfig, RerollConfig, RerollCost {
		use pond::bash_colors::{print, bcolor, color, join, color_bg};
		let mint_certificate_index = 0;
		let i = 0;
		print(join( vector<String> [
			string::utf8(b"	"),
			color(b"white", minter_name),
			bcolor(b"blue", b" certificate: "),
			color(b"green", utils::u64_to_string(mint_certificate_index)),
		], string::utf8(b"")));
		while (i < num_rerolls) {
			let old_token_uri = {
				let user_mint_certificates = borrow_global<UserMintCertificates>(minter_address);
				((&vector::borrow(&user_mint_certificates.inner, mint_certificate_index).token_metadata).token_uri)
			};
			// //////////////////////////////////////////////////
			//				REROLL AND RE-PRINT MINT CERTIFICATE #i DATA
			// //////////////////////////////////////////////////
			utils::register_acc_and_fill(aptos_framework, minter, utils::test_get_reroll_cost());
			reroll<coin::FakeMoney>(minter, owner_address, 0);

			let user_mint_certificates = borrow_global<UserMintCertificates>(minter_address);
			print(join( vector<String> [
				string::utf8(b"       	"),
				color_bg(b"cyan", bcolor(b"black", b"REROLL #")),
				color_bg(b"cyan", color(b"black", utils::u64_to_string(vector::borrow(&user_mint_certificates.inner, mint_certificate_index).rerolls))),
				string::utf8(b"	"),
				color(b"grey", old_token_uri),
				bcolor(b"yellow", b" => "),
				color(b"cyan", (&vector::borrow(&user_mint_certificates.inner, mint_certificate_index).token_metadata).token_uri),
			], string::utf8(b"")));
			i = i + 1;
		};
		print(string::utf8(b""));
	}

	#[test_only]
	fun print_and_mint(
		minter: &signer,
		minter_address: address,
		owner_address: address,
		resource_address: address,
	) acquires UserMintCertificates, RerollResourceSigner, RerollerEventStore, CollectionConfig {
		use pond::bash_colors::{print, bcolor, color, join, print_key_value_as_string};

		let num_certificates = vector::length(&borrow_global<UserMintCertificates>(minter_address).inner);
		let i = 0;
		while (i < num_certificates) {
				//let last_index_in_vector = vector::length(&borrow_global<UserMintCertificates>(minter_address).inner) - 1;
				mint_with_certificate(
					minter,
					owner_address,
					0,
				);

			let (token_name, token_id) = utils::get_last_minted_token_id(resource_address);
			print_key_value_as_string(b"	 ", join( vector<String> [
				color(b"white", token_name),
				bcolor(b"blue", b"	certificate: "),
				color(b"green", utils::u64_to_string(i)),
				bcolor(b"blue", b"	token_uri: "),
				color(b"green", utils::get_last_minted_token_uri(resource_address)),
			],
			string::utf8(b"")));
			assert!(token::balance_of(minter_address, token_id) == 1, MINTER_DID_NOT_GET_TOKEN);
			i = i + 1;
		};
		print(string::utf8(b""));
	}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////                                  											 ///////////////////
///////////////////////////      	MINT SETTINGS INTERFACE FOR REROLL_RESOURCE_SIGNER			 ///////////////////
///////////////////////////                                  											 ///////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	public entry fun enable_global_mint(
		owner: &signer,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::enable_global_mint(&resource_signer);
	}

	public entry fun disable_global_mint(
		owner: &signer,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::disable_global_mint(&resource_signer);
	}

	public entry fun set_launch_time<Tier>(
		owner: &signer,
		new_launch_time: u64,
	) acquires RerollResourceSigner {
		set_launch_time_ms<Tier>(owner, new_launch_time * MILLI_CONVERSION_FACTOR);
	}

	public entry fun set_launch_time_ms<Tier>(
		owner: &signer,
		new_launch_time_ms: u64,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::set_launch_time_ms<Tier>(&resource_signer, new_launch_time_ms);
	}

	public entry fun set_end_time<Tier>(
		owner: &signer,
		new_end_time: u64,
	) acquires RerollResourceSigner {
		set_end_time_ms<Tier>(owner, new_end_time * MILLI_CONVERSION_FACTOR);
	}

	public entry fun set_end_time_ms<Tier>(
		owner: &signer,
		new_end_time_ms: u64,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::set_end_time_ms<Tier>(&resource_signer, new_end_time_ms);
	}

	public entry fun set_global_end_time_ms(
		owner: &signer,
		new_global_end_time_ms: u64,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::set_global_end_time_ms(&resource_signer, new_global_end_time_ms);
	}

	public entry fun upsert_tiered_mint_settings<Tier>(
		owner: &signer,
		launch_time_ms: u64,
		end_time_ms: u64,
		max_mints_per_user: u64,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::upsert_tiered_mint_settings<Tier>(
			&resource_signer,
			launch_time_ms,
			end_time_ms,
			max_mints_per_user,
		);
	}

	public entry fun upsert_mint_price<Tier, CoinType>(
		owner: &signer,
		mint_price: u64,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::upsert_mint_price<Tier, CoinType>(&resource_signer, mint_price);
	}

	public entry fun add_addresses_to_tier<Tier>(
		owner: &signer,
		addresses: vector<address>,
	) acquires RerollResourceSigner {
		let (resource_signer, _) = safe_get_resource_signer_and_addr(owner);
		mint_settings::add_addresses_to_tier<Tier>(&resource_signer, addresses);
	}


}
