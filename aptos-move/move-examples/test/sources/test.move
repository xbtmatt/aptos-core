module test::test {
	use std::object;

	#[view]
	public fun test_u64(n: u64): u64 {
		n
	}

	#[view]
	public fun test_object_creation(): address {
		let constructor_ref = object::create_object(@test);
		object::address_from_constructor_ref(&constructor_ref)
	}

	#[test]
	fun testy() {
		std::debug::print(&test_object_creation());
	}

}
