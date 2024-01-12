#!/bin/bash

# High level steps:
# 1. Compiles the circuit (if not compiled)
# 2. Generates a witness
# 3. Generates a trusted setup (if not generated)
# 4. Generates a proof
# 5. Generates TX calldata for the verifier contract (`step`)

set -e

# Download the powers of tau file from here: https://github.com/iden3/snarkjs#7-prepare-phase-2
# Move to directory specified below
PHASE1=/proj/powers_of_tau/powersOfTau28_hez_final_27.ptau

BASE_CIRCUIT_DIR=../../circuits/verify_header
BUILD_DIR=$BASE_CIRCUIT_DIR/build
COMPILED_DIR=$BUILD_DIR/compiled_circuit
TRUSTED_SETUP_DIR=$BUILD_DIR/trusted_setup

SLOT_PROOF=$BASE_CIRCUIT_DIR/proof_data_${SLOT}
CIRCUIT_NAME=verify_header
CIRCUIT_PATH=../../circuits/verify_header/$CIRCUIT_NAME.circom
OUTPUT_DIR=$COMPILED_DIR/$CIRCUIT_NAME_cpp

run() {
  echo "SLOT: $SLOT"
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

  if [ ! -d "$SLOT_PROOF" ]; then
    echo "No directory found for proof data. Creating a slot's proof data directory..."
    mkdir "$SLOT_PROOF"
  fi

  echo "====GENERATING INPUT FOR PROOF===="
  echo $SLOT_PROOF/input.json
  start=$(date +%s)
  BEACON_NODE_API=$BEACON_NODE_API yarn ts-node --project ./tsconfig.json ./header/index.ts --slot $SLOT
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
  "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/"$CIRCUIT_NAME" "$SLOT_PROOF"/input.json "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns
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
  node=/root/circom/node/node
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
  echo $SLOT_PROOF/packInput.json
  start=$(date +%s)
  yarn ts-node --project ./tsconfig.json ./header/pack-input.ts --slot $SLOT
  end=$(date +%s)
  echo "DONE ($((end - start))s)"
  
  echo "====GENERATING PROOF FOR GIVEN SLOT===="
  start=$(date +%s)
#  ../build/prover "$TRUSTED_SETUP_DIR"/"$CIRCUIT_NAME".zkey "$COMPILED_DIR"/"$CIRCUIT_NAME"_cpp/witness.wtns "$SLOT_PROOF"/proof.json "$SLOT_PROOF"/public.json
  fullProof=$(curl -d @"$SLOT_PROOF"/packInput.json -H "Content-Type: application/json" -X POST "$PROVER_API"/api/v1/proof/generate)
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

#  echo "====VERIFYING PROOF FOR GIVEN SLOT===="
#  start=$(date +%s)
#  /proj/node/out/Release/node ../node_modules/snarkjs/cli.js groth16 verify "$TRUSTED_SETUP_DIR"/vkey.json ./"$SLOT_PROOF"/input.json "$SLOT_PROOF"/proof.json
#  end=$(date +%s)
#  echo "DONE ($((end - start))s)"

  echo "====GENERATING SPLIT PROOF===="
  echo $SLOT_PROOF/input.json
  start=$(date +%s)
  yarn ts-node --project ./tsconfig.json ./header/split.ts --slot $SLOT --fullProof $fullProof
  end=$(date +%s)
  echo "DONE ($((end - start))s)"

  # Outputs calldata for the verifier contract.
  echo "====GENERATING CALLDATA FOR VERIFIER CONTRACT===="
  start=$(date +%s)
  node ../node_modules/snarkjs/cli.js zkey export soliditycalldata $SLOT_PROOF/public.json "$SLOT_PROOF"/proof.json >"$SLOT_PROOF"/calldata.txt
  end=$(date +%s)
  echo "DONE ($((end - start))s)"
}

mkdir -p logs
run 2>&1 | tee logs/"$CIRCUIT_NAME"_$(date '+%Y-%m-%d-%H-%M').log
