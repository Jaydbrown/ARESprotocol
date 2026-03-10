// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {CoreBase} from "../Base/CoreBase.sol";
import {ARES} from "../../src/modules/AREScontract.sol";
import {ProposalModule} from "../../src/modules/transactionProposalSystem.sol";
import {cryptoGraphicAuthorizationLAyer} from "../../src/modules/cryptoGraphicAuthorizationLAyer.sol";
import {TimeDelayedExecutionEngine} from "../../src/modules/timeDelayedExecutionEngine.sol";

contract Core is CoreBase, ARES, ProposalModule, cryptoGraphicAuthorizationLAyer, TimeDelayedExecutionEngine {

    constructor(
        address          _rewardToken,
        address[] memory _owners,
        uint256          _threshold,
        address          _governors,
        address          _treasury
    )
        CoreBase(_rewardToken)
        ARES(_rewardToken, _owners, _threshold)
        cryptoGraphicAuthorizationLAyer(_rewardToken, _governors)
        TimeDelayedExecutionEngine(_treasury)
    {}
}

