pragma solidity ^0.8.17;

interface IliquidityProviders {
   function addLiquidity(
    address from,
    address to,
    uint256 maximumAmount
   ) external; //liquidity providers can provide liquidity to the protocol

   function removeLiquidity(
    address to,
    uint256 amount
   ) external; //liqiuidity can remove their provided liquidity from the protocl when they feel like

   function getTotalLiquidity() external view returns (uint256 amount); //liquidity providers can check the liquidity they have provided this far
   function verifyLiquidityProvider(uint256 id) external; //to become a liquidity provider you must recieve verification by providing and Id.
}