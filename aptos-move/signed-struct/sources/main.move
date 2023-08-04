module package::main {
   use std::option::{Self, Option};
   use std::object::{Self, Object};
   use std::string::{Self, String};
   use std::bcs;
   use std::ed25519;

   struct R has key { }

   struct ObjectInfo has key {
      obj: Object<R>,
   }
   struct Resource has key, drop {
      arg_1: u8,
      arg_2: u16,
      arg_3: u32,
      arg_4: u64,
      arg_5: u128,
      arg_6: u256,
      arg_7: bool,
      arg_8: String,
      arg_9: address,
      arg_10: Object<R>,
      arg_11: Option<u8>,
      arg_12: Option<u16>,
      arg_13: Option<u32>,
      arg_14: Option<u64>,
      arg_15: Option<u128>,
      arg_16: Option<u256>,
      arg_17: Option<bool>,
      arg_18: Option<String>,
      arg_19: Option<address>,
      arg_20: vector<u8>,
      arg_21: vector<u16>,
      arg_22: vector<u32>,
      arg_23: vector<u64>,
      arg_24: vector<u128>,
      arg_25: vector<u256>,
      arg_26: vector<bool>,
      arg_27: vector<String>,
      arg_28: vector<address>,
   }


   fun init_module(deployer: &signer) {
      let constructor_ref = object::create_object_from_account(deployer);
      move_to(
         &object::generate_signer(&constructor_ref),
         R {}
      );
      let obj = object::object_from_constructor_ref<R>(&constructor_ref);
      move_to(
         deployer,
         ObjectInfo {
            obj,
         },
      );
   }

   // #[test (deployer = @0x1234)]
   // fun run_test(
   //    deployer: &signer,
   // ) {
   //    test(deployer);
   // }

   /// Quietly succeeds. Needs to be an entry function because #[view] won't serialize the args.
   public entry fun verify_signed_struct(
      sender: &signer,
      signed_struct_bytes: vector<u8>,
      account_public_key_bytes: vector<u8>,
   ) acquires ObjectInfo {
      let resource = create_resource(std::signer::address_of(sender));
      assert!(ed25519::signature_verify_strict_t(
         &ed25519::new_signature_from_bytes(signed_struct_bytes),
         &ed25519::new_unvalidated_public_key_from_bytes(account_public_key_bytes),
         resource,
      ), 0);
   }

   #[view]
   public fun check_bcs_serialization(sender_addr: address, bcs_serialized_resource: vector<u8>): bool acquires ObjectInfo {
      let resource = create_resource(sender_addr);
      let bcs_resource = bcs::to_bytes(&resource);
      bcs_resource == bcs_serialized_resource
   }

   #[view]
   public fun view_bcs_resource(sender_addr: address): vector<u8> acquires ObjectInfo {
      bcs::to_bytes(&create_resource(sender_addr))
   }

   #[view]
   public fun get_obj_addr(): address acquires ObjectInfo {
      object::object_address(&borrow_global<ObjectInfo>(@package).obj)
   }


   inline fun create_resource(sender_addr: address): Resource acquires ObjectInfo {
      let obj = borrow_global<ObjectInfo>(@package).obj;
      Resource {
         arg_1: 8,
         arg_2: 16,
         arg_3: 32,
         arg_4: 64,
         arg_5: 128,
         arg_6: 256,
         arg_7: true,
         arg_8: string::utf8(b"string"),
         arg_9: sender_addr,
         arg_10: obj,
         arg_11: option::some<u8>(8),
         arg_12: option::some<u16>(16),
         arg_13: option::some<u32>(32),
         arg_14: option::some<u64>(64),
         arg_15: option::some<u128>(128),
         arg_16: option::some<u256>(256),
         arg_17: option::some<bool>(true),
         arg_18: option::some<String>(string::utf8(b"string")),
         arg_19: option::some<address>(sender_addr),
         arg_20: vector<u8> [8],
         arg_21: vector<u16> [16],
         arg_22: vector<u32> [32],
         arg_23: vector<u64> [64],
         arg_24: vector<u128> [128],
         arg_25: vector<u256> [256],
         arg_26: vector<bool> [true],
         arg_27: vector<String> [ string::utf8(b"string") ],
         arg_28: vector<address> [sender_addr],
      }
   }
}
