// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

interface IFuturesTreasury {
    function withdraw(uint256 tokenAmount) external;

    function withdrawTo(address _to, uint256 _amount) external;
}