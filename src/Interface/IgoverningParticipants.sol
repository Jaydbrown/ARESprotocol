pragma solidity ^0.8.17;

interface IgoverningParticipants {
    function createProposal(uint256 proposalId) external; //governing participants can create a proposal by providing a unique proposalId.
    function queueProposal(uint256 proposalId, bool add) external; // proposals are queued after creation and governing participants decides if its worth queueing or not.
    function confirmProposal(address[] calldata proposers, uint256 proposalId) external; // proposers can confirm a proposal by providing the proposalId and everyone who endorsed the proposal.
    function executeProposal(uint256 proposalId) external; // the proposal created can be executed.
}