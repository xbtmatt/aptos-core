module package::test_merkle {
    use package::merkle_tree::{Self, MerkleTree};
    use std::signer;
    use std::error;
    use std::hash;
    use std::bcs;

    /// Only the package deployer can call this function.
    const ENOT_PACKAGE_OWNER: u64 = 0;
    /// The sender's address is not present in the merkle tree.
    const ENOT_IN_MERKLE_TREE: u64 = 1;

    struct MerkleTreeResource has key {
        inner: MerkleTree,
    }

    /// Creates the merkle tree based off of the root hash. This root hash is calculated with the 'merkletreejs' javascript library.
    /// More details in the merkle_tree.move file.
    /// Use the ~/aptos-core/ecosystem/typescript/sdk/examples/typescript-esm/merkle_tree.ts file to see how to generate the root hash.
    public entry fun init_and_store(owner: &signer, root_hash: vector<u8>) {
        move_to(
            owner,
            MerkleTreeResource {
                inner: merkle_tree::new(root_hash),
            }
        );
    }

    /// This function verifies the sender has elevated access by checking its presence in the merkle tree.
    /// Then it theoretically would do something once elevated access has been verified.
    public entry fun do_something_with_elevated_access(
        sender: &signer,
        merkle_owner: address,
        proof: vector<vector<u8>>,
    ) acquires MerkleTreeResource {
        let sender_addr = signer::address_of(sender);
        assert!(verify_proof(sender_addr, merkle_owner, proof), error::invalid_argument(ENOT_IN_MERKLE_TREE));
        // ...
        // Now we can do something with elevated access.
    }

    #[view]
    /// Verifies that the given proof is valid for the given sender.
    /// The validation here is arbitrary and depends on how you as the developer want to verify the presence of something in the merkle tree.
    /// In this case, we verify the sender's address is in the tree.
    public fun verify_proof(
        address_to_verify: address,
        merkle_owner: address,
        proof: vector<vector<u8>>
    ): bool acquires MerkleTreeResource {
        // Our leaf node in this case (the thingw e're verifying the presence of in the tree) is the sender's address, serialized to BCS bytes.
        let address_bytes = hash::sha3_256(bcs::to_bytes(&address_to_verify));
        merkle_tree::verify_proof(
            &borrow_global<MerkleTreeResource>(merkle_owner).inner,
            address_bytes,
            proof
        )
    }
}
