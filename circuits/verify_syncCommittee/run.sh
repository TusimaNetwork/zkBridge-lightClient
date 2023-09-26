#!/bin/bash

# High level steps:
# 1. Compiles the circuit
# 2. Generates a witness
# 3. Generates a trusted setup
# 4. Generates a proof
# 5. Generates TX calldata for the verifier contract (`verify_syncCommittee.sol`)

set -e

# Download the powers of tau file from here: https://github.com/iden3/snarkjs#7-prepare-phase-2
# Move to directory specified below
PHASE1=../../../powers_of_tau/powersOfTau28_hez_final_27.ptau

BASE_CIRCUIT_DIR=./
BUILD_DIR=$BASE_CIRCUIT_DIR/build
COMPILED_DIR=$BUILD_DIR/compiled_circuit
TRUSTED_SETUP_DIR=$BUILD_DIR/trusted_setup

SYNC_COMMITTEE_PROOF=$BASE_CIRCUIT_DIR/proof_data_${SYNC_COMMITTEE_PERIOD}
CIRCUIT_NAME=verify_sync_committee
CIRCUIT_PATH=$BASE_CIRCUIT_DIR/$CIRCUIT_NAME.circom
OUTPUT_DIR=$COMPILED_DIR/$CIRCUIT_NAME_cpp
INPUT_DIR=$BASE_CIRCUIT_DIR/input
VERIFIER_DIR=$BASE_CIRCUIT_DIR/contract

# A patched node
NODE_PATH=../../../node/out/Release/node

# Rapid snark prover
PROVER_PATH=../../../rapidsnark/build/prover

run() {
  echo "SYNC_COMMITTEE_PERIOD: $SYNC_COMMITTEE_PERIOD"

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

  if [ ! -d "$VERIFIER_DIR" ]; then
    echo "No verifiyer directory found. Creating a verifiyer directory..."
    mkdir "$VERIFIER_DIR"
  fi

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
  "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/"$CIRCUIT_NAME" "$INPUT_DIR"/${SYNC_COMMITTEE_PROOF}_input.json "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns
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
    $NODE_PATH --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc ../node_modules/snarkjs/cli.js zkey new "$COMPILED_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME"_p1.zkey
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====Contribute to Phase2 Ceremony===="
    start=$(date +%s)
    $NODE_PATH ../node_modules/snarkjs/cli.js zkey contribute "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME"_p1.zkey "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey -n="First phase2 contribution" -e="some random text for entropy"
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====VERIFYING FINAL ZKEY===="
    start=$(date +%s)
    $NODE_PATH --trace-gc --trace-gc-ignore-scavenger --max-old-space-size=2048000 --initial-old-space-size=2048000 --no-global-gc-scheduling --no-incremental-marking --max-semi-space-size=1024 --initial-heap-size=2048000 --expose-gc ../node_modules/snarkjs/cli.js zkey verify "$COMPILED_DIR"/"$CIRCUIT_NAME".r1cs "$PHASE1" "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey
    end=$(date +%s)
    echo "DONE ($((end - start))s)"

    echo "====EXPORTING VKEY===="
    start=$(date +%s)
    $NODE_PATH ../node_modules/snarkjs/cli.js zkey export verificationkey "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$TRUSTED_SETUP_DIR"/vkey.json
    end=$(date +%s)
    echo "DONE ($((end - start))s)"
  fi

  echo "====GENERATING PROOF FOR SYNC COMMITTEE PERIOD===="
  start=$(date +%s)
  $PROVER_PATH "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns "$SYNC_COMMITTEE_PROOF"/proof.json "$SYNC_COMMITTEE_PROOF"/public.json
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

#  Bug in snarkjs. Error: Scalar size does not match. Verification goes through using the Verifier contract
#  echo "====VERIFYING PROOF FOR SYNC COMMITTEE PERIOD===="
#  start=$(date +%s)
#  node ../node_modules/snarkjs/cli.js groth16 verify "$TRUSTED_SETUP_DIR"/vkey.json ./"$INPUT_DIR"/${SYNC_COMMITTEE_PROOF}_input.json "$SYNC_COMMITTEE_PROOF"/proof.json
#  end=$(date +%s)
#  echo "DONE ($((end - start))s)"

  # Outputs calldata for the verifier contract.
  echo "====GENERATING CALLDATA FOR VERIFIER CONTRACT===="
  start=$(date +%s)
  node ../node_modules/snarkjs/cli.js zkey export soliditycalldata $SYNC_COMMITTEE_PROOF/public.json "$SYNC_COMMITTEE_PROOF"/proof.json >"$SYNC_COMMITTEE_PROOF"/calldata.txt
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  # Generate verifier contract
  if [ ! -f "$VERIFIER_DIR"/"$CIRCUIT_NAME".sol ]; then
    echo "====GENERATING VERIFIER CONTRACT===="
    start=$(date +%s)
    node ../node_modules/snarkjs/cli.js zkey export solidityverifier "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$VERIFIER_DIR"/"$CIRCUIT_NAME".sol
    end=$(date +%s)
    echo "DONE ($((end - start))s)"
  fi
}

mkdir -p logs
run 2>&1 | tee logs/"$CIRCUIT_NAME"_$(date '+%Y-%m-%d-%H-%M').log
