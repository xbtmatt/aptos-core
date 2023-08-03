module package::main {
   use std::option::{Option};
   use std::object::{Object};
   use std::string::{String};
   // use std::vector;
   // use std::account;
   use std::features;

   struct Resource has key {
      arg_1: u8,
      arg_2: u16,
      arg_3: u32,
      arg_4: u64,
      arg_5: u128,
      arg_6: u256,
      arg_7: bool,
      arg_8: String,
      arg_9: address,
      arg_10: Object<u8>,
      arg_11: Object<u16>,
      arg_12: Object<u32>,
      arg_13: Object<u64>,
      arg_14: Object<u128>,
      arg_15: Object<u256>,
      arg_16: Object<bool>,
      arg_17: Object<String>,
      arg_18: Object<address>,
      arg_19: Option<u8>,
      arg_20: Option<u16>,
      arg_21: Option<u32>,
      arg_22: Option<u64>,
      arg_23: Option<u128>,
      arg_24: Option<u256>,
      arg_25: Option<bool>,
      arg_26: Option<String>,
      arg_27: Option<address>,
      arg_28: vector<u8>,
      arg_29: vector<u16>,
      arg_30: vector<u32>,
      arg_31: vector<u64>,
      arg_32: vector<u128>,
      arg_33: vector<u256>,
      arg_34: vector<bool>,
      arg_35: vector<String>,
      arg_36: vector<address>,
   }


   #[view]
   public fun fee_payer_enabled(): bool {
      features::fee_payer_enabled()
   }

   public entry fun big_test(
      _arg_1: u8,
      _arg_2: u16,
      _arg_3: u32,
      _arg_4: u64,
      _arg_5: u128,
      _arg_6: u256,
      _arg_7: bool,
      _arg_8: String,
      _arg_9: address,
      _arg_10: Object<u8>,
      _arg_11: Object<u16>,
      _arg_12: Object<u32>,
      _arg_13: Object<u64>,
      _arg_14: Object<u128>,
      _arg_15: Object<u256>,
      _arg_16: Object<bool>,
      _arg_17: Object<String>,
      _arg_18: Object<address>,
      _arg_19: Option<u8>,
      _arg_20: Option<u16>,
      _arg_21: Option<u32>,
      _arg_22: Option<u64>,
      _arg_23: Option<u128>,
      _arg_24: Option<u256>,
      _arg_25: Option<bool>,
      _arg_26: Option<String>,
      _arg_27: Option<address>,
      _arg_28: vector<u8>,
      _arg_29: vector<u16>,
      _arg_30: vector<u32>,
      _arg_31: vector<u64>,
      _arg_32: vector<u128>,
      _arg_33: vector<u256>,
      _arg_34: vector<bool>,
      _arg_35: vector<String>,
      _arg_36: vector<address>,
   ) {

   }


}
