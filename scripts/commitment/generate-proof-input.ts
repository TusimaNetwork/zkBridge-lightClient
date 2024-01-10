import {aggregatePublicKeys} from "@noble/bls12-381";
import {SyncCommittee} from "../common/sync-committee";
import {BeaconChainAPI} from "../common/beacon-chain-api";

const SLOTS_PER_SYNC_COMMITTEE_PERIOD = 8192

export async function generateProofInput(period: string) {
  console.log(`Generating Input data for proving Sync Committee for period: ${period}`)

  if (!(period == 'latest' || period == 'next' || !isNaN(Number(period)))) {
    throw new Error('Period is invalid. Must be `latest`, `next` or number');
  }

  const beaconAPI = new BeaconChainAPI();
  const syncCommittee = new SyncCommittee(beaconAPI);

  const slot = Number(period) * SLOTS_PER_SYNC_COMMITTEE_PERIOD;
  const result = await syncCommittee.getValidatorsPubKey(slot);
  const aggregatePubKeyBytes = aggregatePublicKeys(result.pubKeys.map(e => e.toBytes()));
  const aggregatePubKeyHex: string[] = [];
  aggregatePubKeyBytes.forEach(v => aggregatePubKeyHex.push(v.toString()));
  return {
    pubkeys: result.pubKeysInt,
    pubkeyHex: result.pubKeysHex,
    aggregatePubkeyHex: aggregatePubKeyHex
  };
}
