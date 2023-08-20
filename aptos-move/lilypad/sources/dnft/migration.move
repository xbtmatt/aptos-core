module pond::migration {
   use std::signer;
   use std::error;
   use std::option;
   // use std::table;
   use std::object::{Object};
   use std::vector;
   use aptos_token::property_map;
   use aptos_token::token::{Self as token_v1, Token, TokenId};
   use aptos_token_objects::collection::{Self as collection_v2, Collection};
   use aptos_token_objects::token::{Self as token_v2};
   use std::string::{utf8 as str, String};

   /// You are not the owner of that token.
   const ENOT_OWNER: u64 = 0;
   /// The maximum supply of the given collection needs to be 4,000.
   const EMAXIMUM_DOES_NOT_MATCH: u64 = 1;

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                      toad extraction/storage                      ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   public fun extract_generic_v1_token_and_traits(
      token_owner: &signer,
      token_name: String,
      creator_address: address,
      collection_name: String,
   ): (Token, vector<String>, vector<String>) {
      let owner_addr = signer::address_of(token_owner);
      let token_id = create_nft_token_id(creator_address, collection_name, token_name);
      assert!(token_v1::balance_of(owner_addr, token_id) == 1, error::permission_denied(ENOT_OWNER));
      let token = token_v1::withdraw_token(token_owner, token_id, 1);
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
      token_v2::create_token_address(
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
      let supply_1 = *option::borrow(&token_v1::get_collection_supply(creator_1, collection_1_name));
      let supply_2 = *option::borrow(&collection_v2::count(collection_2_obj));
      (supply_1, supply_2)
   }

   // NFTs will always only have 1 property version.
   // This function may not work as expected for fungible/semi-fungible tokens.
   #[view]
   public fun create_nft_token_id(
      creator_address: address,
      collection_name: String,
      token_name: String,
   ): TokenId {
      let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
      let property_version = token_v1::get_tokendata_largest_property_version(creator_address, token_data_id);
      token_v1::create_token_id(token_data_id, property_version)
   }

   #[view]
   public fun view_generic_pmap(
      token_name: String,
      owner_address: address,
      creator_address: address,
      collection_name: String,
   ): (vector<String>, vector<String>) {
      let token_id = create_nft_token_id(creator_address, collection_name, token_name);
      get_keys_and_values(owner_address, token_id)
   }

   #[view]
   public fun view_generic_pmap_and_uri(
      token_name: String,
      owner_address: address,
      creator_address: address,
      collection_name: String,
   ): (vector<String>, vector<String>, String) {
      let token_data_id = token_v1::create_token_data_id(creator_address, collection_name, token_name);
      let property_version = token_v1::get_tokendata_largest_property_version(creator_address, token_data_id);
      let token_id = token_v1::create_token_id(token_data_id, property_version);

      let token_uri = token_v1::get_tokendata_uri(creator_address, token_data_id);
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
      let property_map = token_v1::get_property_map(owner_address, token_id);
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
