pragma solidity 0.8.14;
pragma experimental ABIEncoderV2;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./libraries/HeaderBLSVerifier.sol";
import "./libraries/SyncCommitteeRootToPoseidonVerifier.sol";
import "./libraries/SimpleSerialize.sol";
import {ILightClientGetter, ILightClientSetter} from "../interfaces/ILightClient.sol";

uint256 constant OPTIMISTIC_UPDATE_TIMEOUT = 86400;
uint256 constant SLOTS_PER_EPOCH = 32;
uint256 constant SLOTS_PER_SYNC_COMMITTEE_PERIOD = 8192;
uint256 constant MIN_SYNC_COMMITTEE_PARTICIPANTS = 10;
uint256 constant SYNC_COMMITTEE_SIZE = 512;
uint256 constant FINALIZED_ROOT_INDEX = 105;
uint256 constant NEXT_SYNC_COMMITTEE_INDEX = 55;
uint256 constant EXECUTION_STATE_ROOT_INDEX = 402;
uint256 constant BLOCK_NUMBER_ROOT_INDEX = 406;

/// @title An on-chain light client for Ethereum
/// @author iwan.eth
/// @notice An on-chain light client that complies with the Ethereum light client protocol witch 
///         is defined in `https://github.com/ethereum/consensus-specs`, it can be ethereum main 
///         net or goerli/sepolia test net.
///         With this light client you can verify any block headers from ethereum(main/test net).
/// @dev Different from normal light clients, on-chain light clients require a lower running 
///      costs because of the gas, but there is a lot of complex computational logic in ethereum 
///      consensus specs that cannot even be run in smart contracts. However, we can use zkSnarks 
///      technology to calculate complex logic and then verify it in smart contracts.
contract EthereumLightClient is ILightClientGetter, ILightClientSetter, Ownable {
    bytes32 public immutable GENESIS_VALIDATORS_ROOT;
    uint256 public immutable GENESIS_TIME;
    uint256 public immutable SECONDS_PER_SLOT;

    bool public active;
    bytes4 public defaultForkVersion;
    uint64 public headSlot;
    uint64 public headBlockNumber;
    uint256 public latestSyncCommitteePeriod;

    mapping(uint64 => uint64) internal _slot2block;
    mapping(uint64 => bytes32) internal _executionStateRoots;
    mapping(uint256 => bytes32) internal _syncCommitteeRootByPeriod;
    mapping(bytes32 => bytes32) internal _syncCommitteeRootToPoseidon;

    event HeaderUpdated(uint64 indexed slot, uint64 indexed blockNumber, bytes32 indexed executionRoot);
    event SyncCommitteeUpdated(uint64 indexed period, bytes32 indexed root);

    constructor(
        bytes32 genesisValidatorsRoot,
        uint256 genesisTime,
        uint256 secondsPerSlot,
        bytes4 forkVersion,
        uint256 startSyncCommitteePeriod,
        bytes32 startSyncCommitteeRoot,
        bytes32 startSyncCommitteePoseidon
    ) {
        GENESIS_VALIDATORS_ROOT = genesisValidatorsRoot;
        GENESIS_TIME = genesisTime;
        SECONDS_PER_SLOT = secondsPerSlot;
        defaultForkVersion = forkVersion;
        latestSyncCommitteePeriod = startSyncCommitteePeriod;
        _syncCommitteeRootByPeriod[startSyncCommitteePeriod] = startSyncCommitteeRoot;
        _syncCommitteeRootToPoseidon[startSyncCommitteeRoot] = startSyncCommitteePoseidon;
        active = true;
    }

    /// @notice Updates the execution state root given a finalized light client update
    /// @dev The primary conditions for this are:
    ///      1) At least 2n/3+1 signatures from the current sync committee where n = 512
    ///      2) A valid merkle proof for the finalized header inside the currently attested header
    /// @param update a parameter just like in doxygen (must be followed by parameter name)
    function updateHeader(HeaderUpdate calldata update) external override isActive {
        _verifyHeader(update);
        _updateHeader(update);
    }

    /// @notice Update the sync committee, it contains two updates actually: 
    ///         1. syncCommitteePoseidon
    ///         2. a header
    /// @dev Set the sync committee validator set root for the next sync committee period. This root 
    ///      is signed by the current sync committee. To make the proving cost of _headerBLSVerify(..) 
    ///      cheaper, we map the ssz merkle root of the validators to a poseidon merkle root (a zk-friendly 
    ///      hash function)
    /// @param update The header
    /// @param nextSyncCommitteePoseidon the syncCommitteePoseidon in the next sync committee period
    /// @param commitmentMappingProof A zkSnark proof to prove that `nextSyncCommitteePoseidon` is correct
    function updateSyncCommittee(
        HeaderUpdate calldata update,
        bytes32 nextSyncCommitteePoseidon,
        Groth16Proof calldata commitmentMappingProof
    ) external override isActive {
        _verifyHeader(update);
        _updateHeader(update);

        uint64 currentPeriod = _getPeriodFromSlot(update.finalizedHeader.slot);
        uint64 nextPeriod = currentPeriod + 1;
        require(_syncCommitteeRootByPeriod[nextPeriod] == 0, "Next sync committee was already initialized");
        require(SimpleSerialize.isValidMerkleBranch(
                update.nextSyncCommitteeRoot,
                NEXT_SYNC_COMMITTEE_INDEX,
                update.nextSyncCommitteeBranch,
                update.finalizedHeader.stateRoot
            ), "Next sync committee proof is invalid");

        _mapRootToPoseidon(update.nextSyncCommitteeRoot, nextSyncCommitteePoseidon, commitmentMappingProof);

        latestSyncCommitteePeriod = nextPeriod;
        _syncCommitteeRootByPeriod[nextPeriod] = update.nextSyncCommitteeRoot;
        emit SyncCommitteeUpdated(nextPeriod, update.nextSyncCommitteeRoot);
    }

    modifier isActive {
        require(active, "Light client must be active");
        _;
    }

    /// @notice Verify a new header come from source chain
    /// @dev Implements shared logic for processing light client updates. In particular, it checks:
    ///      1) Does Merkle Inclusion Proof that proves inclusion of finalizedHeader in attestedHeader
    ///      2) Does Merkle Inclusion Proof that proves inclusion of executionStateRoot in finalizedHeader
    ///      3) Checks that 2n/3+1 signatures are provided
    ///      4) Verifies that the light client update has update.signature.participation signatures from 
    ///         the current sync committee with a zkSNARK
    /// @param update a set of params that contains attestedHeader and finalizedHeader and branches and 
    ///               proofs that prove the two header is correct
    function _verifyHeader(HeaderUpdate calldata update) internal view {
        require(update.finalityBranch.length > 0, "No finality branches provided");
        require(update.executionStateRootBranch.length > 0, "No execution state root branches provided");

        // TODO Potential for improvement: Use multi-node merkle inclusion proofs instead of 2 separate single proofs
        require(SimpleSerialize.isValidMerkleBranch(
                SimpleSerialize.sszBeaconBlockHeader(update.finalizedHeader),
                FINALIZED_ROOT_INDEX,
                update.finalityBranch,
                update.attestedHeader.stateRoot
            ), "Finality checkpoint proof is invalid");

        require(SimpleSerialize.isValidMerkleBranch(
                update.executionStateRoot,
                EXECUTION_STATE_ROOT_INDEX,
                update.executionStateRootBranch,
                update.finalizedHeader.bodyRoot
            ), "Execution state root proof is invalid");
        require(SimpleSerialize.isValidMerkleBranch(
                SimpleSerialize.toLittleEndian(update.blockNumber),
                BLOCK_NUMBER_ROOT_INDEX,
                update.blockNumberBranch,
                update.finalizedHeader.bodyRoot
            ), "Block number proof is invalid");

        require(
            3 * update.signature.participation > 2 * SYNC_COMMITTEE_SIZE, 
            "Not enough members of the sync committee signed"
        );

        uint64 currentPeriod = _getPeriodFromSlot(update.finalizedHeader.slot);
        bytes32 signingRoot = SimpleSerialize.computeSigningRoot(
            update.attestedHeader, 
            defaultForkVersion, 
            GENESIS_VALIDATORS_ROOT
        );
        require(
            _syncCommitteeRootByPeriod[currentPeriod] != 0, 
            "Sync committee was never updated for this period"
        );
        require(
            _headerBLSVerify(
                signingRoot, 
                _syncCommitteeRootByPeriod[currentPeriod], 
                update.signature.participation, 
                update.signature.proof
            ), 
            "Signature is invalid"
        );
    }

    function _updateHeader(HeaderUpdate calldata headerUpdate) internal {
        require(
            headerUpdate.finalizedHeader.slot > headSlot, 
            "Update slot must be greater than the current head"
        );
        require(
            headerUpdate.finalizedHeader.slot <= _getCurrentSlot(), 
            "Update slot is too far in the future"
        );

        headSlot = headerUpdate.finalizedHeader.slot;
        headBlockNumber = headerUpdate.blockNumber;
        _slot2block[headerUpdate.finalizedHeader.slot] = headerUpdate.blockNumber;
        _executionStateRoots[headerUpdate.finalizedHeader.slot] = headerUpdate.executionStateRoot;

        emit HeaderUpdated(
            headerUpdate.finalizedHeader.slot, 
            headerUpdate.blockNumber, 
            headerUpdate.executionStateRoot
        );
    }

    /// @notice Maps a simple serialize merkle root to a poseidon merkle root with a zkSNARK. 
    /// @param syncCommitteeRoot sync committee root(ssz)
    /// @param syncCommitteePoseidon sync committee poseidon hash
    /// @param proof A zkSnarks proof to asserts that:
    ///              SimpleSerialize(syncCommittee) == Poseidon(syncCommittee).
    function _mapRootToPoseidon(
        bytes32 syncCommitteeRoot, 
        bytes32 syncCommitteePoseidon, 
        Groth16Proof calldata proof
    ) internal {
        uint256[33] memory inputs;
        // inputs is syncCommitteeSSZ[0..32] + [syncCommitteePoseidon]
        uint256 sszCommitmentNumeric = uint256(syncCommitteeRoot);
        for (uint256 i = 0; i < 32; i++) {
            inputs[32 - 1 - i] = sszCommitmentNumeric % 2 ** 8;
            sszCommitmentNumeric = sszCommitmentNumeric / 2 ** 8;
        }
        inputs[32] = uint256(syncCommitteePoseidon);
        require(
            SyncCommitteeRootToPoseidonVerifier.verifyCommitmentMappingProof(proof.a, proof.b, proof.c, inputs), 
            "Proof is invalid"
        );
        _syncCommitteeRootToPoseidon[syncCommitteeRoot] = syncCommitteePoseidon;
    }

    /// @notice Verify BLS signature
    /// @dev Does an aggregated BLS signature verification with a zkSNARK. The proof asserts that:
    ///      Poseidon(validatorPublicKeys) == _syncCommitteeRootToPoseidon[syncCommitteeRoot]
    ///      aggregatedPublicKey = InnerProduct(validatorPublicKeys, bitmap)
    ///      BLSVerify(aggregatedPublicKey, signature) == true
    /// @param signingRoot a parameter just like in doxygen (must be followed by parameter name)
    /// @return bool true/false
    function _headerBLSVerify(
        bytes32 signingRoot, 
        bytes32 syncCommitteeRoot, 
        uint256 claimedParticipation, 
        Groth16Proof calldata proof
    ) internal view returns (bool) {
        require(_syncCommitteeRootToPoseidon[syncCommitteeRoot] != 0, "Must map sync committee root to poseidon");
        uint256[34] memory inputs;
        inputs[0] = claimedParticipation;
        inputs[1] = uint256(_syncCommitteeRootToPoseidon[syncCommitteeRoot]);
        uint256 signingRootNumeric = uint256(signingRoot);
        for (uint256 i = 0; i < 32; i++) {
            inputs[(32 - 1 - i) + 2] = signingRootNumeric % 2 ** 8;
            signingRootNumeric = signingRootNumeric / 2 ** 8;
        }
        return HeaderBLSVerifier.verifySignatureProof(proof.a, proof.b, proof.c, inputs);
    }

    function _getCurrentSlot() internal view returns (uint64) {
        return uint64((block.timestamp - GENESIS_TIME) / SECONDS_PER_SLOT);
    }

    function _getPeriodFromSlot(uint64 slot) internal pure returns (uint64) {
        return uint64(slot / SLOTS_PER_SYNC_COMMITTEE_PERIOD);
    }

    function setDefaultForkVersion(bytes4 forkVersion) public onlyOwner {
        defaultForkVersion = forkVersion;
    }

    function setActive(bool newActive) public onlyOwner {
        active = newActive;
    }

    function slot2block(uint64 _slot) external view returns (uint64) {
        return _slot2block[_slot];
    }

    function syncCommitteeRootByPeriod(uint256 _period) external view returns (bytes32) {
        return _syncCommitteeRootByPeriod[_period];
    }

    function syncCommitteeRootToPoseidon(bytes32 _root) external view returns (bytes32) {
        return _syncCommitteeRootToPoseidon[_root];
    }

    /// @notice A view function that allows you to get an executionStateRoot from a valid header
    /// @dev The executionStateRoot can be used to verify that if something happened on the source chain
    /// @param slot The slot corresponding to the executionStateRoot
    /// @return bytes32 Return the executionStateRoot corresponding to the slot
    function executionStateRoot(uint64 slot) external override view returns (bytes32) {
        return _executionStateRoots[slot];
    }
}
