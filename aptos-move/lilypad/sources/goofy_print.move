module pond::printer {
	 use aptos_std::simple_map::{Self, SimpleMap};
    use std::string::{String};
    use std::signer;

	struct Printer has key {
		info: SimpleMap<u64, String>,
	}

	public entry fun goofy_print(
		writer: &signer,
		s: String,
	) acquires Printer {
		let writer_addr = signer::address_of(writer);
		if (!exists<Printer>(writer_addr)) {
			move_to(
				writer,
				Printer {
					info: simple_map::create(),
				},
			);
		};

		let printer = &mut borrow_global_mut<Printer>(writer_addr).info;
		let len = simple_map::length(printer);
		simple_map::add(printer, len, s);
	}
}
