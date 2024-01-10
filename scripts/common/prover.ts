import {ethers} from "ethers";

export class ProverService {

  private readonly baseUrl: string;
  private readonly proofEndpoint: string = "/api/v1/proof/generate";

  constructor() {
    this.baseUrl = process.env.PROVER_API || "";
  }

  public async requestSyncCommitteeProof(inputs: any) {
    const proof = await this.callProver("ssz2Poseidon", inputs);
    return {
      proof: {
        a: [
          proof.proof["pi_a"][0],
          proof.proof["pi_a"][1]
        ],
        b: [
          [
            proof.proof["pi_b"][0][1],
            proof.proof["pi_b"][0][0]
          ],
          [
            proof.proof["pi_b"][1][1],
            proof.proof["pi_b"][1][0]
          ]
        ], c: [
          proof.proof["pi_c"][0],
          proof.proof["pi_c"][1]
        ]
      },
      syncCommitteePoseidon: ethers.utils.hexlify(ethers.BigNumber.from(proof["pub_signals"][32]))
    }
  }

  public async requestHeaderProof(inputs: any) {
    const proof = await this.callProver("blsHeaderVerify", inputs);
    return {
      a: [
        proof.proof["pi_a"][0],
        proof.proof["pi_a"][1]
      ],
      b: [
        [
          proof.proof["pi_b"][0][1],
          proof.proof["pi_b"][0][0]
        ],
        [
          proof.proof["pi_b"][1][1],
          proof.proof["pi_b"][1][0]
        ]
      ], c: [
        proof.proof["pi_c"][0],
        proof.proof["pi_c"][1]
      ]
    };
  }

  private async callProver(circuit: string, inputs: any) {
    try {
      const response = await fetch(this.baseUrl + this.proofEndpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify({circuit, inputs})
      });
      const result = await response.json();
      if (response.status >= 400) {
        console.error(`Failed to request proof. Error ${result.error}`);
      }
      return result;
    } catch (e) {
      console.error(`Failed to request proof. Error ${e}`);
    }
  }
}