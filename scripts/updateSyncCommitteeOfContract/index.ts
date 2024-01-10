import minimist from "minimist";
import {generateProofInput} from "../syncCommitteeComittment/generate-proof-input";
import {ProverService} from "../common/prover";
import {BeaconChainAPI} from "../common/beacon-chain-api";
import {ethers} from "ethers";
import * as lodestar from "@lodestar/types";
import {createProof, ProofType, SingleProof} from "@chainsafe/persistent-merkle-tree";
import {generateInputForProof} from "../verifyHeaderSignatures/generate-proof-input";
import fs from "fs";

const LightClientABI = JSON.parse(fs.readFileSync("./../contracts/out/BeaconLightClient.sol/BeaconLightClient.json").toString());

async function updateSyncCommitteeOfContract(lightClient: string, period: string, usingSlot: string, rpcUrl: string, pk: string) {
  // Phase 1 Sync Committee Proof and Arguments
  const latestUpdatedPeriod = Number(period) - 1;
  // SLOT at which nextSyncCommittee was published for desired PERIOD
  const finalizedSlot = Number(latestUpdatedPeriod) * 8192;
  // SLOT at which the finalizedSlot is finalized (2 epochs in the future!)
  const attestedSlot = usingSlot ? Number(usingSlot) : finalizedSlot + 2 * 32;

  console.log(`Getting input data for SyncCommittee Proof generation for Period ${period}`);
  const prover = new ProverService();
  const proofInput = await generateProofInput(period);
  console.log(`Requesting ZKP from Prover`);

  // 1. Get All required data + Request ZKP proof for Sync Committee
  console.log(`Getting all the required data for Finalized slot: ${finalizedSlot} and Attested slot: ${attestedSlot}`);
  console.log(`Requesting ZKP for Sync Committee`);
  const beaconAPI = new BeaconChainAPI();
  const [finalizedState, attestedBeaconState, attestedBlock, finalizedBlock, attestedHeader, finalizedHeader, syncCommitteeProof] = await Promise.all([
    beaconAPI.getBeaconState(finalizedSlot),
    beaconAPI.getBeaconState(attestedSlot),
    beaconAPI.getBeaconBlock(attestedSlot),
    beaconAPI.getBeaconBlock(finalizedSlot),
    beaconAPI.getBeaconBlockHeader(attestedSlot),
    beaconAPI.getBeaconBlockHeader(finalizedSlot),
    prover.requestSyncCommitteeProof(proofInput),
  ])
  console.log(`Generated ZKP for Sync Committee Update`);

  // 2. Sanity checks
  if (Math.floor(finalizedSlot / 32) != attestedBeaconState.finalizedCheckpoint.epoch) {
    throw new Error(`Attested Beacon state finalized an older epoch and not the target one. Finalized epoch ${attestedBeaconState.finalizedCheckpoint.epoch}. Target Epoch ${Math.floor(finalizedSlot / 32)}`);
  }
  console.log(`Finalized checkpoint ${ethers.utils.hexlify(attestedBeaconState.finalizedCheckpoint.root)}`);

  // 3. Generate BLS Header ZK Proof
  const blsHeaderProofInput = await generateInputForProof(attestedSlot.toString());
  if (blsHeaderProofInput.participation <= 512 * 2 / 3) {
    throw new Error(`Low participation. Slot = ${attestedSlot}, Participation = ${blsHeaderProofInput.participation}`);
  } else {
    console.log(`Sync Committee Participation is ${blsHeaderProofInput.participation}`);
  }
  console.log(`Requesting BLS Verify ZKP from Prover`);
  const headerProof = await prover.requestHeaderProof(blsHeaderProofInput.proofInput);
  console.log(`Computed BLS Header proof`);

  // 4. Prepare transaction arguments
  const update = await buildLightClientUpdate(
    beaconAPI,
    attestedBeaconState,
    attestedBlock,
    attestedHeader,
    finalizedState,
    finalizedBlock,
    finalizedHeader,
    headerProof,
    blsHeaderProofInput.participation
  );

  console.log(`Submitting Sync Committee Update to contract`);

  // Submit TX
  const wallet = new ethers.Wallet(pk, new ethers.providers.JsonRpcProvider(rpcUrl));
  const lightClientContract = new ethers.Contract(lightClient, LightClientABI.abi, wallet);
  const tx = await lightClientContract.updateWithSyncCommittee(update, syncCommitteeProof.syncCommitteePoseidon, syncCommitteeProof.proof);
  console.log(`Submitted Sync Committee Update TX: ${tx.hash}`);
  await tx.wait();
  console.log(`Successfully updated Sync Committee period to ${period}`);
}

async function buildLightClientUpdate(beaconAPI: BeaconChainAPI, attestedState: any, attestedBlock: any, attestedHeader: any, finalizedState: any, finalizedBlock: any, finalizedHeader: any, headerProof: any, participation: number) {
  const executionStateRootMIP = createProof(
    lodestar.ssz.bellatrix.BeaconBlockBody.toView(finalizedBlock).node, {
      type: ProofType.single,
      gindex: lodestar.ssz.bellatrix.BeaconBlockBody.getPathInfo(["executionPayload", "stateRoot"]).gindex
    }
  ) as SingleProof;
  const executionStateRootBranch = executionStateRootMIP.witnesses.map(witnessNode => {
    return ethers.utils.hexlify(witnessNode);
  });
  const blockNumberMIP = createProof(
    lodestar.ssz.bellatrix.BeaconBlockBody.toView(finalizedBlock).node, {
      type: ProofType.single,
      gindex: lodestar.ssz.bellatrix.BeaconBlockBody.getPathInfo(["executionPayload", "blockNumber"]).gindex
    }
  ) as SingleProof;
  const blockNumberBranch = blockNumberMIP.witnesses.map(witnessNode => {
    return ethers.utils.hexlify(witnessNode);
  });
  const finalityMIP = createProof(
    lodestar.ssz.bellatrix.BeaconState.toView(attestedState).node, {
      type: ProofType.single,
      gindex: lodestar.ssz.bellatrix.BeaconState.getPathInfo(["finalizedCheckpoint", "root"]).gindex
    }
  ) as SingleProof;
  const finalityBranch = finalityMIP.witnesses.map(witnessNode => {
    return ethers.utils.hexlify(witnessNode);
  });

  const nextSyncCommitteeRoot = ethers.utils.hexlify(lodestar.ssz.altair.SyncCommittee.hashTreeRoot(finalizedState.nextSyncCommittee));
  const merkleInclusionProof = createProof(
    lodestar.ssz.bellatrix.BeaconState.toView(finalizedState).node, {
      type: ProofType.single,
      gindex: lodestar.ssz.bellatrix.BeaconState.getPathInfo(["nextSyncCommittee"]).gindex
    }
  ) as SingleProof;
  const nextSyncCommitteeRootBranch = merkleInclusionProof.witnesses.map(witnessNode => {
    return ethers.utils.hexlify(witnessNode);
  });

  return {
    attestedHeader: asHeaderObject(attestedHeader),
    finalizedHeader: asHeaderObject(finalizedHeader),
    finalityBranch: finalityBranch,
    nextSyncCommitteeRoot: nextSyncCommitteeRoot,
    nextSyncCommitteeBranch: nextSyncCommitteeRootBranch,
    executionStateRoot: ethers.utils.hexlify(finalizedBlock.executionPayload.stateRoot),
    executionStateRootBranch,
    blockNumber: finalizedBlock.executionPayload.blockNumber,
    blockNumberBranch,
    signature: {
      participation: participation,
      proof: headerProof
    }
  };
}

function asHeaderObject(header: any) {
  return {
    slot: Number(header.slot),
    proposerIndex: Number(header['proposer_index']),
    parentRoot: header['parent_root'],
    stateRoot: header['state_root'],
    bodyRoot: header['body_root']
  };
}

const argv = minimist(process.argv.slice(1));
const committeePeriod = argv.period || process.env.COMMITTEE_PERIOD;
const lightClient = argv.lightClient || process.env.LIGHT_CLIENT;
const usingSlot = argv.slot || process.env.SLOT;
const rpcUrl = argv.rpcUrl || process.env.RPC_URL;
const pk = argv.privateKey || process.env.PRIVATE_KEY;

if (!committeePeriod) {
  throw new Error("CLI arg 'committee_period' is required!")
}

if (!lightClient) {
  throw new Error("CLI arg 'committee_period' is required!")
}

if (!rpcUrl) {
  throw new Error(`CLI arg 'rpcUrl' is required!`);
}

updateSyncCommitteeOfContract(lightClient, committeePeriod, usingSlot, rpcUrl, pk);