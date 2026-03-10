pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ARES} from "../../src/modules/AREScontract.sol";
import {MockToken} from "./mockData/mockToken.sol";

contract ARESTest is Test {
    ARES ares;
    MockToken token;

    uint256 ownerKey1 = 0xA11CE;
    uint256 ownerKey2 = 0xB0B;
    uint256 ownerKey3 = 0xCA7;

    address owner1;
    address owner2;
    address owner3;

    function setUp() public {
        owner1 = vm.addr(ownerKey1);
        owner2 = vm.addr(ownerKey2);
        owner3 = vm.addr(ownerKey3);

        token = new MockToken();

        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;

        ares = new ARES(address(token), owners, 2);
        token.mint(address(ares), 1000 ether);
    }

    function test_OwnersInitialized() public {
        assertTrue(ares.isOwner(owner1));
        assertTrue(ares.isOwner(owner2));
        assertTrue(ares.isOwner(owner3));
        assertEq(ares.threshold(), 2);
    }

    function test_TokenBalance() public {
        assertEq(ares.tokenBalance(), 1000 ether);
    }

    function test_SubmitTx() public {
        bytes memory data = abi.encodeWithSignature("setMerkleRoot(bytes32)", bytes32(uint256(1)));
        vm.prank(owner1);
        uint256 txId = ares.submitTx(address(ares), data, 0);
        assertEq(txId, 0);
    }

    function test_ConfirmAndExecuteTx() public {
        bytes32 newRoot = bytes32(uint256(0xDEAD));
        bytes memory data = abi.encodeWithSignature("setMerkleRoot(bytes32)", newRoot);

        vm.prank(owner1);
        uint256 txId = ares.submitTx(address(ares), data, 0);

        vm.prank(owner1);
        ares.confirmTx(txId);

        vm.prank(owner2);
        ares.confirmTx(txId);

        vm.prank(owner1);
        ares.executeTx(txId);

        assertEq(ares.merkleRoot(), newRoot);
    }

    function test_CannotExecuteWithoutThreshold() public {
        bytes memory data = abi.encodeWithSignature("setMerkleRoot(bytes32)", bytes32(uint256(1)));

        vm.prank(owner1);
        uint256 txId = ares.submitTx(address(ares), data, 0);

        vm.prank(owner1);
        ares.confirmTx(txId);

        vm.prank(owner1);
        vm.expectRevert("not enough confirmations");
        ares.executeTx(txId);
    }

    function test_CannotReuseRoot() public {
        bytes32 root = bytes32(uint256(0xDEAD));
        bytes memory data = abi.encodeWithSignature("setMerkleRoot(bytes32)", root);

        vm.prank(owner1);
        uint256 txId = ares.submitTx(address(ares), data, 0);
        vm.prank(owner1); ares.confirmTx(txId);
        vm.prank(owner2); ares.confirmTx(txId);
        vm.prank(owner1); ares.executeTx(txId);

        bytes memory data2 = abi.encodeWithSignature("setMerkleRoot(bytes32)", root);
        vm.prank(owner1);
        uint256 txId2 = ares.submitTx(address(ares), data2, 0);
        vm.prank(owner1); ares.confirmTx(txId2);
        vm.prank(owner2); ares.confirmTx(txId2);

        vm.prank(owner1);
        vm.expectRevert("execution failed");
        ares.executeTx(txId2);
    }
}
