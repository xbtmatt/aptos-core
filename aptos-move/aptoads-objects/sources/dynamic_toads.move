module aptoads_objects::dynamic_toads {
   use std::object::{Self, Object, ConstructorRef, ExtendRef, TransferRef};
   use token_objects::token::{Self, MutatorRef, Token};
   use token_objects::collection::{Self, Collection};
   use token_objects::royalty::{Royalty};
   use std::string::{Self, String};
   use std::option::{Self, Option};
   use aptos_std::string_utils;
   use aptos_std::type_info;
   use std::vector;
   use std::signer;

   // TODO:
   // create tree of traits mapped to images
   // don't have time to make (or in pressentation to make) the
   // image generator. so just statically create these images
   // and link them in the smart contract.
   // when equipping/uneqipping things to toads, use the tree
   // to find what image should be used

   // 1 base toad with static background
   // 2 clothing
   // 2 headwear
   // 2 glasses
   // 2 tongue
   // 1 fly
   // 32 combinations total

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Metadata has key {
      z_index: u64,
      //image_data: vector<u8>,
   }

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Aptoad has key {
      background: String,
      body: String,
      clothing: Option<Object<Clothing>>,
      headwear: Option<Object<Headwear>>,
      glasses: Option<Object<Glasses>>,
      tongue: Option<Object<Tongue>>,
      fly: Option<Object<Fly>>,
      mutator_ref: MutatorRef,
   }

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Clothing has key {
      trait_name: String,
   }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Headwear has key {
      trait_name: String,
   }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Glasses has key {
      trait_name: String,
   }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Tongue has key {
      trait_name: String,
   }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Fly has key {
      trait_name: String,
   }

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Refs has key {
      transfer_ref: TransferRef,
      extend_ref: ExtendRef,
   }

   /// Action not authorized because the signer is not the owner of this module
   const ENOT_AUTHORIZED: u64 = 1;
   /// That type doesn't exist on the object
   const EINVALID_TYPE: u64 = 2;

   const COLLECTION_NAME: vector<u8> = b"Aptos Toad Overload";
   const COLLECTION_DESCRIPTION: vector<u8> = b"the OGs";
   const COLLECTION_URI: vector<u8> = b"https://aptoads.nyc3.digitaloceanspaces.com/images/perfects/pilot.png";
   const BASE_TOKEN_NAME: vector<u8> = b"{} #{}";
   const BASE_TOKEN_URI: vector<u8> = b"https://aptoads.nyc3.digitaloceanspaces.com/images/";
   const MAXIMUM_SUPPLY: u64 = 1000;

   fun init_module(creator: &signer) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly, Metadata {
      let collection_constructor_ref = collection::create_fixed_collection(
         creator,
         string::utf8(COLLECTION_DESCRIPTION),
         MAXIMUM_SUPPLY,
         string::utf8(COLLECTION_NAME),
         option::none<Royalty>(),
         string::utf8(COLLECTION_URI),
      );

      let _collection_object = object::object_from_constructor_ref<Collection>(&collection_constructor_ref);

      let aptoad_constructor_ref = create<Aptoad>(creator, string::utf8(b"Base"), string::utf8(b"1"), 1, 0);
      let clothing_constructor_ref_1 = create<Clothing>(creator, string::utf8(b"Clothing"), string::utf8(b"Chef Coat"), 1, 1);
      let clothing_constructor_ref_2 = create<Clothing>(creator, string::utf8(b"Clothing"), string::utf8(b"Pilots Garb"), 2, 1);
      let headwear_constructor_ref_1 = create<Headwear>(creator, string::utf8(b"Headwear"), string::utf8(b"Cowboy Hat"), 1, 3);
      let headwear_constructor_ref_2 = create<Headwear>(creator, string::utf8(b"Headwear"), string::utf8(b"Mini Green"), 2, 3);
      let glasses_constructor_ref_1 = create<Glasses>(creator, string::utf8(b"Glasses"), string::utf8(b"Lab Goggles"), 1, 2);
      let glasses_constructor_ref_2 = create<Glasses>(creator, string::utf8(b"Glasses"), string::utf8(b"Zuck Goggles"), 2, 2);
      let tongue_constructor_ref_1 = create<Tongue>(creator, string::utf8(b"Tongue"), string::utf8(b"Tongue Out"), 1, 4);
      let tongue_constructor_ref_2 = create<Tongue>(creator, string::utf8(b"Tongue"), string::utf8(b"Stache"), 2, 4);
      let fly_constructor_ref_1 = create<Fly>(creator, string::utf8(b"Fly"), string::utf8(b"Fly"), 1, 5);

      let aptoad_object = object::object_from_constructor_ref<Aptoad>(&aptoad_constructor_ref);
      let aptoad_metadata = object::object_from_constructor_ref<Metadata>(&aptoad_constructor_ref);
      let clothing_object_1 = object::object_from_constructor_ref<Clothing>(&clothing_constructor_ref_1);
      let clothing_metadata_1 = object::object_from_constructor_ref<Metadata>(&clothing_constructor_ref_1);
      let clothing_object_2 = object::object_from_constructor_ref<Clothing>(&clothing_constructor_ref_2);
      let headwear_object_1 = object::object_from_constructor_ref<Headwear>(&headwear_constructor_ref_1);
      let headwear_object_2 = object::object_from_constructor_ref<Headwear>(&headwear_constructor_ref_2);
      let glasses_object_1 = object::object_from_constructor_ref<Glasses>(&glasses_constructor_ref_1);
      let glasses_object_2 = object::object_from_constructor_ref<Glasses>(&glasses_constructor_ref_2);
      let tongue_object_1 = object::object_from_constructor_ref<Tongue>(&tongue_constructor_ref_1);
      let tongue_object_2 = object::object_from_constructor_ref<Tongue>(&tongue_constructor_ref_2);
      let fly_object_1 = object::object_from_constructor_ref<Fly>(&fly_constructor_ref_1);

      std::debug::print(&view_object(aptoad_object));
      std::debug::print(&view_metadata_object(aptoad_metadata));
      std::debug::print(&view_object(clothing_object_1));
      std::debug::print(&view_metadata_object(clothing_metadata_1));
      std::debug::print(&view_object(clothing_object_1));
      std::debug::print(&view_object(clothing_object_2));
      std::debug::print(&view_object(headwear_object_1));
      std::debug::print(&view_object(headwear_object_2));
      std::debug::print(&view_object(glasses_object_1));
      std::debug::print(&view_object(glasses_object_2));
      std::debug::print(&view_object(tongue_object_1));
      std::debug::print(&view_object(tongue_object_2));
      std::debug::print(&view_object(fly_object_1));


      toad_equip_trait(creator, aptoad_object, clothing_object_1);
      toad_equip_trait(creator, aptoad_object, headwear_object_2);
      toad_equip_trait(creator, aptoad_object, glasses_object_1);
      toad_equip_trait(creator, aptoad_object, tongue_object_2);
      toad_equip_trait(creator, aptoad_object, fly_object_1);

      std::debug::print(&view_object(aptoad_object));
   }

   fun create<T>(
      creator: &signer,
      trait_type: String,
      trait_name: String,
      num_trait_type: u64,
      z_index: u64,
   ): ConstructorRef {
      let token_name = trait_type;
      string::append_utf8(&mut token_name, b" #");
      string::append_utf8(&mut token_name, *string::bytes(&u64_to_string(num_trait_type)));

      let token_uri = string::utf8(BASE_TOKEN_URI);
      string::append_utf8(&mut token_uri, *string::bytes(&trait_type));
      string::append_utf8(&mut token_uri, b"/");
      string::append_utf8(&mut token_uri, *string::bytes(&trait_name));
      string::append_utf8(&mut token_uri, (b".png"));

      std::debug::print(&token_name);
      // https://aptoads.nyc3.digitaloceanspaces.com/images/Glasses/Zuck Goggles.png
      std::debug::print(&token_uri);

      let constructor_ref = token::create_named_token(
         creator,
         string::utf8(COLLECTION_NAME),
         string::utf8(COLLECTION_DESCRIPTION),
         token_name,
         option::none(),
         token_uri,
      );

      let transfer_ref = object::generate_transfer_ref(&constructor_ref);
      let extend_ref = object::generate_extend_ref(&constructor_ref);
      let token_signer = object::generate_signer(&constructor_ref);

      move_to(
         &token_signer,
         Refs {
            transfer_ref,
            extend_ref,
         }
      );

      if (type_info::type_of<T>() == type_info::type_of<Aptoad>()) {
         let mutator_ref = token::generate_mutator_ref(&constructor_ref);
         // create aptoad object
         move_to(
            &token_signer,
            Aptoad {
               background: string::utf8(b"Blue"),
               body: string::utf8(b"Golden"),
               clothing: option::none(),
               headwear: option::none(),
               glasses: option::none(),
               tongue: option::none(),
               fly: option::none(),
               mutator_ref,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Clothing>()) {
         move_to(
            &token_signer,
            Clothing {
               trait_name,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Headwear>()) {
         move_to(
            &token_signer,
            Headwear {
               trait_name,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Glasses>()) {
         move_to(
            &token_signer,
            Glasses {
               trait_name,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Tongue>()) {
         move_to(
            &token_signer,
            Tongue {
               trait_name,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Fly>()) {
         move_to(
            &token_signer,
            Fly {
               trait_name,
            }
         );
      };

      move_to(
         &token_signer,
         Metadata {
            z_index
         }
      );
      //string_utils::debug_string(borrow_global<T>(std::signer::address_of(&token_signer)));

      constructor_ref
   }

   public fun toad_equip_trait<T: key>(owner: &signer, toad_object: Object<Aptoad>, obj_to_equip: Object<T>) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly {
      let toad_obj_resources = borrow_global_mut<Aptoad>(object::object_address(&toad_object));
      let object_address = object::object_address<T>(&obj_to_equip);
      if (exists<Clothing>(object_address)) {
         let clothing_obj = object::convert<T, Clothing>(obj_to_equip);
         option::fill<Object<Clothing>>(&mut toad_obj_resources.clothing, clothing_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Headwear>(object_address)) {
         let headwear_obj = object::convert<T, Headwear>(obj_to_equip);
         option::fill<Object<Headwear>>(&mut toad_obj_resources.headwear, headwear_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Glasses>(object_address)) {
         let glasses_obj = object::convert<T, Glasses>(obj_to_equip);
         option::fill<Object<Glasses>>(&mut toad_obj_resources.glasses, glasses_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Tongue>(object_address)) {
         let tongue_obj = object::convert<T, Tongue>(obj_to_equip);
         option::fill<Object<Tongue>>(&mut toad_obj_resources.tongue, tongue_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Fly>(object_address)) {
         let fly_obj = object::convert<T, Fly>(obj_to_equip);
         option::fill<Object<Fly>>(&mut toad_obj_resources.fly, fly_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      };
      update_uri(toad_object);
   }

   fun update_uri(toad_object: Object<Aptoad>) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly {
      let token_object = object::convert<Aptoad, Token>(toad_object);
      let toad_object_resources = borrow_global<Aptoad>(object::object_address(&toad_object));

      let clothing_object = &toad_object_resources.clothing;
      let headwear_object = &toad_object_resources.headwear;
      let glasses_object = &toad_object_resources.glasses;
      let tongue_object = &toad_object_resources.tongue;
      let fly_object = &toad_object_resources.fly;

      //let token_name = token::name(token_object);

      std::debug::print(&string_utils::to_string(clothing_object));
      std::debug::print(&string_utils::to_string(headwear_object));
      std::debug::print(&string_utils::to_string(glasses_object));
      std::debug::print(&string_utils::to_string(tongue_object));
      std::debug::print(&string_utils::to_string(fly_object));




      let mutator_ref = &toad_object_resources.mutator_ref;
      // get address of each trait object, check if it's 1 or 2

      //
      // update uri to coded value
      // c1_h1_g1_t1_f1 == clothing 1, headwear 1, glasses 1, tongue 1, fly 1
      let new_uri = string::utf8(b"");
      token::set_uri(mutator_ref, new_uri);
      std::debug::print(&token::uri(token_object));

      view_object(toad_object);
   }

   public entry fun set_uri(
      _creator: &signer,
      _toad_object: Object<Aptoad>,
      _new_uri: String
   ) { }

   public entry fun change_uri(
      creator: &signer,
      toad_object_addr: address,
      new_uri: String
   ) acquires Aptoad {
      let creator_addr = signer::address_of(creator);
      let collection_addr = collection::create_collection_address(&creator_addr, &string::utf8(COLLECTION_NAME));
      assert!(object::owner(object::address_to_object<Collection>(collection_addr)) == creator_addr, 0);
      let toad_object_resources = borrow_global<Aptoad>(toad_object_addr);
      let mutator_ref = &toad_object_resources.mutator_ref;
      token::set_uri(mutator_ref, new_uri);
   }

   #[view]
   fun view_object<T: key>(obj: Object<T>): String acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly {
      let token_address = object::object_address(&obj);
      //string::utils::to_string(borrow_global<T>(token_address))
      if (exists<Aptoad>(token_address)) {
         string_utils::debug_string(borrow_global<Aptoad>(token_address))
      } else if (exists<Clothing>(token_address)) {
         string_utils::debug_string(borrow_global<Clothing>(token_address))
      } else if (exists<Headwear>(token_address)) {
         string_utils::debug_string(borrow_global<Headwear>(token_address))
      } else if (exists<Glasses>(token_address)) {
         string_utils::debug_string(borrow_global<Glasses>(token_address))
      } else if (exists<Tongue>(token_address)) {
         string_utils::debug_string(borrow_global<Tongue>(token_address))
      } else if (exists<Fly>(token_address)) {
         string_utils::debug_string(borrow_global<Fly>(token_address))
      } else {
         abort EINVALID_TYPE
      }
   }

   #[view]
   fun view_metadata_object<T: key>(obj: Object<T>): String acquires Metadata {
      let token_address = object::object_address(&obj);
      //string::utils::to_string(borrow_global<T>(token_address))
      string_utils::debug_string(borrow_global<Metadata>(token_address))
   }

   fun u64_to_string(value: u64): String {
      if (value == 0) {
         return string::utf8(b"0")
      };
      let buffer = vector::empty<u8>();
      while (value != 0) {
         vector::push_back(&mut buffer, ((48 + value % 10) as u8));
         value = value / 10;
      };
      vector::reverse(&mut buffer);
      string::utf8(buffer)
   }

   #[test(owner = @0xFA)]
   fun test(
      owner: &signer,
   ) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly, Metadata {
      init_module(owner);
   }

}
