import axios from "axios";
import {Utils} from "./utils";
import * as lodestar from '@lodestar/types';
import fetch from 'node-fetch';

const BEACON_API_V1 = `/eth/v1/beacon/`;
const BEACON_STATE_API = `/eth/v2/debug/beacon/states`;
const PUB_KEY_BATCH_SIZE = 100;

export class BeaconChainAPI {

	private readonly baseUrl: string;

	constructor() {
		this.baseUrl = process.env.BEACON_NODE_API || "";
	}

	async getSyncCommitteePubKeys(slot: number) {
		const result = await axios.get(`${this.baseUrl}${BEACON_API_V1}states/${slot}/sync_committees`);
		const committee = result.data.data.validators;
		const url = `${this.baseUrl}${BEACON_API_V1}states/${slot}/validators?id=`;
		const validator2PubKey = new Map<string, string>();
		for (let i = 0; i < Math.ceil(committee.length / PUB_KEY_BATCH_SIZE); i++) {
			const validatorIndices = committee.slice(i * PUB_KEY_BATCH_SIZE, (i + 1) * PUB_KEY_BATCH_SIZE);
			const resp = await axios.get(url + validatorIndices.toString());
			const validatorsBatchInfo = resp.data.data;
			for (let index in validatorsBatchInfo) {
				const validatorIndex = validatorsBatchInfo[index]['index'];
				const validatorPubKey = Utils.remove0x(validatorsBatchInfo[index]['validator']['pubkey']);
				validator2PubKey.set(validatorIndex, validatorPubKey)
			}
		}
		return committee.map((validatorIndex: string) => validator2PubKey.get(validatorIndex));
	}

	async getBeaconBlockHeader(slotN: number): Promise<BeaconBlockHeader> {
		const result = await axios.get(this.baseUrl + BEACON_API_V1 + `headers/` + slotN);
		const {slot, proposer_index, parent_root, state_root, body_root} = result.data.data.header.message;
		const header_root = result.data.data.root;
		return {slot, proposer_index, parent_root, state_root, body_root, header_root};
	}

	async getSyncCommitteeAggregateData(slotN: number) {
		const result = await axios.get(this.baseUrl + BEACON_API_V1 + `blocks/` + slotN, {
			headers: {
				accept: 'application/json'
			}
		});
		const {sync_committee_bits, sync_committee_signature} = result.data.data.message.body['sync_aggregate'];
		return {
			sync_committee_bits,
			sync_committee_signature
		};
	}

	async getBeaconBlock(slotN: number) {
		const result = await axios.get(this.baseUrl + BEACON_API_V1 + `blocks/` + slotN, {
			headers: {
				accept: 'application/json'
			}
		});
		return lodestar.ssz.bellatrix.BeaconBlockBody.fromJson(result.data.data.message.body);
	}

	async getGenesisValidatorRoot() {
		const result = await axios.get(this.baseUrl + BEACON_API_V1 + "genesis");
		return result.data.data['genesis_validators_root'];
	}

	async getForkVersion(slot: number) {
		const result = await axios.get(this.baseUrl + BEACON_API_V1 + `states/${slot}/fork`);
		return result.data.data['current_version'];
	}

	async getBeaconState(slot: number) {
		const response = await fetch(`${this.baseUrl + BEACON_STATE_API}/${slot}`);
		const beaconState = (await response.json())['data'];
		return lodestar.ssz.bellatrix.BeaconState.fromJson(beaconState);
	}
}

export type BeaconBlockHeader = {
	slot: number
	proposer_index: number
	parent_root: string
	state_root: string
	body_root: string
	header_root: string
}