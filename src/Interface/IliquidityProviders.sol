pragma solidity ^0.8.17;

interface IliquidityProviders {
   function addLiquidity(
    address from,
    address to,
    uint256 maximumAmount
   ) external;

   function removeLiquidity(
    address to,
    uint256 amount
   ) external;

   function getTotalLiquidity() external view returns (uint256 amount);
   function verifyLiquidityProvider(uint256 id) external;
}