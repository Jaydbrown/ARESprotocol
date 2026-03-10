pragma solidity ^0.8.17;

interface Itreasury {
   function deposit( address _token, uint _amount) external;
    function checkBalance() external;
    function transfer(address token, uint256 amount, address recipient) external;
    function call(address target, bytes calldata data) external;
    function upgrade (address oldcontract, address newContract) external;
}