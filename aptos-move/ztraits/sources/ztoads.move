module ztraits::ztoads {
   use std::object::{Self, Object, ConstructorRef, ExtendRef, TransferRef};
   use token_objects::token::{Self, MutatorRef, Token};
   use token_objects::collection::{Self, Collection};
   use token_objects::royalty::{Royalty};
   use std::string::{Self, String};
   use std::option::{Self, Option};
   use aptos_std::string_utils;
   use aptos_std::type_info;
   use std::vector;

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
	struct ZTrait has key {
		negative: bool,
		z_index: u64,
		uri: String,
		trait_name: String,
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
   struct Clothing has key { }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Headwear has key { }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Glasses has key { }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Tongue has key { }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Fly has key { }

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

   fun init_module(creator: &signer) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly, ZTrait {
      let collection_constructor_ref = collection::create_fixed_collection(
         creator,
         string::utf8(COLLECTION_DESCRIPTION),
         MAXIMUM_SUPPLY,
         string::utf8(COLLECTION_NAME),
         option::none<Royalty>(),
         string::utf8(COLLECTION_URI),
      );

      let _collection_object = object::object_from_constructor_ref<Collection>(&collection_constructor_ref);

      let aptoad_constructor_ref = create<Aptoad>(creator, b"Base", b"1", 1, false, 0, b"uri");
      let clothing_constructor_ref_1 = create<Clothing>(creator, b"Clothing", b"Chef Coat", 1, false, 1, b"uri");
      let clothing_constructor_ref_2 = create<Clothing>(creator, b"Clothing", b"Pilots Garb", 2, false, 1, b"uri");
      let headwear_constructor_ref_1 = create<Headwear>(creator, b"Headwear", b"Cowboy Hat", 1, false, 3, b"uri");
      let headwear_constructor_ref_2 = create<Headwear>(creator, b"Headwear", b"Mini Green", 2, false, 3, b"uri");
      let glasses_constructor_ref_1 = create<Glasses>(creator, b"Glasses", b"Lab Goggles", 1, false, 2, b"uri");
      let glasses_constructor_ref_2 = create<Glasses>(creator, b"Glasses", b"Zuck Goggles", 2, false, 2, b"uri");
      let tongue_constructor_ref_1 = create<Tongue>(creator, b"Tongue", b"Tongue Out", 1, false, 4, b"uri");
      let tongue_constructor_ref_2 = create<Tongue>(creator, b"Tongue", b"Stache", 2, false, 4, b"uri");
      let fly_constructor_ref_1 = create<Fly>(creator, b"Fly", b"Fly", 1, false, 5, b"uri");

      let aptoad_object = object::object_from_constructor_ref<Aptoad>(&aptoad_constructor_ref);
      //let aptoad_ztrait = object::object_from_constructor_ref<ZTrait>(&aptoad_constructor_ref);
      let clothing_object_1 = object::object_from_constructor_ref<Clothing>(&clothing_constructor_ref_1);
      let clothing_ztrait_1 = object::object_from_constructor_ref<ZTrait>(&clothing_constructor_ref_1);
      let clothing_object_2 = object::object_from_constructor_ref<Clothing>(&clothing_constructor_ref_2);
      let headwear_object_1 = object::object_from_constructor_ref<Headwear>(&headwear_constructor_ref_1);
      let headwear_object_2 = object::object_from_constructor_ref<Headwear>(&headwear_constructor_ref_2);
      let glasses_object_1 = object::object_from_constructor_ref<Glasses>(&glasses_constructor_ref_1);
      let glasses_object_2 = object::object_from_constructor_ref<Glasses>(&glasses_constructor_ref_2);
      let tongue_object_1 = object::object_from_constructor_ref<Tongue>(&tongue_constructor_ref_1);
      let tongue_object_2 = object::object_from_constructor_ref<Tongue>(&tongue_constructor_ref_2);
      let fly_object_1 = object::object_from_constructor_ref<Fly>(&fly_constructor_ref_1);

      std::debug::print(&view_object(aptoad_object));
      //std::debug::print(&view_object_ztrait(aptoad_ztrait));
      std::debug::print(&view_object(clothing_object_1));
      std::debug::print(&view_object(clothing_ztrait_1));
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
      trait_type: vector<u8>,
      trait_name: vector<u8>,
      num_trait_type: u64,
      negative: bool,
      z_index: u64,
      uri: vector<u8>,
   ): ConstructorRef acquires ZTrait {
      let trait_type = string::utf8(trait_type);
      let trait_name = string::utf8(trait_name);
      let uri = string::utf8(uri);

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
      } else {
         if (type_info::type_of<T>() == type_info::type_of<Clothing>()) {
            move_to( &token_signer, Clothing { } );
         } else if (type_info::type_of<T>() == type_info::type_of<Headwear>()) {
            move_to( &token_signer, Headwear { } );
         } else if (type_info::type_of<T>() == type_info::type_of<Glasses>()) {
            move_to( &token_signer, Glasses { } );
         } else if (type_info::type_of<T>() == type_info::type_of<Tongue>()) {
            move_to( &token_signer, Tongue { } );
         } else if (type_info::type_of<T>() == type_info::type_of<Fly>()) {
            move_to( &token_signer, Fly { } );
         };

         move_to(
            &token_signer,
            ZTrait {
               negative,
               z_index,
               uri,
               trait_name
            }
         );

         let obj_str = view_object_ztrait(object::object_from_constructor_ref<ZTrait>(&constructor_ref));
         std::debug::print(&obj_str);
      };


      constructor_ref
   }


   // still need to do the trait reference thing where it points to a trait uri instead of stores one directly
   // will have to figure out some way to derive a trait uri from a trait
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
      } else {
         abort EINVALID_TYPE
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
   /// This function is necessary because the resource is adjacent to the Generic type data.
   /// an if else statement in view_object will choose the first resource it rus into.
   fun view_object_ztrait<T: key>(obj: Object<T>): String acquires ZTrait {
      let token_address = object::object_address(&obj);
      //string::utils::to_string(borrow_global<T>(token_address))
      string_utils::debug_string(borrow_global<ZTrait>(token_address))
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
   ) acquires Aptoad, Clothing, Headwear, Glasses, Tongue, Fly, ZTrait {
      init_module(owner);
   }

}
