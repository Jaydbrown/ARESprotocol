pragma solidity ^0.8.17;

library MultiSigLib {

    struct State {
        address[] owners;
        mapping(address => bool) isOwner;
        uint256 threshold;
        uint256 txCount;
        mapping(uint256 => Tx) txs;
        mapping(uint256 => mapping(address => bool)) hasConfirmed;
    }

    struct Tx {
        address target;
        bytes data;
        uint256 value;
        uint256 confirmations;
        bool executed;
    }

    function initOwners(
        State storage self,
        address[] memory _owners,
        uint256 _threshold
    ) internal {
        require(_owners.length > 0, "no owners");
        require(_threshold > 0 && _threshold <= _owners.length, "invalid threshold");
        for (uint256 i = 0; i < _owners.length; i++) {
            address o = _owners[i];
            require(o != address(0), "zero address owner");
            require(!self.isOwner[o], "duplicate owner");
            self.isOwner[o] = true;
            self.owners.push(o);
        }
        self.threshold = _threshold;
    }

    function submitTx(
        State storage self,
        address _target,
        bytes memory _data,
        uint256 _value
    ) internal returns (uint256) {
        uint256 txId = self.txCount++;
        self.txs[txId] = Tx({
            target: _target,
            data: _data,
            value: _value,
            confirmations: 0,
            executed: false
        });
        return txId;
    }

    function confirmTx(
        State storage self,
        uint256 _txId,
        address _owner
    ) internal {
        require(!self.txs[_txId].executed, "already executed");
        require(!self.hasConfirmed[_txId][_owner], "already confirmed");
        self.hasConfirmed[_txId][_owner] = true;
        self.txs[_txId].confirmations++;
    }

    function isReadyToExecute(
        State storage self,
        uint256 _txId
    ) internal view returns (bool) {
        return
            !self.txs[_txId].executed &&
            self.txs[_txId].confirmations >= self.threshold;
    }

    function markExecuted(State storage self, uint256 _txId) internal {
        self.txs[_txId].executed = true;
    }
}