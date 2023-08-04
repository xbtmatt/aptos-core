import {
  TransactionBuilder,
  TransactionBuilderABI,
  TransactionBuilderRemoteABI,
  TxnBuilderTypes,
  argToTransactionArgument,
  serializeArg,
} from "../../transaction_builder";
import { AptosClient } from "../../providers";
import { FAUCET_URL, getFaucetClient, longTestTimeout, NODE_URL } from "./test_helper.test";
import { AptosAccount } from "../../account";
import {
  RawTransaction,
  StructTag,
  TransactionPayloadEntryFunction,
  TypeTagBool,
  TypeTagParser,
  TypeTagStruct,
  TypeTagU8,
  TypeTagVector,
} from "../../aptos_types";
import { HexString } from "../../utils";
import { FaucetClient } from "../../plugins";
import { MoveFunction, MoveStructField } from "../../generated";
import { Serializer } from "../../bcs";
import { BCS } from "../..";

const aptosClient = new AptosClient(NODE_URL);
const alice = new AptosAccount();
const bob = new AptosAccount();
const MODULE_ADDRESS = "0x99b99d0324c6859c6e5b4be28915ab2c19bcc4710db71f56df1a1f3c73cd72ef";

describe("TransactionBuilderRemoteABI", () => {
  test(
    "signs an struct off-chain and verifies the signature on-chain",
    async () => {
      const faucetClient = new FaucetClient(aptosClient.nodeUrl, FAUCET_URL);
      await faucetClient.fundAccount(alice.address(), 100_000_000);
      await faucetClient.fundAccount(bob.address(), 100_000_000);

      const objForModule = (
        await aptosClient.view({
          function: `${MODULE_ADDRESS}::main::get_obj_addr`,
          type_arguments: [],
          arguments: [],
        })
      )[0];

      const resourceFields = [
        // primitives
        8,
        16,
        32,
        64,
        128,
        256,
        true,
        "string",
        alice.address(),
        // object
        new HexString(objForModule.toString()),
        // options
        8,
        16,
        32,
        64,
        128,
        256,
        true,
        "string",
        alice.address(),
        // vectors
        [8],
        [16],
        [32],
        [64],
        [128],
        [256],
        [true],
        ["string"],
        [alice.address()],
      ];

      // Next thing is to have it use a Map instead of an array
      // then you can generalize this serialization helper function to arguments
      // and you won't have to supply a vector of arguments anymore, you will be able to use named arguments!

      const rotationCapabilityOffer = [
        await aptosClient.getChainId(),
        (await aptosClient.getAccount(alice.address())).sequence_number,
        alice.address(),
        bob.address(),
      ];

      const rotationCapabilityOffer2 = {
        chain_id: await aptosClient.getChainId(),
        sequence_number: (await aptosClient.getAccount(alice.address())).sequence_number,
        source_address: alice.address(),
        recipient_address: bob.address(),
      };

      const bcsRotationCapability = await serializeResource(
        StructTag.fromString("0x1::account::RotationCapabilityOfferProofChallengeV2"),
        rotationCapabilityOffer,
      );
      const bcsRotationCapability2 = await serializeResource(
        StructTag.fromString("0x1::account::RotationCapabilityOfferProofChallengeV2"),
        rotationCapabilityOffer2,
      );
      console.log(
        HexString.fromUint8Array(bcsRotationCapability).toString() ==
          HexString.fromUint8Array(bcsRotationCapability2).toString(),
      );

      const signedMessage = await signStruct(
        alice,
        StructTag.fromString("0x1::account::RotationCapabilityOfferProofChallengeV2"),
        rotationCapabilityOffer2,
      );

      const res = await aptosClient.generateSignSubmitTransaction(
        alice,
        new TransactionPayloadEntryFunction(
          TxnBuilderTypes.EntryFunction.natural(
            "0x1::account",
            "offer_rotation_capability",
            [],
            [
              BCS.bcsSerializeBytes(signedMessage),
              BCS.bcsSerializeU8(0), // ed25519 scheme
              BCS.bcsSerializeBytes(alice.pubKey().toUint8Array()),
              BCS.bcsToBytes(TxnBuilderTypes.AccountAddress.fromHex(bob.address())),
            ],
          ),
        ),
      );
      console.debug(await aptosClient.waitForTransactionWithResult(res));

      {
        const signedResource = await signStruct(
          alice,
          StructTag.fromString(`${MODULE_ADDRESS}::main::Resource`),
          resourceFields,
        );
        const res = await aptosClient.generateSignSubmitTransaction(
          alice,
          new TransactionPayloadEntryFunction(
            TxnBuilderTypes.EntryFunction.natural(
              `${MODULE_ADDRESS}::main`,
              "verify_signed_struct",
              [],
              [BCS.bcsSerializeBytes(signedResource), BCS.bcsSerializeBytes(bob.pubKey().toUint8Array())],
            ),
          ),
        );
        console.debug(await aptosClient.waitForTransactionWithResult(res));
      }

      const serializedResource = await serializeResource(
        StructTag.fromString(`${MODULE_ADDRESS}::main::Resource`),
        resourceFields,
      );
      const viewResult = await aptosClient.view({
        function: `${MODULE_ADDRESS}::main::check_bcs_serialization`,
        type_arguments: [],
        arguments: [alice.address().toString(), HexString.fromUint8Array(serializedResource).toString()],
      });
      console.log(viewResult);

      const viewResult2 = await aptosClient.view({
        function: `${MODULE_ADDRESS}::main::view_bcs_resource`,
        type_arguments: [],
        arguments: [alice.address().toString()],
      });
      console.log(HexString.fromUint8Array(serializedResource));
      console.log(viewResult2);
    },
    longTestTimeout,
  );
});

export const signStruct = async (
  account: AptosAccount,
  structTag: StructTag,
  resourceFields: Array<any> | Object,
): Promise<Uint8Array> => {
  const serializedStruct = await serializeResource(structTag, resourceFields);
  const proofBytes = new Uint8Array([
    ...BCS.bcsToBytes(structTag.address),
    ...BCS.bcsSerializeStr(structTag.module_name.value),
    ...BCS.bcsSerializeStr(structTag.name.value),
    ...serializedStruct,
  ]);
  return account.signBuffer(proofBytes).toUint8Array();
};

const serializeResource = async (structTag: StructTag, resourceFields: Array<any> | Object): Promise<Uint8Array> => {
  const module = await aptosClient.getAccountModule(structTag.address.toHexString(), structTag.module_name.value);

  const resource = module.abi?.structs.find((struct) => struct.name === structTag.name.value);
  if (resource === undefined) {
    throw new Error(`Could not find resource struct for module ${structTag.module_name.value}`);
  }

  // const resource = modules.map((module) => module.abi).flatMap((abi) => abi!.structs).find((struct) => struct.name === 'Resource');
  //console.log(resource);
  const argumentABIs = resource!.fields.map((f) => {
    return new TxnBuilderTypes.ArgumentABI(`${f.name}`, new TypeTagParser(f.type, []).parseTypeTag());
  });

  let orderedResourceFields: Array<any> = [];
  if (!Array.isArray(resourceFields)) {
    Object.keys(resourceFields).map((field) => {
      if (!argumentABIs.find((arg) => arg.name === field)) {
        throw new Error(
          `${structTag.address.toHexString()}::${structTag.module_name.value}::${structTag.name.value} ` +
            `does not have a field named ${field}`,
        );
      }
      orderedResourceFields.push((resourceFields as any)[field]);
    });
  } else {
    orderedResourceFields = resourceFields;
  }

  if (orderedResourceFields.length != argumentABIs.length) {
    throw new Error(
      `${structTag.address.toHexString()}::${structTag.module_name.value}::${structTag.name.value} ` +
        `has ${argumentABIs.length} fields, got ${orderedResourceFields.length}`,
    );
  }

  const serializer = new Serializer();
  const transactionArguments = argumentABIs.forEach((arg, i) => {
    serializeArg(orderedResourceFields[i], arg.type_tag, serializer);
  });
  const bcsResourceHex = new HexString(
    "0x0810002000000040000000000000008000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000106737472696e67d4ad054fbddb3e917b053a6760f191a2d868e2514c05377bd4e7440b006eaf9ad4ad054fbddb3e917b053a6760f191a2d868e2514c05377bd4e7440b006eaf9a01080110000120000000014000000000000000018000000000000000000000000000000001000100000000000000000000000000000000000000000000000000000000000001010106737472696e6701d4ad054fbddb3e917b053a6760f191a2d868e2514c05377bd4e7440b006eaf9a01080110000120000000014000000000000000018000000000000000000000000000000001000100000000000000000000000000000000000000000000000000000000000001010106737472696e6701d4ad054fbddb3e917b053a6760f191a2d868e2514c05377bd4e7440b006eaf9a",
  );
  expect(bcsResourceHex.toString() == HexString.fromUint8Array(serializer.getBytes()).toString());
  return serializer.getBytes();
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
