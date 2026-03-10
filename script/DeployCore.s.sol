pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {ARES} from "../src/modules/AREScontract.sol";
import {ProposalModule} from "../src/modules/transactionProposalSystem.sol";
import {cryptoGraphicAuthorizationLAyer} from "../src/modules/cryptoGraphicAuthorizationLAyer.sol";
import {TimeDelayedExecutionEngine} from "../src/modules/TimeDelayedExecutionEngine.sol";
import {Core} from "../src/core/Core.sol";

contract DeployCore is Script {

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address rewardToken = vm.envAddress("REWARD_TOKEN");
        address governors   = vm.envAddress("GOVERNORS");
        address treasury    = vm.envAddress("TREASURY");

        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("OWNER_1");
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");

        uint256 threshold = vm.envUint("THRESHOLD");

        vm.startBroadcast(deployerKey);

        ARES ares = new ARES(rewardToken, owners, threshold);
        console.log("ARES deployed at:            ", address(ares));

        ProposalModule proposalModule = new ProposalModule();
        console.log("ProposalModule deployed at:  ", address(proposalModule));

        cryptoGraphicAuthorizationLAyer authLayer = new cryptoGraphicAuthorizationLAyer(rewardToken, governors);
        console.log("AuthLayer deployed at:       ", address(authLayer));

        TimeDelayedExecutionEngine executionEngine = new TimeDelayedExecutionEngine(treasury);
        console.log("ExecutionEngine deployed at: ", address(executionEngine));

        Core core = new Core(
            address(ares),
            address(proposalModule),
            address(authLayer),
            address(executionEngine)
        );
        console.log("Core deployed at:            ", address(core));

        vm.stopBroadcast();
    }
}
