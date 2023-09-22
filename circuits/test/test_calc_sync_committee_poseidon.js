// import path from 'path';
const path = require("path");
// import { expect, assert } from 'chai';

// const { ethers } = require("ethers");

// eslint-disable-next-line @typescript-eslint/no-var-requires
const circom_tester = require('circom_tester');
const wasm_tester = circom_tester.wasm;

describe('SyncCommitteePoseidon', function () {
    this.timeout(1000000);

    const n = 55;
    const k = 7;

    const pubkeys = require('./pubkeys.json');
    const pubkeysBigIntX = pubkeys.pubKeysX;
    const pubkeysBigIntY = pubkeys.pubKeysY;

    it('generate poseidon root correctly', async function () {
        let circuit = await wasm_tester(
            path.join(__dirname, '../verify_ssz_to_poseidon_commitment', 'sync_committee_poseidon.circom')
        );
        const witness = await circuit.calculateWitness({
            pubkeysBigIntX: pubkeysBigIntX,
            pubkeysBigIntY: pubkeysBigIntY
        });
        // await circuit.assertOut(witness, {
        //     out: syncCommitteePoseidon
        // });
        console.log("witness: ");
        console.log(witness[1].toString(16));
        console.log("poseidon: " + witness[1].toString(16));
        await circuit.checkConstraints(witness);
    });
});