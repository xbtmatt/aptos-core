//# init --addresses Alice=0xf75daa73fc071f93593335eb9033da804777eb94491650dd3f095ce6f778acb6 Bob=0x9c3b634ac05d0af393e0f93b9b19b61e7cac1c519f566276aa0c6fd15dac12aa
//#      --private-keys Alice=56a26140eb233750cd14fb168c3eb4bd0782b099cde626ec8aff7f3cceb6364f Bob=952aaf3a98a27903dd078d76fc9e411740d2ae9dd9ecb87b96c7cd6b791ffc69
//#      --initial-coins 10000

//# run --script --signers Alice  --args @Bob 100



// Change publish network to testnet
// create signer account for the publishing module, use it
// create signer for the collection creator
// fund both accounts on testnet
// initialize_lilypad_v2, make sure max_mints_per_user is like 777 or smth


// tester wallet seed:
// bar mad lift farm omit wheat motor animal lock rain lizard shallow

//old one
// zero artwork judge insect chapter surge magic dose noise wheel mistake they

// 0x11637e8328263828fc96583fbdb4f263a0141d66a740f6a36017f685e71dd5ba, 0xac27bc01db6b4001a70f2273d3bf8a3877fd409a22cc2fd3a0eef534df789d94
// 0x8b1858c4ccf21024bb4b8dd23a8941fe763dbc3cb6750fc5a0bdb544e4aa18d0, 0xbc640853a95507db0fedaa04c82448b77c0be0d334d29f1fdc578db1ae6ebfdf
// 0x3a25227bc36e1f564ddce1ae9ee8006bdcc7b0e3451f07c2a1c9a9648be9bd72, 0xceb6ab10bf7878af3858e9c7104fb37cd0dd1c1ab60df91710d143aa5d187524
// 0x28f716ebd56a57d08764304e17fe3b8a32eff85b2a0c3b22206d713c5e3e41cf, 0xcee8ef03507ef65dff29253fa4664ebedf964b4d00a87db44813bdd4115177b0
// 0xe05b094d6a6c97b2612d52927249707a8563191703277c17d829033950fd120a, 0x318a716226cdb8f1f6612be7dbf515e076f43a9fde06f92508b2a74e0e876b9d
// 0x9755e1e3b25bff344d3c007eeac97709bce7ac3c2449333552cae90b2e1324f6, 0xc1500082e5b31026e3e3f109d4a1930370deba0c4a7c4f46c6ba7685071adb26

script {

	use std::string::{String, utf8};
	//use pond::lilypad_v2::{Self};//, BasicMint, WhitelistMint, VipMint};
	use std::signer;
	//use aptos_token::token::{Self};
	//use std::vector::{Self};

	//use aptos_token::property_map::{Self};
	const BURNABLE_BY_CREATOR: vector<u8> = b"TOKEN_BURNABLE_BY_CREATOR";
	const TOKEN_DID_NOT_BECOME_BURNABLE: u64 = 7; // 0x7
	const COLLECTION_NAME: vector<u8> = b"Kreachers";
	const COLLECTION_MAXIMUM: u64 = 777;
	const TOKEN_NAME_BASE: vector<u8> = b"Kreacher #";
	const TOKEN_DESCRIPTION: vector<u8> = b"A mystic Kreacher known to inhabit the lands of InSilva.";
	const COLLECTION_IMAGE: vector<u8> = b"https://arweave.net/CqFDEPEFSYmkkCskO1rm_zQztZx6NKnkt1KGi1Z5xwo";
	const COLLECTION_DESCRIPTION: vector<u8> = b"Who else lives in the forest that starts with a K? The KREACHERS of InSilva. These cute little balls of fur live amongst Elves and Humans who also play dress up. Yes you heard that right, the Kreachers love a good fashion game. Dress them as you see fit!";
	const COLLECTION_MUTABILITY: vector<bool> = vector<bool> [true, true, true];
	const TOKEN_MUTABILITY: vector<bool> = vector<bool> [ false, true, true, true, true ];
	const TREASURY_ADDRESS: address = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0;
	const ROYALTY_ADDRESS: address = @0x441d63bc5d378bd01c1021e2286515f9231879bd70f7881cb39c57ea34ee62b0;
	const ROYALTY_POINTS_DENOMINATOR: u64 = 100;
	const ROYALTY_POINTS_NUMERATOR: u64 = 5;
	const PRE_REVEAL_IMAGE: vector<u8> = b"https://arweave.net/jdCNSwTIa3PWYEruzUsTogZzR5wuWUHkKvEOqt5gohE";
	const LAUNCH_TIME: u64 = 1675033200000;
	const MINT_PRICE: u64 = 0;
	const WL_LAUNCH_TIME: u64 = 1675033200000;
	const WL_MINT_PRICE: u64 = 0;
	const VIP_LAUNCH_TIME: u64 = 1675033200000;
	const VIP_MINT_PRICE: u64 = 0;
	const MINTING_ENABLED: bool = true;

	const MAX_MINTS_PER_TX: u64 = 111;
	const MAX_MINTS_BASIC: u64 = 777;
	const MAX_MINTS_WHITELIST: u64 = 777;
	const MAX_MINTS_VIP: u64 = 777;
	const DELAYED_REVEAL: bool = true;

	const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";

	const WRONG_CREATOR:  u64 = 123; // 0x7b

	fun create_lilypad_v2(
		creator: &signer,
	) {
		assert!(signer::address_of(creator) == @creator_address, WRONG_CREATOR);

		let token_metadata_keys: vector<String> = vector<String> [
				utf8(b"Background"),
				utf8(b"Body"),
				utf8(b"Eyes"),
				utf8(b"Antler Polish"),
				utf8(b"Shoes"),
				utf8(b"Pants"),
				utf8(b"Shirt"),
				utf8(b"Hats"),
				utf8(b"Eyewear"),
				utf8(b"Antler Accessories"),
			];


		pond::lilypad_v2::initialize_lilypad<aptos_framework::aptos_coin::AptosCoin>(
			creator,
			utf8(COLLECTION_NAME),
			utf8(COLLECTION_DESCRIPTION),
			utf8(COLLECTION_IMAGE),
			COLLECTION_MAXIMUM,
			COLLECTION_MUTABILITY,
			LAUNCH_TIME,
			MINT_PRICE,
			WL_LAUNCH_TIME,
			WL_MINT_PRICE,
			VIP_LAUNCH_TIME,
			VIP_MINT_PRICE,
			TREASURY_ADDRESS,
			utf8(TOKEN_NAME_BASE),
			utf8(TOKEN_DESCRIPTION),
			utf8(PRE_REVEAL_IMAGE),
			TOKEN_MUTABILITY,
			ROYALTY_ADDRESS,
			ROYALTY_POINTS_DENOMINATOR,
			ROYALTY_POINTS_NUMERATOR,
			token_metadata_keys,
			MINTING_ENABLED,
			MAX_MINTS_PER_TX,
			MAX_MINTS_BASIC,
			MAX_MINTS_WHITELIST,
			MAX_MINTS_VIP,
			DELAYED_REVEAL,
		);

		let whitelist_addresses = vector<address> [ @creator_address,
			@minter1_address,
			@minter2_address,
			@minter3_address,
			@minter4_address, ];

		pond::lilypad_v2::add_to_whitelist(
			creator,
			whitelist_addresses,
		);


		pond::lilypad_v2::update_collection_config(
			creator,
			utf8(TOKEN_NAME_BASE),
			utf8(TOKEN_DESCRIPTION),
			utf8(PRE_REVEAL_IMAGE),
			TOKEN_MUTABILITY,
			ROYALTY_ADDRESS,
			ROYALTY_POINTS_DENOMINATOR,
			ROYALTY_POINTS_NUMERATOR,
			token_metadata_keys,
			MINTING_ENABLED,
			MAX_MINTS_PER_TX,
			MAX_MINTS_BASIC,
			MAX_MINTS_WHITELIST,
			MAX_MINTS_VIP,
			DELAYED_REVEAL,
		)

	// fun whitelist_mint_111_times(
		// minter: &signer,
	// ) {
		// pond::lilypad_v2::mint<AptosCoin, WhitelistMint>(
			// @creator_address,
			// utf8(COLLECTION_NAME),
			// 112,
		// );
	// }
	}

}

//# view --address Bob  --resource 0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>
