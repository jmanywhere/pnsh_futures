// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

interface IFuturesYieldEngine {
    function yield(
        address _user,
        uint256 _amount
    ) external returns (uint256 yieldAmount);

    function estimateCollateralToCore(
        uint256 collateralAmount
    ) external view returns (uint256 wethAmount, uint256 coreAmount);
}