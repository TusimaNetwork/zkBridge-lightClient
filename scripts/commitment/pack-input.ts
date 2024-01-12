import fs from 'fs';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import minimist from 'minimist';

async function generateAndSaveInput(period: string) {
    // Write object to a block specific folder in circuits directory.
    const file = `./../circuits/verify_syncCommittee/proof_data_${period}/input.json`;
    const inputs = JSON.parse(fs.readFileSync(file).toString());

    const input = { inputs, circuit: 'verify_sync_committee' };

    const packFile = `./../circuits/verify_syncCommittee/proof_data_${period}/packInput.json`;
    fs.writeFileSync(packFile, JSON.stringify(input));
    console.log('Finished writing pack input file', packFile);
}

const argv = minimist(process.argv.slice(1));
const committeePeriod = argv.period || process.env.COMMITTEE_PERIOD;

if (!committeePeriod) {
    throw new Error("CLI arg 'slot' is required!");
}

// usage: yarn ts-node generate-proof-input.ts --slot=4278368
generateAndSaveInput(committeePeriod);
