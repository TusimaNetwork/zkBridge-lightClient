#!/bin/bash

# High level steps:
# 1. Gets the current Sync Committee of Ethereum
# 2. Generates input for the circuit - BLS12-381 single and aggregated public keys (in hex and BigInt) and size
# 3. Compiles the circuit
# 4. Generates a witness
# 5. Generates a trusted setup
# 6. Generates a proof
# 7. Generates TX calldata for the verifier contract (`updateSyncCommittee`)

set -e

# Download the powers of tau file from here: https://github.com/iden3/snarkjs#7-prepare-phase-2
# Move to directory specified below
PHASE1=/proj/powers_of_tau/powersOfTau28_hez_final_27.ptau

BASE_CIRCUIT_DIR=../../circuits/verify_syncCommittee
BUILD_DIR=$BASE_CIRCUIT_DIR/build
COMPILED_DIR=$BUILD_DIR/compiled_circuit
TRUSTED_SETUP_DIR=$BUILD_DIR/trusted_setup

SYNC_COMMITTEE_PROOF=$BASE_CIRCUIT_DIR/proof_data_${SYNC_COMMITTEE_PERIOD}
CIRCUIT_NAME=verify_sync_committee
CIRCUIT_PATH=../../circuits/verify_syncCommittee/$CIRCUIT_NAME.circom
OUTPUT_DIR=$COMPILED_DIR/$CIRCUIT_NAME_cpp
run() {
  echo "SYNC_COMMITTEE_PERIOD: $SYNC_COMMITTEE_PERIOD"
  echo "Node URL: $BEACON_NODE_API"
  echo "Prover URL: $PROVER_API"

  if [ ! -d "$BUILD_DIR" ]; then
    echo "No build directory found. Creating build directory..."
    mkdir "$BUILD_DIR"
  fi

  if [ ! -d "$COMPILED_DIR" ]; then
    echo "No compiled directory found. Creating compiled circuit directory..."
    mkdir "$COMPILED_DIR"
  fi

  if [ ! -d "$TRUSTED_SETUP_DIR" ]; then
    echo "No trusted setup directory found. Creating trusted setup directory..."
    mkdir "$TRUSTED_SETUP_DIR"
  fi

  if [ ! -d "$SYNC_COMMITTEE_PROOF" ]; then
    echo "No directory found for proof data. Creating a sync committee's proof data directory..."
    mkdir "$SYNC_COMMITTEE_PROOF"
  fi

  echo "====GENERATING INPUT FOR PROOF===="
  echo $SYNC_COMMITTEE_PROOF/input.json
  start=$(date +%s)
  BEACON_NODE_API=$BEACON_NODE_API yarn ts-node --project ./tsconfig.json ./commitment/index.ts --period ${SYNC_COMMITTEE_PERIOD}
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  if [ ! -f "$COMPILED_DIR"/"$CIRCUIT_NAME".r1cs ]; then
    echo "==== COMPILING CIRCUIT $CIRCUIT_NAME.circom ===="
    start=$(date +%s)
    circom "$CIRCUIT_PATH" --O1 --r1cs --sym --c --output "$COMPILED_DIR"
    end=$(date +%s)
    echo "DONE ($((end - start))s)"
  fi

  echo "====Build Witness Generation Binary===="
  start=$(date +%s)
  make -C "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  echo "====Generate Witness===="
  start=$(date +%s)
  "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/"$CIRCUIT_NAME" "$SYNC_COMMITTEE_PROOF"/input.json "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  if [ -f "$PHASE1" ]; then
    echo "Found Phase 1 ptau file"
  else
    echo "No Phase 1 ptau file found. Exiting..."
    exit 1
  fi

  # Generates circuit-specific trusted setup if it doesn't exist.
  # This step takes a while.
  if test ! -f "$TRUSTED_SETUP_DIR/vkey.json"; then
    echo "====Generating zkey===="
    start=$(date +%s)
    ../../../node/out/Release/node --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc ../node_modules/snarkjs/cli.js zkey new "$COMPILED_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME"_p1.zkey
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====Contribute to Phase2 Ceremony===="
    start=$(date +%s)
    ../../../node/out/Release/node ../node_modules/snarkjs/cli.js zkey contribute "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME"_p1.zkey "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey -n="First phase2 contribution" -e="some random text for entropy"
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====VERIFYING FINAL ZKEY===="
    start=$(date +%s)
    ../../../node/out/Release/node --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc ../node_modules/snarkjs/cli.js zkey verify "$COMPILED_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====EXPORTING VKEY===="
    start=$(date +%s)
    ../../../node/out/Release/node ../node_modules/snarkjs/cli.js zkey export verificationkey "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$TRUSTED_SETUP_DIR"/vkey.json
    end=$(date +%s)
    echo "DONE ($((end - start))s)"
  fi

  echo "====GENERATING PACK INPUT FOR PROOF===="
  echo $SYNC_COMMITTEE_PROOF/packInput.json
  start=$(date +%s)
  yarn ts-node --project ./tsconfig.json ./commitment/pack-input.ts --period $SYNC_COMMITTEE_PERIOD
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  echo "====GENERATING PROOF FOR SYNC COMMITTEE PERIOD===="
  start=$(date +%s)
#  ../build/prover "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns "$SYNC_COMMITTEE_PROOF"/proof.json "$SYNC_COMMITTEE_PROOF"/public.json
  fullProof=$(curl -d @"$SYNC_COMMITTEE_PROOF"/packInput.json -H "Content-Type: application/json" -X POST "$PROVER_API"/api/v1/proof/generate)
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  echo "====GENERATING SPLIT PROOF===="
  echo $SYNC_COMMITTEE_PROOF/input.json
  start=$(date +%s)
  yarn ts-node --project ./tsconfig.json ./commitment/split.ts --period $SYNC_COMMITTEE_PERIOD --fullProof $fullProof
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

#  Bug in snarkjs. Error: Scalar size does not match. Verification goes through using the Verifier contract
#  echo "====VERIFYING PROOF FOR SYNC COMMITTEE PERIOD===="
#  start=$(date +%s)
#  node ../node_modules/snarkjs/cli.js groth16 verify "$TRUSTED_SETUP_DIR"/vkey.json ./"$SYNC_COMMITTEE_PROOF"/input.json "$SYNC_COMMITTEE_PROOF"/proof.json
#  end=$(date +%s)
#  echo "DONE ($((end - start))s)"

  # Outputs calldata for the verifier contract.
  echo "====GENERATING CALLDATA FOR VERIFIER CONTRACT===="
  start=$(date +%s)
  node ../node_modules/snarkjs/cli.js zkey export soliditycalldata $SYNC_COMMITTEE_PROOF/public.json "$SYNC_COMMITTEE_PROOF"/proof.json >"$SYNC_COMMITTEE_PROOF"/calldata.txt
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

}

mkdir -p logs
run 2>&1 | tee logs/"$CIRCUIT_NAME"_$(date '+%Y-%m-%d-%H-%M').log
