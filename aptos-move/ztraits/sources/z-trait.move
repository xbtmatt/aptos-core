module ztraits::ztrait {
	use std::object::{Self, Object};
	use std::string::{String};

	#[resource_group_member(group = object::ObjectGroup)]
   struct ZTrait has key {
      negative: bool,
      z_index: u64,
		uri: String,
		trait_name: String,
   }

	public fun add_ztrait_to_object<T>(
		_obj: Object<T>,
	) { //acquires ZTrait {
		// ? idk
	}

}
