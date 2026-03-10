pragma solidity ^0.8.17;

contract MockTreasury {
    event Transferred(address indexed to, uint256 amount, address indexed token);

    function transfer(address to, uint256 amount, address token) external {
        emit Transferred(to, amount, token);
    }
}
