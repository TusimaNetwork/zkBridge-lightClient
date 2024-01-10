import fs from 'fs';

// import {generateInputForProof} from "./generate-proof-input";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import minimist from 'minimist';

import { buildLightClientUpdate } from './generate-update-input';

async function generateAndSaveInput(slotStr: string) {
    const proofInput = await buildLightClientUpdate(slotStr);

    // Write object to a block specific folder in circuits directory.
    const dir = `../../circuits/proof_data_update_${slotStr}`;
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir);
    }
    const file = `../../circuits/proof_data_update_${slotStr}/input.json`;
    fs.writeFileSync(file, JSON.stringify(proofInput));
    console.log('Finished writing proof input file', file);
}

const argv = minimist(process.argv.slice(1));
const slotArg = argv.slot || process.env.SLOT;

if (!slotArg) {
    throw new Error("CLI arg 'slot' is required!");
}

// usage: yarn ts-node generate-proof-input.ts --slot=4278368
generateAndSaveInput(slotArg);
