pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ethereum/EthereumLightClient.sol";
import "forge-std/console.sol";

contract DeployLightClient is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        bytes32 goerliGenesisValidatorRoot = vm.envBytes32(
            "GenesisValidatorRoot"
        );
        uint256 goerliGenesisType = vm.envUint("GenesisType");
        uint256 goerliSecondsPerSlot = vm.envUint("SecondsPerSlot");
		
        bytes4 goerliForkVersion = bytes4(vm.envBytes("ForkVersion"));

        // Important! The following script will deploy a Goerli Beacon Light Client starting from Period 622 (1 March 2023)
        uint256 goerliStartSyncCommitteePeriod = vm.envUint(
            "StartSyncCommitteePeriod"
        );
        bytes32 goerliStartSyncCommitteeRoot = vm.envBytes32(
            "StartSyncCommitteeRoot"
        );
        bytes32 goerliStartSyncCommitteePoseidon = vm.envBytes32(
            "StartSyncCommitteePoseidon"
        );
        new EthereumLightClient(
            goerliGenesisValidatorRoot,
            goerliGenesisType,
            goerliSecondsPerSlot,
            goerliForkVersion,
            goerliStartSyncCommitteePeriod,
            goerliStartSyncCommitteeRoot,
            goerliStartSyncCommitteePoseidon
        );

        vm.stopBroadcast();
    }
}
