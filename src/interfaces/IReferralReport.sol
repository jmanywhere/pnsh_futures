// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

//@dev Callback function called by FarmEngine.yield upon completion
interface IReferralReport {
    function rewardDistribution(
        address _referrer,
        address _user,
        uint _referrerReward,
        uint _userReward
    ) external;
}
