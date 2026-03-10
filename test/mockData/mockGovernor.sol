pragma solidity ^0.8.17;

contract MockGovernors {
    uint256 public lastProposalId;

    function createProposal(uint256 proposalId) external {
        lastProposalId = proposalId;
    }
}
