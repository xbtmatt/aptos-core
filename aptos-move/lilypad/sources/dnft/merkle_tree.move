module pond::merkle_tree {
	use std::vector;
	use std::error;
	use std::hash;

	struct MerkleTree has copy, store {
		root_hash: vector<u8>,
	}

	/// The signer is not the module owner.
	const ENOT_OWNER: u64 = 0;
	/// The MerkleTree resource already exists.
	const EALREADY_EXISTS: u64 = 1;
	/// Invalid value for sibling position flag byte.
	const EINVALID_FLAG: u64 = 2;
	/// The sibling position flag is not present.
	const EFLAG_NOT_PRESENT: u64 = 3;
	/// The hash length isn't 32 bytes.
	const EINCORRECT_HASH_LENGTH: u64 = 4;
	/// The provided proof is not valid.
	const EINVALID_PROOF: u64 = 5;

	/// a sha3_256 hash is a vector<u8> of 32 elements
	const HASH_LENGTH: u64 = 32;

	public fun new(root_hash: vector<u8>): MerkleTree {
		assert!(vector::length(&root_hash) == HASH_LENGTH, error::invalid_argument(EINCORRECT_HASH_LENGTH));
		MerkleTree {
			root_hash
		}
	}

	#[view]
	/// Note that the first bit of each hash in the proof vector represents a boolean value for the sibling hash being on the left or the right side when hashed.
	/// That is, each vector<u8> inside the `proof: vector<vector<u8>>` will consist of 1 + 32 bytes
	public fun verify_proof(
		merkle_tree: &MerkleTree,
		leaf_hash: vector<u8>,     // this is the leaf hash that we are verifying exists in the tree
		proof: vector<vector<u8>>, // vector of sibling hashes
	): bool {
		let current_hash = leaf_hash;
		vector::for_each(proof, |sibling_hash| {
			//assert!(vector::length(&sibling_hash) == 1 + 32, error::invalid_argument(EFLAG_NOT_PRESENT));
			let flag = vector::remove(&mut sibling_hash, 0);
			// 0 means sibling_hash is on left, 1 means sibling_hash is on right
			if (flag == 0) {
				current_hash = hash::sha3_256(append(sibling_hash, current_hash));
			} else if (flag == 1) {
				current_hash = hash::sha3_256(append(current_hash, sibling_hash));
			} else {
				abort error::invalid_argument(EINVALID_FLAG)
			};
		});

		(current_hash == merkle_tree.root_hash)
	}

	public fun assert_verify_proof(
		merkle_tree: &MerkleTree,
		leaf_hash: vector<u8>,
		proof: vector<vector<u8>>,
	) {
		assert!(verify_proof(merkle_tree, leaf_hash, proof), error::invalid_argument(EINVALID_PROOF));
	}

	public inline fun destroy(
		merkle_tree: MerkleTree,
	) {
		let MerkleTree {
			root_hash: _,
		} = merkle_tree;
	}

	/// helper function to return the concat'd vector :p
	inline fun append(
		v1: vector<u8>,
		v2: vector<u8>,
	): vector<u8> {
		vector::append(&mut v1, v2);
		v1
	}

	#[test(creator = @dnft)]
	fun merkle_test_root_with_64k_leaves(creator: &signer,) {
		// merkle tree initialized with sha3_256 hash in typescript using 'merkletree' package
		// contains 64,000 leaves of values '1', to '64000'
		let root_hash = x"81f0069a0da2699125a3cb308546d98af07784329a7e5424f603e236b59f0f28";
		let merkle_tree = new(root_hash);

		// when leaf == '1', this is our proof. generated with typescript
		let leaf_hash = x"eda84fb0563b2d2c1c189edb24c673d7d662446093f2ec1fc0a604093123ff57";
		let proof = vector<vector<u8>> [
			x"018337e9d7350810c732984d9aef86ddc8e2e58a4ed37f6884a657e06653c4be19",
			x"010cd789b0ccc6140424560aa0e79d5f1888f5c8d8825e7e6212ab33cc91ea2769",
			x"018308df2c5b0597cae193d7053a31480cecf94eb2d1ceeda21f021cbdf2a62b37",
			x"01a16a576e592ebc46070f232e2a15b0a8c0cd787fda843491b9479221243d28de",
			x"01d717ff4599b57947479282ba337efa76612bc43a451f9d1b3aafef62ce8100ba",
			x"01d692d6d0eb802d15c7b32f410442a9067ef2c15540aa74071cd732ea340a09ff",
			x"0130ebeae3db51eb3686b0c52095d4afa5b180370911131eb754672959a7ab8988",
			x"018353c966b7393cfa6e0c40eecd4246b08ad5ef5550320b75ac0ed14e67665ff3",
			x"01502ca6f9a927bd78d075c233ae759cf04bd9bd1c6be6388e94649d0303ec590b",
			x"01f7677c6cdf74fd7ab721dc6af6ec66ad2238dc10223032f8ea1a04590473bf8f",
			x"0197846a50ac3a474bb0cf66c799ba90c4d4e158285a48fcfd418a536a7294338d",
			x"0103ab49d5dc339ab1793ae10ec89f8d31b555b0eeaffd91eb2aa007ecb5aa1474",
			x"011719c27c4f928c78e2cff3306879f621335193ea8a35a9a51c56a79750d71033",
			x"01d312c8a0ceff8463c10f4887116e4965746e7b2165ded4a3b98faaeb4ba7a66a",
			x"01f6a58925a457c4006a238b0dbe586e7616e6a12a18cf467750e0223348088b45",
			x"01fef0b4813722fd16f5e5172cde340da0ae58c46a85c8de4173019cc575a7b6c4",
		];

		assert!(leaf_hash == hash::sha3_256(b"Leaf #1"), 0);
		verify_proof(&merkle_tree, leaf_hash, proof);
		destroy(merkle_tree);
	}


	#[test(creator = @dnft)]
	fun merkle_test_multiple_proofs(creator: &signer,) {
		// merkle tree initialized with sha3_256 hash in typescript using 'merkletree' package
		// contains 64 leaves of values '1', to '64'
		let root_hash = x"79089f39012cf1fa0f9643f782c29126672519c566f18aa95bec0336857d210b";
		let merkle_tree = new(root_hash);

		// when leaf == '1', this is our proof. generated with typescript
		let leaf_hash = x"67b176705b46206614219f47a05aee7ae6a3edbe850bbbe214c536b989aea4d2";
		assert!(leaf_hash == hash::sha3_256(b"1"), 0);
		let proof = vector<vector<u8>> [
			x"01b1b1bd1ed240b1496c81ccf19ceccf2af6fd24fac10ae42023628abbe2687310",
			x"01d9caa76dd26dadf81943a9a422acf187573d06772d202ccadeee3f7e003bf524",
			x"01e93c9778d10b03669171b4dc0dbe7ff731fb74557a994436f3739c23ce17c8f4",
			x"01f3e0a74c6a93830ed7e990c649c692aba86bf0e7997fee5fe07d274c94367549",
			x"0156b5fe77286fa17588798731eec05a91f7cc9f12624e8d60938ee667629fa306",
			x"017e94024d4d6a5d9a4a968ea04fdb729dd29161ec682423d2da91923b869a5f1e",
		];
		assert!(verify_proof(&merkle_tree, leaf_hash, proof), 1);


		// when leaf == '17', this is our proof. generated with typescript
		let leaf_hash = x"8f9b51ce624f01b0a40c9f68ba8bb0a2c06aa7f95d1ed27d6b1b5e1e99ee5e4d";
		assert!(leaf_hash == hash::sha3_256(b"7"), 2);
		let proof = vector<vector<u8>> [
			x"01d14a329a1924592faf2d4ba6dc727d59af6afae983a0c208bf980237b63a5a6a",
			x"00583388cffa51027de400b999827ea92a0da3ea6b0e96c34fc1f5b56b0132e90d",
			x"0089992c7ba4824fc31587ba4a5edc7d624914647757dc4db9da3cf3fc48781c59",
			x"01f3e0a74c6a93830ed7e990c649c692aba86bf0e7997fee5fe07d274c94367549",
			x"0156b5fe77286fa17588798731eec05a91f7cc9f12624e8d60938ee667629fa306",
			x"017e94024d4d6a5d9a4a968ea04fdb729dd29161ec682423d2da91923b869a5f1e",
		];
		assert!(verify_proof(&merkle_tree, leaf_hash, proof), 3);


		// when leaf == '16', this is our proof. generated with typescript
		let leaf_hash = x"958b08cb3a6f8252890b89292372d10357890e39ca35cbc684d3ecd9e4f052a6";
		assert!(leaf_hash == hash::sha3_256(b"16"), 4);
		let proof = vector<vector<u8>> [
			x"0071f0c2511c6d5dae680e288d7d627eb127f3b3cc1079f0fc497170c4b35759f7",
			x"00c0e2bcad06e9649b3f0624cfc7f9d23bc739d4b0b7088474b2b99ceeb154991d",
			x"0077cd4ad1aa7a3f900a269d1303137abefddb405babd973908617dbf5a6f48cc7",
			x"00226da258c274ce060a24df5705458d99708589e949190f854bdfa2963972dade",
			x"0156b5fe77286fa17588798731eec05a91f7cc9f12624e8d60938ee667629fa306",
			x"017e94024d4d6a5d9a4a968ea04fdb729dd29161ec682423d2da91923b869a5f1e",
		];
		assert!(verify_proof(&merkle_tree, leaf_hash, proof), 5);


		// when leaf == '32', this is our proof. generated with typescript
		let leaf_hash = x"d5801fd41203eeab32fb40335c47fce04361491b37c430b186035ef61dc3ad9a";
		assert!(leaf_hash == hash::sha3_256(b"32"), 6);
		let proof = vector<vector<u8>> [
			x"0074733b5d1ec0c5e611cc68ab4c656cee5c5241bb09012c73ff5f9a02077c8532",
			x"00bd322338e02b5b834a0d8a03caa0dad39e7b0ad860615eb9a572b44a2a92b3f9",
			x"000f92d6fb27fc125d5b25d63f99451da1db4ea5b5d6e52df0147a44a049779c8c",
			x"0093b04691a041eea22597a49b22c2ff34350e609b387b54130e4a27789e3ddd12",
			x"00f33378adf419718ff39a8f89b6150119ae6bdbbb2161fc6fdd7ad176c2763be5",
			x"017e94024d4d6a5d9a4a968ea04fdb729dd29161ec682423d2da91923b869a5f1e",
		];
		assert!(verify_proof(&merkle_tree, leaf_hash, proof), 7);


		// when leaf == '64', this is our proof. generated with typescript
		let leaf_hash = x"c043633486d685a8b0cd8014f79a12cb83055ff16f2076f2c22f2f31e5828d0f";
		assert!(leaf_hash == hash::sha3_256(b"64"), 8);
		let proof = vector<vector<u8>> [
			x"006d598c87bf4b41cb477b024473acab547d3dad60589c5162ade957155730571f",
			x"007e4f092eb7263c393b154706bfca582da43ab954c18eb157f439b6551013858f",
			x"00bbfa5a8e621958d73442dee8cd0d32fbcc9ee4ea0c34d152f0bfd6f2d13f807e",
			x"00dd6dbb4e822bc717b9a1eba9175af967fed85131293d7d93cc7a93ec26e82bed",
			x"00a98994829b5e9d1eda998ee53ea1dcfe946313e26198f8b2ae8df4cddcefef26",
			x"0032779c0c1da1bb75a128c4392e9353f1f89bd465fb5bb614d906302e11db4791",
		];
		assert!(verify_proof(&merkle_tree, leaf_hash, proof), 9);

		destroy(merkle_tree);
	}



}
