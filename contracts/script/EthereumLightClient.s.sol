pragma solidity ^0.8.12;

import "forge-std/Script.sol";
import "../src/ethereum/EthereumLightClient.sol";
import "forge-std/console.sol";

contract DeployLightClient is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory logPath = "./exports/address.txt";
        if (vm.isFile(logPath)) {
            vm.removeFile(logPath);
        }

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
        EthereumLightClient lightClientAddr = new EthereumLightClient(
            goerliGenesisValidatorRoot,
            goerliGenesisType,
            goerliSecondsPerSlot,
            goerliForkVersion,
            goerliStartSyncCommitteePeriod,
            goerliStartSyncCommitteeRoot,
            goerliStartSyncCommitteePoseidon
        );
        console.log("lightClient", address(lightClientAddr));

        string memory a = "lightClient: ";
        string memory b = vm.toString(address(lightClientAddr));
        string memory c = string.concat(a, b);
        vm.writeLine(logPath, c);

        vm.stopBroadcast();
    }
}
