// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

//@dev Tracks summary information for users across all farms
struct FuturesUser {
    bool exists; //has the user joined
    uint deposits; //total inbound deposits
    uint compoundDeposits; //compound deposit; not fresh capital
    uint currentBalance; //current balance
    uint currentApr; //current apr
    uint payouts; //total yield payouts across all farms
    uint rewards; //partner rewards
    uint lastTime; //last interaction
    uint lastDeposit;
}

struct FuturesGlobals {
    uint256 totalUsers;
    uint256 totalDeposited;
    uint256 totalCompoundDeposited;
    uint256 totalClaimed;
    uint256 totalRewards;
    uint256 totalTxs;
    uint256 currentBalance;
}
