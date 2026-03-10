pragma solidity ^0.8.17;

import {proposeAssetTransaction} from "../../src/libraries/proposeAssetTransaction.sol";
import {Itoken} from "../../src/interface/Itoken.sol";

contract ProposalModule {

    enum Status { Pending, Committed, Ready, Executed, Cancelled }
    enum ProposalType { Transfer, Call, Upgrade }

    struct Proposal {
        uint256 proposalId;
        ProposalType pType;
        address proposer;
        address token;
        address recipient;
        uint256 amount;
        address target;
        bytes data;
        address oldContract;
        address newContract;
        uint256 committedAt;
        uint256 confirmations;
        Status status;
        bytes32 proposalHash;
    }

    address public admin;
    uint256 public proposalCount;
    uint256 internal constant DELAY = 2 days;
    uint256 internal constant REQUIRED_CONFIRMATIONS = 3;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public authorizedProposers;
    mapping(uint256 => mapping(address => bool)) public hasConfirmed;
    mapping(bytes32 => bool) public proposalHashUsed;

    event ProposalCreated(uint256 indexed proposalId, ProposalType pType, address indexed proposer);
    event ProposalCommitted(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "not admin");
        _;
    }

    modifier onlyProposer() {
        require(authorizedProposers[msg.sender], "not authorized");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function authorizeProposer(address _proposer) external onlyAdmin {
        require(_proposer != address(0), "invalid address");
        authorizedProposers[_proposer] = true;
    }

    function proposeTransfer(
        address _token,
        uint256 _amount,
        address _recipient
    ) external onlyProposer returns (uint256) {
        proposeAssetTransaction.transfer(_token, _amount, _recipient);

        bytes32 pHash = keccak256(abi.encode(ProposalType.Transfer, _token, _amount, _recipient, msg.sender));
        require(!proposalHashUsed[pHash], "duplicate proposal");
        proposalHashUsed[pHash] = true;

        uint256 pId = proposalCount++;
        proposals[pId] = Proposal({
            proposalId: pId,
            pType: ProposalType.Transfer,
            proposer: msg.sender,
            token: _token,
            recipient: _recipient,
            amount: _amount,
            target: address(0),
            data: "",
            oldContract: address(0),
            newContract: address(0),
            committedAt: 0,
            confirmations: 0,
            status: Status.Pending,
            proposalHash: pHash
        });

        emit ProposalCreated(pId, ProposalType.Transfer, msg.sender);
        return pId;
    }

    function proposeCall(
        address _target,
        bytes calldata _data
    ) external onlyProposer returns (uint256) {
        proposeAssetTransaction.call(_target, _data);

        bytes32 pHash = keccak256(abi.encode(ProposalType.Call, _target, _data, msg.sender));
        require(!proposalHashUsed[pHash], "duplicate proposal");
        proposalHashUsed[pHash] = true;

        uint256 pId = proposalCount++;
        proposals[pId] = Proposal({
            proposalId: pId,
            pType: ProposalType.Call,
            proposer: msg.sender,
            token: address(0),
            recipient: address(0),
            amount: 0,
            target: _target,
            data: _data,
            oldContract: address(0),
            newContract: address(0),
            committedAt: 0,
            confirmations: 0,
            status: Status.Pending,
            proposalHash: pHash
        });

        emit ProposalCreated(pId, ProposalType.Call, msg.sender);
        return pId;
    }

    function proposeUpgrade(
        address _oldContract,
        address _newContract
    ) external onlyProposer returns (uint256) {
        proposeAssetTransaction.upgrade(_oldContract, _newContract);

        bytes32 pHash = keccak256(abi.encode(ProposalType.Upgrade, _oldContract, _newContract, msg.sender));
        require(!proposalHashUsed[pHash], "duplicate proposal");
        proposalHashUsed[pHash] = true;

        uint256 pId = proposalCount++;
        proposals[pId] = Proposal({
            proposalId: pId,
            pType: ProposalType.Upgrade,
            proposer: msg.sender,
            token: address(0),
            recipient: address(0),
            amount: 0,
            target: address(0),
            data: "",
            oldContract: _oldContract,
            newContract: _newContract,
            committedAt: 0,
            confirmations: 0,
            status: Status.Pending,
            proposalHash: pHash
        });

        emit ProposalCreated(pId, ProposalType.Upgrade, msg.sender);
        return pId;
    }

    function commitProposal(uint256 _proposalId) external onlyAdmin {
        require(proposals[_proposalId].status == Status.Pending, "not pending");
        proposals[_proposalId].status = Status.Committed;
        proposals[_proposalId].committedAt = block.timestamp;
        emit ProposalCommitted(_proposalId);
    }

    function confirmProposal(uint256 _proposalId) external onlyProposer {
        require(proposals[_proposalId].status == Status.Committed, "not committed");
        require(!hasConfirmed[_proposalId][msg.sender], "already confirmed");

        hasConfirmed[_proposalId][msg.sender] = true;
        proposals[_proposalId].confirmations++;

        if (
            proposals[_proposalId].confirmations >= REQUIRED_CONFIRMATIONS &&
            block.timestamp >= proposals[_proposalId].committedAt + DELAY
        ) {
            proposals[_proposalId].status = Status.Ready;
        }
    }

    function executeProposal(uint256 _proposalId) external onlyAdmin {
        Proposal storage p = proposals[_proposalId];
        require(p.status == Status.Ready, "not ready");
        require(block.timestamp >= p.committedAt + DELAY, "delay not elapsed");

        bytes32 currentHash;

        if (p.pType == ProposalType.Transfer) {
            currentHash = keccak256(abi.encode(ProposalType.Transfer, p.token, p.amount, p.recipient, p.proposer));
        } else if (p.pType == ProposalType.Call) {
            currentHash = keccak256(abi.encode(ProposalType.Call, p.target, p.data, p.proposer));
        } else if (p.pType == ProposalType.Upgrade) {
            currentHash = keccak256(abi.encode(ProposalType.Upgrade, p.oldContract, p.newContract, p.proposer));
        }

        require(currentHash == p.proposalHash, "proposal replaced");
        p.status = Status.Executed;
        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external onlyAdmin {
        require(
            proposals[_proposalId].status == Status.Pending ||
            proposals[_proposalId].status == Status.Committed,
            "cannot cancel"
        );
        proposals[_proposalId].status = Status.Cancelled;
        emit ProposalCancelled(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }
}