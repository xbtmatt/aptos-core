import {
  AptosAccount,
  FaucetClient,
  Network,
  Provider,
  HexString,
  TxnBuilderTypes,
  Types,
  TransactionBuilder,
  TransactionBuilderABI,
  TransactionBuilderRemoteABI,
  TypeTagParser,
} from "aptos";
export const NODE_URL = process.env.APTOS_NODE_URL || "http://0.0.0.0:8080" || "https://fullnode.devnet.aptoslabs.com";
export const FAUCET_URL =
  process.env.APTOS_FAUCET_URL || "http://0.0.0.0:8081" || "https://faucet.devnet.aptoslabs.com";

const provider = new Provider({ fullnodeUrl: NODE_URL, indexerUrl: "none" });
const aptosClient = provider.aptosClient;
const faucetClient = new FaucetClient(NODE_URL, FAUCET_URL);

function toTransactionArguments(abiArgs: any[], args: any[]): TxnBuilderTypes.TransactionArgument[] {
  if (abiArgs.length !== args.length) {
    throw new Error("Wrong number of args provided.");
  }

  return args.map((arg, i) => argToTransactionArgument(arg, abiArgs[i].type_tag));
}

export const fetchABI = async (addr: string) => {
  const modules = await aptosClient.getAccountModules(addr);
  const resource = modules
    .map((module) => module.abi)
    .flatMap((abi) => abi.structs)
    .find((struct) => struct.name === "Resource");
  //console.log(resource);
  const argumentABIs = resource.fields.map((f) => {
    console.log(f.name, f.type);
    return new TxnBuilderTypes.ArgumentABI(`${f.name}`, new TypeTagParser(f.type, []).parseTypeTag());
  });

  const myArgs = [
    // primitives

    8, // arg_1: u8,
    16, // arg_2: u16,
    32, // arg_3: u32,
    64, // arg_4: u64,
    128, // arg_5: u128,
    256, // arg_6: u256,
    true, // arg_7: bool,
    "string", // arg_8: String,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_9: address,

    // objects

    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_10: Object<u8>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_11: Object<u16>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_12: Object<u32>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_13: Object<u64>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_14: Object<u128>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_15: Object<u256>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_16: Object<bool>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_17: Object<String>,
    new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451"), // arg_18: Object<address>,

    // options

    [8], // arg_19: Option<u8>,
    [16], // arg_20: Option<u16>,
    [32], // arg_21: Option<u32>,
    [64], // arg_22: Option<u64>,
    [128], // arg_23: Option<u128>,
    [256], // arg_24: Option<u256>,
    [true], // arg_25: Option<bool>,
    ["string"], // arg_26: Option<String>,
    [new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451")], // arg_27: Option<address>,

    // vectors

    [8], // arg_28: vector<u8>,
    [16], // arg_29: vector<u16>,
    [32], // arg_30: vector<u32>,
    [64], // arg_31: vector<u64>,
    [128], // arg_32: vector<u128>,
    [256], // arg_33: vector<u256>,
    [true], // arg_34: vector<bool>,
    ["string"], // arg_35: vector<String>,
    [new HexString("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451")], // arg_36: vector<address>,
  ];

  const transactionArguments = argumentABIs.map((arg, i) => {
    console.log("\n---------------------------------------------------------------");
    console.log(myArgs[i], arg.name, arg.type_tag);
    console.log(argToTransactionArgument(myArgs[i], arg.type_tag));
    argToTransactionArgument(myArgs[i], arg.type_tag);
  });
  console.debug(transactionArguments);

  // modules.map((module) => {
  //   module.abi
  // }).flatMap((abi) => { console.log(abi); });

  // const abis = modules
  //   .map((module) => module.abi)
  //   .flatMap((abi) =>
  //     abi!.structs
  //       .filter((ef) => ef.fields.every((f) => isSupportedStruct(f)))
  //       .map(
  //         (ef) =>
  //           { ef
  //           console.debug(ef.fields.map(f => new TxnBuilderTypes.ArgumentABI(`var${f}`, new TypeTagParser(f.type, []).parseTypeTag()))) }
  //       ),
  //   );

  // // Convert abi string arguments to TypeArgumentABI
  // const typeArgABIs = abiArgs.map(
  //   (abiArg, i) => new TxnBuilderTypes.ArgumentABI(`var${i}`, new TypeTagParser(abiArg, ty_tags).parseTypeTag()),
  // );
};

function isSupportedStruct(f: Types.MoveStructField): boolean {
  const arr = [
    "u8",
    "u16",
    "u32",
    "u64",
    "u128",
    "u256",
    "bool",
    "String",
    "address",
    "0x1::object::Object",
    "0x1::string::String",
    "0x1::option::Option",
    "vector",
  ];

  return arr.includes(f.type);
}

function isObjectTypeTag(tag: TxnBuilderTypes.TypeTagStruct): boolean {
  if (
    tag.value.module_name.value === "object" &&
    tag.value.name.value === "Object" &&
    tag.value.address.toHexString() === TxnBuilderTypes.AccountAddress.CORE_CODE_ADDRESS.toHexString()
  ) {
    return true;
  }
  return false;
}

function isOptionTypeTag(tag: TxnBuilderTypes.TypeTagStruct): boolean {
  if (
    tag.value.module_name.value === "option" &&
    tag.value.name.value === "Option" &&
    tag.value.address.toHexString() === TxnBuilderTypes.AccountAddress.CORE_CODE_ADDRESS.toHexString()
  ) {
    return true;
  }
  return false;
}

export function argToTransactionArgument(
  argVal: any,
  argType: TxnBuilderTypes.TypeTag,
): TxnBuilderTypes.TransactionArgument {
  if (argType instanceof TxnBuilderTypes.TypeTagStruct) {
    console.debug(argType);
    console.debug(argVal);
    if (argType.isStringTypeTag()) {
    } else if (isObjectTypeTag(argType)) {
    } else if (isOptionTypeTag(argType)) {
      return new TxnBuilderTypes.TransactionArgumentU8Vector();
    }
  }
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

async function main() {
  await fetchABI("0x0a56e8b03118e51cf88140e5e18d1f764e0a1048c23e7c56bd01bd5b76993451");
}

main();
