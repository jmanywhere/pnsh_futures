// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

interface ISponsorData {
    function add(address _user, uint256 _amount) external;

    function settle(address _user) external;
}
