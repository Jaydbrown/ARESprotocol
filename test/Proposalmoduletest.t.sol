pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ProposalModule} from "../../src/modules/transactionProposalSystem.sol";
import {MockToken} from "./mockData/mockToken.sol";

contract ProposalModuleTest is Test {
    ProposalModule proposalModule;
    MockToken token;

    address admin = address(this);
    address proposer1 = address(0xAA);
    address proposer2 = address(0xBB);
    address proposer3 = address(0xCC);
    address recipient = address(0xDEAD);

    function setUp() public {
        token = new MockToken();
        proposalModule = new ProposalModule();

        proposalModule.authorizeProposer(proposer1);
        proposalModule.authorizeProposer(proposer2);
        proposalModule.authorizeProposer(proposer3);
    }

    function test_ProposeTransfer() public {
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeTransfer(address(token), 100 ether, recipient);

        ProposalModule.Proposal memory p = proposalModule.getProposal(pId);
        assertEq(uint(p.status), uint(ProposalModule.Status.Pending));
        assertEq(p.amount, 100 ether);
        assertEq(p.recipient, recipient);
        assertEq(p.proposer, proposer1);
    }

    function test_ProposeCall() public {
        bytes memory data = abi.encodeWithSignature("someFunction()");
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeCall(address(0xBEEF), data);

        ProposalModule.Proposal memory p = proposalModule.getProposal(pId);
        assertEq(uint(p.pType), uint(ProposalModule.ProposalType.Call));
        assertEq(p.target, address(0xBEEF));
    }

    function test_ProposeUpgrade() public {
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeUpgrade(address(0x111), address(0x222));

        ProposalModule.Proposal memory p = proposalModule.getProposal(pId);
        assertEq(uint(p.pType), uint(ProposalModule.ProposalType.Upgrade));
        assertEq(p.oldContract, address(0x111));
        assertEq(p.newContract, address(0x222));
    }

    function test_FullProposalLifecycle() public {
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeTransfer(address(token), 100 ether, recipient);

        proposalModule.commitProposal(pId);
        assertEq(uint(proposalModule.getProposal(pId).status), uint(ProposalModule.Status.Committed));

        vm.warp(block.timestamp + 2 days + 1);

        vm.prank(proposer1); proposalModule.confirmProposal(pId);
        vm.prank(proposer2); proposalModule.confirmProposal(pId);
        vm.prank(proposer3); proposalModule.confirmProposal(pId);

        assertEq(uint(proposalModule.getProposal(pId).status), uint(ProposalModule.Status.Ready));

        proposalModule.executeProposal(pId);
        assertEq(uint(proposalModule.getProposal(pId).status), uint(ProposalModule.Status.Executed));
    }

    function test_CancelPendingProposal() public {
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeTransfer(address(token), 100 ether, recipient);

        proposalModule.cancelProposal(pId);
        assertEq(uint(proposalModule.getProposal(pId).status), uint(ProposalModule.Status.Cancelled));
    }

    function test_DuplicateProposalReverts() public {
        vm.prank(proposer1);
        proposalModule.proposeTransfer(address(token), 100 ether, recipient);

        vm.prank(proposer1);
        vm.expectRevert("duplicate proposal");
        proposalModule.proposeTransfer(address(token), 100 ether, recipient);
    }

    function test_UnauthorizedProposerReverts() public {
        vm.prank(address(0xFF));
        vm.expectRevert("not authorized");
        proposalModule.proposeTransfer(address(token), 100 ether, recipient);
    }

    function test_CannotExecuteBeforeDelay() public {
        vm.prank(proposer1);
        uint256 pId = proposalModule.proposeTransfer(address(token), 100 ether, recipient);

        proposalModule.commitProposal(pId);

        vm.prank(proposer1); proposalModule.confirmProposal(pId);
        vm.prank(proposer2); proposalModule.confirmProposal(pId);
        vm.prank(proposer3); proposalModule.confirmProposal(pId);

        assertEq(uint(proposalModule.getProposal(pId).status), uint(ProposalModule.Status.Committed));
    }
}
