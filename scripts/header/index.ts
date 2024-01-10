import fs from "fs";
import {generateInputForProof} from "./generate-proof-input";
import minimist from "minimist";

async function generateAndSaveInput(slotStr: string) {
  const {slot, proofInput} = await generateInputForProof(slotStr);

  // Write object to a block specific folder in circuits directory.
  const dir = `../../circuits/header/proof_data_${slot}`;
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir);
  }
  const file = `../../circuits/header/proof_data_${slot}/input.json`;
  fs.writeFileSync(
    file,
    JSON.stringify(proofInput)
  );
  console.log("Finished writing proof input file", file);
}

const argv = minimist(process.argv.slice(1));
const slotArg = argv.slot || process.env.SLOT;

if (!slotArg) {
  throw new Error("CLI arg 'slot' is required!")
}

// usage: yarn ts-node generate-proof-input.ts --slot=4278368
generateAndSaveInput(slotArg);
