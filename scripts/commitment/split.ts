import fs from 'fs';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import minimist from 'minimist';

async function generateAndSaveInput(period: string, fullProofStr: string) {
    let fullProof;
    try {
        fullProof = JSON.parse(fullProofStr);
    } catch (err) {
        console.error(err);
        return;
    }

    // Write object to a block specific folder in circuits directory.
    const dir = `./../circuits/verify_syncCommittee/proof_data_${period}`;
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir);
    }
    const file = `./../circuits/verify_syncCommittee/proof_data_${period}/proof.json`;
    fs.writeFileSync(file, JSON.stringify(fullProof.proof));
    console.log('Finished writing proof file', file);

    const publicFile = `./../circuits/verify_syncCommittee/proof_data_${period}/public.json`;
    fs.writeFileSync(publicFile, JSON.stringify(fullProof.pub_signals));
    console.log('Finished writing public file', publicFile);
}

const argv = minimist(process.argv.slice(1));
const committeePeriod = argv.period || process.env.COMMITTEE_PERIOD;
const fullProofArg = argv.fullProof || process.env.FULLPROOF;

if (!committeePeriod) {
    throw new Error("CLI arg 'slot' is required!");
}

// usage: yarn ts-node generate-proof-input.ts --slot=4278368
generateAndSaveInput(committeePeriod, fullProofArg);
