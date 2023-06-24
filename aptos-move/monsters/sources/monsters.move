module monsters::synthesis {
   use std::object::{Self, Object, ConstructorRef, ExtendRef};
   use token_objects::token::{Self, MutatorRef};
   use token_objects::collection::{Self, Collection};
   use token_objects::royalty::{Royalty};
   use std::string::{Self, String};
   use std::option::{Self, Option};
   use aptos_std::string_utils;
	use aptos_std::type_info;
   //use std::vector;

   //#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
	struct Monster<phantom T0, phantom T1> has key {
		jelly_core: JellyCore<T0>,
		joose_core: JooseCore<T1>,
		extend_ref: ExtendRef,
		mutator_ref: MutatorRef,
	}

   //#[resource_group_member(group = aptos_framework::object::ObjectGroup)]
	struct Monstrum<phantom T0, phantom T1> has key {
		jelly_core: JellyCore<T0>,
		joose_core: Option<JooseCore<T1>>,
		extend_ref: ExtendRef,
		mutator_ref: MutatorRef,
	}

	struct Cauldron<phantom T> has key {
		joose_core: JooseCore<T>,
	}

	struct JellyCore<phantom T> has store, drop { }
	struct JooseCore<phantom T> has store, drop { }

	/*

	we mint 1 Mint Monstrum
	it has a type Ferocious, Swift, Adaptive, or Solid
	let's call this type T0
	image == monstrum of type T0

	then we infuse it with a JooseCore. We submerge/incubate into the Cauldron with the JooseCore
	let's call this type T1
	image == Joose of type T1

	when we infuse it, it automatically creates a monster.
	This results in: a monster of type T0, T1
	image == Monster of type T0, T1       12 images

	You now have a monster of 2 core types, jelly and joose

	*/


	struct Solid has drop, store { }
	struct Swift has drop, store { }
	struct Adaptive has drop, store { }
	struct Ferocious has drop, store { }

	struct None has drop, store { }
	struct Earth has drop, store { }
	struct Water has drop, store { }
	struct Fire has drop, store { }

	struct Comparison<phantom T0, phantom T1, phantom T2, phantom T3> { }

   /// That type doesn't exist on the object
   const EINVALID_TYPE: u64 = 0;

   const COLLECTION_NAME: vector<u8> = b"Mojo Mayhem";
   const COLLECTION_DESCRIPTION: vector<u8> = b"A bunch of monsters.";
   const TOKEN_DESCRIPTION: vector<u8> = b"A monster or monstrum or cauldron.";
   const COLLECTION_URI: vector<u8> = b"https://monsters.nyc3.digitaloceanspaces.com/images/perfects/pilot.png";
   const BASE_TOKEN_NAME: vector<u8> = b"{} #{}";
   const BASE_TOKEN_URI: vector<u8> = b"https://monsters.nyc3.digitaloceanspaces.com/images/";
   const MAXIMUM_SUPPLY: u64 = 1000;

	fun init_module(creator: &signer) acquires Monstrum, Monster, Cauldron {
      collection::create_fixed_collection(
         creator,
         string::utf8(COLLECTION_DESCRIPTION),
         MAXIMUM_SUPPLY,
         string::utf8(COLLECTION_NAME),
         option::none<Royalty>(),
         string::utf8(COLLECTION_URI),
      );

		let monstrum_image_uri = string::utf8(b"image.uri//");
		let monstrum_constructor_ref = create_monstrum<Ferocious, None>(creator, string::utf8(b"Monstrum #1"), monstrum_image_uri);
		let monstrum_object = object::object_from_constructor_ref<Monstrum<Ferocious, None>>(&monstrum_constructor_ref);

		let fire_cauldron_image_uri = string::utf8(b"image.uri//");
		let fire_cauldron_constructor_ref = create_cauldron<Fire>(creator, string::utf8(b"Fire Cauldron #1"), fire_cauldron_image_uri);
		let fire_cauldron_object = object::object_from_constructor_ref<Cauldron<Fire>>(&fire_cauldron_constructor_ref);

		let water_cauldron_image_uri = string::utf8(b"image.uri//");
		let water_cauldron_constructor_ref = create_cauldron<Water>(creator, string::utf8(b"Water Cauldron #1"), water_cauldron_image_uri);
		let water_cauldron_object = object::object_from_constructor_ref<Cauldron<Water>>(&water_cauldron_constructor_ref);

		let earth_cauldron_image_uri = string::utf8(b"image.uri//");
		let earth_cauldron_constructor_ref = create_cauldron<Earth>(creator, string::utf8(b"Earth Cauldron #1"), earth_cauldron_image_uri);
		let earth_cauldron_object = object::object_from_constructor_ref<Cauldron<Earth>>(&earth_cauldron_constructor_ref);

		infuse_monstrum( creator, monstrum_object, fire_cauldron_object);
		0x1::debug::print(&token::name(monstrum_object));
		let monster_object = object::convert<Monstrum<Ferocious, None>, Monster<Ferocious, Fire>>(monstrum_object);
		0x1::debug::print(&token::name(monster_object));
		infuse_monster( creator, monster_object, water_cauldron_object);
		let monster_object = object::convert<Monster<Ferocious, Fire>, Monster<Ferocious, Water>>(monster_object);
		infuse_monster( creator, monster_object, earth_cauldron_object);
		let monster_object = object::convert<Monster<Ferocious, Water>, Monster<Ferocious, Earth>>(monster_object);
		//std::debug::print(&view_object(monstrum_object));
		0x1::debug::print(&token::name(monster_object));

		let monstrum_image_uri = string::utf8(b"image.uri//");
		let monstrum_constructor_ref = create_monstrum<Ferocious, None>(creator, string::utf8(b"Monstrum #2"), monstrum_image_uri);
		let solid_water_monstrum_object = object::object_from_constructor_ref<Monstrum<Ferocious, None>>(&monstrum_constructor_ref);
		0x1::debug::print(&token::name(solid_water_monstrum_object));

		infuse_monstrum( creator, solid_water_monstrum_object, water_cauldron_object );
		let solid_water_monstrum_object = object::convert<Monstrum<Ferocious, None>, Monster<Ferocious, Water>>(solid_water_monstrum_object);

		0x1::debug::print(&token::name(solid_water_monstrum_object));


		0x1::debug::print(&string_utils::format2(&b"monster #1 name: {}, object address: {}", token::name(monster_object), object::object_address(&monster_object)));
		0x1::debug::print(&string_utils::format2(&b"monster #2 name: {}, object address: {}", token::name(solid_water_monstrum_object), object::object_address(&solid_water_monstrum_object)));

		let bred_monster_addr = breed(
			creator,
			&monster_object,
			&solid_water_monstrum_object,
			string::utf8(b"uri")
		);
		0x1::debug::print(&bred_monster_addr);
		//let bred_adaptive_fire_monster = object::address_to_object<Monster<Adaptive, Fire>>(bred_monster_addr);
		//0x1::debug::print(&bred_adaptive_fire_monster);
		//0x1::debug::print(&string_utils::format2(&b"monster #3 name: {}, object address: {}", token::name(bred_adaptive_fire_monster), bred_monster_addr));
	}

	fun create_monstrum<T0, T1>(
		creator: &signer,
		name: String,
		token_uri: String,
	): ConstructorRef {
		let constructor_ref = token::create_named_token(
			creator,
			string::utf8(COLLECTION_NAME),
			string::utf8(TOKEN_DESCRIPTION),
			name,
			option::none(),
			token_uri,
		);
		let token_signer = object::generate_signer(&constructor_ref);
		let extend_ref = object::generate_extend_ref(&constructor_ref);
		let mutator_ref = token::generate_mutator_ref(&constructor_ref);

		move_to(
			&token_signer,
			Monstrum<T0, T1> {
				jelly_core: JellyCore<T0> { },
				joose_core: option::some(JooseCore<T1> { }),
				extend_ref,
				mutator_ref,
			}
		);

		constructor_ref
	}

	fun create_cauldron<T>(
		creator: &signer,
		name: String,
		token_uri: String,
	): ConstructorRef {
		let constructor_ref = token::create_named_token(
			creator,
			string::utf8(COLLECTION_NAME),
			string::utf8(TOKEN_DESCRIPTION),
			name,
			option::none(),
			token_uri,
		);
		let token_signer = object::generate_signer(&constructor_ref);

		move_to(
			&token_signer,
			Cauldron<T> {
				joose_core: JooseCore<T> { },
			}
		);

		constructor_ref
	}

	fun breed<T0, T1, T2, T3>(
		creator: &signer,
		_monster1: &Object<Monster<T0, T1>>,
		_monster2: &Object<Monster<T2, T3>>,
		token_uri: String,
	): address {

		// struct Solid has drop, store { }
		// struct Swift has drop, store { }
		// struct Adaptive has drop, store { }
		// struct Ferocious has drop, store { }

		// struct Earth has drop, store { }
		// struct Water has drop, store { }
		// struct Fire has drop, store { }

		let collection_addr = collection::create_collection_address(&0x1::signer::address_of(creator), &string::utf8(COLLECTION_NAME));
		let _collection_object = object::address_to_object<Collection>(collection_addr);

		let constructor_ref = token::create_named_token(
			creator,
			string::utf8(COLLECTION_NAME),
			string::utf8(TOKEN_DESCRIPTION),
			string::utf8(b"Monster #3"),//string_utils::format1(&b"Monster #", option::some(collection::count(collection_object))),
			option::none(),
			token_uri,
		);

		let token_signer = object::generate_signer(&constructor_ref);
		let extend_ref = object::generate_extend_ref(&constructor_ref);
		let mutator_ref = token::generate_mutator_ref(&constructor_ref);

		if (type_info::type_of<Comparison<T0, T1, T2, T3>>() == type_info::type_of<Comparison<Solid, Earth, Solid, Earth>>()) {
			move_to(
				&token_signer,
				Monster<Solid, Earth> {
					jelly_core: JellyCore<Solid> { },
					joose_core: JooseCore<Earth> { },
					extend_ref,
					mutator_ref,
				}
			);
		} else {// if (type_info::type_of<Comparison<T0, T1, T2, T3>>() == type_info::type_of<Comparison<Ferocious, Water, Ferocious, Earth>>()) {
			move_to(
				&token_signer,
				Monster<Adaptive, Fire> {
					jelly_core: JellyCore<Adaptive> { },
					joose_core: JooseCore<Fire> { },
					extend_ref,
					mutator_ref,
				}
			);
		};

		0x1::signer::address_of(&token_signer)
	}

	fun infuse_monstrum<T0, T1, T2>(
		creator: &signer,
		monstrum: Object<Monstrum<T0, T1>>,
		cauldron: Object<Cauldron<T2>>,
	) acquires Monstrum, Monster, Cauldron {
		let _ = 0x1::signer::address_of(creator);

		let monstrum_addr = object::object_address(&monstrum);
		let monstrum_object_resource = borrow_global<Monstrum<T0, T1>>(monstrum_addr);
		let extend_ref = &monstrum_object_resource.extend_ref;
		let token_signer = object::generate_signer_for_extending(extend_ref);

	 //////////////// instead of doing a move_from for each specific type of type info, just do a generic
	 // move from for T0, T1, and then move_to(token_signer, )

		if (type_info::type_of<T1>() == type_info::type_of<T2>()) {
			return
		} else {
			// delete the Monstrum resource with T1 typing, capture old jelly_core and extend_ref
			let Monstrum<T0, T1> {
				jelly_core,
				joose_core: _,
				extend_ref,
				mutator_ref,
			} = move_from<Monstrum<T0, T1>>(monstrum_addr);

			// TODO: make this based off of actual name, need #[view] fun index(...) in token.move!
			//let token_monstrum_object = object::convert<Monstrum<T0, T1>, Token>(monstrum);
			let token_name = if (token::name(monstrum) == string::utf8(b"Monstrum #1")) {
				string::utf8(b"Monster #1")
			} else if (token::name(monstrum) == string::utf8(b"Monstrum #2")) {
				string::utf8(b"Monster #2")
			} else {
				abort 12345
			};

			token::set_name(&mutator_ref, token_name);

			// create a new Monster resource with the T0, T2 typing and extend_ref into Monstrum at same object address.
			move_to(
				&token_signer,
				Monster<T0, T2> {
					jelly_core,
					joose_core: JooseCore<T2> { },
					extend_ref,
					mutator_ref,
				}
			);
			// the Monstrum<T0, T1> object has now been converted to a Monster<T0, T2> object
		};


		if (type_info::type_of<T0>() == type_info::type_of<Ferocious>()) {
			//std::debug::print(&string::utf8(b"ferocious type!"));
		};
		if (exists<Monster<T0, T2>>(monstrum_addr)) {
			let s = string_utils::debug_string(borrow_global<Monster<T0, T2>>(monstrum_addr));
			std::debug::print(&s);
		};

		let cauldron_addr = object::object_address(&cauldron);
		if (exists<Cauldron<T2>>(cauldron_addr)) {
			let _s = string_utils::debug_string(borrow_global<Cauldron<T2>>(cauldron_addr));
			//std::debug::print(&s);
		}
	}

	fun infuse_monster<T0, T1, T2>(
		creator: &signer,
		monstrum: Object<Monster<T0, T1>>,
		cauldron: Object<Cauldron<T2>>,
	) acquires Monster, Cauldron {
		let _ = 0x1::signer::address_of(creator);

		let monstrum_addr = object::object_address(&monstrum);
		let monstrum_object_resource = borrow_global<Monster<T0, T1>>(monstrum_addr);
		let extend_ref = &monstrum_object_resource.extend_ref;
		let token_signer = object::generate_signer_for_extending(extend_ref);

		if (type_info::type_of<T1>() == type_info::type_of<T2>()) {
			return
		} else {
			// delete the Monster resource with T1 typing, capture old jelly_core and extend_ref
			let Monster<T0, T1> {
				jelly_core,
				joose_core: _,
				extend_ref,
				mutator_ref,
			} = move_from<Monster<T0, T1>>(monstrum_addr);

			// create a new Monster resource with the T0, T2 typing and extend_ref into Monstrum at same object address.
			move_to(
				&token_signer,
				Monster<T0, T2> {
					jelly_core,
					joose_core: JooseCore<T2> { },
					extend_ref,
					mutator_ref,
				}
			);
			// the Monster<T0, T1> object has now been converted to a Monster<T0, T2> object
		};

		if (type_info::type_of<T0>() == type_info::type_of<Ferocious>()) {
			//std::debug::print(&string::utf8(b"ferocious type!"));
		};
		if (exists<Monster<T0, T2>>(monstrum_addr)) {
			let s = string_utils::debug_string(borrow_global<Monster<T0, T2>>(monstrum_addr));
			std::debug::print(&s);
		};

		let cauldron_addr = object::object_address(&cauldron);
		if (exists<Cauldron<T2>>(cauldron_addr)) {
			let _s = string_utils::debug_string(borrow_global<Cauldron<T2>>(cauldron_addr));
			//std::debug::print(&s);
		}
	}

	fun rand_range(start: u64, end: u64): u64 {
		assert!(end > start, 123456);
		let now = 0x1::timestamp::now_microseconds();
		let range = end - start;
		assert!(now > range, 1234567);
		let modulo = now % range;
		range + modulo
	}

   #[test(owner = @monsters)]
   fun test(
      owner: &signer,
   ) acquires Monstrum, Monster, Cauldron {
      init_module(owner);
   }


}
