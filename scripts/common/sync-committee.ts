import {Utils} from "./utils";
import {PointG1} from "@noble/bls12-381";
import {BeaconChainAPI} from "./beacon-chain-api";
import {PublicKey }  from "@chainsafe/bls/blst-native";
import {fromHexString} from "@chainsafe/ssz";

export class SyncCommittee {

	private readonly beaconAPI: BeaconChainAPI;

	constructor(beaconAPI: BeaconChainAPI) {
		this.beaconAPI = beaconAPI;
	}


	async getValidatorsPubKey(slot: number) {
		const committeePubKeys = await this.beaconAPI.getSyncCommitteePubKeys(slot);

		const pubKeys: PublicKey[] = [];
		const pubKeysInt = [];
		const pubKeysHex = [];
		for (let i = 0; i < committeePubKeys.length; i++) {
			const pubKey = committeePubKeys[i];
			const point = PointG1.fromHex(pubKey);
			const bigInts = Utils.pointToBigInt(point);
			pubKeysInt.push([
				Utils.bigIntToArray(bigInts[0]),
				Utils.bigIntToArray(bigInts[1])
			]);
			pubKeysHex.push(Utils.hexToIntArray(pubKey));
			pubKeys.push(PublicKey.fromBytes(fromHexString(pubKey)))
		}

		return {
			pubKeys: pubKeys,
			pubKeysInt: pubKeysInt,
			pubKeysHex: pubKeysHex
		}
	}

	getSyncCommitteeBits(aggregatedBits: string) {
		let aggregatedBitsString: any[] = [];
		aggregatedBits = Utils.remove0x(aggregatedBits);
		for (let i = 0; i < aggregatedBits.length; i = i + 2) {
			let uint8Bits = parseInt(aggregatedBits[i] + aggregatedBits[i + 1], 16).toString(2);
			uint8Bits = this.padBitsToUint8Length(uint8Bits);
			aggregatedBitsString = aggregatedBitsString.concat(uint8Bits.split('').reverse());
		}
		return aggregatedBitsString.map(bit => { return !!Number(bit) });
	}

	padBitsToUint8Length(str: string): string {
		while (str.length < 8) {
			str = '0' + str;
		}
		return str;
	}
}