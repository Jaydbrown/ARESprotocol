// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ARES} from "../../src/modules/AREScontract.sol";
import {ProposalModule} from "../../src/modules/transactionProposalSystem.sol";
import {cryptoGraphicAuthorizationLAyer} from "../../src/modules/cryptoGraphicAuthorizationLAyer.sol";
import {TimeDelayedExecutionEngine} from "../../src/modules/TimeDelayedExecutionEngine.sol";

contract Core {

    ARES public ares;
    ProposalModule public proposalModule;
    cryptoGraphicAuthorizationLAyer public authLayer;
    TimeDelayedExecutionEngine public executionEngine;

    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(
        address _ares,
        address _proposalModule,
        address _authLayer,
        address _executionEngine
    ) {
        require(_ares != address(0), "invalid ares");
        require(_proposalModule != address(0), "invalid proposalModule");
        require(_authLayer != address(0), "invalid authLayer");
        require(_executionEngine != address(0), "invalid executionEngine");

        admin = msg.sender;
        ares = ARES(_ares);
        proposalModule = ProposalModule(_proposalModule);
        authLayer = cryptoGraphicAuthorizationLAyer(_authLayer);
        executionEngine = TimeDelayedExecutionEngine(_executionEngine);
    }

    function submitTx(address _target, bytes calldata _data, uint256 _value) external returns (uint256) {
        return ares.submitTx(_target, _data, _value);
    }

    function confirmTx(uint256 _txId) external {
        ares.confirmTx(_txId);
    }

    function executeTx(uint256 _txId) external {
        ares.executeTx(_txId);
    }

    function setMerkleRoot(bytes32 _root) external {
        ares.setMerkleRoot(_root);
    }

    function claim(bytes32[] calldata proof, uint256 amount, bytes memory signature) external {
        ares.claim(proof, amount, signature);
    }

    function hasClaimed(address _claimant) external view returns (bool) {
        return ares.hasClaimed(_claimant);
    }

    function hasClaimedForRoot(address _claimant, bytes32 _root) external view returns (bool) {
        return ares.hasClaimedForRoot(_claimant, _root);
    }

    function getOwners() external view returns (address[] memory) {
        return ares.getOwners();
    }

    function isOwner(address _addr) external view returns (bool) {
        return ares.isOwner(_addr);
    }

    function threshold() external view returns (uint256) {
        return ares.threshold();
    }

    function tokenBalance() external view returns (uint256) {
        return ares.tokenBalance();
    }

    function authorizeProposer(address _proposer) external onlyAdmin {
        proposalModule.authorizeProposer(_proposer);
    }

    function proposeTransfer(address _token, uint256 _amount, address _recipient) external returns (uint256) {
        return proposalModule.proposeTransfer(_token, _amount, _recipient);
    }

    function proposeCall(address _target, bytes calldata _data) external returns (uint256) {
        return proposalModule.proposeCall(_target, _data);
    }

    function proposeUpgrade(address _oldContract, address _newContract) external returns (uint256) {
        return proposalModule.proposeUpgrade(_oldContract, _newContract);
    }

    function commitProposal(uint256 _proposalId) external onlyAdmin {
        proposalModule.commitProposal(_proposalId);
    }

    function confirmProposal(uint256 _proposalId) external {
        proposalModule.confirmProposal(_proposalId);
    }

    function executeProposal(uint256 _proposalId) external onlyAdmin {
        proposalModule.executeProposal(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external onlyAdmin {
        proposalModule.cancelProposal(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (ProposalModule.Proposal memory) {
        return proposalModule.getProposal(_proposalId);
    }

    function hashProposal(uint256 proposalId, address proposer, uint256 nonce) external view returns (bytes32) {
        return authLayer.hashProposal(proposalId, proposer, nonce);
    }

    function verifySentToken(
        uint256 _amount,
        uint256 _proposalId,
        uint256 _nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        authLayer.verifySentToken(_amount, _proposalId, _nonce, v, r, s);
    }

    function queueTransaction(
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _delay,
        address _token
    ) external onlyAdmin returns (uint256) {
        return executionEngine.queueTransaction(_to, _amount, _data, _delay, _token);
    }

    function executeTransaction(uint256 _txId) external onlyAdmin {
        executionEngine.executeTransaction(_txId);
    }

    function cancelTransaction(uint256 _txId) external onlyAdmin {
        executionEngine.cancelTransaction(_txId);
    }

    function hashTransaction(
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _eta
    ) external view returns (bytes32) {
        return executionEngine.hashTransaction(_to, _amount, _data, _eta);
    }
}
