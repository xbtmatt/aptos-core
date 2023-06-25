script {
	fun test_bcs_to_bytes() {
		use std::string::{String};
		let s1 = b"test";
		let s2 = std::bcs::to_bytes<String>(&std::string::utf8(b"test"));
		let s3 = std::bcs::to_bytes<vector<u8>>(&b"test");

		pond::bash_colors::print_key_value(b"s1: ", s1);
		pond::bash_colors::print_key_value(b"s2: ", s2);
		pond::bash_colors::print_key_value(b"s3: ", s3);
	}
}
