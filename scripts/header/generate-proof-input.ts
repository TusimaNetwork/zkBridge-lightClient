import {BeaconChainAPI} from "../common/beacon-chain-api";
import {Utils} from "../common/utils";
import {SyncCommittee} from "../common/sync-committee";
// @ts-ignore
import {bls, PublicKey} from "@chainsafe/bls/blst-native";
// @ts-ignore
import {BitArray, fromHexString} from "@chainsafe/ssz";
// @ts-ignore
import {ethers} from "ethers";

export async function generateInputForProof(slotStr: string) {
	console.log(`Generating Input data for proving slot: ${slotStr}`);
	if (!(slotStr == 'latest' || !isNaN(Number(slotStr)))) {
		throw new Error('Slot is invalid. Must be `latest` or number');
	}
	const beaconAPI = new BeaconChainAPI();
	const syncCommittee = new SyncCommittee(beaconAPI);

	const slot = Number(slotStr);
	const committee = await syncCommittee.getValidatorsPubKey(slot);
	const beaconBlockHeader = await beaconAPI.getBeaconBlockHeader(slot);
	// Sync Committee Bitmask and Signatures for slot X are at slot x+1
	const syncCommitteeAggregateData = await beaconAPI.getSyncCommitteeAggregateData(slot + 1);
	const genesisValidatorRoot = await beaconAPI.getGenesisValidatorRoot();
	const forkVersion = await beaconAPI.getForkVersion(slot);
	const signingRoot = computeSigningRoot(forkVersion, genesisValidatorRoot, beaconBlockHeader);

	console.log(`================================`);
	console.log(`forkVersion: ${forkVersion}`);
	console.log(`genesisValidatorRoot: ${genesisValidatorRoot}`);
	console.log(`beaconBlockHeader header_root: ${beaconBlockHeader.header_root}`);
	console.log(`beaconBlockHeader slot: ${beaconBlockHeader.slot}`);
	console.log(`beaconBlockHeader body_root: ${beaconBlockHeader.body_root}`);
	console.log(`beaconBlockHeader parent_root: ${beaconBlockHeader.parent_root}`);
	console.log(`beaconBlockHeader proposer_index: ${beaconBlockHeader.proposer_index}`);
	console.log(`beaconBlockHeader state_root: ${beaconBlockHeader.state_root}`);
	console.log(`signingRoot: ${signingRoot}`);
	console.log(`================================`);

	const syncCommitteeBits = syncCommittee.getSyncCommitteeBits(syncCommitteeAggregateData.sync_committee_bits);

	await verifyBLSSignature(ethers.utils.arrayify(signingRoot), committee.pubKeys, syncCommitteeAggregateData.sync_committee_signature, syncCommitteeBits)
	let participation = 0;
	const pubkeybits = syncCommitteeBits.map(e => {
		if (e) {
			participation++;
			return 1;
		} else {
			return 0;
		}
	})
	const proofInput = {
		signing_root: Utils.hexToIntArray(signingRoot),
		pubkeys: committee.pubKeysInt,
		pubkeybits,
		signature: Utils.sigHexAsSnarkInput(syncCommitteeAggregateData.sync_committee_signature)
	}
	return {slot, proofInput, participation};
}

async function verifyBLSSignature(signingRoot: Uint8Array, pubKeys: PublicKey[], aggregateSyncCommitteeSignature: string, bitmap: boolean[]) {
	const bits = BitArray.fromBoolArray(bitmap);
	const activePubKeys = bits.intersectValues<PublicKey>(pubKeys);
	if (activePubKeys.length <= (512 * 2) /3) {
		throw new Error(`No majority reached for this slot`);
	}
	const aggPubkey = bls.PublicKey.aggregate(activePubKeys);
	const sig = bls.Signature.fromBytes(fromHexString(aggregateSyncCommitteeSignature), undefined, true);
	const success = sig.verify(aggPubkey, signingRoot);

	console.log("Successful BLS Signature verification: ", success);
}

function computeSigningRoot(forkVersion: string, genesisValidatorRoot: string, beaconBlock: any): string {
	const sszHeader = sszBeaconBlockHeader(beaconBlock);
	const domain = computeDomain(forkVersion, genesisValidatorRoot);
	return ethers.utils.sha256(Buffer.concat([ethers.utils.arrayify(sszHeader), domain]));
}

function sszBeaconBlockHeader(beaconBlock: any) {
	const left = ethers.utils.sha256(Buffer.concat([
		ethers.utils.arrayify(ethers.utils.sha256(Buffer.concat([Buffer.concat([toLittleEndian(Number(beaconBlock.slot))], 32), Buffer.concat([toLittleEndian(Number(beaconBlock.proposer_index))], 32)]))),
		ethers.utils.arrayify(ethers.utils.sha256(Buffer.concat([ethers.utils.arrayify(beaconBlock.parent_root), ethers.utils.arrayify(beaconBlock.state_root)])))
	]));
	const right = ethers.utils.sha256(Buffer.concat([
		ethers.utils.arrayify(ethers.utils.sha256(Buffer.concat([ethers.utils.arrayify(beaconBlock.body_root), ethers.utils.arrayify(ethers.constants.HashZero)]))),
		ethers.utils.arrayify(ethers.utils.sha256(Buffer.concat([ethers.utils.arrayify(ethers.constants.HashZero), ethers.utils.arrayify(ethers.constants.HashZero)])))
	]));
	return ethers.utils.sha256(Buffer.concat([ethers.utils.arrayify(left), ethers.utils.arrayify(right)]));
}

function toLittleEndian(number: number): Buffer {
	let buf = Buffer.alloc(32)
	buf.writeUInt32LE(number);
	return buf;
}

function computeDomain(forkVersionStr: string, genesisValidatorsRootStr: string): Uint8Array {
	const forkVersion = ethers.utils.arrayify(forkVersionStr);
	const genesisValidatorRoot = ethers.utils.arrayify(genesisValidatorsRootStr);
	const right = ethers.utils.arrayify(ethers.utils.sha256(ethers.utils.defaultAbiCoder.encode(["bytes4", "bytes32"], [forkVersion, genesisValidatorRoot])));
	// SYNC_COMMITTEE_DOMAIN_TYPE https://github.com/ethereum/consensus-specs/blob/da3f5af919be4abb5a6db5a80b235deb8b4b5cba/specs/altair/beacon-chain.md#domain-types
	const domain = new Uint8Array(32);
	domain.set([7, 0, 0, 0], 0);
	domain.set(right.slice(0, 28), 4);
	return domain;
}
