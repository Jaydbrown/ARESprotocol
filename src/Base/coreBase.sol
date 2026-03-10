// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract CoreBase {
    address public admin;
    bytes32 public immutable personalHash;
    mapping(address => bool) public authorizedProposers;

    constructor(address _token) {
        admin = msg.sender;
        personalHash = keccak256(abi.encodePacked(
            keccak256("hashedToken"),
            block.chainid,
            address(this)
        ));
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin is authorized");
        _;
    }

    function authorizeProposer(address _proposer) external onlyAdmin {
        require(_proposer != address(0), "invalid proposer address");
        authorizedProposers[_proposer] = true;
    }
}
