//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/Whitelist.sol";

contract TestWhitelist is Test {
    Whitelist public whitelist;
    ERC20PresetFixedSupply public token;

    address[] public users;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        whitelist = new Whitelist(users[0]);

        token = new ERC20PresetFixedSupply(
            "token",
            "tkn",
            1_000 ether,
            address(whitelist)
        );
    }

    function test_constructorGrantRoles() public {
        assertTrue(whitelist.hasRole(whitelist.DEFAULT_ADMIN_ROLE(), users[0]));
        assertFalse(
            whitelist.hasRole(whitelist.DEFAULT_ADMIN_ROLE(), users[1])
        );
    }

    function test_setAddressesToWhitelist() public {
        address[] memory usersToWhitelist = new address[](2);
        usersToWhitelist[0] = users[1];
        usersToWhitelist[1] = users[2];
        vm.prank(users[0]);
        whitelist.addAddressesToWhitelist(usersToWhitelist);
        vm.prank(users[1]);
        vm.expectRevert();
        whitelist.addAddressesToWhitelist(usersToWhitelist);

        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[0]));
        assertTrue(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[1]));
        assertTrue(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[2]));
        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[3]));

        vm.prank(users[1]);
        vm.expectRevert();
        whitelist.removeAddressesFromWhitelist(usersToWhitelist);
        vm.prank(users[0]);
        whitelist.removeAddressesFromWhitelist(usersToWhitelist);

        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[0]));
        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[1]));
        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[2]));
        assertFalse(whitelist.hasRole(whitelist.WHITELIST_ROLE(), users[3]));
    }

    function test_recoverERC20() public {
        vm.prank(users[1]);
        vm.expectRevert();
        whitelist.recoverERC20(address(token));

        vm.prank(users[0]);
        whitelist.recoverERC20(address(token));

        assertEq(token.balanceOf(address(whitelist)), 0);
        assertEq(token.balanceOf(address(users[0])), 1_000 ether);
    }
}
