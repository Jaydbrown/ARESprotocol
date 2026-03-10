pragma solidity ^0.8.17;

import {Itreasury} from "../../src/Interface/Itreasury.sol";
import {ECDSA} from "../../src/libraries/ECDSA.sol";

contract TimeDelayedExecutionEngine {
    using ECDSA for bytes32;

    Itreasury public treasury;
    bytes32 public immutable personalHash;
    address public admin;
    bool private locked;

    uint256 internal constant DELAY = 2 days;
    uint256 internal constant MIN_DELAY = 1 days;
    uint256 internal constant MAX_DELAY = 30 days;
    uint256 public transactionCount;

    enum Status { Queued, Executed, Cancelled }

    struct Transaction {
        uint256 transactionId;
        address to;
        uint256 amount;
        bytes data;
        uint256 queuedAt;
        uint256 eta;
        Status status;
        bytes32 txHash;
        address token;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(bytes32 => bool) public txHashUsed;

    event TransactionQueued(uint256 indexed transactionId, address indexed to, uint256 amount, uint256 eta);
    event TransactionExecuted(uint256 indexed transactionId);
    event TransactionCancelled(uint256 indexed transactionId);

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin is allowed");
        _;
    }

    modifier noReentrancy() {
        require(!locked, "reentrant call detected");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _treasury) {
        require(_treasury != address(0), "invalid treasury");
        treasury = Itreasury(_treasury);
        admin = msg.sender;
        personalHash = keccak256(abi.encode(
            keccak256("TimeDelayedExecutionEngine_v1"),
            block.chainid,
            address(this)
        ));
    }

    function hashTransaction(
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _eta
    ) public view returns (bytes32) {
        return keccak256(abi.encode(
            personalHash,
            _to,
            _amount,
            _data,
            _eta
        ));
    }

    function queueTransaction(
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _delay,
        address _token
    ) external onlyAdmin returns (uint256) {
        require(_to != address(0), "invalid address");
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "invalid delay");

        uint256 eta = block.timestamp + _delay;
        bytes32 txHash = hashTransaction(_to, _amount, _data, eta);

        require(!txHashUsed[txHash], "transaction already queued");
        txHashUsed[txHash] = true;

        uint256 txId = transactionCount++;

        transactions[txId] = Transaction({
            transactionId: txId,
            to: _to,
            amount: _amount,
            data: _data,
            queuedAt: block.timestamp,
            eta: eta,
            status: Status.Queued,
            txHash: txHash,
            token: _token
        });

        emit TransactionQueued(txId, _to, _amount, eta);
        return txId;
    }

    function executeTransaction(uint256 _txId) external onlyAdmin noReentrancy {
        Transaction storage txn = transactions[_txId];

        require(txn.status == Status.Queued, "not queued");
        require(block.timestamp >= txn.eta, "delay not elapsed");
        require(block.timestamp <= txn.eta + 7 days, "transaction expired");

        txn.status = Status.Executed;

        bytes32 currentHash = hashTransaction(
            txn.to,
            txn.amount,
            txn.data,
            txn.eta
        );
        require(currentHash == txn.txHash, "transaction replaced");

        treasury.transfer(txn.to, txn.amount, txn.token);

        emit TransactionExecuted(_txId);
    }

    function cancelTransaction(uint256 _txId) external onlyAdmin {
        Transaction storage txn = transactions[_txId];
        require(txn.status == Status.Queued, "not queued");
        txn.status = Status.Cancelled;
        emit TransactionCancelled(_txId);
    }
}