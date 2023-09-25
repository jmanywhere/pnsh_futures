// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "./IAmmTwapOracle.sol";

interface IFuturesYieldEngine {
    function yield(
        address _user,
        uint256 _amount
    ) external returns (uint256 yieldAmount);

    function estimateCollateralToCore(
        uint256 collateralAmount
    ) external view returns (uint256 coreAmount);

    function oracle() external view returns (IAmmTwapOracle);
}
