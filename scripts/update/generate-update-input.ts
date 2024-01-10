import { createProof, ProofType, SingleProof } from '@chainsafe/persistent-merkle-tree';
import * as lodestar from '@lodestar/types';
import { ssz } from '@lodestar/types';
import { ethers } from 'ethers';

import { BeaconChainAPI } from '../common/beacon-chain-api';
import { SyncCommittee } from '../common/sync-committee';

function uint8ArrayToArray(array: Uint8Array) {
    const result: any[] = [];
    for (let i = 0; i < array.length; i++) {
        result.push(array[i]);
    }
    return result;
}

export async function buildLightClientUpdate(finalizedSlotStr: string) {
    let finalizedSlot = Number(finalizedSlotStr);
    const attestedSlot = Number(finalizedSlotStr) + 64;
    const committeePeriod = Number(finalizedSlot) / 8192;
    finalizedSlot = committeePeriod * 8192;
    const beaconAPI = new BeaconChainAPI();
    const finalizedState = await beaconAPI.getBeaconState(finalizedSlot);
    const syncCommittee = new SyncCommittee(beaconAPI);

    const nextSyncCommitteeRoot = ethers.utils.hexlify(
        lodestar.ssz.altair.SyncCommittee.hashTreeRoot(finalizedState.nextSyncCommittee)
    );

    const version = await beaconAPI.getForkVersion(Number(finalizedSlot));
    const finalizedSyncCommitteeAggregateData = await beaconAPI.getSyncCommitteeAggregateData(
        Number(finalizedSlot)
    );
    const finalizedSyncCommitteeBits = syncCommittee.getSyncCommitteeBits(
        finalizedSyncCommitteeAggregateData.sync_committee_bits
    );
    let participation = 0;
    const finalizedPubkeybits = finalizedSyncCommitteeBits.map((e) => {
        if (e) {
            participation++;
            return 1;
        } else {
            return 0;
        }
    });
    const posiden = BigInt(
        '14944880964912256459396718186599713983931472913713440333995180464050223680200'
    );
    console.log('==============');
    console.log(version);
    console.log(nextSyncCommitteeRoot);
    console.log(posiden.toString(16));
    console.log('==============');

    const attestedBlockHeader = await beaconAPI.getBeaconBlockHeader(Number(attestedSlot));
    const attestedBlock = await beaconAPI.getBeaconBlock(Number(attestedSlot));
    const attestedBodyRoot = ethers.utils.hexlify(attestedBlockHeader.body_root);
    const attestedParentRoot = ethers.utils.hexlify(attestedBlockHeader.parent_root);
    const attestedProposerIndex = attestedBlockHeader.proposer_index;
    // const attestedStateRoot = ethers.utils.hexlify(attestedBlock.executionPayload.stateRoot);
    const attestedStateRoot = ethers.utils.hexlify(attestedBlockHeader.state_root);

    const syncCommitteeAggregateData = await beaconAPI.getSyncCommitteeAggregateData(
        Number(attestedSlot)
    );
    const syncCommitteeBits = syncCommittee.getSyncCommitteeBits(
        syncCommitteeAggregateData.sync_committee_bits
    );
    let attestedParticipation = 0;
    const pubkeybits = syncCommitteeBits.map((e) => {
        if (e) {
            attestedParticipation++;
            return 1;
        } else {
            return 0;
        }
    });

    console.log('attested header: ');
    console.log(attestedProposerIndex);
    console.log(attestedParentRoot);
    console.log(attestedStateRoot);
    console.log(attestedBodyRoot);
    console.log(attestedParticipation);
    console.log('==============');

    const finalizedBlock = await beaconAPI.getBeaconBlock(finalizedSlot);
    const attestedState = await beaconAPI.getBeaconState(Number(attestedSlot));
    const finalizedBlockHeader = await beaconAPI.getBeaconBlockHeader(Number(finalizedSlot));

    const executionStateRootMIP = createProof(
        lodestar.ssz.bellatrix.BeaconBlockBody.toView(finalizedBlock).node,
        {
            type: ProofType.single,
            gindex: lodestar.ssz.bellatrix.BeaconBlockBody.getPathInfo([
                'executionPayload',
                'stateRoot'
            ]).gindex
        }
    ) as SingleProof;
    const executionStateRootBranch = executionStateRootMIP.witnesses.map((witnessNode) => {
        return ethers.utils.hexlify(witnessNode);
    });
    const blockNumberMIP = createProof(
        lodestar.ssz.bellatrix.BeaconBlockBody.toView(finalizedBlock).node,
        {
            type: ProofType.single,
            gindex: lodestar.ssz.bellatrix.BeaconBlockBody.getPathInfo([
                'executionPayload',
                'blockNumber'
            ]).gindex
        }
    ) as SingleProof;
    const blockNumberBranch = blockNumberMIP.witnesses.map((witnessNode) => {
        return ethers.utils.hexlify(witnessNode);
    });
    const finalityMIP = createProof(lodestar.ssz.bellatrix.BeaconState.toView(attestedState).node, {
        type: ProofType.single,
        gindex: lodestar.ssz.bellatrix.BeaconState.getPathInfo(['finalizedCheckpoint', 'root'])
            .gindex
    }) as SingleProof;
    const finalityBranch = finalityMIP.witnesses.map((witnessNode) => {
        return ethers.utils.hexlify(witnessNode);
    });

    const merkleInclusionProof = createProof(
        lodestar.ssz.bellatrix.BeaconState.toView(finalizedState).node,
        {
            type: ProofType.single,
            gindex: lodestar.ssz.bellatrix.BeaconState.getPathInfo(['nextSyncCommittee']).gindex
        }
    ) as SingleProof;
    const nextSyncCommitteeRootBranch = merkleInclusionProof.witnesses.map((witnessNode) => {
        return ethers.utils.hexlify(witnessNode);
    });
    const headerOrigin = {
        slot: finalizedBlockHeader.slot,
        proposer_index: finalizedBlockHeader.proposer_index,
        parent_root: finalizedBlockHeader.parent_root,
        state_root: finalizedBlockHeader.state_root,
        body_root: finalizedBlockHeader.body_root
    };
    const header = lodestar.ssz.phase0.BeaconBlockHeader.fromJson(headerOrigin);
    const finalizedHeaderSsz = ethers.utils.hexlify(
        lodestar.ssz.phase0.BeaconBlockHeader.hashTreeRoot(header)
    );
    const syncCommitteeSSZ = ethers.utils.hexlify(
        ssz.altair.SyncCommittee.hashTreeRoot(finalizedState.nextSyncCommittee)
    );
    return {
        attestedSlot,
        finalizedSlot,
        participation,
        finalizedHeaderRoot: ethers.utils.hexlify(finalizedBlockHeader.header_root),
        executionStateRoot: ethers.utils.hexlify(finalizedBlock.executionPayload.stateRoot),
        blockNumber: finalizedBlock.executionPayload.blockNumber,
        //
        attestedProposerIndex,
        attestedParentRoot,
        attestedStateRoot,
        attestedBodyRoot,
        attestedParticipation,
        //
        finalityBranch,
        nextSyncCommitteeBranch: nextSyncCommitteeRootBranch,
        executionStateRootBranch,
        blockNumberBranch,
        nextSyncCommitteeRoot,
        finalizedHeaderBodyRoot: ethers.utils.hexlify(finalizedBlockHeader.body_root),
        finalizedHeaderSsz,
        syncCommitteeSSZ
    };
}

// buildLightClientUpdate('5960282');
