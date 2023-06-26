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

   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Aptoad has key {
      background: String,
      body: String,
      clothing: Option<Object<Clothing>>,
      headwear: Option<Object<Headwear>>,
      eyewear: Option<Object<Eyewear>>,
      mouth: Option<Object<Mouth>>,
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
   struct Eyewear has key {
      trait_name: String,
   }
   #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
   struct Mouth has key {
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

	struct TraitImages has key {
		map: SimpleMap<String, SimpleMap<String, String>>,
	}

	const BASE_IMAGE_URI: vector<u8> = b"https://arweave.net/";

   /// Action not authorized because the signer is not the owner of this module
   const ENOT_AUTHORIZED: u64 = 1;
   /// That type doesn't exist on the object
   const ENOT_A_VALID_OBJECT: u64 = 2;
   /// That trait type doesn't exist on the object
   const ENOT_A_VALID_TRAIT_TYPE: u64 = 3;

	public(friend) fun create_aptoad_object(
		v1_token: Token,
		
	): ConstructorRef {

	}

	public(friend) fun create_trait_object(

	): ConstructorRef {

	}

   fun create<T>(
      creator: &signer,
      trait_type: String,
      trait_name: String,
      num_trait_type: u64,
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
               eyewear: option::none(),
               mouth: option::none(),
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
      } else if (type_info::type_of<T>() == type_info::type_of<Eyewear>()) {
         move_to(
            &token_signer,
            Eyewear {
               trait_name,
            }
         );
      } else if (type_info::type_of<T>() == type_info::type_of<Mouth>()) {
         move_to(
            &token_signer,
            Mouth {
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

      //string_utils::debug_string(borrow_global<T>(std::signer::address_of(&token_signer)));

      constructor_ref
   }

   public fun toad_equip_trait<T: key>(owner: &signer, toad_object: Object<Aptoad>, obj_to_equip: Object<T>) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
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
      } else if (exists<Eyewear>(object_address)) {
         let eyewear_obj = object::convert<T, Eyewear>(obj_to_equip);
         option::fill<Object<Eyewear>>(&mut toad_obj_resources.eyewear, eyewear_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Mouth>(object_address)) {
         let mouth_obj = object::convert<T, Mouth>(obj_to_equip);
         option::fill<Object<Mouth>>(&mut toad_obj_resources.mouth, mouth_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      } else if (exists<Fly>(object_address)) {
         let fly_obj = object::convert<T, Fly>(obj_to_equip);
         option::fill<Object<Fly>>(&mut toad_obj_resources.fly, fly_obj);
         object::transfer_to_object(owner, obj_to_equip, toad_object);
      };
      update_uri(toad_object);
   }

   fun update_uri(toad_object: Object<Aptoad>) acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
      let token_object = object::convert<Aptoad, Token>(toad_object);
      let toad_object_resources = borrow_global<Aptoad>(object::object_address(&toad_object));

      let clothing_object = &toad_object_resources.clothing;
      let headwear_object = &toad_object_resources.headwear;
      let eyewear_object = &toad_object_resources.eyewear;
      let mouth_object = &toad_object_resources.mouth;
      let fly_object = &toad_object_resources.fly;

      //let token_name = token::name(token_object);

      std::debug::print(&string_utils::to_string(clothing_object));
      std::debug::print(&string_utils::to_string(headwear_object));
      std::debug::print(&string_utils::to_string(eyewear_object));
      std::debug::print(&string_utils::to_string(mouth_object));
      std::debug::print(&string_utils::to_string(fly_object));




      let mutator_ref = &toad_object_resources.mutator_ref;
      // get address of each trait object, check if it's 1 or 2

      //
      // update uri to coded value
      // c1_h1_g1_t1_f1 == clothing 1, headwear 1, eyewear 1, mouth 1, fly 1
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
   fun view_object<T: key>(obj: Object<T>): String acquires Aptoad, Clothing, Headwear, Eyewear, Mouth, Fly {
      let token_address = object::object_address(&obj);
      if (is_aptoad(obj)) {
         string_utils::debug_string(borrow_global<Aptoad>(token_address))
      } else if (is_clothing(obj)) {
         string_utils::debug_string(borrow_global<Clothing>(token_address))
      } else if (is_headwear(obj)) {
         string_utils::debug_string(borrow_global<Headwear>(token_address))
      } else if (is_eyewear(obj)) {
         string_utils::debug_string(borrow_global<Eyewear>(token_address))
      } else if (is_mouth(obj)) {
         string_utils::debug_string(borrow_global<Mouth>(token_address))
      } else if (is_fly(obj)) {
         string_utils::debug_string(borrow_global<Fly>(token_address))
      } else {
         error::invalid_argument(ENOT_A_VALID_OBJECT)
      }
   }


   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   ///////////////////////                                                                   ///////////////////////
   ///////////////////////                            trait info                             ///////////////////////
   ///////////////////////                                                                   ///////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	#[view]
	public fun is_aptoad<T: key>(obj: Object<T>): bool {
		exists<Aptoad>(object::object_address(&obj))
	}

	#[view]
	public fun is_clothing<T: key>(obj: Object<T>): bool {
		exists<Clothing>(object::object_address(&obj))
	}

	#[view]
	public fun is_headwear<T: key>(obj: Object<T>): bool {
		exists<Headwear>(object::object_address(&obj))
	}

	#[view]
	public fun is_eyewear<T: key>(obj: Object<T>): bool {
		exists<Eyewear>(object::object_address(&obj))
	}

	#[view]
	public fun is_mouth<T: key>(obj: Object<T>): bool {
		exists<Mouth>(object::object_address(&obj))
	}

	#[view]
	public fun is_fly<T: key>(obj: Object<T>): bool {
		exists<Fly>(object::object_address(&obj))
	}

	#[view]
	public fun is_a_trait_type<T: key>(obj: Object<T>): bool acquires Clothing, Headwear, Eyewear, Mouth, Fly {
      is_clothing(obj) || is_headwear(obj) || is_eyewear(obj) || is_mouth(obj) || is_fly(obj)
	}

	#[view]
   public fun trait_type_to_string<T: key>(): String acquires Clothing, Headwear, Eyewear, Mouth, Fly {
      if (is_clothing(obj)) { str(b"Clothing") } else
      if (is_headwear(obj)) { str(b"Headwear") } else
      if (is_eyewear(obj))  { str(b"Eyewear") } else
      if (is_mouth(obj))    { str(b"Mouth") } else
      if (is_fly(obj))      { str(b"Fly") } else
      { error::invalid_argument(ENOT_A_VALID_TRAIT_TYPE) }
	}

	#[view]
   public fun trait_name<T: key>(obj: Object<T>): String acquires Clothing, Headwear, Eyewear, Mouth, Fly {
      if (is_clothing(obj)) {
         borrow_global<Clothing>(token_address).trait_name
      } else if (is_headwear(obj)) {
         borrow_global<Headwear>(token_address).trait_name
      } else if (is_eyewear(obj)) {
         borrow_global<Eyewear>(token_address).trait_name
      } else if (is_mouth(obj)) {
         borrow_global<Mouth>(token_address).trait_name
      } else if (is_fly(obj)) {
         borrow_global<Fly>(token_address).trait_name
      } else {
         error::invalid_argument(ENOT_A_VALID_TRAIT_TYPE)
      }
	}

	inline fun initialize_trait_images(resource_signer: &signer) {
		let resource_addr = signer::address_of(resource_signer);
		move_to(
			resource_signer,
			TraitImages {
				map: simple_map::new_from(
					vector<String> [
						trait_type_to_string<Clothing>,
						trait_type_to_string<Headwear>,
						trait_type_to_string<Eyewear>,
						trait_type_to_string<Mouth>,
						trait_type_to_string<Fly>,
					],
					vector<SimpleMap<String, String>> [
						simple_map::new<String, String>(),
						simple_map::new<String, String>(),
						simple_map::new<String, String>(),
						simple_map::new<String, String>(),
						simple_map::new<String, String>(),
					],
				),
			}
		);

		add_trait_image<Clothing>(resource_addr, str(b"Army Jacket"), str(b"fl3TSX-F2BYnW5X43CFuGh425gX2meDEU99nKp9ucjs"));
		add_trait_image<Clothing>(resource_addr, str(b"ANS Shirt"), str(b"PB4hixtTbNViOK7xPdCNnftEIYpZs6QmEkO17fejm4c"));
		add_trait_image<Clothing>(resource_addr, str(b"Blue Hawaiian"), str(b"Tky5PB6LhbPzmvvg6BeEAFohojwz4LSr4ZqbO-tGwPg"));
		add_trait_image<Clothing>(resource_addr, str(b"Away Jersey"), str(b"5pel5_ExWoka3hwN-o85zRZkTniOIXcE7IgctX1vkwI"));
		add_trait_image<Clothing>(resource_addr, str(b"Blue Snake"), str(b"PB5YB26Qb03PUKf3YQqyDYWUA4IuXvyuwkYTfxlNT8k"));
		add_trait_image<Clothing>(resource_addr, str(b"Black Tux"), str(b"ueuD82oRytF3V4P-Zb52uTsQ1Eq7C_psEL34TT4g-kY"));
		add_trait_image<Clothing>(resource_addr, str(b"Black Tee"), str(b"OsULdUGRvTYrLm4pozZ4zKixWSYxVs6u4LlIu2C_sQY"));
		add_trait_image<Clothing>(resource_addr, str(b"Chef Coat"), str(b"JnzYYLqNE21nTAiLX3uvC6hSkkJdt7QhhRqOaeUssC8"));
		add_trait_image<Clothing>(resource_addr, str(b"Clown Suit"), str(b"fE7FGpTZHWLSLp4jqg1VDiiSJP1mEaImP6uFKyLkr7c"));
		add_trait_image<Clothing>(resource_addr, str(b"Elf Outfit"), str(b"0dGs0ELibF-DoarI_TAihKi6AhpnXeA6uqQno22_wk0"));
		add_trait_image<Clothing>(resource_addr, str(b"Button Down"), str(b"6bC7Ud0P1Sjiy0p6piE61WMA1MnDoobaHDUmWs32XII"));
		add_trait_image<Clothing>(resource_addr, str(b"Blue Suit"), str(b"5GmYUr_tFTmU1sFlyKo6zkH4jHQKrYwrC-vcSPuiCX4"));
		add_trait_image<Clothing>(resource_addr, str(b"Firefighter Jacket"), str(b"LrN7v72POLKtHcs3Js591gvWHFPI7ulX7rU4H8HEniY"));
		add_trait_image<Clothing>(resource_addr, str(b"Geisha Robe"), str(b"HqJ8I7JubPR6IPtvZ2WY-kBJUTGqiXKZyjv7ro5Hz1M"));
		add_trait_image<Clothing>(resource_addr, str(b"Gold Chain"), str(b"sXJ377OCFqXEfXTIjRcycVumefOrbOq5ZU6lmpEvKtE"));
		add_trait_image<Clothing>(resource_addr, str(b"Lab Coat"), str(b"KWeJLYMhNb1N31xjiYsPeI0m1gUL36sUPg8zdc8rRSI"));
		add_trait_image<Clothing>(resource_addr, str(b"King Cloak"), str(b"i0P-TURWVWGep1vFU4ctE2ixzgmAY3IU-uUPQuOlcYE"));
		add_trait_image<Clothing>(resource_addr, str(b"Leather Jacket"), str(b"g737S_YDgOIjz-sg_RoD58fq1bUJX8TBJjw3Ra3UPoc"));
		add_trait_image<Clothing>(resource_addr, str(b"Medal"), str(b"u68SCBzktb2XO9WFd4tyjvzII34tbA4I6NOfeJHBeCQ"));
		add_trait_image<Clothing>(resource_addr, str(b"Money Chain"), str(b"vTXPqhIzTkcvkOjb7zGmQrbzJoFVRw6q265cvsZ39b4"));
		add_trait_image<Clothing>(resource_addr, str(b"Moon Suit"), str(b"L5VtCUxmAGmGMzieGYCUI8TcXirpn_Tc8E0gDlWghVQ"));
		add_trait_image<Clothing>(resource_addr, str(b"Home Jersey"), str(b"COBG_qFKAY7tQzoLtFb2jAmaH0CsuXvo43MnfELMNuc"));
		add_trait_image<Clothing>(resource_addr, str(b"Pilots Garb"), str(b"0TXKM_BsegMklPcmWGzZIxD8QL3HCYsZ9gK5gO0eLqg"));
		add_trait_image<Clothing>(resource_addr, str(b"Pink Fur Jacket"), str(b"9JabJRA1PSDRLnnmIng1JaozWdQEHGnsAkfWBwXtnO0"));
		add_trait_image<Clothing>(resource_addr, str(b"Pirate Outfit"), str(b"x7iygHim7gH-Q5mR0bJdIzyfiQF0TpFIXNcxlTdMEeQ"));
		add_trait_image<Clothing>(resource_addr, str(b"Police Uniform"), str(b"xqvotXy0_R9NR-tR7NbWny0CPd5ZU3CIyJUUkmZnsuE"));
		add_trait_image<Clothing>(resource_addr, str(b"Nobleman"), str(b"dNL13mGS7f9zJxzCj8kvyRU-Cf5zltWT8XaF8jFnXX0"));
		add_trait_image<Clothing>(resource_addr, str(b"Poncho"), str(b"olMeSTEYLWXYYR_vIBiKDJTf9MVng7GUoHkHjwS69QM"));
		add_trait_image<Clothing>(resource_addr, str(b"Prison Jump Suit"), str(b"BfiAvXkZHvl25Gd59eJEWznw4IGP0kjmh68jSE7JmRs"));
		add_trait_image<Clothing>(resource_addr, str(b"Red Snake"), str(b"phIOTkAUYPBFVkqe7TnoGNcaTaoQ1s_smR-JPOXdvBY"));
		add_trait_image<Clothing>(resource_addr, str(b"Red Suit"), str(b"SVCak2U6hyX_xqAmxoWF_OESL-qxdFtSXXE-4PV1jHY"));
		add_trait_image<Clothing>(resource_addr, str(b"Rugby"), str(b"LyTm7xIbRl3dHrFFNtY4VYZr12wSzPze5Ir5QnDlZ6g"));
		add_trait_image<Clothing>(resource_addr, str(b"Sailor Garb"), str(b"PsosfJnBEGJCN-XX4ZKBy0DiwRScDmVDpnCGCC09gEk"));
		add_trait_image<Clothing>(resource_addr, str(b"Thobe"), str(b"tfXDydCcwnGGz5pNKnq7CY5ZwM6iETwBRg07GvVaneM"));
		add_trait_image<Clothing>(resource_addr, str(b"Royal Toga"), str(b"XGjlmniez5zsKv8f_40Z0g6s5JoiQowl6UlsqXpQxJc"));
		add_trait_image<Clothing>(resource_addr, str(b"Warrior Robe"), str(b"zpnv3ML8KDoLBbryEITwe53UnLzZJ7q_uJV199YZMwI"));
		add_trait_image<Clothing>(resource_addr, str(b"Space Suit"), str(b"VMTM5u79q6ObygKYbxM8a54DxZ_83TCRM661OvGo-Yg"));
		add_trait_image<Clothing>(resource_addr, str(b"White Tuxedo"), str(b"tx00esjfAYA8Bakw7PAsOSuuIp98rijcgBxr1esFm_s"));
		add_trait_image<Clothing>(resource_addr, str(b"Wife Beater"), str(b"B0C2VKj4yauUDM8Kar8ZxqWvax11NddOsoXM0mpwQ6U"));
		add_trait_image<Clothing>(resource_addr, str(b"Wizard Cloak"), str(b"cGsamf4K0Ct4CipMAMBT-OVGUUg06_DaNgcnkraBbKY"));
		add_trait_image<Clothing>(resource_addr, str(b"White Fur"), str(b"AtZDBSFxoj7xDFzFHtiOKJ9NtsMOEFe0WinRUEIpNvc"));

		add_trait_image<Eyes>(resource_addr, str(b"3D Glasses"), str(b"WN5MrFJtnPJbFQjoiscaVpEfrUDBuKs4lGCMkukICZ8"));
		add_trait_image<Eyes>(resource_addr, str(b"Cool Shades"), str(b"j1KaALl4rJLFRJAlBDf9Mkr1eKHBsY_zzhKrKOl-jOA"));
		add_trait_image<Eyes>(resource_addr, str(b"Lab Goggles"), str(b"kLmRNUKctYmp-Zhu-ziXWEoGc93SdjjMlx-P04RPeUw"));
		add_trait_image<Eyes>(resource_addr, str(b"Monocle"), str(b"I28d8IwIw4B36wpZ31EjUQZWvqo8bDxEDHgVYLlv-q4"));
		add_trait_image<Eyes>(resource_addr, str(b"Zuck Goggles"), str(b"_98cAzczabiP1qsytzoI36waLxU5LYEgl_quONpdlj4"));

		add_trait_image<Fly>(resource_addr, str(b"Fly"), str(b"-zMtnQIG6_P9aN9MBt0us5rOsISmX-sruARUFCLnitc"));

		add_trait_image<Headwear>(resource_addr, str(b"Black Backwards Cap"), str(b"8ZlKI3UqbHwWPoV8z4aiuLd9n0PxLB6dK6CEp1aNavo"));
		add_trait_image<Headwear>(resource_addr, str(b"Army Hat"), str(b"bDZeLOheNvZuVU5jauDPmNZoCwIW8a6fE0aQJV2wL3s"));
		add_trait_image<Headwear>(resource_addr, str(b"Black Beanie"), str(b"kbNspiiScHz6uQMW1Th5KnZTNRBBIR_4xgPHJaldJuQ"));
		add_trait_image<Headwear>(resource_addr, str(b"Art of War"), str(b"niPMus1-fnCm7BDf4NqwYlmqMlXvLNzKGYEvJhol_XU"));
		add_trait_image<Headwear>(resource_addr, str(b"Blue Bandana"), str(b"OPtp6zViZp7lc8NI6LouYZpCFWHeAw_xeKXaU6SIAFA"));
		add_trait_image<Headwear>(resource_addr, str(b"Blue Baseball Cap"), str(b"UIhBP1KWIAhcHmOO534-0n4s-SfNGk-_k_9Heo9v0hw"));
		add_trait_image<Headwear>(resource_addr, str(b"Captain Hat"), str(b"Gp5-wjbTAwluMQcqsvN68CcpGxn1rXygccQWM7Gn5nA"));
		add_trait_image<Headwear>(resource_addr, str(b"Clown"), str(b"5tKFt7YOSppse5FStHQrJDCJH3AfS0ycVscJsK9MIWc"));
		add_trait_image<Headwear>(resource_addr, str(b"Chef Hat"), str(b"vcDcNjOahrayCOMjn03GUARi6318Qc-3nqduRdZ_JRQ"));
		add_trait_image<Headwear>(resource_addr, str(b"Elf Hat"), str(b"pOyxdYLmjpcdOC3TbFTZLVvWHsnGOmOPEcTbdM-oeEs"));
		add_trait_image<Headwear>(resource_addr, str(b"Cowboy Hat"), str(b"5l2cSX36YsvhPWu7MHRkOrQEPxQjyOCVch7JmWYU8Y0"));
		add_trait_image<Headwear>(resource_addr, str(b"Fez Hat"), str(b"UtRURWX_ZLEF17ZGnH6Ld4sWzgmm_otTWeS0z5bWHTU"));
		add_trait_image<Headwear>(resource_addr, str(b"Flower"), str(b"GKVUloqEbLhMV-VZkvyodszMEeQ9WbdK7-l4_0A3mRY"));
		add_trait_image<Headwear>(resource_addr, str(b"Firefighter Helmet"), str(b"bCrYn4J1MiKqVGV3VZdUHRKs7Im48ZGXFKSe3LcEiAc"));
		add_trait_image<Headwear>(resource_addr, str(b"Headphones"), str(b"m9UC3IgRL0CBWCKqki-J-JFBtQMNPkS1riD0Ba4dU4c"));
		add_trait_image<Headwear>(resource_addr, str(b"King of Kings"), str(b"aEbXuwe2TPk6nman12aGFa2FMH_56MYkZiriiHYj-KI"));
		add_trait_image<Headwear>(resource_addr, str(b"Lily Hat"), str(b"TNF1yUiWXFfUA26KUpDMsAnQbrAlLBTU9OYj8C5FABY"));
		add_trait_image<Headwear>(resource_addr, str(b"Mini Green"), str(b"opF7rmzEOhtUN6WrxArFc0ic8ijNTDiET-sUZubwlYk"));
		add_trait_image<Headwear>(resource_addr, str(b"Mini Purp"), str(b"s_PZuZFbT9ku7zIARwCD2ECoHlN4t6P2sk5yX5gFczU"));
		add_trait_image<Headwear>(resource_addr, str(b"Orange Beanie"), str(b"Lo3fBz8_LZpxsTQPBAAJzJFV8bXXVMBRIryrd5HsHL4"));
		add_trait_image<Headwear>(resource_addr, str(b"Oriental Straw"), str(b"gm7X0dlrwBfIAyMBhZWhrLCAQkhgwJrmF8v0otkL1pM"));
		add_trait_image<Headwear>(resource_addr, str(b"Orange Baseball Cap"), str(b"f0qLCJ0nJOG7r0atLTGpy72vPWZgb5z-B_rC3XAnkQo"));
		add_trait_image<Headwear>(resource_addr, str(b"Pilot"), str(b"iMpKt8AjGxjHWE3xODDJBNWWj8DZo23sVcnLsI4K_6U"));
		add_trait_image<Headwear>(resource_addr, str(b"Pirate Hat"), str(b"ORr_SsLgZ_jVOhKPMbwWOvXUZv2NTUd3PDrpm0RtcTk"));
		add_trait_image<Headwear>(resource_addr, str(b"Pinwheel Hat"), str(b"D4yoXs8HpNepjpGSGvZtje0-BadijNZMK1rVaNyk5lI"));
		add_trait_image<Headwear>(resource_addr, str(b"Prince Crown"), str(b"NK2B6S1HjLUar5s2k-Oi5ZdFGYlE9NIu2m0Hb3q19NY"));
		add_trait_image<Headwear>(resource_addr, str(b"Party Hat"), str(b"a_ZmaoR7FGCrRtfV_Cz3Ac77PGQoUpgbLhUKICcKwC0"));
		add_trait_image<Headwear>(resource_addr, str(b"Red Backwards Cap"), str(b"gtglORKyNlZPvpTJFhV_X6IIEB_SPVUaDQaS3p3Z3Fg"));
		add_trait_image<Headwear>(resource_addr, str(b"Police"), str(b"dAAxFXQMq37scrFM2-U8UQ-b9cmW9ZRQF39M4Po1LVU"));
		add_trait_image<Headwear>(resource_addr, str(b"Roman Wreath"), str(b"khbgtQzWBcRqXo2y1gQVOuK9I5e9Q9eplU5-W-l480k"));
		add_trait_image<Headwear>(resource_addr, str(b"Red Bandana"), str(b"3SUjxXFLZaIJu8QkZYscfFi1Ouomdq6r5XwNih92ncY"));
		add_trait_image<Headwear>(resource_addr, str(b"Sailor Hat"), str(b"XdNV6VrrG-J1rx8mn2W75lDilyuzBBqsdDb-zhm3aQQ"));
		add_trait_image<Headwear>(resource_addr, str(b"Santa"), str(b"F0bxt-FJuNMw4DZQYOefHykK1n3jt9nPpxzEr22nhaU"));
		add_trait_image<Headwear>(resource_addr, str(b"Saudi"), str(b"Ks6PBEo-NLAHYyD33TMXkWHv-qboVFG61BG1Uhgz06A"));
		add_trait_image<Headwear>(resource_addr, str(b"Shounen"), str(b"zWwp0uu2G7p04mMrrvXLCz9HXEymdzTlGiON-4H8NOk"));
		add_trait_image<Headwear>(resource_addr, str(b"Sombrero"), str(b"-8WbLgCY-Fi-SlCo9FF37Xeq3T0QQekovUfL6Wtvdn0"));
		add_trait_image<Headwear>(resource_addr, str(b"Space Helmet"), str(b"GQrGrJHKUOz-YdmhMT0BtfA5I0lDx3WONXwcJM0cqgA"));
		add_trait_image<Headwear>(resource_addr, str(b"Wizard Hat"), str(b"UCij5_1ucvI_ucFacV0L7dFjaWtLFu92mw3YbSt9ClQ"));
		add_trait_image<Headwear>(resource_addr, str(b"Zuck Sauce"), str(b"qTXRZhH5s44OZ21D9BA8DVoWhb4ZNl0I9X5KxE5yjOA"));
		add_trait_image<Headwear>(resource_addr, str(b"Top Hat"), str(b"-f1Kj5mjlKPiu5WdrZFID0UULGf58cVKNwFsExqCX-4"));

		add_trait_image<Mouth>(resource_addr, str(b"Bubble Gum"), str(b"EERf8F0cbtD3zafsub7AblJOIHtUa9os564RaCRt48o"));
		add_trait_image<Mouth>(resource_addr, str(b"Cig"), str(b"Ydb2cJkhRaPig4jO9F9TtiWa8P_6JeqOQdUcPddSi6o"));
		add_trait_image<Mouth>(resource_addr, str(b"Stache"), str(b"D-I3wVyKlvhlQGjdJ01QxGdH0oPKmxCsevD0iN8AYIM"));
		add_trait_image<Mouth>(resource_addr, str(b"Tongue Out"), str(b"uenE8zcM4pE668TSSytOEpl7ugW4aXoYOhm25e3bVew"));
		add_trait_image<Mouth>(resource_addr, str(b"Pipe"), str(b"yyCSHvssH1mXpUh1THiNUGNenVmiDe3bSY7WybTaJ8Q"));
	}

	inline fun add_trait_image<T>(
		resource_addr: address,
		trait_name: String,
		uri: String,
	) acquires TraitImages {
		let base_uri = str(BASE_IMAGE_URI);
		let trait_images = borrow_global_mut<TraitImages>(resource_addr);
		let inner_map = simple_map::borrow_mut(&mut trait_images.map, &trait_type_to_string<T>());
		let full_uri = base_uri;
		string::append_utf8(&mut full_uri, uri);
		simple_map::add(&mut inner_map, trait_name, full_uri);
	}

	inline fun get_trait_image<T>(
		resource_addr: address,
		trait_name: String,
	): String acquires TraitImages {
		let trait_images = borrow_global<TraitImages>(resource_addr);
		let inner_map = simple_map::borrow(&trait_images.map, trait_type_to_string<T>());
		simple_map::borrow(&inner_map, &trait_name)
	}



}
