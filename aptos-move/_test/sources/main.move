module package::main {
   #[view]
   public fun fee_payer_enabled(): bool {
      std::features::fee_payer_enabled()
   }
}
