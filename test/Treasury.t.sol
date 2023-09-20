//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/Treasury.sol";

contract TestWhitelist is Test {
    Treasury public treasury;
    ERC20PresetFixedSupply public token;

    address[] public users;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        token = new ERC20PresetFixedSupply(
            "token",
            "tkn",
            1_000 ether,
            address(users[0])
        );

        vm.prank(users[0]);
        treasury = new Treasury(token);
    }

    function test_constructorGrantRoles() public {
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), users[0]));
        assertFalse(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), users[1]));
    }

    function test_testWithdraw() public {
        vm.prank(users[0]);
        token.transfer(address(treasury), 1_000 ether);

        vm.prank(users[1]);
        vm.expectRevert();
        treasury.withdraw(1_000 ether);

        vm.prank(users[0]);
        vm.expectRevert();
        treasury.withdraw(1_000 ether);

        vm.startPrank(users[0]);
        console.log(users[0]);
        treasury.grantRole(treasury.WHITELIST_ROLE(), users[2]);
        vm.stopPrank();

        vm.prank(users[0]);
        vm.expectRevert();
        treasury.withdraw(1_000 ether);

        vm.prank(users[2]);
        treasury.withdraw(1_000 ether);

        assertEq(token.balanceOf(users[2]), 1_000 ether);
    }
}
