module pond::migration {
   use std::signer;
   use std::error;
   use std::option;
   // use std::table;
   use std::object::{Object, ConstructorRef};
   use std::vector;
   use aptos_token::property_map;
   use aptos_token::token::{Self, Token, TokenId};
   use aptos_token_objects::collection::{Self, Collection, MutatorRef as CollectionMutatorRef};
   use std::string::{utf8 as str, String};
   use pond::lilypad::{internal_get_resource_signer_and_addr};
   use pond::merkle_tree::{Self, MerkleTree};

   const COLLECTION_NAME: vector<u8> = b"Aptos Toad Overload";
   const CREATOR_ADDRESS: address = @resource_creator_addr;

   const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";

   const COLLECTION_V2_DESCRIPTION: vector<u8> = b"The flagship Aptos NFT | 4000 dynamic pixelated toads taking a leap into the Aptos pond.";
   const COLLECTION_V2_URI: vector<u8> = b"https://arweave.net/AbA33tqZQj3fJtfn8U4P3EQaCBD9pUWoVNRyTosCxeQ";
   const MAXIMUM_SUPPLY: u64 = 4000;
   const TREASURY_ADDRESS: address = @0x790bc9aa92d6e54fccc7ebd699386b0d526dad9686971ff1720dac513c5ba4dc;

   /// You are not the owner of that toad.
   const ENOT_OWNER: u64 = 0;
   /// Collection supply isn't equal to the collection maximum. There is an issue with the collection supply.
   const EMAX_NOT_SUPPLY: u64 = 1;
   /// Toad store doesn't exist yet.
   const ETOAD_STORE_DOES_NOT_EXIST: u64 = 2;
   /// The maximum supply of the given collection needs to be 4,000.
   const EMAXIMUM_DOES_NOT_MATCH: u64 = 3;
   /// Migrated vs unmigrated tokens are out of sync. The amount of both should sum to 4,000.
   const ESUPPLY_OUT_OF_SYNC: u64 = 4;

   struct CollectionV2Config has key {
      unmigrated_v1_tokens: u64,
      migrated_v1_tokens: u64,
      v1_collection: String,
      v2_collection: String,
      v2_collection_object: Object<Collection>,
      extend_ref: ExtendRef,
      transfer_ref: TransferRef,
      mutator_ref: CollectionMutatorRef,
      merkle_tree: MerkleTree,
   }

   struct ToadStore has key {
      inner: Table<TokenId, Token>,
   }

   public fun initialize_v2_collection(
      creator: &signer,
      v1_collection_name: String,
      v2_collection_uri: String,
      v2_collection_name: String,
      v2_collection_description: String,
      new_royalty_numerator: u64,
      new_royalty_denominator: u64,
      treasury_address: address,
      root_hash: vector<u8>,
   ) acquires CollectionV2Config {
      let creator_addr = signer::address_of(creator);
      lilypad::assert_lilypad_exists(creator_addr);
      // ensures the original collection exists (and is, by implication, owned by `creator`)
      token::check_collection_exists(creator_addr, v1_collection_name);

      // check maximums and supplies
      let maximum = *option::extract(token::get_collection_maximum(creator_addr, v1_collection_name));
      let supply = *option::extract(token::get_collection_supply(creator_addr, v1_collection_name));
      assert!(maximum == supply, error::invalid_state(EMAX_NOT_SUPPLY));
      assert!(maximum == MAXIMUM_SUPPLY, error::invalid_state(EMAXIMUM_DOES_NOT_MATCH));

      // create the collection & get its constructor ref
      let collection_constructor_ref = collection::create_fixed_collection(
         creator,
         v2_collection_description,
         MAXIMUM_SUPPLY,
         v2_collection_name,
         royalty::create(new_royalty_numerator, new_royalty_denominator, treasury_address),
         v2_collection_uri,
      );

      // create object reference and refs from constructor_ref
      let collection_object = object::object_from_constructor_ref<Collection>(&collection_constructor_ref);
      let extend_ref = object::generate_extend_ref(&collection_constructor_ref);
      let transfer_ref = object::generate_transfer_ref(&collection_constructor_ref);
      let mutator_ref = collection::generate_mutator_ref(&collection_constructor_ref);

      // store misc info in collection config for bookkeeping as well as the collection object refs
      // this also creates & stores the merkle tree root hash, which is our validator for
      // image URLs created from a hash of the concatenation of all `TRAIT_TYPE::TRAIT_NAME`s
      move_to(
         creator,
         CollectionV2Config {
            unmigrated_v1_tokens: MAXIMUM_SUPPLY,
            migrated_v1_tokens: 0,
            v1_collection: v1_collection_name,
            v2_collection: v2_collection_name,
            v2_collection_object: collection_object,
            extend_ref: extend_ref,
            transfer_ref: transfer_ref,
            mutator_ref: mutator_ref,
            merkle_tree: merkle_tree::new(root_hash),
         }
      );
   }

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                        toad creation/swap                         ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   /// gets all the trait types and trait names from a toad in its property map
   /// and creates a v2 toad from it. Transfers the toad to the owner after creation
   /// and stores the v1 toad into a simple resource that holds it indefinitely. (would burn if could)
   /// tracks the # migrated and unmigrated to avoid potential backdoors
   public entry fun swap_v1_for_v2(
      owner: &signer,
      toad_name: String,
      creator_addr: address,
      collection_name: String,
      unvalidated_image_uri: String,
   ) {
      let (v1_token, keys, values) =
         extract_generic_v1_toad_and_traits(owner, toad_name, creator_addr, collection_name);

      let (resource_signer, resource_addr) = lilypad::internal_get_resource_signer_and_addr(creator_addr);
      let collection_object = borrow_global<CollectionV2Config>(resource_addr).v2_collection_object;

      // create v2 version
      let aptoad_object = toad_v2::create_v2_from_v1(
         resource_signer,
         resource_addr,
         collection_object,
         v1_token,
         keys,
         values,
         unvalidated_image_uri,
      );

      let owner_addr = signer::address_of(owner);
      object::transfer(resource_signer, aptoad_object, owner_addr);

      store_toad(v1_token);

      increment_migrated_and_decrement_unmigrated(resource_addr);
   }

   fun increment_migrated_and_decrement_unmigrated(
      resource_addr: address,
   ) acquires CollectionV2Config {
      let collection_v2_config = borrow_global_mut<CollectionV2Config>(resource_addr);
      *collection_v2_config.unmigrated_v1_tokens = *collection_v2_config.unmigrated_v1_tokens - 1;
      *collection_v2_config.migrated_v1_tokens = *collection_v2_config.migrated_v1_tokens + 1;
      assert!(*collection_v2_config.migrated_v1_tokens + *collection_v2_config.unmigrated_v1_tokens == MAXIMUM_SUPPLY,
         error::invalid_state(ESUPPLY_OUT_OF_SYNC));
   }

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                      toad extraction/storage                      ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   fun store_toad(
      resource_signer: &signer,
      token: Token,
   ) acquires ToadStore {
      assert!(exists<ToadStore>(resource_addr), error::invalid_state(ETOAD_STORE_DOES_NOT_EXIST));
      let resource_addr = signer::address_of(resource_signer);
      let toad_store = borrow_global_mut<ToadStore>(resource_addr);
      table::add(&mut toad_store.inner, token.id, token);
   }

   public fun extract_v1_toad_and_traits(
      owner: &signer,
      toad_name: String,
   ): (Token, vector<String>, vector<String>) {
      let owner_addr = signer::address_of(owner);
      let token_id = create_nft_token_id(CREATOR_ADDRESS, str(COLLECTION_NAME), toad_name);
      assert!(token::balance_of(owner_addr, token_id) == 1, error::permission_denied(ENOT_OWNER));
      let token = token::withdraw_token(owner, token_id, 1);
      let (keys, values) = get_keys_and_values(owner_addr, token_id);
      (token, keys, values)
   }

   public fun extract_generic_v1_toad_and_traits(
      owner: &signer,
      toad_name: String,
      creator_addr: address,
      collection_name: String,
   ): (Token, vector<String>, vector<String>) {
      let owner_addr = signer::address_of(owner);
      let token_id = create_nft_token_id(creator_addr, collection_name, toad_name);
      assert!(token::balance_of(owner_addr, token_id) == 1, error::permission_denied(ENOT_OWNER));
      let token = token::withdraw_token(owner, token_id, 1);
      let (keys, values) = get_keys_and_values(owner_addr, token_id);
      (token, keys, values)
   }

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                           view functions                          ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   #[view]
   public fun get_token_object_addr(
      creator_addr: address,
      collection_name: String,
      token_name: String,
   ): address {
      create_token_address(
         &creator_addr,
         &collection_name,
         &token_name,
      )
   }

   #[view]
   public fun get_v1_and_v2_supply(
      creator_1: address,
      collection_1_name: String,
      collection_2_obj: Object<Collection>,
   ): (u64, u64) {
      let supply_1 = *option::borrow(&token::get_collection_supply(creator_1, collection_1_name));
      let supply_2 = *option::borrow(&collection::count(collection_2_obj));
      (supply_1, supply_2)
   }

   // NFTs will always only have 1 property version.
   // This function may not work as expected for fungible/semi-fungible tokens.
   #[view]
   public fun create_nft_token_id(
      creator: address,
      collection: String,
      name: String,
   ): TokenId {
      let token_data_id = token::create_token_data_id(creator, collection, name);
      let property_version = token::get_tokendata_largest_property_version(creator, token_data_id);
      token::create_token_id(token_data_id, property_version)
   }

   #[view]
   public fun view_toad_pmap(
      toad_name: String,
      owner_address: address,
   ): (vector<String>, vector<String>) {
      let token_id = create_nft_token_id(CREATOR_ADDRESS, str(COLLECTION_NAME), toad_name);
      get_keys_and_values(owner_address, token_id)
   }

   #[view]
   public fun view_pmap_and_uri(
      toad_name: String,
      owner_address: address,
   ): (vector<String>, vector<String>, String) {
      let token_data_id = token::create_token_data_id(CREATOR_ADDRESS, str(COLLECTION_NAME), toad_name);
      let property_version = token::get_tokendata_largest_property_version(CREATOR_ADDRESS, token_data_id);
      let token_id = token::create_token_id(token_data_id, property_version);
      
      let token_uri = token::get_tokendata_uri(CREATOR_ADDRESS, token_data_id);
      let (keys, values) = get_keys_and_values(owner_address, token_id);
      (keys, values, token_uri)
   }

   #[view]
   public fun view_generic_pmap(
      toad_name: String,
      owner_address: address,
      creator_addr: address,
      collection_name: String,
   ): (vector<String>, vector<String>) {
      let token_id = create_nft_token_id(creator_addr, collection_name, toad_name);
      get_keys_and_values(owner_address, token_id)
   }

   #[view]
   public fun view_generic_pmap_and_uri(
      toad_name: String,
      owner_address: address,
      creator_addr: address,
      collection_name: String,
   ): (vector<String>, vector<String>, String) {
      let token_data_id = token::create_token_data_id(creator_addr, collection_name, toad_name);
      let property_version = token::get_tokendata_largest_property_version(creator_addr, token_data_id);
      let token_id = token::create_token_id(token_data_id, property_version);
      
      let token_uri = token::get_tokendata_uri(creator_addr, token_data_id);
      let (keys, values) = get_keys_and_values(owner_address, token_id);
      (keys, values, token_uri)
   }

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                        property map helpers                       ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   fun get_keys_and_values(
      owner_address: address,
      token_id: TokenId,
   ): (vector<String>, vector<String>) {
      let property_map = token::get_property_map(owner_address, token_id);
      let property_map_length = property_map::length(&property_map);
      let all_keys = get_keys();
      let keys = vector<String> [];
      let values = vector<String> [];

      vector::for_each(all_keys, |k| {
         if (property_map::contains_key(&property_map, &k)) {
            let property_value = property_map::borrow(&property_map, &k);
            let v = property_map::borrow_value(property_value);
            vector::push_back(&mut keys, k);
            vector::push_back(&mut values, str(v));
         };
      });

      // we've never messed with the toads property map, so there's no reason
      // for it to be different than the length we've created here
      assert!(property_map_length == vector::length(&values), 0);

      (keys, values)
   }

   fun get_keys(): vector<String> {
      vector<String> [
         str(b"Fly"),
         str(b"Body"),
         str(b"Eyes"),
         str(b"Mouth"),
         str(b"Clothing"),
         str(b"Background"),
         str(b"Headwear"),
      ]
   }

   #[test]
   fun migration_test(){
      //let (_keys, _values) = view_toad_pmap(str(b"Aptoad #3935"), @me);
   }

}