# Overview

The `./scripts` folder contains a npm project supporting 2 scripts

- `syncCommitteeComittment` prepares the circuits and the trusted setup if necessary. Generates a proof of mapping the
  SSZ merkelized Sync Committee root to a Poseidon merkelized root by providing it with committee period as input.
- `verifyHeaderSignatures` prepares the circuits and the trusted setup if necessary. Generates a proof that at least 2/3
  of the sync committee has signed the specified block header. The script takes as argument only the slot for which a
  proof must be generated.

### Prerequisites

**Note: It is recommended to use Ubuntu 22.04**

## Development

0. Prior to executing scripts, go to `./circuits` and do `npm i`
1. The following tools must be installed in order for you to successfully execute the bash scripts:
    1. Build [RapidSnark](https://github.com/iden3/rapidsnark) and put `prover` binary at `./scripts/build`
    2. [NPM](https://www.npmjs.com/)
    3. [Node.js](https://nodejs.org/)
    4. [Circom](https://docs.circom.io/getting-started/installation/) in order to interact with the circuits
    5. `g++`
    6. `nlohmann-json3-dev`
    7. `libmpc-dev`
    8. `nasm`
2. The following config must be set in order for you to be able to generate a zkey:
    1. Update the current `max_map_count` of the system by executing: `sysctl -w vm.max_map_count=655300`
    2. Add `vm.max_map_count=655300` in `/etc/sysctl.conf` in order to persist the change
3. Download the [PowersOfTau27](https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_27.ptau) file
   from [SnarkJS](https://github.com/iden3/snarkjs#7-prepare-phase-2) and place it
   at `./circuits/powers_of_tau/powersOfTau28_hez_final_27.ptau`

### Sync Committee Proof

```bash
npm i
cd syncCommitteeComittment && SYNC_COMMITTEE_PERIOD={PERIOD} BEACON_NODE_API={BEACON_NODE_API} bash run_sync_committee_commitment.sh
```

### Verify Header Signatures

```bash
npm i
cd ./verifyHeaderSignatures && SLOT={SLOT} BEACON_NODE_API={BEACON_NODE_API} bash run_verify_header_signature.sh &
```

**Note** -> Might take ~60 seconds as the script is not optimised

Start the processes in the background since it might take a while depending on whether you've compiled / generated the
zkey. A `logs` folder for the execution will be created.

### Update SyncCommittee for already deployed contract

```
PROVER_API={PROVER} BEACON_NODE_API={BEACON_NODE} LIGHT_CLIENT={LIGHT_CLIENT_ADDRESS} yarn ts-node --project tsconfig.json ./updateSyncCommitteeOfContract/index.ts --period {PERIOD} --slot {optional} --rpcUrl {RPC URL} --privateKey {PK}
```

By default, the slot to be used is the first slot after 2 epochs. If the slot does not have >66% sync committee participation, provide another slot as argument (`--slot`)