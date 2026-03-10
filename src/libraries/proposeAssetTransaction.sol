pragma solidity ^0.8.17;



library proposeAssetTransaction {

    uint256 internal constant DELAY = 2 days;

    function transfer(address _token, uint256 _amount, address _recipient) internal {
        require ( _amount > 0, "please enter a better amount");
        require (_recipient != address(0), "invalid recipient address");
    }

    function call(address _target, bytes calldata _path) internal {
        require(_target != address(0), "invalid target address");
    }

    function upgrade(address _oldContract, address _newContract) internal {
        require(_newContract != address(0), "invalid new contract address");
        require(_oldContract != address(0), "invalid old contract address");
        require(_oldContract != _newContract, "old contract cannot be equal to the newContract");
    }
}