pragma circom 2.0.3;

include "../utils/pubkey_poseidon.circom";

template CalcSyncCommitteePoseidon(b, k) {
    signal input pubkeysBigIntX[b][k];
    signal input pubkeysBigIntY[b][k];
    signal output syncCommitteePoseidon;

    component poseidonSyncCommittee = PubkeyPoseidon(b, k);
    for (var i=0; i < b; i++) {
        for (var j=0; j < k; j++) {
            poseidonSyncCommittee.pubkeys[i][0][j] <== pubkeysBigIntX[i][j];
            poseidonSyncCommittee.pubkeys[i][1][j] <== pubkeysBigIntY[i][j];
        }
    }

    syncCommitteePoseidon <== poseidonSyncCommittee.out;
}

component main = CalcSyncCommitteePoseidon(512, 7);