// This example is intended to display what happens when you create an object with an EventHandle in it
// and delete the object in the same transaction as the Resource deletion that deletes the event handle
//
// We will check the output of the transaction response of the `delete_and_emit` function

module test_examples::delete_object_event_handle {
	//use std::object::{Self, ExtendRef, DeleteRef};
	use std::object::{Self, ConstructorRef, DeleteRef};
	use std::signer;
	use std::option::{Self, Option};
	use std::event::{Self, EventHandle};

	struct ObjectAddress has key {
		addr: address,
	}

	struct SeparateEventHandle has key {
		event_handle: EventHandle<Event>,
	}

    #[resource_group_member(group = aptos_framework::object::ObjectGroup)]
	struct Resource has key {
		// extend_ref: ExtendRef,
		delete_ref: DeleteRef,
		event_handle: EventHandle<Event>,
	}

	struct Event has copy, drop, store {
		value: u64,
	}

	public entry fun init(owner: &signer) acquires ObjectAddress {
		// create object
		// create event handle
		let constructor_ref = object::create_object_from_account(owner);
		let obj_signer = object::generate_signer(&constructor_ref);

		create_obj_resources(owner, &constructor_ref, &obj_signer, option::none());
	}

	fun create_obj_resources(
		owner: &signer,
		constructor_ref: &ConstructorRef,
		obj_signer: &signer,
		event_handle_option: Option<EventHandle<Event>>,
	) acquires ObjectAddress {
		let event_handle = if (option::is_some(&event_handle_option)) {
			option::extract(&mut event_handle_option)
		} else {
			object::new_event_handle(obj_signer)
		};

		move_to(
			obj_signer,
			Resource {
				// extend_ref: object::generate_extend_ref(constructor_ref),
				delete_ref: object::generate_delete_ref(constructor_ref),
				event_handle: event_handle,
			}
		);

		option::destroy_none(event_handle_option);

		let obj_addr = object::address_from_constructor_ref(constructor_ref);
		let owner_addr = signer::address_of(owner);

		if (!exists<ObjectAddress>(owner_addr)) {
			move_to(
				owner,
				ObjectAddress {
					addr: obj_addr,
				}
			);
		} else {
			borrow_global_mut<ObjectAddress>(owner_addr).addr = obj_addr;
		};
	}

	public entry fun emit(owner: &signer) acquires  Resource, ObjectAddress {
		let obj_addr = borrow_global<ObjectAddress>(signer::address_of(owner)).addr;
		let event_handle = &mut borrow_global_mut<Resource>(obj_addr).event_handle;
		event::emit_event(
			event_handle,
			Event {
				value: 0,
			}
		);
	}

	public entry fun delete(owner: &signer) acquires Resource, ObjectAddress {
		let obj_addr = borrow_global<ObjectAddress>(signer::address_of(owner)).addr;
		let Resource {
			// extend_ref: _,
			delete_ref,
			event_handle,
		} = move_from(obj_addr);
		event::emit_event(
			&mut event_handle,
			Event {
				value: 777,
			}
		);
		event::destroy_handle(event_handle);
		object::delete(delete_ref);
	}

	public entry fun delete_event_handle(owner: &signer) acquires Resource, ObjectAddress {
		let obj_addr = borrow_global<ObjectAddress>(signer::address_of(owner)).addr;
		let Resource {
			// extend_ref: _,
			delete_ref: _,
			event_handle,
		} = move_from(obj_addr);
		event::emit_event(
			&mut event_handle,
			Event {
				value: 777,
			}
		);

		event::destroy_handle(event_handle);

		// move_to(
		// 	&object::generate_signer_for_extending(&extend_ref),
		// 	Resource {
		// 		extend_ref,
		// 		delete_ref,
		// 		event_handle,
		// 	}
		// );
		//object::delete(delete_ref);
	}

	public entry fun delete_object(owner: &signer) acquires Resource, ObjectAddress {
		let obj_addr = borrow_global<ObjectAddress>(signer::address_of(owner)).addr;
		let Resource {
			// extend_ref: _,
			delete_ref,
			event_handle,
		} = move_from(obj_addr);
		object::delete(delete_ref);
		let constructor_ref = object::create_object_from_account(owner);
		let obj_signer = object::generate_signer(&constructor_ref);
		create_obj_resources(owner, &constructor_ref, &obj_signer, option::some(event_handle));
	}

}
