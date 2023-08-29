// Copyright © Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

import { Serializable, Serializer } from "../../src/bcs/serializer";

describe("BCS Serializer", () => {
  let serializer: Serializer;

  beforeEach(() => {
    serializer = new Serializer();
  });

  it("serializes a non-empty string", () => {
    serializer.serializeStr("çå∞≠¢õß∂ƒ∫");
    expect(serializer.getBytes()).toEqual(
      new Uint8Array([
        24, 0xc3, 0xa7, 0xc3, 0xa5, 0xe2, 0x88, 0x9e, 0xe2, 0x89, 0xa0, 0xc2, 0xa2, 0xc3, 0xb5, 0xc3, 0x9f, 0xe2, 0x88,
        0x82, 0xc6, 0x92, 0xe2, 0x88, 0xab,
      ]),
    );

    serializer = new Serializer();
    serializer.serializeStr("abcd1234");
    expect(serializer.getBytes()).toEqual(new Uint8Array([8, 0x61, 0x62, 0x63, 0x64, 0x31, 0x32, 0x33, 0x34]));
  });

  it("serializes an empty string", () => {
    serializer.serializeStr("");
    expect(serializer.getBytes()).toEqual(new Uint8Array([0]));
  });

  it("serializes dynamic length bytes", () => {
    serializer.serializeBytes(new Uint8Array([0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(serializer.getBytes()).toEqual(new Uint8Array([5, 0x41, 0x70, 0x74, 0x6f, 0x73]));
  });

  it("serializes dynamic length bytes with zero elements", () => {
    serializer.serializeBytes(new Uint8Array([]));
    expect(serializer.getBytes()).toEqual(new Uint8Array([0]));
  });

  it("serializes fixed length bytes", () => {
    serializer.serializeFixedBytes(new Uint8Array([0x41, 0x70, 0x74, 0x6f, 0x73]));
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x41, 0x70, 0x74, 0x6f, 0x73]));
  });

  it("serializes fixed length bytes with zero element", () => {
    serializer.serializeFixedBytes(new Uint8Array([]));
    expect(serializer.getBytes()).toEqual(new Uint8Array([]));
  });

  it("serializes a boolean value", () => {
    serializer.serializeBool(true);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x01]));

    serializer = new Serializer();
    serializer.serializeBool(false);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x00]));
  });

  it("throws when serializing a boolean value with wrong data type", () => {
    expect(() => {
      // @ts-ignore
      serializer.serializeBool(12);
    }).toThrow("Value needs to be a boolean");
  });

  it("serializes a uint8", () => {
    serializer.serializeU8(255);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0xff]));
  });

  it("throws when serializing uint8 with out of range value", () => {
    expect(() => {
      serializer.serializeU8(256);
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU8(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes a uint16", () => {
    serializer.serializeU16(65535);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0xff, 0xff]));

    serializer = new Serializer();
    serializer.serializeU16(4660);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x34, 0x12]));
  });

  it("throws when serializing uint16 with out of range value", () => {
    expect(() => {
      serializer.serializeU16(65536);
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU16(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes a uint32", () => {
    serializer.serializeU32(4294967295);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0xff, 0xff, 0xff, 0xff]));

    serializer = new Serializer();
    serializer.serializeU32(305419896);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x78, 0x56, 0x34, 0x12]));
  });

  it("throws when serializing uint32 with out of range value", () => {
    expect(() => {
      serializer.serializeU32(4294967296);
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU32(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes a uint64", () => {
    serializer.serializeU64(BigInt("18446744073709551615"));
    expect(serializer.getBytes()).toEqual(new Uint8Array([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]));

    serializer = new Serializer();
    serializer.serializeU64(BigInt("1311768467750121216"));
    expect(serializer.getBytes()).toEqual(new Uint8Array([0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12]));
  });

  it("throws when serializing uint64 with out of range value", () => {
    expect(() => {
      serializer.serializeU64(BigInt("18446744073709551616"));
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU64(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes a uint128", () => {
    serializer.serializeU128(BigInt("340282366920938463463374607431768211455"));
    expect(serializer.getBytes()).toEqual(
      new Uint8Array([0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
    );

    serializer = new Serializer();
    serializer.serializeU128(BigInt("1311768467750121216"));
    expect(serializer.getBytes()).toEqual(
      new Uint8Array([0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]),
    );
  });

  it("throws when serializing uint128 with out of range value", () => {
    expect(() => {
      serializer.serializeU128(BigInt("340282366920938463463374607431768211456"));
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU128(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes a uleb128", () => {
    serializer.serializeU32AsUleb128(104543565);
    expect(serializer.getBytes()).toEqual(new Uint8Array([0xcd, 0xea, 0xec, 0x31]));
  });

  it("throws when serializing uleb128 with out of range value", () => {
    expect(() => {
      serializer.serializeU32AsUleb128(4294967296);
    }).toThrow("Value is out of range");

    expect(() => {
      serializer = new Serializer();
      serializer.serializeU32AsUleb128(-1);
    }).toThrow("Value is out of range");
  });

  it("serializes multiple values procedurally", () => {
    const serializedBytes = serializer
      .serializeBytes(new Uint8Array([0x41, 0x70, 0x74, 0x6f, 0x73]))
      .serializeBool(true)
      .serializeBool(false)
      .serializeU8(254)
      .serializeU8(255)
      .serializeU16(65535)
      .serializeU16(4660)
      .serializeU32(4294967295)
      .serializeU32(305419896)
      .serializeU64(BigInt("18446744073709551615"))
      .serializeU64(BigInt("1311768467750121216"))
      .serializeU128(BigInt("340282366920938463463374607431768211455"))
      .serializeU128(BigInt("1311768467750121216"))
      .getBytes();
    expect(serializedBytes).toEqual(
      new Uint8Array([
        5, 0x41, 0x70, 0x74, 0x6f, 0x73, 0x01, 0x00, 0xfe, 0xff, 0xff, 0xff, 0x34, 0x12, 0xff, 0xff, 0xff, 0xff, 0x78,
        0x56, 0x34, 0x12, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00, 0xef, 0xcd, 0xab, 0x78, 0x56, 0x34,
        0x12, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x00,
        0xef, 0xcd, 0xab, 0x78, 0x56, 0x34, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]),
    );
  });

  it("serializes multiple Serializable values", () => {
    class MoveStructA implements Serializable {
      constructor(
        public name: string,
        public description: string,
        public enabled: boolean,
        public numbers: Array<number>,
      ) {}

      serialize(serializer: Serializer): void {
        serializer
          .serializeStr(this.name)
          .serializeStr(this.description)
          .serializeBool(this.enabled)
          .serializeBytes(new Uint8Array(this.numbers));
      }
    }
    class MoveStructB implements Serializable {
      constructor(
        public moveStructA: MoveStructA,
        public name: string,
        public description: string,
        public numbers: Array<number>,
      ) {}

      serialize(serializer: Serializer): void {
        serializer
          .serialize(this.moveStructA)
          .serializeStr(this.name)
          .serializeStr(this.description)
          .serializeBytes(new Uint8Array(this.numbers));
      }
    }

    const moveStructA = new MoveStructA("abc", "123", false, [1, 2, 3, 4]);
    const moveStructB = new MoveStructB(moveStructA, "def", "456", [5, 6, 7, 8]);

    const serializedBytes = serializer.serialize(moveStructB).getBytes();

    expect(serializedBytes).toEqual(
      new Uint8Array([
        3, 0x61, 0x62, 0x63, 3, 0x31, 0x32, 0x33, 0x00, 4, 0x01, 0x02, 0x03, 0x04, 3, 0x64, 0x65, 0x66, 3, 0x34, 0x35, 0x36,
        4, 0x05, 0x06, 0x07, 0x08,
      ]),
    );
  });
});
