module pond::migration {
   // use std::signer;
   use std::vector;
   use aptos_token::property_map;
   use aptos_token::token;
   use std::string::{utf8 as str, String};

   const COLLECTION_NAME: vector<u8> = b"Aptos Toad Overload";
   const CREATOR_ADDRESS: address = @resource_creator_addr;

   const PROPERTY_MAP_STRING_TYPE: vector<u8> = b"0x1::string::String";

   #[view]
   public fun view_toad_pmap(
      token_name: String,
      owner_address: address,
   ): (vector<String>, vector<String>) {
      let token_data_id = token::create_token_data_id(CREATOR_ADDRESS, str(COLLECTION_NAME), token_name);
      let property_version = token::get_tokendata_largest_property_version(CREATOR_ADDRESS, token_data_id);
      let token_id = token::create_token_id(token_data_id, property_version);

      let property_map = token::get_property_map(owner_address, token_id);
      let property_map_length = property_map::length(&property_map);
      //let keys = property_map::keys(&property_map);
      //let types = property_map::types(&property_map);
      let keys = get_keys();
      let values = vector<String> [];

      vector::for_each(keys, |k| {
         if (property_map::contains_key(&property_map, &k)) {
            let v = property_map::read_string(&property_map, &k);
            vector::push_back(&mut values, v);
         };
         //std::debug::print(&v);
      });

      // we've never messed with the toads property map, so there's no reason
      // for it to be different than the length we've created here
      assert!(property_map_length == vector::length(&values), 0);
      //pond::bash_colors::print_key_value_as_string(b"property map length: ", pond::bash_colors::u64_to_string(property_map_length));

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