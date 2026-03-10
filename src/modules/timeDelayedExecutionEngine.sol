pragma solidity ^0.8.17;
import {Itreasury} from "../../src/Interface/Itreasury.sol";
import {ECDSA} from "../../src/libraries/ECDSA.sol";

contract timeDelayedExecutionEngine {
    using ECDSA for bytes32;
    Itreasury public treasury;
    bytes32 public immutable personalHash;
    uint256 public commitTime;
    uint256 internal constant DELAY = 2 days;
    uint256 transactionId;
    

    uint256[] public transaction;
    struct Transaction{
        uint256 TransactionId;
        string data;
    }

    constructor(uint256 _proposalId) {
        personalHash = keccak256(abi.encodePacked(
            _proposalId
        ));
    }

    function hashProposal(
        uint256 transactionlId,
        address proposer,
        uint256 nonce
    ) public view returns (bytes32) {
        return keccak256(abi.encode(
            personalHash,
            transactionId,
            proposer,
            nonce
        ));
    }

    function transfer(uint256 _tokens, address _to) public {

    }

}