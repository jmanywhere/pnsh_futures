//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "../src/AddressRegistry.sol";

contract TestWhitelist is Test {
    AddressRegistry public registry;

    address[] public users;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        vm.prank(users[0]);
        registry = new AddressRegistry();
    }

    function test_constructorGrantRoles() public {
        assertEq(
            futuresVault.owner(),users[0]
        );
    }

    function test_setMulti() public {
        string[] memory keys = new string[](3);
        keys[0] = "KEY_0";
        keys[1] = "KEY_1";
        keys[2] = "KEY_2";
        address[] memory vals = new address[](3);
        address[0] = makeAddr("ADDR_0");
        address[1] = makeAddr("ADDR_1");
        address[2] = makeAddr("ADDR_2");

        vm.expectRevert();
        registry.setMulti(keys,vals);

        vm.prank(user[0]);
        registry.setMulti(keys,vals);

        bytes32[] allKeys = registry.getKeysWithHighGasCost();
        bytes32 key2 = registry.at(2);
        address val2 = registry.get(2);

        assertEq(allKeys[0],keys[0]);
        assertEq(allKeys[1],keys[1]);
        assertEq(allKeys[2],keys[2]);

    }
}
