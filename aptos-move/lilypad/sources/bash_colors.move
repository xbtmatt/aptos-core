module pond::bash_colors {
    use std::string::{Self, String};
	 use std::string::utf8;

	const GREATER_THAN_MAX_INT: u64 		= 0x0;
	const INVALID_DIGIT: u64 				= 0x1;
	const INVALID_COLOR: u64 				= 0x2;
	const EINVALID_INPUT: u64 				= 0x3;

	fun GET_WHITE_FG(): String 			{ utf8(b"\\\\e[97m") }
	fun GET_WHITE_BG(): String 			{ utf8(b"\\\\e[107m") }
	fun GET_BLACK_FG(): String 			{ utf8(b"\\\\e[30m") }
	fun GET_BLACK_BG(): String 			{ utf8(b"\\\\e[40m") }
	fun GET_RED_FG(): String 			{ utf8(b"\\\\e[31m") }
	fun GET_RED_BG(): String 			{ utf8(b"\\\\e[41m") }
	fun GET_GREEN_FG(): String 			{ utf8(b"\\\\e[32m") }
	fun GET_GREEN_BG(): String 			{ utf8(b"\\\\e[42m") }
	fun GET_YELLOW_FG(): String 			{ utf8(b"\\\\e[93m") }
	fun GET_YELLOW_BG(): String 			{ utf8(b"\\\\e[103m") }
	fun GET_MAGENTA_FG(): String 			{ utf8(b"\\\\e[33m") }
	fun GET_MAGENTA_BG(): String 			{ utf8(b"\\\\e[43m") }
	fun GET_BLUE_FG(): String 			{ utf8(b"\\\\e[34m") }
	fun GET_BLUE_BG(): String 			{ utf8(b"\\\\e[44m") }
	fun GET_LIGHT_BLUE_FG(): String 	{ utf8(b"\\\\e[94m") }
	fun GET_LIGHT_BLUE_BG(): String 	{ utf8(b"\\\\e[104m") }
	fun GET_PURPLE_FG(): String 		{ utf8(b"\\\\e[35m") }
	fun GET_PURPLE_BG(): String 		{ utf8(b"\\\\e[45m") }
	fun GET_CYAN_FG(): String 			{ utf8(b"\\\\e[36m") }
	fun GET_CYAN_BG(): String 			{ utf8(b"\\\\e[46m") }
	fun GET_GREY_FG(): String 			{ utf8(b"\\\\e[37m") }
	fun GET_GREY_BG(): String 			{ utf8(b"\\\\e[47m") }
	fun GET_NORMAL(): String 		{ utf8(b"\\\\e[0m") }
	fun GET_BOLD(): String 			{ utf8(b"\\\\e[1m") }
	fun GET_UNDERLINED(): String 			{ utf8(b"\\\\e[4m") }
	fun GET_BLINKING(): String 			{ utf8(b"\\\\e[5m") }
	fun GET_REVERSE_VIDEO(): String 		{ utf8(b"\\\\e[7m") }

	//	debug::print(&bash_colors::bcolor(b"green", v));
	// aptos move test | aptos-pprint | xargs -I {} echo -e {}

	public fun bcolor(color: vector<u8>, s: vector<u8>): String {
		color(color, utf8(s))
	}

	public fun bcolor_bg(color: vector<u8>, s: vector<u8>): String {
		color_bg(color, utf8(s))
	}

	// color = "black", "red", etc
	public fun color(color: vector<u8>, s: String): String {
		let str: String = utf8(b"");
		if (color == b"white") 				{ str = wrap(GET_WHITE_FG(), s, GET_NORMAL()); };
		if (color == b"black") 				{ str = wrap(GET_BLACK_FG(), s, GET_NORMAL()); };
		if (color == b"red") 				{ str = wrap(GET_RED_FG(), s, GET_NORMAL()); };
		if (color == b"green") 				{ str = wrap(GET_GREEN_FG(), s, GET_NORMAL()); };
		if (color == b"yellow") 			{ str = wrap(GET_YELLOW_FG(), s, GET_NORMAL()); };
		if (color == b"magenta") 			{ str = wrap(GET_MAGENTA_FG(), s, GET_NORMAL()); };
		if (color == b"pink")	 			{ str = wrap(GET_MAGENTA_FG(), s, GET_NORMAL()); };
		if (color == b"blue") 				{ str = wrap(GET_BLUE_FG(), s, GET_NORMAL()); };
		if (color == b"lightblue") 		{ str = wrap(GET_LIGHT_BLUE_FG(), s, GET_NORMAL()); };
		if (color == b"purple") 			{ str = wrap(GET_PURPLE_FG(), s, GET_NORMAL()); };
		if (color == b"cyan") 				{ str = wrap(GET_CYAN_FG(), s, GET_NORMAL()); };
		if (color == b"grey") 				{ str = wrap(GET_GREY_FG(), s, GET_NORMAL()); };
		if (color == b"normal") 			{ str = wrap(GET_NORMAL(), s, GET_NORMAL()); };
		if (color == b"bold") 				{ str = wrap(GET_BOLD(), s, GET_NORMAL()); };
		if (color == b"underlined") 		{ str = wrap(GET_UNDERLINED(), s, GET_NORMAL()); };
		if (color == b"blinking") 			{ str = wrap(GET_BLINKING(), s, GET_NORMAL()); };
		if (color == b"reverse_video") 	{ str = wrap(GET_REVERSE_VIDEO(), s, GET_NORMAL()); };
		if (str == utf8(b"")) { abort INVALID_COLOR };
		str
	}

	public fun color_bg(color: vector<u8>, s: String): String {
		let str: String = utf8(b"");
		if (color == b"white") 			{ str = wrap(GET_WHITE_BG(), s, GET_NORMAL()); };
		if (color == b"black") 			{ str = wrap(GET_BLACK_BG(), s, GET_NORMAL()); };
		if (color == b"red") 			{ str = wrap(GET_RED_BG(), s, GET_NORMAL()); };
		if (color == b"green") 			{ str = wrap(GET_GREEN_BG(), s, GET_NORMAL()); };
		if (color == b"yellow") 		{ str = wrap(GET_YELLOW_BG(), s, GET_NORMAL()); };
		if (color == b"magenta") 		{ str = wrap(GET_MAGENTA_BG(), s, GET_NORMAL()); };
		if (color == b"pink")	 		{ str = wrap(GET_MAGENTA_BG(), s, GET_NORMAL()); };
		if (color == b"blue") 			{ str = wrap(GET_BLUE_BG(), s, GET_NORMAL()); };
		if (color == b"lightblue") 	{ str = wrap(GET_LIGHT_BLUE_BG(), s, GET_NORMAL()); };
		if (color == b"purple") 		{ str = wrap(GET_PURPLE_BG(), s, GET_NORMAL()); };
		if (color == b"cyan") 			{ str = wrap(GET_CYAN_BG(), s, GET_NORMAL()); };
		if (color == b"grey") 			{ str = wrap(GET_GREY_BG(), s, GET_NORMAL()); };
		if (str == utf8(b"")) { abort INVALID_COLOR };
		str
	}

	public fun wrap(beginning: String, s: String, end: String): String {
		let w: String = beginning;
		string::append(&mut w, s);
		string::append(&mut w, end);
		w
	}

/*
	//const U64_MAX: u64 = 18446744073709551615;
	public fun string_to_u64(s: String): u64 {
		use std::vector::{Self};
		// NOTE: this means we wouldn't be able to parse anything over 9999999999999999999 instead of 18446744073709551615
		assert!(string::length(&s) < 20, GREATER_THAN_MAX_INT);

		let number = 0;

		let lsb = 1;
		let bytes = *string::bytes(&s);
		while(vector::length(&bytes) > 0) {
			let char = vector::pop_back(&mut bytes);
			assert!(char >= 48 && char <= 57, INVALID_DIGIT);
			let digit = (char as u64) - 48;

			number = number + (digit * (lsb));
			lsb = lsb * 10;
		};

		number
	}
*/

	public fun hex_to_u64() { }

	// const MAX_U64: u64 = 18446744073709551615;
	public fun u64_to_string(n: u64): String {
		if (n == 0) { utf8(b"0") }
		else {
			let s: String = utf8(b"");
			while (n > 0) {
				let digit = n % 10;
				let r = if (digit == 9) { utf8(b"9") }
					else if (digit == 8) { utf8(b"8") }
					else if (digit == 7) { utf8(b"7") }
					else if (digit == 6) { utf8(b"6") }
					else if (digit == 5) { utf8(b"5") }
					else if (digit == 4) { utf8(b"4") }
					else if (digit == 3) { utf8(b"3") }
					else if (digit == 2) { utf8(b"2") }
					else if (digit == 1) { utf8(b"1") }
					else if (digit == 0) { utf8(b"0") }
					else { abort INVALID_DIGIT };

				string::append(&mut r, s);
				n = (n - digit) / 10;
				s = r;
			};

			s
		}
	}

	fun address_to_bytes(input: address): vector<u8> {
		use std::vector::{Self};
		use std::bcs::{Self};
		let bytes = bcs::to_bytes<address>(&input);
		let i = 0;
		let result = vector::empty<u8>();
		while (i < vector::length<u8>(&bytes)) {
			vector::append(&mut result, u8_to_hex(*vector::borrow<u8>(&bytes, i)));
			i = i + 1;
		};
		result
	}

	fun address_to_string(input: address): string::String {
		use std::vector::{Self};
		use std::bcs::{Self};
		let bytes = bcs::to_bytes<address>(&input);
		let i = 0;
		let result = vector::empty<u8>();
		while (i < vector::length<u8>(&bytes)) {
			vector::append(&mut result, u8_to_hex(*vector::borrow<u8>(&bytes, i)));
			i = i + 1;
		};
		string::utf8(result)
	}
	fun u8_to_hex(input: u8): vector<u8> {
		use std::vector::{Self};
		let result = vector::empty<u8>();
		vector::push_back(&mut result, u4_to_hex(input / 16));
		vector::push_back(&mut result, u4_to_hex(input % 16));
		//string::utf8(result)
		result
	}

	fun u4_to_hex(input: u8): u8 {
		assert!(input<=15, EINVALID_INPUT);
		if (input<=9) (48 + input) // 0 - 9 => ASCII 48 to 57
		//else (55 + input) //10 - 15 => ASCII 65 to 70
		else (55 + (97 - 65) + input) // use lowercase, ASCII 97 => 102
	}

	public fun join_bytes(b: vector<vector<u8>>, delimiter: String): String {
		use std::vector;
		let i = 0;
		let len = vector::length(&b);
		let s = utf8(b"");
		while(i < len - 1) {
			string::append(&mut s, string::utf8(*vector::borrow(&b, i)));
			string::append(&mut s, delimiter);
			i = i + 1;
		};
		string::append(&mut s, string::utf8(*vector::borrow(&b, len - 1)));

		(s)
	}

	public fun join(strings: vector<String>, delimiter: String): String {
		use std::vector;
		let i = 0;
		let len = vector::length(&strings);
		let s = utf8(b"");
		while(i < len - 1) {
			string::append(&mut s, *vector::borrow(&strings, i));
			string::append(&mut s, delimiter);
			i = i + 1;
		};
		string::append(&mut s, *vector::borrow(&strings, len - 1));

		(s)
	}


	public fun bool_to_string(b: bool): vector<u8> {
		if (b) {
			b"true"
		} else {
			b"false"
		}
	}

	public fun bool_to_string_as_string(b: bool): String {
		std::string::utf8(bool_to_string(b))
	}

	public fun print_key_value(k: vector<u8>, v: vector<u8>) {
		use std::debug::{Self};
		let s: String = bcolor(b"lightblue", k);
		string::append(&mut s, bcolor(b"yellow", v));
		debug::print(&s);
	}

	public fun print_key_value_as_string(k: vector<u8>, v: String) {
		use std::debug::{Self};
		let s: String = bcolor(b"lightblue", k);
		string::append(&mut s, color(b"yellow", v));
		debug::print(&s);
	}

	public fun print_key_value_as_u64(k: vector<u8>, v: u64) {
		use std::debug::{Self};
		let s: String = bcolor(b"lightblue", k);
		string::append(&mut s, color(b"yellow", u64_to_string(v)));
		debug::print(&s);
	}

	public fun print_key_value_as_address(k: vector<u8>, v: address) {
		use std::debug::{Self};
		let s: String = bcolor(b"lightblue", k);
		string::append(&mut s, color(b"yellow", address_to_string(v)));
		debug::print(&s);
	}

	public fun print_bytes(s: vector<u8>) {
		use std::debug::{Self};
		debug::print(&string::utf8(s));
	}

	public fun print(s: String) {
		use std::debug::{Self};
		debug::print(&s);
	}

	#[test]
	fun test_print_address() {
		let address = @pond;
		print_key_value_as_string(b"@pond: ", address_to_string(address));
	}

}
