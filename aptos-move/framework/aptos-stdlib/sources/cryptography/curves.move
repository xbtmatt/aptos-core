module aptos_std::curves {
    use std::option::Option;

    // Error codes
    const E_NATIVE_FUN_NOT_AVAILABLE: u64 = 1;

    /// A phantom type that represents the 1st pairing input group `G1` in BLS12-381 pairing.
    ///
    /// In BLS12-381, a finite field `Fq` is used, where
    /// `q` equals to 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab.
    /// A curve `E(Fq)` is defined as `y^2=x^3+4` over `Fq`.
    /// `G1` is formed by a subset of points on `E(Fq)`.
    /// `G1` has a prime order `r` with value 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001.
    ///
    /// A `Scalar<BLS12_381_G1>` is an integer between 0 and `r-1`.
    ///
    /// Function `scalar_from_bytes<BLS12_381_G1>` and `scalar_to_bytes<BLS12_381_G1>`
    /// assumes a 32-byte little-endian encoding of a `Scalar<BLS12_381_G1>`.
    ///
    /// An `Element<BLS12_381_G1>` is an element in `G1`.
    ///
    /// Function `serialize_element_uncompressed<BLS12_381_G1>` and `deserialize_element_uncompressed<BLS12_381_G1>`
    /// assumes a 96-byte encoding `[b_0, ..., b_95]` of an `Element<BLS12_381_G1>`, with the following rules.
    /// - `b_95 & 0x40` is the infinity flag.
    /// - The infinity flag is 1 if and only if the element is the point at infinity.
    /// - The infinity flag is 0 if and only if the element is a point `(x,y)` on curve `E(Fq)`, with the following rules.
    ///     - `[b_0, ..., b_47 & 0x3f]` is a 48-byte little-endian encoding of `x`.
    ///     - `[b_48, ..., b_95 & 0x3f]` is a 48-byte little-endian encoding of 'y'.
    ///
    /// Function `serialize_element_compressed<BLS12_381_G1>` and `deserialize_element_compressed<BLS12_381_G1>`
    /// assumes a 48-byte encoding `[b_0, ..., b_47]` of an `Element<BLS12_381_G1>` with the following rules.
    /// - `b_47 & 0x40` is the infinity flag.
    /// - The infinity flag is 1 if and only if the element is the point at infinity.
    /// - The infinity flag is 0 if and only if the element is a point `(x,y)` on curve, with the following rules.
    ///     - `[b_0, ..., b_47 & 0x3f]` is a 48-byte little-endian encoding of `x`.
    ///     - `b_47 & 0x80` is the positiveness flag.
    ///     - The positiveness flag is 1 if and only if `y > -y`.
    struct BLS12_381_G1 {}

    /// A phantom type that represents the 2nd pairing input group `G2` in BLS12-381 pairing.
    ///
    /// In BLS12-381, a finite field `Fq` is used, where
    /// `q` equals to 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab.
    /// `Fq2=Fq[u]/(u^2+1)` is a quadratic extension of `Fq`.
    /// A curve `E(Fq2)` is defined as `y^2=x^3+4(u+1)` over `Fq2`.
    /// `G2` is formed by a subset of points on `E(Fq2)`.
    /// `G2` has a prime order `r` with value 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001.
    ///
    /// A `Scalar<BLS12_381_G2>` is an integer between 0 and `r-1`.
    ///
    /// Function `scalar_from_bytes<BLS12_381_G2>` and `scalar_to_bytes<BLS12_381_G2>`
    /// assumes a 32-byte little-endian encoding of a `Scalar<BLS12_381_G2>`.
    ///
    /// An `Element<BLS12_381_G2>` is an element in `G2`.
    ///
    /// Function `serialize_element_uncompressed<BLS12_381_G2>` and `deserialize_element_uncompressed<BLS12_381_G2>`
    /// assumes a 192-byte encoding `[b_0, ..., b_191]` of an `Element<BLS12_381_G2>`, with the following rules.
    /// - `b_191 & 0x40` is the infinity flag.
    /// - The infinity flag is 1 if and only if the element is the point at infinity.
    /// - The infinity flag is 0 if and only if the element is a point `(x,y)` on curve `E(Fq2)`, with the following rules.
    ///     - `[b_0, ..., b_95]` is a 96-byte encoding of `x=(x_0+x_1*u)`.
    ///         - `[b_0, ..., b_47]` is a 48-byte little-endian encoding of `x_0`.
    ///         - `[b_48, ..., b_95]` is a 48-byte little-endian encoding of `x_1`.
    ///     - `[b_96, ..., b_191 & 0x3f]` is a 96-byte encoding of 'y=(y_0+y_1*u)'.
    ///         - `[b_96, ..., b_143]` is a 48-byte little-endian encoding of `y_0`.
    ///         - `[b_144, ..., b_191 & 0x3f]` is a 48-byte little-endian encoding of `y_1`.
    ///
    /// Function `serialize_element_compressed<BLS12_381_G2>` and `deserialize_element_compressed<BLS12_381_G2>`
    /// assumes a 96-byte encoding `[b_0, ..., b_95]` of an `Element<BLS12_381_G2>` with the following rules.
    /// - `b_95 & 0x40` is the infinity flag.
    /// - The infinity flag is 1 if and only if the element is the point at infinity.
    /// - The infinity flag is 0 if and only if the element is a point `(x,y)` on curve `E(Fq2)`, with the following rules.
    ///     - `[b_0, ..., b_95 & 0x3f]` is a 96-byte little-endian encoding of `x=(x_0+x_1*u)`.
    ///         - `[b_0, ..., b_47]` is a 48-byte little-endian encoding of `x_0`.
    ///         - `[b_48, ..., b_95 & 0x3f]` is a 48-byte little-endian encoding of `x_1`.
    ///     - `b_95 & 0x80` is the positiveness flag.
    ///     - The positiveness flag is 1 if and only if `y > -y`.
    ///         - Here `a=(a_0+a_1*u)` is considered greater than `b=(b_0+b_1*u)` if `a_1>b_1 OR (a_1=b_1 AND a_0>b_0)`.
    struct BLS12_381_G2 {}

    /// A phantom type that represents the 2nd pairing input group `G2` in BLS12-381 pairing.
    ///
    /// In BLS12-381, a finite field `Fq` is used, where
    /// `q` equals to 0x1a0111ea397fe69a4b1ba7b6434bacd764774b84f38512bf6730d2a0f6b0f6241eabfffeb153ffffb9feffffffffaaab.
    /// `Fq2` is an extension field of `Fq`, constructed as `Fq2=Fq[u]/(u^2+1)`.
    /// `Fq6` is an extension field of `Fq2`, constructed as `Fq6=Fq2[v]/(v^2-u-1)`.
    /// `Fq12` is an extension field of `Fq6`, constructed as `Fq12=Fq6[w]/(w^2-v)`.
    /// `Gt` is the multiplicative subgroup of `Fq12`.
    /// `Gt` has a prime order `r` with value 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001.
    ///
    /// A `Scalar<BLS12_381_G2>` is an integer between 0 and `r-1`.
    ///
    /// Function `scalar_from_bytes<BLS12_381_Gt>` and `scalar_to_bytes<BLS12_381_Gt>`
    /// assumes a 32-byte little-endian encoding of a `Scalar<BLS12_381_Gt>`.
    ///
    /// An `Element<BLS12_381_Gt>` is an element in `Gt`.
    ///
    /// Function `serialize_element_uncompressed<BLS12_381_Gt>` and `deserialize_element_uncompressed<BLS12_381_Gt>`,
    /// as well as `serialize_element_ompressed<BLS12_381_Gt>` and `deserialize_element_compressed<BLS12_381_Gt>`,
    /// assume a 576-byte encoding `[b_0, ..., b_575]` of an `Element<BLS12_381_Gt>`, with the following rules.
    ///     - Assume the given element is `e=c_0+c_1*w` where `c_i=c_i0+c_i1*v+c_i2*v^2 for i=0..1` and `c_ij=c_ij0+c_ij1*u for j=0..2`.
    ///     - `[b_0, ..., b_575]` is a concatenation of 12 encoded `Fq` elements: `c_000, c_001, c_010, c_011, c_020, c_021, c_100, c_101, c_110, c_111, c_120, c_121`.
    ///     - Every `c_ijk` uses a 48-byte little-endian encoding.
    struct BLS12_381_Gt {}

    /// This struct represents a scalar, usually an integer between 0 and `r-1`,
    /// where `r` is the prime order of a group, where the group is determined by the type argument `G`.
    /// See the comments on the specific `G` for more details about `Scalar<G>`.
    struct Scalar<phantom G> has copy, drop {
        handle: u64
    }

    /// This struct represents a group element, usually a point in an elliptic curve.
    /// The group is determined by the type argument `G`.
    /// See the comments on the specific `G` for more details about `Element<G>`.
    struct Element<phantom G> has copy, drop {
        handle: u64
    }

    /// Perform a bilinear mapping.
    public fun pairing<G1,G2,Gt>(element_1: &Element<G1>, element_2: &Element<G2>): Element<Gt> {
        abort_if_feature_disabled();
        Element<Gt> {
            handle: multi_pairing_internal<G1,G2,Gt>(1, vector[element_1.handle], 1, vector[element_2.handle])
        }
    }

    /// Compute the product of multiple pairing: `e(p1_1,p2_1) * ... * e(p1_n,p2_n)`.
    public fun multi_pairing<G1,G2,Gt>(g1_elements: &vector<Element<G1>>, g2_elements: &vector<Element<G2>>): Element<Gt> {
        abort_if_feature_disabled();
        let num_g1 = std::vector::length(g1_elements);
        let num_g2 = std::vector::length(g2_elements);
        assert!(num_g1 == num_g2, std::error::invalid_argument(1));
        let g1_handles = vector[];
        let g2_handles = vector[];
        let i = 0;
        while (i < num_g2) {
            std::vector::push_back(&mut g1_handles, std::vector::borrow(g1_elements, i).handle);
            std::vector::push_back(&mut g2_handles, std::vector::borrow(g2_elements, i).handle);
            i = i + 1;
        };

        Element<Gt> {
            handle: multi_pairing_internal<G1,G2,Gt>(num_g1, g1_handles, num_g2, g2_handles)
        }
    }

    public fun scalar_from_u64<G>(value: u64): Scalar<G> {
        abort_if_feature_disabled();
        Scalar<G> {
            handle: scalar_from_u64_internal<G>(value)
        }
    }

    public fun scalar_neg<G>(scalar_1: &Scalar<G>): Scalar<G> {
        abort_if_feature_disabled();
        Scalar<G> {
            handle: scalar_neg_internal<G>(scalar_1.handle)
        }
    }

    public fun scalar_add<G>(scalar_1: &Scalar<G>, scalar_2: &Scalar<G>): Scalar<G> {
        abort_if_feature_disabled();
        Scalar<G> {
            handle: scalar_add_internal<G>(scalar_1.handle, scalar_2.handle)
        }
    }

    public fun scalar_mul<G>(scalar_1: &Scalar<G>, scalar_2: &Scalar<G>): Scalar<G> {
        abort_if_feature_disabled();
        Scalar<G> {
            handle: scalar_mul_internal<G>(scalar_1.handle, scalar_2.handle)
        }
    }

    public fun scalar_inv<G>(scalar: &Scalar<G>): Option<Scalar<G>> {
        abort_if_feature_disabled();
        let (succeeded, handle) = scalar_inv_internal<G>(scalar.handle);
        if (succeeded) {
            let scalar = Scalar<G> { handle };
            std::option::some(scalar)
        } else {
            std::option::none()
        }
    }

    public fun scalar_eq<G>(scalar_1: &Scalar<G>, scalar_2: &Scalar<G>): bool {
        abort_if_feature_disabled();
        scalar_eq_internal<G>(scalar_1.handle, scalar_2.handle)
    }

    // Group basics.
    public fun group_identity<G>(): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: group_identity_internal<G>()
        }
    }

    public fun group_generator<G>(): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: group_generator_internal<G>()
        }
    }

    public fun element_neg<G>(element: &Element<G>): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: element_neg_internal<G>(element.handle)
        }
    }

    public fun element_add<G>(element_1: &Element<G>, element_2: &Element<G>): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: element_add_internal<G>(element_1.handle, element_2.handle)
        }
    }

    public fun element_double<G>(element: &Element<G>): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: element_double_internal<G>(element.handle)
        }
    }

    public fun element_mul<G>(scalar: &Scalar<G>, element: &Element<G>): Element<G> {
        abort_if_feature_disabled();
        Element<G> {
            handle: element_mul_internal<G>(scalar.handle, element.handle)
        }
    }

    public fun simul_element_mul<G>(scalars: &vector<Scalar<G>>, elements: &vector<Element<G>>): Element<G> {
        abort_if_feature_disabled();
        //TODO: replace the naive implementation.
        let result = group_identity<G>();
        let num_elements = std::vector::length(elements);
        let num_scalars = std::vector::length(scalars);
        assert!(num_elements == num_scalars, 1);
        let i = 0;
        while (i < num_elements) {
            let scalar = std::vector::borrow(scalars, i);
            let element = std::vector::borrow(elements, i);
            result = element_add(&result, &element_mul(scalar, element));
            i = i + 1;
        };
        result
    }

    /// Decode a `Scalar<G>` from a byte array.
    /// See the comments on the actual type `G` for the format details.
    public fun scalar_from_bytes<G>(bytes: &vector<u8>): Option<Scalar<G>> {
        abort_if_feature_disabled();
        let (succeeded, handle) = scalar_from_bytes_internal<G>(*bytes);
        if (succeeded) {
            let scalar = Scalar<G> {
                handle
            };
            std::option::some(scalar)
        } else {
            std::option::none()
        }
    }

    /// Encode a `Scalar<G>` to a byte array.
    /// See the comments on the actual type `G` for the format details.
    public fun scalar_to_bytes<G>(scalar: &Scalar<G>): vector<u8> {
        abort_if_feature_disabled();
        scalar_to_bytes_internal<G>(scalar.handle)
    }

    /// Encode an `Element<G>` to a byte array with an uncompressed format.
    /// See the comments on the actual type `G` for the format details.
    public fun serialize_element_uncompressed<G>(element: &Element<G>): vector<u8> {
        abort_if_feature_disabled();
        serialize_element_uncompressed_internal<G>(element.handle)
    }

    /// Encode an `Element<G>` to a byte array with a compressed format.
    /// See the comments on the actual type `G` for the format details.
    public fun serialize_element_compressed<G>(element: &Element<G>): vector<u8> {
        abort_if_feature_disabled();
        serialize_element_compressed_internal<G>(element.handle)
    }

    /// Decode an `Element<G>` from a byte array with an uncompressed format.
    /// See the comments on the actual type `G` for the format details.
    public fun deserialize_element_uncompressed<G>(bytes: vector<u8>): Option<Element<G>> {
        abort_if_feature_disabled();
        let (succ, handle) = deserialize_element_uncompressed_internal<G>(bytes);
        if (succ) {
            std::option::some(Element<G> { handle })
        } else {
            std::option::none()
        }
    }

    /// Decode an `Element<G>` from a byte array with a compressed format.
    /// See the comments on the actual type `G` for the format details.
    public fun deserialize_element_compressed<G>(bytes: vector<u8>): Option<Element<G>> {
        abort_if_feature_disabled();
        let (succ, handle) = deserialize_element_compressed_internal<G>(bytes);
        if (succ) {
            std::option::some(Element<G> { handle })
        } else {
            std::option::none()
        }
    }

    public fun element_eq<G>(element_1: &Element<G>, element_2: &Element<G>): bool {
        abort_if_feature_disabled();
        element_eq_internal<G>(element_1.handle, element_2.handle)
    }

    public fun is_prime_order<G>(): bool {
        abort_if_feature_disabled();
        is_prime_order_internal<G>()
    }

    public fun group_order<G>(): vector<u8> {
        abort_if_feature_disabled();
        group_order_internal<G>()
    }

    fun abort_if_feature_disabled() {
        if (!std::features::generic_curves_enabled()) {
            abort(std::error::invalid_state(E_NATIVE_FUN_NOT_AVAILABLE))
        };
    }
    // Native functions.
    native fun deserialize_element_uncompressed_internal<G>(bytes: vector<u8>): (bool, u64);
    native fun deserialize_element_compressed_internal<G>(bytes: vector<u8>): (bool, u64);
    native fun scalar_from_u64_internal<G>(value: u64): u64;
    native fun scalar_from_bytes_internal<G>(bytes: vector<u8>): (bool, u64);
    native fun scalar_neg_internal<G>(handle: u64): u64;
    native fun scalar_add_internal<G>(handle_1: u64, handle_2: u64): u64;
    native fun scalar_double_internal<G>(handle: u64): u64;
    native fun scalar_mul_internal<G>(handle_1: u64, handle_2: u64): u64;
    native fun scalar_inv_internal<G>(handle: u64): (bool, u64);
    native fun scalar_eq_internal<G>(handle_1: u64, handle_2: u64): bool;
    native fun scalar_to_bytes_internal<G>(h: u64): vector<u8>;
    native fun element_add_internal<G>(handle_1: u64, handle_2: u64): u64;
    native fun element_eq_internal<G>(handle_1: u64, handle_2: u64): bool;
    native fun group_identity_internal<G>(): u64;
    native fun is_prime_order_internal<G>(): bool;
    native fun group_order_internal<G>(): vector<u8>;
    native fun group_generator_internal<G>(): u64;
    native fun element_mul_internal<G>(scalar_handle: u64, element_handle: u64): u64;
    native fun element_double_internal<G>(element_handle: u64): u64;
    native fun element_neg_internal<G>(handle: u64): u64;
    native fun serialize_element_uncompressed_internal<G>(handle: u64): vector<u8>;
    native fun serialize_element_compressed_internal<G>(handle: u64): vector<u8>;
    ///TODO: Remove `g1_handle_count` and `g2_handle_count` once working with `vector<u64>` in rust is well supported.
    native fun multi_pairing_internal<G1,G2,Gt>(g1_handle_count: u64, g1_handles: vector<u64>, g2_handle_count: u64, g2_handles: vector<u64>): u64;

    #[test(fx = @std)]
    fun test_bls12_381_g1(fx: signer) {
        std::features::change_feature_flags(&fx, vector[std::features::get_generic_curves_feature()], vector[]);
        // Group info.
        assert!(is_prime_order<BLS12_381_G1>(), 1);
        assert!(x"01000000fffffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == group_order<BLS12_381_G1>(), 1);

        // Scalar encoding/decoding.
        let scalar_7 = scalar_from_u64<BLS12_381_G1>(7);
        let scalar_7_another = std::option::extract(&mut scalar_from_bytes<BLS12_381_G1>(&x"0700000000000000000000000000000000000000000000000000000000000000"));
        assert!(scalar_eq(&scalar_7, &scalar_7_another), 1);
        assert!( x"0700000000000000000000000000000000000000000000000000000000000000" == scalar_to_bytes(&scalar_7), 1);
        assert!(std::option::is_none(&scalar_from_bytes<BLS12_381_G1>(&x"ffff")), 1);

        // Scalar negation.
        let scalar_minus_7 = scalar_neg(&scalar_7);
        assert!(x"fafffffffefffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == scalar_to_bytes(&scalar_minus_7), 1);

        // Scalar addition.
        let scalar_9 = scalar_from_u64<BLS12_381_G1>(9);
        let scalar_2 = scalar_from_u64<BLS12_381_G1>(2);
        let scalar_2_calc = scalar_add(&scalar_minus_7, &scalar_9);
        assert!(scalar_eq(&scalar_2, &scalar_2_calc), 1);

        // Scalar multiplication.
        let scalar_63_calc = scalar_mul(&scalar_7, &scalar_9);
        let scalar_63 = scalar_from_u64<BLS12_381_G1>(63);
        assert!(scalar_eq(&scalar_63, &scalar_63_calc), 1);

        // Scalar inversion.
        let scalar_7_inv_calc = std::option::extract(&mut scalar_inv(&scalar_7));
        assert!(scalar_eq(&scalar_9, &scalar_mul(&scalar_63, &scalar_7_inv_calc)), 1);
        let scalar_0 = scalar_from_u64<BLS12_381_G1>(0);
        assert!(std::option::is_none(&scalar_inv(&scalar_0)), 1);

        // Point encoding/decoding.
        let point_g = group_generator<BLS12_381_G1>();
        assert!(x"bbc622db0af03afbef1a7af93fe8556c58ac1b173f3a4ea105b974974f8c68c30faca94f8c63952694d79731a7d3f117e1e7c5462923aa0ce48a88a244c73cd0edb3042ccb18db00f60ad0d595e0f5fce48a1d74ed309ea0f1a0aae381f4b308" == serialize_element_uncompressed(&point_g), 1);
        assert!(x"bbc622db0af03afbef1a7af93fe8556c58ac1b173f3a4ea105b974974f8c68c30faca94f8c63952694d79731a7d3f117" == serialize_element_compressed(&point_g), 1);
        let point_g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G1>(x"bbc622db0af03afbef1a7af93fe8556c58ac1b173f3a4ea105b974974f8c68c30faca94f8c63952694d79731a7d3f117e1e7c5462923aa0ce48a88a244c73cd0edb3042ccb18db00f60ad0d595e0f5fce48a1d74ed309ea0f1a0aae381f4b308"));
        let point_g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G1>(x"bbc622db0af03afbef1a7af93fe8556c58ac1b173f3a4ea105b974974f8c68c30faca94f8c63952694d79731a7d3f117"));
        assert!(element_eq(&point_g, &point_g_from_comp), 1);
        assert!(element_eq(&point_g, &point_g_from_uncomp), 1);
        let inf = group_identity<BLS12_381_G1>();
        assert!(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040" == serialize_element_uncompressed(&inf), 1);
        assert!(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040" == serialize_element_compressed(&inf), 1);
        let inf_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G1>(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040"));
        let inf_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G1>(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040"));
        assert!(element_eq(&inf, &inf_from_comp), 1);
        assert!(element_eq(&inf, &inf_from_uncomp), 1);
        let point_7g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G1>(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef328191c1a98287eec115a8cb0a1cf4968c6fd101ca4593938d73918dd8e81471d8a3ac4b38930aed539564436b6a4baad8d10"));
        let point_7g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G1>(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef32899"));
        assert!(element_eq(&point_7g_from_comp, &point_7g_from_uncomp), 1);

        // Point multiplication by scalar.
        let point_7g_calc = element_mul(&scalar_7, &point_g);
        assert!(element_eq(&point_7g_calc, &point_7g_from_comp), 1);
        assert!(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef328191c1a98287eec115a8cb0a1cf4968c6fd101ca4593938d73918dd8e81471d8a3ac4b38930aed539564436b6a4baad8d10" == serialize_element_uncompressed(&point_7g_calc), 1);
        assert!(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef32899" == serialize_element_compressed(&point_7g_calc), 1);

        // Point double.
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_double_g = element_double(&point_g);
        assert!(element_eq(&point_2g, &point_double_g), 1);

        // Point negation.
        let point_minus_7g_calc = element_neg(&point_7g_calc);
        assert!(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef32819" == serialize_element_compressed(&point_minus_7g_calc), 1);
        assert!(x"b7fc7e62705aef542dbcc5d4bce62a7bf22eef1691bef30dac121fb200ca7dc9a4403b90da4501cfee1935b9bef328198f9067d78113ed5f734fb2e1b497e52013da0c9d679a592da735f6713d2eed2913f9c11208d2e1f455b0c9942f647309" == serialize_element_uncompressed(&point_minus_7g_calc), 1);

        // Point addition.
        let point_9g = element_mul(&scalar_9, &point_g);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_2g_calc = element_add(&point_minus_7g_calc, &point_9g);
        assert!(element_eq(&point_2g, &point_2g_calc), 1);

        // Simultaneous point multiplication.
        let point_14g = element_mul(&scalar_from_u64<BLS12_381_G1>(14), &point_g);
        let scalar_1 = scalar_from_u64<BLS12_381_G1>(1);
        let scalar_2 = scalar_from_u64<BLS12_381_G1>(2);
        let scalar_3 = scalar_from_u64<BLS12_381_G1>(3);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_3g = element_mul(&scalar_3, &point_g);
        let scalars = vector[scalar_1, scalar_2, scalar_3];
        let points = vector[point_g, point_2g, point_3g];
        let point_14g_calc = simul_element_mul(&scalars, &points);
        assert!(element_eq(&point_14g, &point_14g_calc), 1);
    }

    #[test(fx = @std)]
    fun test_bls12_381_g2(fx: signer) {
        std::features::change_feature_flags(&fx, vector[std::features::get_generic_curves_feature()], vector[]);
        // Group info.
        assert!(is_prime_order<BLS12_381_G2>(), 1);
        assert!(x"01000000fffffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == group_order<BLS12_381_G2>(), 1);

        // Scalar encoding/decoding.
        let scalar_7 = scalar_from_u64<BLS12_381_G2>(7);
        let scalar_7_another = std::option::extract(&mut scalar_from_bytes<BLS12_381_G2>(&x"0700000000000000000000000000000000000000000000000000000000000000"));
        assert!(scalar_eq(&scalar_7, &scalar_7_another), 1);
        assert!( x"0700000000000000000000000000000000000000000000000000000000000000" == scalar_to_bytes(&scalar_7), 1);
        assert!(std::option::is_none(&scalar_from_bytes<BLS12_381_G1>(&x"ffff")), 1);

        // Scalar negation.
        let scalar_minus_7 = scalar_neg(&scalar_7);
        assert!(x"fafffffffefffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == scalar_to_bytes(&scalar_minus_7), 1);

        // Scalar addition.
        let scalar_9 = scalar_from_u64<BLS12_381_G2>(9);
        let scalar_2 = scalar_from_u64<BLS12_381_G2>(2);
        let scalar_2_calc = scalar_add(&scalar_minus_7, &scalar_9);
        assert!(scalar_eq(&scalar_2, &scalar_2_calc), 1);

        // Scalar multiplication.
        let scalar_63_calc = scalar_mul(&scalar_7, &scalar_9);
        let scalar_63 = scalar_from_u64<BLS12_381_G2>(63);
        assert!(scalar_eq(&scalar_63, &scalar_63_calc), 1);

        // Scalar inversion.
        let scalar_7_inv_calc = std::option::extract(&mut scalar_inv(&scalar_7));
        assert!(scalar_eq(&scalar_9, &scalar_mul(&scalar_63, &scalar_7_inv_calc)), 1);
        let scalar_0 = scalar_from_u64<BLS12_381_G2>(0);
        assert!(std::option::is_none(&scalar_inv(&scalar_0)), 1);

        // Point encoding/decoding.
        let point_g = group_generator<BLS12_381_G2>();
        assert!(x"b8bd21c1c85680d4efbb05a82603ac0b77d1e37a640b51b4023b40fad47ae4c65110c52d27050826910a8ff0b2a24a027e2b045d057dace5575d941312f14c3349507fdcbb61dab51ab62099d0d06b59654f2788a0d3ac7d609f7152602be0130128b808865493e189a2ac3bccc93a922cd16051699a426da7d3bd8caa9bfdad1a352edac6cdc98c116e7d7227d5e50cbe795ff05f07a9aaa11dec5c270d373fab992e57ab927426af63a7857e283ecb998bc22bb0d2ac32cc34a72ea0c40606" == serialize_element_uncompressed(&point_g), 1);
        assert!(x"b8bd21c1c85680d4efbb05a82603ac0b77d1e37a640b51b4023b40fad47ae4c65110c52d27050826910a8ff0b2a24a027e2b045d057dace5575d941312f14c3349507fdcbb61dab51ab62099d0d06b59654f2788a0d3ac7d609f7152602be013" == serialize_element_compressed(&point_g), 1);
        let point_g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G2>(x"b8bd21c1c85680d4efbb05a82603ac0b77d1e37a640b51b4023b40fad47ae4c65110c52d27050826910a8ff0b2a24a027e2b045d057dace5575d941312f14c3349507fdcbb61dab51ab62099d0d06b59654f2788a0d3ac7d609f7152602be0130128b808865493e189a2ac3bccc93a922cd16051699a426da7d3bd8caa9bfdad1a352edac6cdc98c116e7d7227d5e50cbe795ff05f07a9aaa11dec5c270d373fab992e57ab927426af63a7857e283ecb998bc22bb0d2ac32cc34a72ea0c40606"));
        let point_g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G2>(x"b8bd21c1c85680d4efbb05a82603ac0b77d1e37a640b51b4023b40fad47ae4c65110c52d27050826910a8ff0b2a24a027e2b045d057dace5575d941312f14c3349507fdcbb61dab51ab62099d0d06b59654f2788a0d3ac7d609f7152602be013"));
        assert!(element_eq(&point_g, &point_g_from_comp), 1);
        assert!(element_eq(&point_g, &point_g_from_uncomp), 1);
        let inf = group_identity<BLS12_381_G2>();
        assert!(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040" == serialize_element_uncompressed(&inf), 1);
        assert!(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040" == serialize_element_compressed(&inf), 1);
        let inf_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G2>(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040"));
        let inf_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G2>(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040"));
        assert!(element_eq(&inf, &inf_from_comp), 1);
        assert!(element_eq(&inf, &inf_from_uncomp), 1);
        let point_7g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_G2>(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673020dddcc1399cdf852dab1e2c8dc3b0ce819362f3a12da56f37aee93d3881ca760e467942c92428864a6172c80bf4daeb7082070fa8e8937746ae82d57ec8b639977f8ceaef21a11375de52b02e145dc39021bf4cab7eeaa955688a1b75436f9ec05"));
        let point_7g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_G2>(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673020d"));
        assert!(element_eq(&point_7g_from_comp, &point_7g_from_uncomp), 1);

        // Point multiplication by scalar.
        let point_7g_calc = element_mul(&scalar_7, &point_g);
        assert!(element_eq(&point_7g_calc, &point_7g_from_comp), 1);
        assert!(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673020dddcc1399cdf852dab1e2c8dc3b0ce819362f3a12da56f37aee93d3881ca760e467942c92428864a6172c80bf4daeb7082070fa8e8937746ae82d57ec8b639977f8ceaef21a11375de52b02e145dc39021bf4cab7eeaa955688a1b75436f9ec05" == serialize_element_uncompressed(&point_7g_calc), 1);
        assert!(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673020d" == serialize_element_compressed(&point_7g_calc), 1);

        // Point double.
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_double_g = element_double(&point_g);
        assert!(element_eq(&point_2g, &point_double_g), 1);

        // Point negation.
        let point_minus_7g_calc = element_neg(&point_7g_calc);
        assert!(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673028d" == serialize_element_compressed(&point_minus_7g_calc), 1);
        assert!(x"3c8dd3f68a360f9c5ba81fad2be3408bdc3070619bc7bf3794851bd623685a5036ef5f1388c0541e58c3d2b2dbd19c04c83472247446b1bdd44416ad1c1f929a3f01ed345be35b9b4ba20f17ccf2b5208e3dec8380d6b8c337ed31bff673020dceddeb663207acdf4d1d8bd4c2f3c304eec676e4c67b3decd07eb16a68a416806f181fb1731fb7a482baff799c6349118b3a057176c88a4f17d2fcc4729c12a72b27020486c1f909dae682123f6f3d62bcb8808bc7fc85f41145c8e4b3181414" == serialize_element_uncompressed(&point_minus_7g_calc), 1);

        // Point addition.
        let point_9g = element_mul(&scalar_9, &point_g);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_2g_calc = element_add(&point_minus_7g_calc, &point_9g);
        assert!(element_eq(&point_2g, &point_2g_calc), 1);

        // Simultaneous point multiplication.
        let point_14g = element_mul(&scalar_from_u64<BLS12_381_G2>(14), &point_g);
        let scalar_1 = scalar_from_u64<BLS12_381_G2>(1);
        let scalar_2 = scalar_from_u64<BLS12_381_G2>(2);
        let scalar_3 = scalar_from_u64<BLS12_381_G2>(3);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_3g = element_mul(&scalar_3, &point_g);
        let scalars = vector[scalar_1, scalar_2, scalar_3];
        let points = vector[point_g, point_2g, point_3g];
        let point_14g_calc = simul_element_mul(&scalars, &points);
        assert!(element_eq(&point_14g, &point_14g_calc), 1);
    }

    #[test(fx = @std)]
    fun test_bls12_381_gt(fx: signer) {
        std::features::change_feature_flags(&fx, vector[std::features::get_generic_curves_feature()], vector[]);
        // Group info.
        assert!(is_prime_order<BLS12_381_Gt>(), 1);
        assert!(x"01000000fffffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == group_order<BLS12_381_Gt>(), 1);

        // Scalar encoding/decoding.
        let scalar_7 = scalar_from_u64<BLS12_381_Gt>(7);
        let scalar_7_another = std::option::extract(&mut scalar_from_bytes<BLS12_381_Gt>(&x"0700000000000000000000000000000000000000000000000000000000000000"));
        assert!(scalar_eq(&scalar_7, &scalar_7_another), 1);
        assert!( x"0700000000000000000000000000000000000000000000000000000000000000" == scalar_to_bytes(&scalar_7), 1);
        assert!(std::option::is_none(&scalar_from_bytes<BLS12_381_G1>(&x"ffff")), 1);

        // Scalar negation.
        let scalar_minus_7 = scalar_neg(&scalar_7);
        assert!(x"fafffffffefffffffe5bfeff02a4bd5305d8a10908d83933487d9d2953a7ed73" == scalar_to_bytes(&scalar_minus_7), 1);

        // Scalar addition.
        let scalar_9 = scalar_from_u64<BLS12_381_Gt>(9);
        let scalar_2 = scalar_from_u64<BLS12_381_Gt>(2);
        let scalar_2_calc = scalar_add(&scalar_minus_7, &scalar_9);
        assert!(scalar_eq(&scalar_2, &scalar_2_calc), 1);

        // Scalar multiplication.
        let scalar_63_calc = scalar_mul(&scalar_7, &scalar_9);
        let scalar_63 = scalar_from_u64<BLS12_381_Gt>(63);
        assert!(scalar_eq(&scalar_63, &scalar_63_calc), 1);

        // Scalar inversion.
        let scalar_7_inv_calc = std::option::extract(&mut scalar_inv(&scalar_7));
        assert!(scalar_eq(&scalar_9, &scalar_mul(&scalar_63, &scalar_7_inv_calc)), 1);
        let scalar_0 = scalar_from_u64<BLS12_381_Gt>(0);
        assert!(std::option::is_none(&scalar_inv(&scalar_0)), 1);

        // Point encoding/decoding.
        let point_g = group_generator<BLS12_381_Gt>();
        assert!(x"b68917caaa0543a808c53908f694d1b6e7b38de90ce9d83d505ca1ef1b442d2727d7d06831d8b2a7920afc71d8eb50120f17a0ea982a88591d9f43503e94a8f1abaf2e4589f65aafb7923c484540a868883432a5c60e75860b11e5465b1c9a08873ec29e844c1c888cb396933057ffdd541b03a5220eda16b2b3a6728ea678034ce39c6839f20397202d7c5c44bb68134f93193cec215031b17399577a1de5ff1f5b0666bdd8907c61a7651e4e79e0372951505a07fa73c25788db6eb8023519a5aa97b51f1cad1d43d8aabbff4dc319c79a58cafc035218747c2f75daf8f2fb7c00c44da85b129113173d4722f5b201b6b4454062e9ea8ba78c5ca3cadaf7238b47bace5ce561804ae16b8f4b63da4645b8457a93793cbd64a7254f150781019de87ee42682940f3e70a88683d512bb2c3fb7b2434da5dedbb2d0b3fb8487c84da0d5c315bdd69c46fb05d23763f2191aabd5d5c2e12a10b8f002ff681bfd1b2ee0bf619d80d2a795eb22f2aa7b85d5ffb671a70c94809f0dafc5b73ea2fb0657bae23373b4931bc9fa321e8848ef78894e987bff150d7d671aee30b3931ac8c50e0b3b0868effc38bf48cd24b4b811a2995ac2a09122bed9fd9fa0c510a87b10290836ad06c8203397b56a78e9a0c61c77e56ccb4f1bc3d3fcaea7550f3503efe30f2d24f00891cb45620605fcfaa4292687b3a7db7c1c0554a93579e889a121fd8f72649b2402996a084d2381c5043166673b3849e4fd1e7ee4af24aa8ed443f56dfd6b68ffde4435a92cd7a4ac3bc77e1ad0cb728606cf08bf6386e5410f" == serialize_element_uncompressed(&point_g), 1);
        assert!(x"b68917caaa0543a808c53908f694d1b6e7b38de90ce9d83d505ca1ef1b442d2727d7d06831d8b2a7920afc71d8eb50120f17a0ea982a88591d9f43503e94a8f1abaf2e4589f65aafb7923c484540a868883432a5c60e75860b11e5465b1c9a08873ec29e844c1c888cb396933057ffdd541b03a5220eda16b2b3a6728ea678034ce39c6839f20397202d7c5c44bb68134f93193cec215031b17399577a1de5ff1f5b0666bdd8907c61a7651e4e79e0372951505a07fa73c25788db6eb8023519a5aa97b51f1cad1d43d8aabbff4dc319c79a58cafc035218747c2f75daf8f2fb7c00c44da85b129113173d4722f5b201b6b4454062e9ea8ba78c5ca3cadaf7238b47bace5ce561804ae16b8f4b63da4645b8457a93793cbd64a7254f150781019de87ee42682940f3e70a88683d512bb2c3fb7b2434da5dedbb2d0b3fb8487c84da0d5c315bdd69c46fb05d23763f2191aabd5d5c2e12a10b8f002ff681bfd1b2ee0bf619d80d2a795eb22f2aa7b85d5ffb671a70c94809f0dafc5b73ea2fb0657bae23373b4931bc9fa321e8848ef78894e987bff150d7d671aee30b3931ac8c50e0b3b0868effc38bf48cd24b4b811a2995ac2a09122bed9fd9fa0c510a87b10290836ad06c8203397b56a78e9a0c61c77e56ccb4f1bc3d3fcaea7550f3503efe30f2d24f00891cb45620605fcfaa4292687b3a7db7c1c0554a93579e889a121fd8f72649b2402996a084d2381c5043166673b3849e4fd1e7ee4af24aa8ed443f56dfd6b68ffde4435a92cd7a4ac3bc77e1ad0cb728606cf08bf6386e5410f" == serialize_element_compressed(&point_g), 1);
        let point_g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_Gt>(x"b68917caaa0543a808c53908f694d1b6e7b38de90ce9d83d505ca1ef1b442d2727d7d06831d8b2a7920afc71d8eb50120f17a0ea982a88591d9f43503e94a8f1abaf2e4589f65aafb7923c484540a868883432a5c60e75860b11e5465b1c9a08873ec29e844c1c888cb396933057ffdd541b03a5220eda16b2b3a6728ea678034ce39c6839f20397202d7c5c44bb68134f93193cec215031b17399577a1de5ff1f5b0666bdd8907c61a7651e4e79e0372951505a07fa73c25788db6eb8023519a5aa97b51f1cad1d43d8aabbff4dc319c79a58cafc035218747c2f75daf8f2fb7c00c44da85b129113173d4722f5b201b6b4454062e9ea8ba78c5ca3cadaf7238b47bace5ce561804ae16b8f4b63da4645b8457a93793cbd64a7254f150781019de87ee42682940f3e70a88683d512bb2c3fb7b2434da5dedbb2d0b3fb8487c84da0d5c315bdd69c46fb05d23763f2191aabd5d5c2e12a10b8f002ff681bfd1b2ee0bf619d80d2a795eb22f2aa7b85d5ffb671a70c94809f0dafc5b73ea2fb0657bae23373b4931bc9fa321e8848ef78894e987bff150d7d671aee30b3931ac8c50e0b3b0868effc38bf48cd24b4b811a2995ac2a09122bed9fd9fa0c510a87b10290836ad06c8203397b56a78e9a0c61c77e56ccb4f1bc3d3fcaea7550f3503efe30f2d24f00891cb45620605fcfaa4292687b3a7db7c1c0554a93579e889a121fd8f72649b2402996a084d2381c5043166673b3849e4fd1e7ee4af24aa8ed443f56dfd6b68ffde4435a92cd7a4ac3bc77e1ad0cb728606cf08bf6386e5410f"));
        let point_g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_Gt>(x"b68917caaa0543a808c53908f694d1b6e7b38de90ce9d83d505ca1ef1b442d2727d7d06831d8b2a7920afc71d8eb50120f17a0ea982a88591d9f43503e94a8f1abaf2e4589f65aafb7923c484540a868883432a5c60e75860b11e5465b1c9a08873ec29e844c1c888cb396933057ffdd541b03a5220eda16b2b3a6728ea678034ce39c6839f20397202d7c5c44bb68134f93193cec215031b17399577a1de5ff1f5b0666bdd8907c61a7651e4e79e0372951505a07fa73c25788db6eb8023519a5aa97b51f1cad1d43d8aabbff4dc319c79a58cafc035218747c2f75daf8f2fb7c00c44da85b129113173d4722f5b201b6b4454062e9ea8ba78c5ca3cadaf7238b47bace5ce561804ae16b8f4b63da4645b8457a93793cbd64a7254f150781019de87ee42682940f3e70a88683d512bb2c3fb7b2434da5dedbb2d0b3fb8487c84da0d5c315bdd69c46fb05d23763f2191aabd5d5c2e12a10b8f002ff681bfd1b2ee0bf619d80d2a795eb22f2aa7b85d5ffb671a70c94809f0dafc5b73ea2fb0657bae23373b4931bc9fa321e8848ef78894e987bff150d7d671aee30b3931ac8c50e0b3b0868effc38bf48cd24b4b811a2995ac2a09122bed9fd9fa0c510a87b10290836ad06c8203397b56a78e9a0c61c77e56ccb4f1bc3d3fcaea7550f3503efe30f2d24f00891cb45620605fcfaa4292687b3a7db7c1c0554a93579e889a121fd8f72649b2402996a084d2381c5043166673b3849e4fd1e7ee4af24aa8ed443f56dfd6b68ffde4435a92cd7a4ac3bc77e1ad0cb728606cf08bf6386e5410f"));
        assert!(element_eq(&point_g, &point_g_from_comp), 1);
        assert!(element_eq(&point_g, &point_g_from_uncomp), 1);
        let inf = group_identity<BLS12_381_Gt>();
        assert!(x"010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" == serialize_element_uncompressed(&inf), 1);
        assert!(x"010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000" == serialize_element_compressed(&inf), 1);
        let inf_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_Gt>(x"010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"));
        let inf_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_Gt>(x"010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"));
        assert!(element_eq(&inf, &inf_from_comp), 1);
        assert!(element_eq(&inf, &inf_from_uncomp), 1);
        let point_7g_from_uncomp = std::option::extract(&mut deserialize_element_uncompressed<BLS12_381_Gt>(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c185d185b4605dc9808517196bba9d00a3e37bca466c19187486db104ee03962d39fe473e276355618e44c965f05082bb027a7baa4bcc6d8c0775c1e8a481e77df36ddad91e75a982302937f543a11fe71922dcd4f46fe8f951f91cde412b359507f2b3b6df0374bfe55c9a126ad31ce254e67d64194d32d7955ec791c9555ea5a917fc47aba319e909de82da946eb36e12aff936708402228295db2712f2fc807c95092a86afd71220699df13e2d2fdf2857976cb1e605f72f1b2edabadba3ff05501221fe81333c13917c85d725ce92791e115eb0289a5d0b3330901bb8b0ed146abeb81381b7331f1c508fb14e057b05d8b0190a9e74a3d046dcd24e7ab747049945b3d8a120c4f6d88e67661b55573aa9b361367488a1ef7dffd967d64a1518"));
        let point_7g_from_comp = std::option::extract(&mut deserialize_element_compressed<BLS12_381_Gt>(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c185d185b4605dc9808517196bba9d00a3e37bca466c19187486db104ee03962d39fe473e276355618e44c965f05082bb027a7baa4bcc6d8c0775c1e8a481e77df36ddad91e75a982302937f543a11fe71922dcd4f46fe8f951f91cde412b359507f2b3b6df0374bfe55c9a126ad31ce254e67d64194d32d7955ec791c9555ea5a917fc47aba319e909de82da946eb36e12aff936708402228295db2712f2fc807c95092a86afd71220699df13e2d2fdf2857976cb1e605f72f1b2edabadba3ff05501221fe81333c13917c85d725ce92791e115eb0289a5d0b3330901bb8b0ed146abeb81381b7331f1c508fb14e057b05d8b0190a9e74a3d046dcd24e7ab747049945b3d8a120c4f6d88e67661b55573aa9b361367488a1ef7dffd967d64a1518"));
        assert!(element_eq(&point_7g_from_comp, &point_7g_from_uncomp), 1);
        assert!(std::option::is_none(&deserialize_element_uncompressed<BLS12_381_Gt>(x"000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")), 1);

        // Point multiplication by scalar.
        let point_7g_calc = element_mul(&scalar_7, &point_g);
        assert!(element_eq(&point_7g_calc, &point_7g_from_comp), 1);
        assert!(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c185d185b4605dc9808517196bba9d00a3e37bca466c19187486db104ee03962d39fe473e276355618e44c965f05082bb027a7baa4bcc6d8c0775c1e8a481e77df36ddad91e75a982302937f543a11fe71922dcd4f46fe8f951f91cde412b359507f2b3b6df0374bfe55c9a126ad31ce254e67d64194d32d7955ec791c9555ea5a917fc47aba319e909de82da946eb36e12aff936708402228295db2712f2fc807c95092a86afd71220699df13e2d2fdf2857976cb1e605f72f1b2edabadba3ff05501221fe81333c13917c85d725ce92791e115eb0289a5d0b3330901bb8b0ed146abeb81381b7331f1c508fb14e057b05d8b0190a9e74a3d046dcd24e7ab747049945b3d8a120c4f6d88e67661b55573aa9b361367488a1ef7dffd967d64a1518" == serialize_element_uncompressed(&point_7g_calc), 1);
        assert!(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c185d185b4605dc9808517196bba9d00a3e37bca466c19187486db104ee03962d39fe473e276355618e44c965f05082bb027a7baa4bcc6d8c0775c1e8a481e77df36ddad91e75a982302937f543a11fe71922dcd4f46fe8f951f91cde412b359507f2b3b6df0374bfe55c9a126ad31ce254e67d64194d32d7955ec791c9555ea5a917fc47aba319e909de82da946eb36e12aff936708402228295db2712f2fc807c95092a86afd71220699df13e2d2fdf2857976cb1e605f72f1b2edabadba3ff05501221fe81333c13917c85d725ce92791e115eb0289a5d0b3330901bb8b0ed146abeb81381b7331f1c508fb14e057b05d8b0190a9e74a3d046dcd24e7ab747049945b3d8a120c4f6d88e67661b55573aa9b361367488a1ef7dffd967d64a1518" == serialize_element_compressed(&point_7g_calc), 1);

        // Point double.
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_double_g = element_double(&point_g);
        assert!(element_eq(&point_2g, &point_double_g), 1);

        // Point negation.
        let point_minus_7g_calc = element_neg(&point_7g_calc);
        assert!(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c184e92a4b9fa2366b1ae8ebdf5542fa1e0ec390c90df40a91e5261800581b5492bd9640d1c5352babc551d1a49998f4517312f55b4339272b28a3e6b0c7d182e2bb61bd7d72b29ae3696db8fafe32b904ab5d0764e46bf21f9a0c9a1f7bedc6b12b9f64820fc8b3fd4a26541472be3c9c93d784cdd53a059d1604bf3292fedd1babfb00398128e3241bc63a5a47b5e9207fcb0c88f7bfddc376a242c9f0c032ba28eec8670f1fa1d47567593b4571c983b8015df91cfa1241b7fb8a57e0e6e01145b98de017eccc2a66e83ced9d83119a505e552467838d35b8ce2f4d7cc9a894f6dee922f35f0e72b7e96f0879b0c8614d3f9e5f5618b5be9b82381628448641a8bb0fd1dffb16c70e6831d8d69f61f2a2ef9e90c421f7a5b1ce7a5d113c7eb01" == serialize_element_compressed(&point_minus_7g_calc), 1);
        assert!(x"2041ea7b66c19680e2c0bb23245a71918753220b31f88a925aa9b1e192e7c188a0b365cb994b3ec5e809206117c6411242b940b10caa37ce734496b3b7c63578a0e3c076f9b31a7ca13a716262e0e4cda4ac994efb9e19893cbfe4d464b9210d099d808a08b3c4c3846e7529984899478639c4e6c46152ef49a04af9c8e6ff442d286c4613a3dac6a4bee4b40e1f6b030f2871dabe4223b250c3181ecd3bc6819004745aeb6bac567407f2b9c7d1978c45ee6712ae46930bc00638383f6696158bad488cbe7663d681c96c035481dbcf78e7a7fbaec3799163aa6914cef3365156bdc3e533a7c883d5974e3462ac6f19e3f9ce26800ae248a45c5f0dd3a48a185969224e6cd6af9a048241bdcac9800d94aeee970e08488fb961e36a769b6c184e92a4b9fa2366b1ae8ebdf5542fa1e0ec390c90df40a91e5261800581b5492bd9640d1c5352babc551d1a49998f4517312f55b4339272b28a3e6b0c7d182e2bb61bd7d72b29ae3696db8fafe32b904ab5d0764e46bf21f9a0c9a1f7bedc6b12b9f64820fc8b3fd4a26541472be3c9c93d784cdd53a059d1604bf3292fedd1babfb00398128e3241bc63a5a47b5e9207fcb0c88f7bfddc376a242c9f0c032ba28eec8670f1fa1d47567593b4571c983b8015df91cfa1241b7fb8a57e0e6e01145b98de017eccc2a66e83ced9d83119a505e552467838d35b8ce2f4d7cc9a894f6dee922f35f0e72b7e96f0879b0c8614d3f9e5f5618b5be9b82381628448641a8bb0fd1dffb16c70e6831d8d69f61f2a2ef9e90c421f7a5b1ce7a5d113c7eb01" == serialize_element_uncompressed(&point_minus_7g_calc), 1);

        // Point addition.
        let point_9g = element_mul(&scalar_9, &point_g);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_2g_calc = element_add(&point_minus_7g_calc, &point_9g);
        assert!(element_eq(&point_2g, &point_2g_calc), 1);

        // Simultaneous point multiplication.
        let point_14g = element_mul(&scalar_from_u64<BLS12_381_Gt>(14), &point_g);
        let scalar_1 = scalar_from_u64<BLS12_381_Gt>(1);
        let scalar_2 = scalar_from_u64<BLS12_381_Gt>(2);
        let scalar_3 = scalar_from_u64<BLS12_381_Gt>(3);
        let point_2g = element_mul(&scalar_2, &point_g);
        let point_3g = element_mul(&scalar_3, &point_g);
        let scalars = vector[scalar_1, scalar_2, scalar_3];
        let points = vector[point_g, point_2g, point_3g];
        let point_14g_calc = simul_element_mul(&scalars, &points);
        assert!(element_eq(&point_14g, &point_14g_calc), 1);
    }

    #[test(fx = @std)]
    fun test_bls12381_pairing(fx: signer) {
        std::features::change_feature_flags(&fx, vector[std::features::get_generic_curves_feature()], vector[]);
        let gt_point_1 = pairing<BLS12_381_G1, BLS12_381_G2, BLS12_381_Gt>(
            &element_mul(&scalar_from_u64(5), &group_generator<BLS12_381_G1>()),
            &element_mul(&scalar_from_u64(7), &group_generator<BLS12_381_G2>()),
        );
        let gt_point_2 = pairing<BLS12_381_G1, BLS12_381_G2, BLS12_381_Gt>(
            &element_mul(&scalar_from_u64(1), &group_generator()),
            &element_mul(&scalar_from_u64(35), &group_generator()),
        );
        let gt_point_3 = pairing<BLS12_381_G1, BLS12_381_G2, BLS12_381_Gt>(
            &element_mul(&scalar_from_u64(35), &group_generator<BLS12_381_G1>()),
            &element_mul(&scalar_from_u64(1), &group_generator<BLS12_381_G2>()),
        );
        assert!(element_eq(&gt_point_1, &gt_point_2), 1);
        assert!(element_eq(&gt_point_1, &gt_point_3), 1);
    }

    #[test(fx = @std)]
    fun test_bls12381_multi_pairing(fx: signer) {
        std::features::change_feature_flags(&fx, vector[std::features::get_generic_curves_feature()], vector[]);
        let g1_point_1 = group_generator<BLS12_381_G1>();
        let g2_point_1 = group_generator<BLS12_381_G2>();
        let g1_point_2 = element_mul(&scalar_from_u64<BLS12_381_G1>(5), &g1_point_1);
        let g2_point_2 = element_mul(&scalar_from_u64<BLS12_381_G2>(2), &g2_point_1);
        let g1_point_3 = element_mul(&scalar_from_u64<BLS12_381_G1>(20), &g1_point_1);
        let g2_point_3 = element_mul(&scalar_from_u64<BLS12_381_G2>(5), &g2_point_1);
        let expected = element_mul(&scalar_from_u64<BLS12_381_Gt>(111), &pairing<BLS12_381_G1,BLS12_381_G2,BLS12_381_Gt>(&g1_point_1, &g2_point_1));
        let actual = multi_pairing<BLS12_381_G1, BLS12_381_G2, BLS12_381_Gt>(&vector[g1_point_1, g1_point_2, g1_point_3], &vector[g2_point_1, g2_point_2, g2_point_3]);
        assert!(element_eq(&expected, &actual), 1);
    }
}
