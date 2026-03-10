pragma solidity ^0.8.17;

import {Itoken} from "../../src/Interface/Itoken.sol";
import {IgoverningParticipants} from "../../src/Interface/IgoverningParticipants.sol";
import {ECDSA} from "../../src/libraries/ECDSA.sol";



contract cryptoGraphicAuthorizationLAyer{
    using ECDSA for bytes32;
    bytes32 public immutable personalHash;
    bytes32 public constant PREFIX = keccak256("CryptoGraphicAuth_v1");

    address public admin;

    address[] public contributors;
    Itoken public token;
    IgoverningParticipants public governors;

    mapping(bytes32 => bool) public usedSignatures;
    mapping(address => uint256) public nonces;
    mapping(address => bool) public authorizedProposers;
    
    constructor (address _token, address  _governors) {
        token = Itoken(_token);
        governors = IgoverningParticipants(_governors);
        personalHash = keccak256(abi.encodePacked(
            keccak256("hashedToken"),
            block.chainid,
            address(this)
        ));
        admin = msg.sender;
    }

    modifier onlyAdmin (){
        require(msg.sender == admin, "only admin is authorized to perform this function");
        _;
    }

    function authorizeProposer(address _proposer) external onlyAdmin{
        require(_proposer != address(0), "proposer cannot be from address 0");
        authorizedProposers[_proposer] = true;
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
        uint8  v,
        bytes32 r,
        bytes32 s 
        ) public {
            require(nonces[msg.sender] == _nonce, "nonce is invalid");
            bytes32 sigHash = keccak256(abi.encodePacked(r,s));
            require(!usedSignatures[sigHash], "signature already used");
            bytes32 hash = hashProposal(_proposalId, msg.sender, _nonce);
            address signer = ECDSA.recover(hash,v,r,s);
            require(signer == msg.sender, "invalid signature");
            require(token.balanceOf(msg.sender) >= _amount, "the amount you entered is too little");
            usedSignatures[sigHash] = true;
            nonces[msg.sender]++;
            governors.createProposal(_proposalId);
    }




}