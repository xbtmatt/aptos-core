module test_examples::input_test {
    use std::string::{String};
    use aptos_std::string_utils;

    public entry fun test_vector_u8(v: vector<u8>) {
        let _ = v;
    }

    #[view]
    public fun two_strings(s1: String, s2: String): String {
        string_utils::format2(&b"{}::{}", s1, s2)
    }
}
