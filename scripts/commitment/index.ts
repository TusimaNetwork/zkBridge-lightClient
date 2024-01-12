import fs from "fs";
import minimist from "minimist";
import {generateProofInput} from "./generate-proof-input";

async function generateAndSaveProofInput(period: string) {
  const proofInput = await generateProofInput(period);

  // Write object to a block specific folder in circuits directory.
  const dir = `../circuits/verify_syncCommittee/proof_data_${period}`;
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir);
  }
  const file = `../circuits/verify_syncCommittee/proof_data_${period}/input.json`;
  fs.writeFileSync(
    file,
    JSON.stringify(proofInput)
  );

  console.log("Finished writing proof input file", file);
}

const argv = minimist(process.argv.slice(1));
const committeePeriod = argv.period || process.env.COMMITTEE_PERIOD;

if (!committeePeriod) {
  throw new Error("CLI arg 'committee_period' is required!")
}

// usage: yarn ts-node generate-proof-input.ts --period=495
generateAndSaveProofInput(committeePeriod)
