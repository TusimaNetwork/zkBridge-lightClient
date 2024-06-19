# On-chain Light Client - Circuits

![Tusima zkBridge](https://ucarecdn.com/f4e08f06-c238-47f8-b98a-97629c199377/bridgelogo.png)

[![Twitter Follow](https://img.shields.io/twitter/follow/TusimaNetwork?style=social)](https://twitter.com/TusimaNetwork)
[![Discord](https://img.shields.io/discord/965918503070728203?logo=Discord&logoColor=5865F2&label=discord&color=3ae600
)](https://discord.com/invite/tusimanetwork)

## Overview

This section pertains to the zkSNARKs circuit program, which is written in the Circom language.

> Circom, developed by the iden3 team, is a language used to specify the constraints for zkSNARKs. Currently, Circom is at version 2.0 and supports two verification systems, Groth16 and Plonk. In this project, we employ the Groth16 system. For more information about Circom, please refer to this [link](https://docs.circom.io/).

The circuit program serves the smart contract. Due to gas limitations, executing complex computational logic, such as the `BLS12-381` signature verification algorithm, within the smart contract is not feasible. Given that the sync committee comprises 512 validators, each with its unique public key, this would result in a substantial expense for the smart contract. Consequently, we implement this logic in the circuit program, generate a proof, and submit it for verification by the smart contract. This approach enables on-chain verification of signatures efficiently.

> The Curve BLS12-381 is an aggregation signature algorithm that can combine signatures from multiple validators into a single signature. During verification, only this aggregated signature needs to be validated, eliminating the need to verify each individual signature separately. This significantly reduces the computational resources required for signature verification in Ethereum light clients. Otherwise, the verification of 512 individual signatures, even in offline scenarios, would entail substantial computational costs. For more information about the BLS12-381 curve, please refer to this link.

Within this circuit program, there are two key template functions:
- `VerifyHeader`, corresponding to the `updateHeader` function within the smart contract.
- `VerifySyncCommittee`, corresponding to the `updateSyncCommittee` function within the smart contract.

Here is the template function for VerifyHeader:
```circom=
/**
 * Given the sync committee public keys and a bitmask to represent which validators signed,
 * verifies that there exists some valid BLS12-381 signature over the SSZ root of the Phase0BeaconBlockHeader
 * @param  b                     The size of the set of public keys
 * @param  n                     The number of bits to use per register
 * @param  k                     The number of registers
 * @input  pubkeys               The b BLS12-381 public keys in BigInt(n, k)
 * @input  pubkeybits            The b-length bitmask for which pubkeys to include
 * @input  signature             The BLS12-381 signature for the signing_root
 * @input  signing_root          The SSZ root of the block header
 * @output bitSum                \sum_{i=0}^{b-1} pubkeybits[i]
 * @output syncCommitteePoseidon Poseidon merkle root of pubkeys
 */
template VerifyHeader(b, n, k) {
    signal input pubkeys[b][2][k];
    signal input pubkeybits[b];
    signal input signature[2][2][k];
    signal input signing_root[32]; // signing_root

    signal output bitSum;
    signal output syncCommitteePoseidon;

    // ......
}
```

This template function accepts **512 public keys** and an aggregated signature as input signals and yields **the count of valid signatures** as an output signal. The program validates the aggregated signature and produces the count of valid signatures, along with a **Proof**. The **Operator** executes this program and submits the resulting proof, along with other pertinent parameters, to the `updateHeader` function within the smart contract. This proof serves as evidence of the correctness of the computation process within this circuit program, demonstrating the verification of the `BLS12-381` signature algorithm.

Here is the template function for `VerifySyncCommittee`:
```circom=
/**
 * Computes the SSZ root and Poseidon root of the sync committee
 * @param  b                     The size of the set of public keys
 * @param  n                     The number of bits to use per register
 * @param  k                     The number of registers
 * @input  pubkeyHex             The sync committee's BLS12-381 public keys in hex form
 * @input  aggregatePubkeyHex    The sync committee's aggregated BLS12-381 public key in hex form
 * @input  pubkeys               The sync committee's BLS12-381 public keys in BigInt form
 * @output syncCommitteeSSZ      The SSZ root of the sync committee
 * @output syncCommitteePoseidon The Poseidon root of the sync committee
 */
template VerifySyncCommittee(b, n, k) {
    signal input pubkeyHex[b][48];
    signal input aggregatePubkeyHex[48];
    signal input pubkeys[b][2][k];

    signal output syncCommitteeSSZ[32];
    signal output syncCommitteePoseidon;

    // ......
}
```

When verifying BLS signatures within the smart contract, a crucial factor is the need to know the current sync committee roster for the given epoch. However, storing 512 validator public keys in the smart contract is prohibitively expensive. Fortunately, the Ethereum light client protocol provides a way to represent the 512 validators using a hash value known as `SyncCommitteeRoot`. This `SyncCommitteeRoot` is serialized using Simple Serialize (SSZ), and SSZ employs the `SHA-256` hash function. However, because this hash function is not circuit-friendly, it results in slow execution of the circuit program, leading to expensive cross-chain costs. To address this, it is necessary to recompute the `SyncCommitteeRoot` using a circuit-friendly hash algorithm, which in this case is Poseidon. Therefore, the modified `SyncCommitteeRoot` is named `SyncCommitteePoseidon`.

> Simple serialize (SSZ) is the serialization method used on the Beacon Chain. It replaces the RLP serialization used on the execution layer everywhere across the consensus layer except the peer discovery protocol.

The purpose of this template function is to convert `SyncCommitteeRoot` into `SyncCommitteePoseidon`. Its proof establishes the correctness of the correspondence between the two. The proof will be submitted by the Operator to the `updateSyncCommittee` function within the smart contract.

**Testing data:**

Testing the circuit program is indeed a resource-intensive task, requiring substantial CPU and memory resources. Below are the results of our execution on a cloud server with 32 cores and 256GB of memory:

| Text               | VerifyHeader | VerifySyncCommittee |
| ------------------ | ------------ | ------------------- |
| Constraints        | 27M          | 68M                 |
| Witness Generation | 124 Seconds  | 180 Seconds         |
| Proving Time       | 118 Seconds  | 60 Seconds          |




## Build circuits
1. Update submodules
    ```bash
    git submodule init
    git submodule update
    ```

1. Install dependencies
    ```bash
    npm install
    ```

2. Build circuit `verify_header`
    ```bash
    cd verify_header
    SLOT=6154570 bash run.sh
    ```
    > Notice that, you have to use the patched node instead of regular node, to install the patched node please check [here](./docs/installation-for-patched-node.md).

1. Build circuit `verify_syncCommittee`
    ```bash
    cd verify_syncCommittee
    PERIOD=727 bash run.sh
    ```