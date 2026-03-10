pragma solidity ^0.8.17;

import {MultiSigLib} from "../../src/libraries/MultiSigLib.sol";
import {MerkleLib} from "../../src/libraries/MerkleLib.sol";
import {Itoken} from "../../src/interface/Itoken.sol";

contract ARES {
    using MultiSigLib for MultiSigLib.State;

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

    modifier onlyViaMultisig() {
        require(msg.sender == address(this), "not via multisig");
        _;
    }

    modifier onlyOwner() {
        require(_state.isOwner[msg.sender], "not an owner");
        _;
    }

    constructor(
        address _rewardToken,
        address[] memory _owners,
        uint256 _threshold
    ) {
        require(_rewardToken != address(0), "invalid token");
        rewardToken = Itoken(_rewardToken);
        _state.initOwners(_owners, _threshold);
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
        require(_state.isReadyToExecute(_txId), "not ready");
        _state.markExecuted(_txId);
        MultiSigLib.Tx storage mtx = _state.txs[_txId];
        (bool success,) = address(this).call{value: mtx.value}(mtx.data);
        require(success, "execution failed");
        emit TxExecuted(_txId);
    }

    function setMerkleRoot(bytes32 _root) external onlyViaMultisig {
        require(_root != bytes32(0), "invalid root");
        require(!usedRoots[_root], "root already used");
        bytes32 oldRoot = merkleRoot;
        usedRoots[_root] = true;
        merkleRoot = _root;
        rootNonce++;
        emit MerkleRootUpdated(oldRoot, _root, rootNonce);
    }

    function claim(
        bytes32[] calldata proof,
        uint256 amount,
        bytes memory signature
    ) external {
        require(merkleRoot != bytes32(0), "no active root");
        require(!claimed[merkleRoot][msg.sender], "already claimed");

        bytes32 messageHash = MerkleLib.buildMessageHash(
            msg.sender,
            amount,
            merkleRoot,
            rootNonce
        );
        bytes32 ethHash = MerkleLib.toEthSignedHash(messageHash);
        require(
            MerkleLib.recoverSigner(ethHash, signature) == msg.sender,
            "invalid signature"
        );

        bytes32 leaf = MerkleLib.buildLeaf(msg.sender, amount);
        require(
            MerkleLib.verify(proof, merkleRoot, leaf),
            "invalid proof"
        );

        claimed[merkleRoot][msg.sender] = true;
        require(rewardToken.transfer(msg.sender, amount), "transfer failed");
        emit Claimed(msg.sender, amount, merkleRoot);
    }

    function hasClaimed(address _claimant) external view returns (bool) {
        return claimed[merkleRoot][_claimant];
    }

    function hasClaimedForRoot(
        address _claimant,
        bytes32 _root
    ) external view returns (bool) {
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
}
