
import { AptosAccount, FaucetClient, Network, Provider, HexString, TxnBuilderTypes, Types, TransactionBuilder, TransactionBuilderABI, TransactionBuilderRemoteABI, TypeTagParser } from "aptos";
export const NODE_URL = process.env.APTOS_NODE_URL || "https://fullnode.devnet.aptoslabs.com";
export const FAUCET_URL = process.env.APTOS_FAUCET_URL || "https://faucet.devnet.aptoslabs.com";

const provider = new Provider(Network.LOCAL);
const aptosClient = provider.aptosClient;
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

export const fetchABI = async(addr: string) => {
    const modules = await aptosClient.getAccountModules(addr);
    const resource = modules.map((module) => module.abi).flatMap((abi) => abi.structs).find((struct) => struct.name === 'Resource');
    //console.log(resource);
    const argumentABIs = resource.fields.map((f) =>
      new TxnBuilderTypes.ArgumentABI(`${f.name}`, new TypeTagParser(f.type, []).parseTypeTag());
    );

    argumentABIs.map((arg, i) => argToTransactionArgument(arg, abiArgs[i].type_tag));
    
  public static toTransactionArguments(abiArgs: any[], args: any[]): TransactionArgument[] {
    if (abiArgs.length !== args.length) {
      throw new Error("Wrong number of args provided.");
    }

    return args.map((arg, i) => argToTransactionArgument(arg, abiArgs[i].type_tag));
  }

    modules.map((module) => {
      module.abi
    }).flatMap((abi) => { console.log(abi); });

    const abis = modules
      .map((module) => module.abi)
      .flatMap((abi) =>
        abi!.structs
          .filter((ef) => ef.fields.every((f) => isSupportedStruct(f)))
          .map(
            (ef) =>
              { ef
              console.debug(ef.fields.map(f => new TxnBuilderTypes.ArgumentABI(`var${f}`, new TypeTagParser(f.type, []).parseTypeTag()))) }
          ),
      );

      // // Convert abi string arguments to TypeArgumentABI
      // const typeArgABIs = abiArgs.map(
      //   (abiArg, i) => new TxnBuilderTypes.ArgumentABI(`var${i}`, new TypeTagParser(abiArg, ty_tags).parseTypeTag()),
      // );

  }
  
  function isSupportedStruct(f: Types.MoveStructField): boolean {
    const arr = ['u8',
    'u16',
    'u32',
    'u64',
    'u128',
    'u256',
    'bool',
    'String',
    'address',
    '0x1::object::Object',
    '0x1::string::String',
    '0x1::option::Option',
    'vector'];
  
    return (arr.includes(f.type))
  
  }


  
(async () => {
  await fetchABI("0x9cb015cc08c4c21a68ec80011163cafc3cecbc9a359b8daeac108d0a2cc8f646");
})()




export function argToTransactionArgument(argVal: any, argType: TxnBuilderTypes.TypeTag): TxnBuilderTypes.TransactionArgument {
  if (argType instanceof TxnBuilderTypes.TypeTagBool) {
    return new TxnBuilderTypes.TransactionArgumentBool(ensureBoolean(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU8) {
    return new TxnBuilderTypes.TransactionArgumentU8(ensureNumber(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU16) {
    return new TxnBuilderTypes.TransactionArgumentU16(ensureNumber(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU32) {
    return new TxnBuilderTypes.TransactionArgumentU32(ensureNumber(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU64) {
    return new TxnBuilderTypes.TransactionArgumentU64(ensureBigInt(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU128) {
    return new TxnBuilderTypes.TransactionArgumentU128(ensureBigInt(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagU256) {
    return new TxnBuilderTypes.TransactionArgumentU256(ensureBigInt(argVal));
  }
  if (argType instanceof TxnBuilderTypes.TypeTagAddress) {
    let addr: TxnBuilderTypes.AccountAddress;
    if (typeof argVal === "string" || argVal instanceof HexString) {
      addr = TxnBuilderTypes.AccountAddress.fromHex(argVal);
    } else if (argVal instanceof TxnBuilderTypes.AccountAddress) {
      addr = argVal;
    } else {
      throw new Error("Invalid account address.");
    }
    return new TxnBuilderTypes.TransactionArgumentAddress(addr);
  }
  if (argType instanceof TxnBuilderTypes.TypeTagVector && argType.value instanceof TxnBuilderTypes.TypeTagU8) {
    if (!(argVal instanceof Uint8Array)) {
      throw new Error(`${argVal} should be an instance of Uint8Array`);
    }
    return new TxnBuilderTypes.TransactionArgumentU8Vector(argVal);
  }

  throw new Error("Unknown type for TransactionArgument.");
}


function assertType(val: any, types: string[] | string, message?: string) {
  if (!types?.includes(typeof val)) {
    throw new Error(
      message || `Invalid arg: ${val} type should be ${types instanceof Array ? types.join(" or ") : types}`,
    );
  }
}

export function ensureBoolean(val: boolean | string): boolean {
  assertType(val, ["boolean", "string"]);
  if (typeof val === "boolean") {
    return val;
  }

  if (val === "true") {
    return true;
  }
  if (val === "false") {
    return false;
  }

  throw new Error("Invalid boolean string.");
}

export function ensureNumber(val: number | string): number {
  assertType(val, ["number", "string"]);
  if (typeof val === "number") {
    return val;
  }

  const res = Number.parseInt(val, 10);
  if (Number.isNaN(res)) {
    throw new Error("Invalid number string.");
  }

  return res;
}

export function ensureBigInt(val: number | bigint | string): bigint {
  assertType(val, ["number", "bigint", "string"]);
  return BigInt(val);
}