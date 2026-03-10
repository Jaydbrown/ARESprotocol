pragma solidity ^0.8.17;

library ECDSA {
    function tryRecover(bytes32 hash, bytes32 r, bytes32 s, uint8 v)
    internal
    pure
    returns (address){
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");
        return signer;
    }

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
    internal
    pure
    returns (address) {
        (address recover) = tryRecover(hash, r, s, v);
        return recover;
    }

    function toEthSignedMessageHash(bytes32 hash)
    internal
    pure
    returns (bytes32){

    return keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
    );
    }

    /* used this signature scheme cause anytime a person signs a token, a corresponding signature is generated -s mod n.
    the attacker can flip this and get the corresponding signature and authorize transactions. So we block the first 32 bytes
    and allow only the last 32 bytes of the transaction to go through */
}