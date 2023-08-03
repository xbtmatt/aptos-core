import { TransactionBuilder, TransactionBuilderABI, TransactionBuilderRemoteABI } from "../../transaction_builder";
import { AptosClient } from "../../providers";
import { getFaucetClient, longTestTimeout, NODE_URL } from "./test_helper.test";
import { AptosAccount } from "../../account";
import {
  RawTransaction,
  TransactionPayloadEntryFunction,
  TypeTagBool,
  TypeTagStruct,
  TypeTagU8,
  TypeTagVector,
} from "../../aptos_types";
import { HexString } from "../../utils";
import { FaucetClient } from "../../plugins";
import { MoveFunction, MoveStructField } from "../../generated";

const aptosClient = new AptosClient("http://0.0.0.0:8080");
const alice = new AptosAccount();

describe("TransactionBuilderRemoteABI", () => {
  test(
    "generates raw txn from an entry function",
    async () => {
      const faucetClient = new FaucetClient(aptosClient.nodeUrl, "http://0.0.0.0:8081")
      await faucetClient.fundAccount(alice.address(), 100000000);
      // Create an instance of the class
      const builder = new TransactionBuilderRemoteABI(aptosClient, { sender: alice.address() });

      await fetchABI('0x9cb015cc08c4c21a68ec80011163cafc3cecbc9a359b8daeac108d0a2cc8f646');

    },
    longTestTimeout,
  );




});

const fetchABI = async(addr: string) => {
  const modules = await aptosClient.getAccountModules(addr);
  const abis = modules
    .map((module) => module.abi)
    .flatMap((abi) =>
      abi!.structs
        .filter((ef) => ef.fields.every((f) => isSupportedStruct(f)))
        .map(
          (ef) =>
            ef
        ),
    );

  const abiMap = new Map<string, string>();
  abis.forEach((abi) => {
    abi.fields.forEach( (f) =>
      abiMap.set(f.name, f.type)
    )
  });

  console.log(abiMap);

  return abiMap;
}

function isSupportedStruct(f: MoveStructField): boolean {
  const arr = ['u8',
  'u16',
  'u32',
  'u64',
  'u128',
  'u256',
  'bool',
  'String',
  'address',
  ' Object<u8>',
  ' Option<address>',
  ' vector<address>'];
  console.log(f.type);

  return (arr.includes(f.type))

}