pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {cryptoGraphicAuthorizationLAyer} from "../src/modules/cryptographicAuthorizationLayer.sol";
import {MockToken} from "./mockData/mockToken.sol";
import {MockGovernors} from "./mockData/mockGovernor.sol";

contract AuthLayerTest is Test {
    cryptoGraphicAuthorizationLAyer authLayer;
    MockToken token;
    MockGovernors governors;

    uint256 claimantKey = 0xC1A1E;
    address claimant;

    function setUp() public {
        token = new MockToken();
        governors = new MockGovernors();
        authLayer = new cryptoGraphicAuthorizationLAyer(address(token), address(governors));

        claimant = vm.addr(claimantKey);
        token.mint(claimant, 500 ether);
    }

    function test_ValidSignature() public {
        uint256 proposalId = 1;
        uint256 nonce = 0;
        uint256 amount = 100 ether;

        bytes32 hash = authLayer.hashProposal(proposalId, claimant, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantKey, hash);

        vm.prank(claimant);
        authLayer.verifySentToken(amount, proposalId, nonce, v, r, s);

        assertEq(governors.lastProposalId(), proposalId);
        assertEq(authLayer.nonces(claimant), 1);
    }

    function test_InvalidNonceReverts() public {
        bytes32 hash = authLayer.hashProposal(1, claimant, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantKey, hash);

        vm.prank(claimant);
        vm.expectRevert("nonce is invalid");
        authLayer.verifySentToken(100 ether, 1, 99, v, r, s);
    }

    function test_ReplayReverts() public {
        uint256 proposalId = 1;
        uint256 nonce = 0;

        bytes32 hash = authLayer.hashProposal(proposalId, claimant, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantKey, hash);

        vm.prank(claimant);
        authLayer.verifySentToken(100 ether, proposalId, nonce, v, r, s);

        vm.prank(claimant);
        vm.expectRevert("nonce is invalid");
        authLayer.verifySentToken(100 ether, proposalId, nonce, v, r, s);
    }

    function test_InsufficientBalanceReverts() public {
        uint256 proposalId = 1;
        uint256 nonce = 0;
        uint256 amount = 1000 ether;

        bytes32 hash = authLayer.hashProposal(proposalId, claimant, nonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantKey, hash);

        vm.prank(claimant);
        vm.expectRevert("the amount you entered is too little");
        authLayer.verifySentToken(amount, proposalId, nonce, v, r, s);
    }

    function test_WrongSignerReverts() public {
        uint256 wrongKey = 0xBAD;
        bytes32 hash = authLayer.hashProposal(1, claimant, 0);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongKey, hash);

        vm.prank(claimant);
        vm.expectRevert("invalid signature");
        authLayer.verifySentToken(100 ether, 1, 0, v, r, s);
    }

    function test_NonceIncrementsAfterVerification() public {
        for (uint256 i = 0; i < 3; i++) {
            bytes32 hash = authLayer.hashProposal(i, claimant, i);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(claimantKey, hash);

            vm.prank(claimant);
            authLayer.verifySentToken(100 ether, i, i, v, r, s);

            assertEq(authLayer.nonces(claimant), i + 1);
        }
    }
}
