module utilities::utils {
   use aptos_token_objects::token;
   use aptos_token_objects::collection;
   use std::string::{String};

   #[view]
   public fun token_object_address(creator: address, collection: String, name: String): address {
      token::create_token_address(&creator, &collection, &name)
   }

   #[view]
   public fun collection_object_address(creator: address, name: String): address {
      collection::create_collection_address(&creator, &name)
   }

}
