// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "./Whitelist.sol";
import "./structs/StructsFutures.sol";

//@dev Immutable Vault that stores ledger for Futures
contract FuturesVault is Whitelist {
    mapping(address => FuturesUser) private _users; //Asset -> User

    FuturesGlobals private _globals;

    constructor() Whitelist(msg.sender) {}

    //@dev Get User info
    function getUser(address _user) external view returns (FuturesUser memory) {
        return _users[_user];
    }

    //@dev Get FuturesGlobal info
    function getGlobals() external view returns (FuturesGlobals memory) {
        return _globals;
    }

    //@dev commit User Info
    function commitUser(
        address user,
        FuturesUser memory userData
    ) external onlyWhitelisted {
        //update user
        _users[user].exists = userData.exists;
        _users[user].deposits = userData.deposits;
        _users[user].compoundDeposits = userData.compoundDeposits;
        _users[user].currentBalance = userData.currentBalance;
        _users[user].currentApr = userData.currentApr;
        _users[user].payouts = userData.payouts;
        _users[user].rewards = userData.rewards;
        _users[user].lastTime = userData.lastTime;
    }

    //@dev commit Globals Info
    function commitGlobals(
        FuturesGlobals memory globals
    ) external onlyWhitelisted {
        //update globals
        _globals.totalUsers = globals.totalUsers;
        _globals.totalDeposited = globals.totalDeposited;
        _globals.totalCompoundDeposited = globals.totalCompoundDeposited;
        _globals.totalClaimed = globals.totalClaimed;
        _globals.totalRewards = globals.totalRewards;
        _globals.totalTxs = globals.totalTxs;
        _globals.currentBalance = globals.currentBalance;
        _users[user].currentApr = userData.currentApr;
    }
}
