pragma solidity 0.8.14;

import "forge-std/StdJson.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/ethereum/EthereumLightClient.sol";

contract EthereumLightClientTest is Test {
    using stdJson for string;

    EthereumLightClient lightClient;

    function setUp() public {
        (
        bytes32 genesisValidatorRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        bytes4 forkVersion,
        uint256 startSyncCommitteePeriod,
        bytes32 startSyncCommitteeRoot,
        bytes32 startSyncCommitteePoseidon
        ) = readNetworkConfig("goerli");
        // TODO fix forkVersion
        lightClient = new EthereumLightClient(
            genesisValidatorRoot,
            genesisTime,
            secondsPerSlot,
            0x02001020,
            startSyncCommitteePeriod,
            startSyncCommitteeRoot,
            startSyncCommitteePoseidon
        );
        vm.warp(1999999999);
    }

    function test() public {
        // TODO resolve it
        // HeaderUpdate memory lcUpdate = readLightClientUpdateTestData("goerli", "lightClientUpdate", "5097760");
        HeaderUpdate memory lcUpdate = readLightClientUpdateTestData("goerli", "ssz2Poseidon", "5097760");
        lightClient.updateHeader(lcUpdate);
    }

    function testSyncCommitteeUpdate() external {
        (HeaderUpdate memory lcUpdate, bytes32 nexSCPoseidon, Groth16Proof memory proof) = readLCUpdateWithSyncCommittee("goerli", "5097760");
        lightClient.updateSyncCommittee(lcUpdate, nexSCPoseidon, proof);
    }

    function readNetworkConfig(string memory network)
    public
    view
    returns (
        bytes32 genesisValidatorRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        bytes4 forkVersion,
        uint256 period,
        bytes32 scRoot,
        bytes32 scpRoot
    )
    {
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/test/config/",
            network,
            ".json"
        );
        string memory json = vm.readFile(path);

        genesisValidatorRoot = json.readBytes32(".genesisValidatorRoot");
        genesisTime = json.readUint(".genesisTime");
        secondsPerSlot = json.readUint(".secondsPerSlot");
        forkVersion = bytes4(json.parseRaw(".forkVersion"));
        period = json.readUint(".startSyncCommitteePeriod");
        scRoot = json.readBytes32(".startSyncCommitteeRoot");
        scpRoot = bytes32(json.readUint(".startSyncCommitteePoseidon"));
    }

    function readLCUpdateWithSyncCommittee(string memory network, string memory slot) public view returns (HeaderUpdate memory, bytes32, Groth16Proof memory)  {
        HeaderUpdate memory lcUpdate = readLightClientUpdateTestData(network, "ssz2Poseidon", slot);

        string memory path = string.concat(vm.projectRoot(), "/test/data/ssz2Poseidon/", network, "/", slot, ".json");
        string memory json = vm.readFile(path);
        bytes32 nextSyncCommitteePoseidon = json.readBytes32(".nextSyncCommitteePoseidon");
        uint256[2] memory a = [uint256(0), uint256(0)];
        uint256[2][2] memory b = [[uint256(0), uint256(0)], [uint256(0), uint256(0)]];
        uint256[2] memory c = [uint256(0), uint256(0)];
        a[0] = json.readUint(".ssz2PoseidonProof.a[0]");
        a[1] = json.readUint(".ssz2PoseidonProof.a[1]");
        b[0][0] = json.readUint(".ssz2PoseidonProof.b[0][0]");
        b[0][1] = json.readUint(".ssz2PoseidonProof.b[0][1]");
        b[1][0] = json.readUint(".ssz2PoseidonProof.b[1][0]");
        b[1][1] = json.readUint(".ssz2PoseidonProof.b[1][1]");
        c[0] = json.readUint(".ssz2PoseidonProof.c[0]");
        c[1] = json.readUint(".ssz2PoseidonProof.c[1]");
        Groth16Proof memory proof = Groth16Proof(a, b, c);
        return (lcUpdate, nextSyncCommitteePoseidon, proof);
    }

    function readLightClientUpdateTestData(
        string memory network,
        string memory fileName,
        string memory slot
    ) public view returns (HeaderUpdate memory) {
        string memory path = string.concat(vm.projectRoot(), "/test/data/", fileName, "/", network, "/", slot, ".json");
        string memory json = vm.readFile(path);

        BeaconBlockHeader memory attestedHeader = BeaconBlockHeader(
            uint64(json.readUint(".attestedHeader.slot")),
            uint64(json.readUint(".attestedHeader.proposerIndex")),
            json.readBytes32(".attestedHeader.parentRoot"),
            json.readBytes32(".attestedHeader.stateRoot"),
            json.readBytes32(".attestedHeader.bodyRoot")
        );
        BeaconBlockHeader memory finalizedHeader = BeaconBlockHeader(
            uint64(json.readUint(".finalizedHeader.slot")),
            uint64(json.readUint(".finalizedHeader.proposerIndex")),
            json.readBytes32(".finalizedHeader.parentRoot"),
            json.readBytes32(".finalizedHeader.stateRoot"),
            json.readBytes32(".finalizedHeader.bodyRoot")
        );
        bytes32 executionStateRoot = json.readBytes32(".executionStateRoot");
        bytes32[] memory executionStateRootBranch = json.readBytes32Array(
            ".executionStateRootBranch"
        );
        uint64 blockNumber = uint64(json.readUint(".blockNumber"));
        bytes32[] memory blockNumberBranch = json.readBytes32Array(
            ".blockNumberBranch"
        );
        bytes32 nextSyncCommitteeRoot = json.readBytes32(
            ".nextSyncCommitteeRoot"
        );
        bytes32[] memory nextSyncCommitteeBranch = json.readBytes32Array(
            ".nextSyncCommitteeBranch"
        );
        bytes32[] memory finalityBranch = json.readBytes32Array(
            ".finalityBranch"
        );

        BLSAggregatedSignature memory signature = buildSignatureObject(json);
        return HeaderUpdate(
            attestedHeader,
            finalizedHeader,
            finalityBranch,
            nextSyncCommitteeRoot,
            nextSyncCommitteeBranch,
            executionStateRoot,
            executionStateRootBranch,
            blockNumber,
            blockNumberBranch,
            signature
        );
    }

    function buildSignatureObject(string memory json) public pure returns (BLSAggregatedSignature memory) {
        uint256[2] memory a = [uint256(0), uint256(0)];
        uint256[2][2] memory b = [
        [uint256(0), uint256(0)],
        [uint256(0), uint256(0)]
        ];
        uint256[2] memory c = [uint256(0), uint256(0)];
        a[0] = json.readUint(".signature.proof.a[0]");
        a[1] = json.readUint(".signature.proof.a[1]");
        b[0][0] = json.readUint(".signature.proof.b[0][0]");
        b[0][1] = json.readUint(".signature.proof.b[0][1]");
        b[1][0] = json.readUint(".signature.proof.b[1][0]");
        b[1][1] = json.readUint(".signature.proof.b[1][1]");
        c[0] = json.readUint(".signature.proof.c[0]");
        c[1] = json.readUint(".signature.proof.c[1]");

        Groth16Proof memory proof = Groth16Proof(a, b, c);
        uint64 participation = uint64(
            json.readUint(".signature.participation")
        );
        return BLSAggregatedSignature(
            participation,
            proof
        );
    }
}
