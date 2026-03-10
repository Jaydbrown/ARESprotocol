pragma solidity ^0.8.17;

interface IgoverningParticipants {
    function createProposal(uint256 proposalId) external;
    function queueProposal(uint256 proposalId, bool add) external;
    function confirmProposal(address[] calldata proposers, uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;
}