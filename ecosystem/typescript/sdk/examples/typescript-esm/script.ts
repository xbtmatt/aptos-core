import { HexString, AptosAccount, TxnBuilderTypes, Provider, Network, Types } from 'aptos';
​
const submitScriptTransaction = async(
    provider: Provider,
    acc: AptosAccount,
    bytecode: Uint8Array,
): Promise<Types.Transaction> => {
	const script = new TxnBuilderTypes.Script(bytecode, [], []);
	const scriptPayload = new TxnBuilderTypes.TransactionPayloadScript(script);
	
	const txn = await provider.generateSignSubmitTransaction(acc, scriptPayload);
	const res = await provider.waitForTransactionWithResult(txn);
	return res;
}
​
const scriptBytecode = new 
HexString('a11ceb0b0600000006010002020208030a0f05190e072756087d200000000102000003060000020001000004030400000504020001060c0108000001060800010801066f626a6563740e436f6e7374727563746f725265661a6372656174655f6f626a6563745f66726f6d5f6163636f756e740944656c6574655265661367656e65726174655f64656c6574655f7265660664656c6574650000000000000000000000000000000000000000000000000000000000000001000001070b0011000c010e011101110202');
const pk = '980be56b2ac2dfe6c56e585453c1ba4ddcd3f395947f3507c67fb2117d507725';
const account = new AptosAccount(Buffer.from(pk, 'hex'));
const provider = new Provider(Network.DEVNET);
​
async function main() {
	const txnResponse = await submitScriptTransaction(provider, account, scriptBytecode.toUint8Array());
    console.debug(txnResponse);
}
​
main();
