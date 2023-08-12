import pkg from 'js-sha3';
import { TxnBuilderTypes, HexString, Network, Provider, AptosAccount, BCS, Types, FaucetClient } from 'aptos';
import { MerkleTree } from 'merkletreejs';
import assert from 'assert';
import { verify } from 'tweetnacl';
const { sha3_256 } = pkg;

const DEPLOYMENT_ADDRESS = TxnBuilderTypes.AccountAddress.fromHex(new HexString('0x7bebd4cb2f61101b5bfc9f17c2e0a7754368de05391333c6c02439d7f533bb49'));

const serializeVectorOfVectors = (proofVector: Array<Uint8Array>): Uint8Array => {
    const serializer = new BCS.Serializer();
    serializer.serializeU32AsUleb128(proofVector.length);
    proofVector.forEach(v => {
        serializer.serializeBytes(v);
    });
    // or serializer.serializeVectorWithFunc(proofVector, 'serializeBytes');
    return serializer.getBytes();
}

const createMerkleTreeOnChain = async (
    provider: Provider,
    account: AptosAccount,
    rootHash: HexString,
): Promise<Types.UserTransaction> => {
    assert(TxnBuilderTypes.AccountAddress.isValid(DEPLOYMENT_ADDRESS.toHexString()), 'The deployment address is not set or invalid.');
    const payload = new TxnBuilderTypes.TransactionPayloadEntryFunction(
        TxnBuilderTypes.EntryFunction.natural(
            `${DEPLOYMENT_ADDRESS.toHexString()}::test_merkle`,
            "init_and_store",
            [],
            [
                BCS.bcsSerializeBytes(rootHash.toUint8Array())
            ],
        ),
    );
    const txnHash = await provider.generateSignSubmitTransaction(account, payload);
    return (await provider.waitForTransactionWithResult(txnHash,)) as Types.UserTransaction;
}

const doSomethingWithElevatedAccessOnChain = async (
    provider: Provider,
    account: AptosAccount,
    merkleOwner: TxnBuilderTypes.AccountAddress,
    proofVectors: Array<Uint8Array>,
): Promise<Types.UserTransaction> => {
    assert(TxnBuilderTypes.AccountAddress.isValid(DEPLOYMENT_ADDRESS.toHexString()), 'The deployment address is not set or invalid.');
    const payload = new TxnBuilderTypes.TransactionPayloadEntryFunction(
        TxnBuilderTypes.EntryFunction.natural(
            `${DEPLOYMENT_ADDRESS.toHexString()}::test_merkle`,
            "do_something_with_elevated_access",
            [],
            [
                BCS.bcsToBytes(merkleOwner),
                serializeVectorOfVectors(proofVectors),
            ],
        ),
    );
    const txnHash = await provider.generateSignSubmitTransaction(account, payload);
    return (await provider.waitForTransactionWithResult(txnHash,)) as Types.UserTransaction;
}

const createProofVectorForAddress = (
    merkleTree: MerkleTree,
    accountAddress: TxnBuilderTypes.AccountAddress
): Array<Uint8Array> => {
    const leafHash = merkleTree.getProof(sha3_256(accountAddress.address));
    return leafHash.map(v =>
        Buffer.concat(
            [Buffer.from([v.position == 'left' ? 0 : 1]), new Uint8Array(v.data.valueOf())]
    ));
}

// Say I have a list of addresses I want to allow to do something and I want to use a merkle tree to do it
// the process for this, using this file and `merkle_tree.move` is as follows:
// 1. Create a list of all the addresses you want to allow to do something
//     - Use at least one address that you can call a contract entry function with later. (Can randomly generate this, shown below)
// 2. Convert each one to a vector of bytes that we can also verify on-chain as a `vector<u8>`
// 3. Create a MerkleTree from the vector of byte vectors
// 4. Deploy the merkle tree package on-chain.
// 5. Get the root hash of the MerkleTree and send it into the contract with the function:
//      `test_merkle::init_and_store(root_hash)`
// 6. Create a proof vector for the address you plan on testing with.
// 7. Call `test_merkle::verify_proof(proof, address)` with the proof vector and the address you want to test.
// 8. Call the entry function to view how you can gate access to this function with the merkle tree.

const main = async () => {
    // Here is where we store each addresses byte value representation as elements in the merkle tree
    const data = Array.from({ length: 64000 }, (_, i) =>
        TxnBuilderTypes.AccountAddress.fromHex(
            new HexString(i.toString(16))
        ).address
    );

    const network = Network.TESTNET;
    const provider = new Provider(network);
    const merkleOwner = new AptosAccount();
    console.log(`merkleOwner: ${merkleOwner.address().toString()}`)
    const testAccount = new AptosAccount();
    console.log(`testAccount: ${testAccount.address().toString()}`)
    const testAccountAddress = testAccount.address().toUint8Array();

    const faucetClient = new FaucetClient(
        provider.aptosClient.nodeUrl,
        `https://faucet.${network}.aptoslabs.com`,
    );

    // Fund our test accounts
    console.log('Funding accounts...');
    await faucetClient.fundAccount(merkleOwner.address(), 100_000_000);
    await faucetClient.fundAccount(testAccount.address(), 100_000_000);


    // Store our generated address as a value in the tree so we can test it later
    data[12321] = testAccountAddress;

    // Generate the merkle tree from the 64,000 addresses.
    let merkleTree = new MerkleTree(data.map(v => sha3_256(v)), sha3_256);

    console.debug()
    console.debug('Root Hash')
    console.debug('------------------------------------------------------------------------------')
    const root = new HexString(merkleTree.getHexRoot());
    console.debug(root.toString()); // for easy insertion into the contract as a hard coded vector<u8> value
    console.debug('------------------------------------------------------------------------------')

    console.log('Proof vector:')
    const proofVector = createProofVectorForAddress(merkleTree, TxnBuilderTypes.AccountAddress.fromHex(testAccount.address()));

    // View each hash in the proof vector. Note the first byte is the left or right position of the hash in the tree
    console.log(proofVector.forEach(v => console.log(HexString.fromUint8Array(v).toString())));

    // Serialize the proof vector into a vector<vector<u8>>
    const proofVectorSerialized = serializeVectorOfVectors(proofVector);

    console.log(proofVectorSerialized);


    // In a real e2e flow, this would happen at very different times, not in the same script.
    // This is merely to demonstrate the intended usage of this contract.

    // Create the merkle tree on-chain as the merkle owner
    {
        const createMerkleTreeTxn = await createMerkleTreeOnChain(provider, merkleOwner, root);
        const { hash, sender, success, payload, events, vm_status } = createMerkleTreeTxn;
        console.log('------------------');
        console.log('Create the merkle tree on-chain as the merkle owner');
        console.log({ hash, sender, success, payload, events, vm_status });
    }

    // Call the do_something_with_elevated_access function as the testAccount with the proof vector we generated from it earlier
    {
        const elevatedAccessTxn = await doSomethingWithElevatedAccessOnChain(
            provider,
            testAccount,
            TxnBuilderTypes.AccountAddress.fromHex(merkleOwner.address()),
            proofVector
        );
        const { hash, sender, success, payload, events, vm_status } = elevatedAccessTxn;
        console.log('------------------');
        console.log('Call the do_something_with_elevated_access function as the verified testAccount');
        console.log({ hash, sender, success, payload, events, vm_status });
        assert(success, 'The transaction failed.');
    }

    // Call the do_something_with_elevated_access function as an account that does NOT have elevated access
    // But use the proof earlier
    {
        const badAccount = new AptosAccount();
        await faucetClient.fundAccount(badAccount.address(), 100_000_000);
        const badAccountTxn = await doSomethingWithElevatedAccessOnChain(
            provider,
            badAccount,
            TxnBuilderTypes.AccountAddress.fromHex(merkleOwner.address()),
            proofVector
        );
        const { hash, sender, success, payload, events, vm_status } = badAccountTxn;
        console.log('------------------');
        console.log('Call the do_something_with_elevated_access function as an account that does NOT have elevated access');
        console.log({ hash, sender, success, payload, events, vm_status });
        assert(!success, 'The transaction should have failed.');
    }
}

main();