pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {TimeDelayedExecutionEngine} from "../src/modules/timeDelayedExecutionEngine.sol";
import {MockTreasury} from "./mockData/mockTreasury.sol";
import {MockToken} from "./mockData/mockToken.sol";

contract TimelockTest is Test {
    TimeDelayedExecutionEngine engine;
    MockTreasury treasury;
    MockToken token;

    address admin = address(this);
    address recipient = address(0xBEEF);

    function setUp() public {
        token = new MockToken();
        treasury = new MockTreasury();
        engine = new TimeDelayedExecutionEngine(address(treasury));
    }

    function test_QueueTransaction() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        (
            uint256 transactionId,
            address to,
            uint256 amount,
            ,
            ,
            ,
            TimeDelayedExecutionEngine.Status status,
            ,
            address tkn
        ) = engine.transactions(txId);

        assertEq(transactionId, 0);
        assertEq(to, recipient);
        assertEq(amount, 100 ether);
        assertEq(uint(status), uint(TimeDelayedExecutionEngine.Status.Queued));
        assertEq(tkn, address(token));
    }

    function test_ExecuteAfterDelay() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        vm.warp(block.timestamp + 1 days + 1);
        engine.executeTransaction(txId);

        (, , , , , , TimeDelayedExecutionEngine.Status status, ,) = engine.transactions(txId);
        assertEq(uint(status), uint(TimeDelayedExecutionEngine.Status.Executed));
    }

    function test_CannotExecuteBeforeDelay() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        vm.expectRevert("delay not elapsed");
        engine.executeTransaction(txId);
    }

    function test_CannotExecuteExpiredTransaction() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        vm.warp(block.timestamp + 9 days);
        vm.expectRevert("transaction expired");
        engine.executeTransaction(txId);
    }

    function test_CancelTransaction() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        engine.cancelTransaction(txId);

        (, , , , , , TimeDelayedExecutionEngine.Status status, ,) = engine.transactions(txId);
        assertEq(uint(status), uint(TimeDelayedExecutionEngine.Status.Cancelled));
    }

    function test_CannotExecuteCancelledTransaction() public {
        uint256 txId = engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));
        engine.cancelTransaction(txId);

        vm.warp(block.timestamp + 1 days + 1);
        vm.expectRevert("not queued");
        engine.executeTransaction(txId);
    }

    function test_DuplicateTransactionReverts() public {
        engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));

        vm.expectRevert("transaction already queued");
        engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));
    }

    function test_InvalidDelayReverts() public {
        vm.expectRevert("invalid delay");
        engine.queueTransaction(recipient, 100 ether, "", 31 days, address(token));

        vm.expectRevert("invalid delay");
        engine.queueTransaction(recipient, 100 ether, "", 1 hours, address(token));
    }

    function test_OnlyAdminCanQueue() public {
        vm.prank(address(0xFF));
        vm.expectRevert("only admin is allowed");
        engine.queueTransaction(recipient, 100 ether, "", 1 days, address(token));
    }
}
