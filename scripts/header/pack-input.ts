import fs from 'fs';

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import minimist from 'minimist';

async function generateAndSaveInput(slot: string) {
    // Write object to a block specific folder in circuits directory.
    const file = `./../circuits/verify_header/proof_data_${slot}/input.json`;
    const inputs = JSON.parse(fs.readFileSync(file).toString());

    const input = { inputs, circuit: 'verify_header' };

    const packFile = `./../circuits/verify_header/proof_data_${slot}/packInput.json`;
    fs.writeFileSync(packFile, JSON.stringify(input));
    console.log('Finished writing pack input file', packFile);
}

const argv = minimist(process.argv.slice(1));
const slotArg = argv.slot || process.env.SLOT;

if (!slotArg) {
    throw new Error("CLI arg 'slot' is required!");
}

// usage: yarn ts-node generate-proof-input.ts --slot=4278368
generateAndSaveInput(slotArg);
