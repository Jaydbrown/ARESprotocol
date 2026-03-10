pragma solidity ^0.8.17;

library MerkleLib {

    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computed = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computed <= proofElement) {
                computed = keccak256(abi.encodePacked(computed, proofElement));
            } else {
                computed = keccak256(abi.encodePacked(proofElement, computed));
            }
        }
        return computed == root;
    }

    function buildLeaf(
        address _claimant,
        uint256 _amount
    ) internal pure returns (bytes32) {
        return keccak256(
            bytes.concat(keccak256(abi.encode(_claimant, _amount)))
        );
    }

    function buildMessageHash(
        address _claimant,
        uint256 _amount,
        bytes32 _root,
        uint256 _nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            _claimant,
            _amount,
            _root,
            _nonce
        ));
    }

    function recoverSigner(
        bytes32 _hash,
        bytes memory _signature
    ) internal pure returns (address) {
        require(_signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := byte(0, mload(add(_signature, 96)))
        }
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "invalid s value"
        );
        require(v == 27 || v == 28, "invalid v value");
        address signer = ecrecover(_hash, v, r, s);
        require(signer != address(0), "invalid signature");
        return signer;
    }

    function toEthSignedHash(bytes32 _hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            _hash
        ));
    }
}