pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/ethereum/EthereumLightClient.sol";


contract DeployLightClient is Script {

	function run() external {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		vm.startBroadcast(deployerPrivateKey);

		bytes32 goerliGenesisValidatorRoot = bytes32(0x043db0d9a83813551ee2f33450d23797757d430911a9320530ad8a0eabc43efb);
		uint256 goerliGenesisType = 1616508000;
		uint256 goerliSecondsPerSlot = uint256(12);
		bytes4 goerliForkVersion = bytes4(0x02001020);

		// Important! The following script will deploy a Goerli Beacon Light Client starting from Period 622 (1 March 2023)
		uint256 goerliStartSyncCommitteePeriod = uint256(622);
		bytes32 goerliStartSyncCommitteeRoot = 0x3e550c1ec5b6ce738f0f377dad7dabb3db732075bb2f716617bd2670326f51e2;
		bytes32 goerliStartSyncCommitteePoseidon = bytes32(uint256(15723372587160775010106261491283302547283441397492210875652651465207522176490));

		new EthereumLightClient(
			goerliGenesisValidatorRoot,
			goerliGenesisType,
			goerliSecondsPerSlot,
			goerliForkVersion,
			goerliStartSyncCommitteePeriod,
			goerliStartSyncCommitteeRoot,
			goerliStartSyncCommitteePoseidon);

		vm.stopBroadcast();
	}
}
