// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {MultiSigLib} from "../../src/libraries/MultiSigLib.sol";
import {MerkleLib} from "../../src/libraries/MerkleLib.sol";
import {proposeAssetTransaction} from "../../src/libraries/proposeAssetTransaction.sol";
import {ECDSA} from "../../src/libraries/ECDSA.sol";
import {Itoken} from "../../src/interface/Itoken.sol";
import {IgoverningParticipants} from "../../src/Interface/IgoverningParticipants.sol";
import {Itreasury} from "../../src/Interface/Itreasury.sol";

contract Core {
    using MultiSigLib for MultiSigLib.State;
    using ECDSA for bytes32;

    address public admin;
    bool private locked;

    MultiSigLib.State internal _state;

    Itoken public rewardToken;
    bytes32 public merkleRoot;
    uint256 public rootNonce;

    mapping(bytes32 => mapping(address => bool)) public claimed;
    mapping(bytes32 => bool) public usedRoots;

    event TxSubmitted(uint256 indexed txId, address indexed target);
    event TxConfirmed(uint256 indexed txId, address indexed owner);
    event TxExecuted(uint256 indexed txId);
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot, uint256 nonce);
    event Claimed(address indexed claimant, uint256 amount, bytes32 indexed root);

    enum ProposalStatus { Pending, Committed, Ready, Executed, Cancelled }
    enum ProposalType   { Transfer, Call, Upgrade }

    struct Proposal {
        uint256        proposalId;
        ProposalType   pType;
        address        proposer;
        address        token;
        address        recipient;
        uint256        amount;
        address        target;
        bytes          data;
        address        oldContract;
        address        newContract;
        uint256        committedAt;
        uint256        confirmations;
        ProposalStatus status;
        bytes32        proposalHash;
    }

    uint256 public proposalCount;
    uint256 internal constant PROPOSAL_DELAY         = 2 days;
    uint256 internal constant REQUIRED_CONFIRMATIONS = 3;

    mapping(uint256 => Proposal)                         public proposals;
    mapping(address => bool)                             public authorizedProposers;
    mapping(uint256 => mapping(address => bool))         public hasConfirmed;
    mapping(bytes32 => bool)                             public proposalHashUsed;

    event ProposalCreated(uint256 indexed proposalId, ProposalType pType, address indexed proposer);
    event ProposalCommitted(uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);

    bytes32 public immutable personalHash;
    bytes32 public constant PREFIX = keccak256("CryptoGraphicAuth_v1");

    IgoverningParticipants public governors;

    mapping(bytes32 => bool)    public usedSignatures;
    mapping(address => uint256) public nonces;

    Itreasury public treasury;
    bytes32 public immutable timelockHash;

    uint256 internal constant MIN_DELAY = 1 days;
    uint256 internal constant MAX_DELAY = 30 days;
    uint256 public transactionCount;

    enum TxStatus { Queued, Executed, Cancelled }

    struct Transaction {
        uint256  transactionId;
        address  to;
        uint256  amount;
        bytes    data;
        uint256  queuedAt;
        uint256  eta;
        TxStatus status;
        bytes32  txHash;
        address  token;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(bytes32 => bool)        public txHashUsed;

    event TransactionQueued(uint256 indexed transactionId, address indexed to, uint256 amount, uint256 eta);
    event TransactionExecuted(uint256 indexed transactionId);
    event TransactionCancelled(uint256 indexed transactionId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin is authorized");
        _;
    }

    modifier onlyOwner() {
        require(_state.isOwner[msg.sender], "not a multisig owner");
        _;
    }

    modifier onlyViaMultisig() {
        require(msg.sender == address(this), "not via multisig");
        _;
    }

    modifier onlyProposer() {
        require(authorizedProposers[msg.sender], "not an authorized proposer");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "reentrant call detected");
        locked = true;
        _;
        locked = false;
    }

    constructor(
        address          _rewardToken,
        address[] memory _owners,
        uint256          _threshold,
        address          _governors,
        address          _treasury
    ) {
        require(_rewardToken != address(0), "invalid reward token");
        require(_governors   != address(0), "invalid governors address");
        require(_treasury    != address(0), "invalid treasury address");

        admin       = msg.sender;
        rewardToken = Itoken(_rewardToken);
        governors   = IgoverningParticipants(_governors);
        treasury    = Itreasury(_treasury);

        _state.initOwners(_owners, _threshold);

        personalHash = keccak256(abi.encodePacked(
            keccak256("hashedToken"),
            block.chainid,
            address(this)
        ));

        timelockHash = keccak256(abi.encode(
            keccak256("TimeDelayedExecutionEngine_v1"),
            block.chainid,
            address(this)
        ));
    }

    function submitTx(
        address _target,
        bytes calldata _data,
        uint256 _value
    ) external onlyOwner returns (uint256) {
        uint256 txId = _state.submitTx(_target, _data, _value);
        emit TxSubmitted(txId, _target);
        return txId;
    }

    function confirmTx(uint256 _txId) external onlyOwner {
        _state.confirmTx(_txId, msg.sender);
        emit TxConfirmed(_txId, msg.sender);
    }

    function executeTx(uint256 _txId) external onlyOwner {
        require(_state.isReadyToExecute(_txId), "not enough confirmations");
        _state.markExecuted(_txId);
        MultiSigLib.Tx storage mtx = _state.txs[_txId];
        (bool success,) = address(this).call{value: mtx.value}(mtx.data);
        require(success, "multisig execution failed");
        emit TxExecuted(_txId);
    }

    function setMerkleRoot(bytes32 _root) external onlyViaMultisig {
        require(_root != bytes32(0), "invalid root");
        require(!usedRoots[_root], "root already used");
        bytes32 oldRoot  = merkleRoot;
        usedRoots[_root] = true;
        merkleRoot       = _root;
        rootNonce++;
        emit MerkleRootUpdated(oldRoot, _root, rootNonce);
    }

    function claim(
        bytes32[] calldata proof,
        uint256            amount,
        bytes memory       signature
    ) external {
        require(merkleRoot != bytes32(0), "no active root");
        require(!claimed[merkleRoot][msg.sender], "already claimed");

        bytes32 messageHash = MerkleLib.buildMessageHash(msg.sender, amount, merkleRoot, rootNonce);
        bytes32 ethHash     = MerkleLib.toEthSignedHash(messageHash);
        require(MerkleLib.recoverSigner(ethHash, signature) == msg.sender, "invalid signature");

        bytes32 leaf = MerkleLib.buildLeaf(msg.sender, amount);
        require(MerkleLib.verify(proof, merkleRoot, leaf), "invalid proof");

        claimed[merkleRoot][msg.sender] = true;
        require(rewardToken.transfer(msg.sender, amount), "token transfer failed");
        emit Claimed(msg.sender, amount, merkleRoot);
    }

    function authorizeProposer(address _proposer) external onlyAdmin {
        require(_proposer != address(0), "invalid proposer address");
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
            proposalId:    pId,
            pType:         ProposalType.Transfer,
            proposer:      msg.sender,
            token:         _token,
            recipient:     _recipient,
            amount:        _amount,
            target:        address(0),
            data:          "",
            oldContract:   address(0),
            newContract:   address(0),
            committedAt:   0,
            confirmations: 0,
            status:        ProposalStatus.Pending,
            proposalHash:  pHash
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
            proposalId:    pId,
            pType:         ProposalType.Call,
            proposer:      msg.sender,
            token:         address(0),
            recipient:     address(0),
            amount:        0,
            target:        _target,
            data:          _data,
            oldContract:   address(0),
            newContract:   address(0),
            committedAt:   0,
            confirmations: 0,
            status:        ProposalStatus.Pending,
            proposalHash:  pHash
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
            proposalId:    pId,
            pType:         ProposalType.Upgrade,
            proposer:      msg.sender,
            token:         address(0),
            recipient:     address(0),
            amount:        0,
            target:        address(0),
            data:          "",
            oldContract:   _oldContract,
            newContract:   _newContract,
            committedAt:   0,
            confirmations: 0,
            status:        ProposalStatus.Pending,
            proposalHash:  pHash
        });

        emit ProposalCreated(pId, ProposalType.Upgrade, msg.sender);
        return pId;
    }

    function commitProposal(uint256 _proposalId) external onlyAdmin {
        require(proposals[_proposalId].status == ProposalStatus.Pending, "not pending");
        proposals[_proposalId].status      = ProposalStatus.Committed;
        proposals[_proposalId].committedAt = block.timestamp;
        emit ProposalCommitted(_proposalId);
    }

    function confirmProposal(uint256 _proposalId) external onlyProposer {
        require(proposals[_proposalId].status == ProposalStatus.Committed, "not committed");
        require(!hasConfirmed[_proposalId][msg.sender], "already confirmed");

        hasConfirmed[_proposalId][msg.sender] = true;
        proposals[_proposalId].confirmations++;

        if (
            proposals[_proposalId].confirmations >= REQUIRED_CONFIRMATIONS &&
            block.timestamp >= proposals[_proposalId].committedAt + PROPOSAL_DELAY
        ) {
            proposals[_proposalId].status = ProposalStatus.Ready;
        }
    }

    function executeProposal(uint256 _proposalId) external onlyAdmin {
        Proposal storage p = proposals[_proposalId];
        require(p.status == ProposalStatus.Ready, "not ready");
        require(block.timestamp >= p.committedAt + PROPOSAL_DELAY, "delay not elapsed");

        bytes32 currentHash;

        if (p.pType == ProposalType.Transfer) {
            currentHash = keccak256(abi.encode(ProposalType.Transfer, p.token, p.amount, p.recipient, p.proposer));
        } else if (p.pType == ProposalType.Call) {
            currentHash = keccak256(abi.encode(ProposalType.Call, p.target, p.data, p.proposer));
        } else if (p.pType == ProposalType.Upgrade) {
            currentHash = keccak256(abi.encode(ProposalType.Upgrade, p.oldContract, p.newContract, p.proposer));
        }

        require(currentHash == p.proposalHash, "proposal replaced");
        p.status = ProposalStatus.Executed;
        emit ProposalExecuted(_proposalId);
    }

    function cancelProposal(uint256 _proposalId) external onlyAdmin {
        require(
            proposals[_proposalId].status == ProposalStatus.Pending ||
            proposals[_proposalId].status == ProposalStatus.Committed,
            "cannot cancel"
        );
        proposals[_proposalId].status = ProposalStatus.Cancelled;
        emit ProposalCancelled(_proposalId);
    }

    function hashProposal(
        uint256 proposalId,
        address proposer,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encode(
            personalHash,
            proposalId,
            proposer,
            nonce
        ));
    }

    function verifySentToken(
        uint256 _amount,
        uint256 _proposalId,
        uint256 _nonce,
        uint8   v,
        bytes32 r,
        bytes32 s
    ) external {
        require(nonces[msg.sender] == _nonce, "nonce is invalid");

        bytes32 sigHash = keccak256(abi.encodePacked(r, s));
        require(!usedSignatures[sigHash], "signature already used");

        bytes32 hash   = hashProposal(_proposalId, msg.sender, _nonce);
        address signer = ECDSA.recover(hash, v, r, s);
        require(signer == msg.sender, "invalid signature");
        require(rewardToken.balanceOf(msg.sender) >= _amount, "insufficient token balance");

        usedSignatures[sigHash] = true;
        nonces[msg.sender]++;
        governors.createProposal(_proposalId);
    }

    function hashTransaction(
        address  _to,
        uint256  _amount,
        bytes memory _data,
        uint256  _eta
    ) public view returns (bytes32) {
        return keccak256(abi.encode(
            timelockHash,
            _to,
            _amount,
            _data,
            _eta
        ));
    }

    function queueTransaction(
        address      _to,
        uint256      _amount,
        bytes memory _data,
        uint256      _delay,
        address      _token
    ) external onlyAdmin returns (uint256) {
        require(_to != address(0), "invalid address");
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "invalid delay");

        uint256 eta    = block.timestamp + _delay;
        bytes32 txHash = hashTransaction(_to, _amount, _data, eta);

        require(!txHashUsed[txHash], "transaction already queued");
        txHashUsed[txHash] = true;

        uint256 txId = transactionCount++;
        transactions[txId] = Transaction({
            transactionId: txId,
            to:            _to,
            amount:        _amount,
            data:          _data,
            queuedAt:      block.timestamp,
            eta:           eta,
            status:        TxStatus.Queued,
            txHash:        txHash,
            token:         _token
        });

        emit TransactionQueued(txId, _to, _amount, eta);
        return txId;
    }

    function executeTransaction(uint256 _txId) external onlyAdmin noReentrancy {
        Transaction storage txn = transactions[_txId];

        require(txn.status == TxStatus.Queued, "not queued");
        require(block.timestamp >= txn.eta, "delay not elapsed");
        require(block.timestamp <= txn.eta + 7 days, "transaction expired");

        txn.status = TxStatus.Executed;

        bytes32 currentHash = hashTransaction(txn.to, txn.amount, txn.data, txn.eta);
        require(currentHash == txn.txHash, "transaction replaced");

        treasury.transfer(txn.to, txn.amount, txn.token);

        emit TransactionExecuted(_txId);
    }

    function cancelTransaction(uint256 _txId) external onlyAdmin {
        Transaction storage txn = transactions[_txId];
        require(txn.status == TxStatus.Queued, "not queued");
        txn.status = TxStatus.Cancelled;
        emit TransactionCancelled(_txId);
    }

    function hasClaimed(address _claimant) external view returns (bool) {
        return claimed[merkleRoot][_claimant];
    }

    function hasClaimedForRoot(address _claimant, bytes32 _root) external view returns (bool) {
        return claimed[_root][_claimant];
    }

    function getOwners() external view returns (address[] memory) {
        return _state.owners;
    }

    function isOwner(address _addr) external view returns (bool) {
        return _state.isOwner[_addr];
    }

    function threshold() external view returns (uint256) {
        return _state.threshold;
    }

    function tokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }
}


