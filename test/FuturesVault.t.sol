//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/FuturesVault.sol";
import "../src/structs/StructsFutures.sol";

contract TestFuturesVault is Test {
    FuturesVault public futuresVault;

    address[] public users;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        vm.prank(users[0]);
        futuresVault = new FuturesVault();
    }

    function test_constructorGrantRoles() public {
        assertTrue(
            futuresVault.hasRole(futuresVault.DEFAULT_ADMIN_ROLE(), users[0])
        );
        assertFalse(
            futuresVault.hasRole(futuresVault.DEFAULT_ADMIN_ROLE(), users[1])
        );
    }

    function test_commitUser() public {
        FuturesUser memory testUserData = FuturesUser(
            true, //bool exists; //has the user joined
            1, //uint deposits; //total inbound deposits
            2, //uint compoundDeposits; //compound deposit; not fresh capital
            3, //uint currentBalance; //current balance
            4, //uint currentApr; //current apr
            5, //uint payouts; //total yield payouts across all farms
            6, //uint rewards; //partner rewards
            7 //uint lastTime; //last interaction
        );

        vm.prank(users[1]);
        vm.expectRevert();
        futuresVault.commitUser(users[3], testUserData);

        vm.startPrank(users[0]);
        futuresVault.grantRole(futuresVault.WHITELIST_ROLE(), users[0]);
        futuresVault.commitUser(users[3], testUserData);
        vm.stopPrank();

        FuturesUser memory resultUserData = futuresVault.getUser(users[3]);

        assertEq(resultUserData.exists, testUserData.exists);
        assertEq(resultUserData.deposits, testUserData.deposits);
        assertEq(
            resultUserData.compoundDeposits,
            testUserData.compoundDeposits
        );
        assertEq(resultUserData.currentBalance, testUserData.currentBalance);
        assertEq(resultUserData.currentApr, testUserData.currentApr);
        assertEq(resultUserData.payouts, testUserData.payouts);
        assertEq(resultUserData.rewards, testUserData.rewards);
        assertEq(resultUserData.lastTime, testUserData.lastTime);
    }

    function test_commitGlobals() public {
        FuturesGlobals memory testUserData = FuturesGlobals(
            1, //uint256 totalUsers;
            2, //uint256 totalDeposited;
            4, //uint256 totalCompoundDeposited;
            5, //uint256 totalClaimed;
            6, //uint256 totalRewards;
            7, //uint256 totalTxs;
            8 //uint256 currentBalance;
        );

        vm.prank(users[1]);
        vm.expectRevert();
        futuresVault.commitGlobals(testUserData);

        vm.startPrank(users[0]);
        futuresVault.grantRole(futuresVault.WHITELIST_ROLE(), users[0]);
        futuresVault.commitGlobals(testUserData);
        vm.stopPrank();

        FuturesGlobals memory resultUserData = futuresVault.getGlobals();

        assertEq(resultUserData.totalUsers, testUserData.totalUsers);
        assertEq(resultUserData.totalDeposited, testUserData.totalDeposited);
        assertEq(
            resultUserData.totalCompoundDeposited,
            testUserData.totalCompoundDeposited
        );
        assertEq(resultUserData.totalClaimed, testUserData.totalClaimed);
        assertEq(resultUserData.totalRewards, testUserData.totalRewards);
        assertEq(resultUserData.totalTxs, testUserData.totalTxs);
        assertEq(resultUserData.currentBalance, testUserData.currentBalance);
    }
}
