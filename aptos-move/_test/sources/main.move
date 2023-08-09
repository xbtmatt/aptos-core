module package::main {
   struct ObjectResource has key {
      value: u64,
   }

   struct Resource has key {
      value: u64,
   }

   /// This is a generic error.
   const EGENERIC_ERROR: u64 = 0;

   #[view]
   public fun view_function(x: u64): u64 {
      x
   }

   public entry fun do_something(y: u64) {
      let _ = y;
   }
}
