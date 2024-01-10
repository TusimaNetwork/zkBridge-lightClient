import {PointG1, PointG2} from "@noble/bls12-381";

const N: number = 55; // The number of bits to use per register
const K: number = 7; // The number of registers

export namespace Utils {
  export function remove0x(str: string): string {
    if (str.startsWith("0x")) {
      str = str.slice(2);
    }
    return str;
  }

  export function hexToIntArray(hex: string): string[] {
    hex = remove0x(hex);
    if (hex.length % 2) {
      throw new Error("hexToBytes: received invalid not padded hex");
    }
    const array = [];
    for (let i = 0; i < hex.length / 2; i++) {
      const j = i * 2;
      const hexByte = hex.slice(j, j + 2);
      if (hexByte.length !== 2) throw new Error("Invalid byte sequence");
      const byte = Number.parseInt(hexByte, 16);
      if (Number.isNaN(byte) || byte < 0) {
        console.log(hexByte, byte);
        throw new Error("Invalid byte sequence");
      }
      array.push(BigInt(byte).toString());
    }
    return array;
  }

  export function pointToBigInt(point: PointG1): [bigint, bigint] {
    let [x, y] = point.toAffine();
    return [x.value, y.value];
  }

  export function bigIntToArray(x: bigint) {
    let mod: bigint = 1n;
    for (let idx = 0; idx < N; idx++) {
      mod = mod * 2n;
    }

    let ret: string[] = [];
    let x_temp: bigint = x;
    for (let idx = 0; idx < K; idx++) {
      ret.push((x_temp % mod).toString());
      x_temp = x_temp / mod;
    }
    return ret;
  }

  export function sigHexAsSnarkInput(
    signatureHex: string,
  ) {
    const sig = PointG2.fromSignature(remove0x(signatureHex));
    sig.assertValidity();
    return [
      [
        bigIntToArray(sig.toAffine()[0].c0.value),
        bigIntToArray(sig.toAffine()[0].c1.value),
      ],
      [
        bigIntToArray(sig.toAffine()[1].c0.value),
        bigIntToArray(sig.toAffine()[1].c1.value),
      ],
    ];
  }

  export function padBitsToUint8Length(str: string): string {
    while (str.length < 8) {
      str = "0" + str;
    }
    return str;
  }
}