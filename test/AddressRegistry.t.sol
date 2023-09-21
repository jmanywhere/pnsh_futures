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
        assertEq(registry.owner(), users[0]);
    }

    function test_setMulti() public {
        string[] memory keys = new string[](3);
        keys[0] = "KEY_0";
        keys[1] = "KEY_1";
        keys[2] = "KEY_2";
        address[] memory vals = new address[](3);
        vals[0] = makeAddr("ADDR_0");
        vals[1] = makeAddr("ADDR_1");
        vals[2] = makeAddr("ADDR_2");

        vm.expectRevert();
        registry.setMulti(keys, vals);

        vm.prank(users[0]);
        registry.setMulti(keys, vals);

        bytes32[] memory allKeys = registry.getKeysWithHighGasCost();
        (uint256 key1, address val1) = registry.at(1);

        assertEq(
            uint256(allKeys[0]),
            uint256(keccak256(abi.encodePacked(keys[0])))
        );
        assertEq(
            uint256(allKeys[1]),
            uint256(keccak256(abi.encodePacked(keys[1])))
        );
        assertEq(
            uint256(allKeys[2]),
            uint256(keccak256(abi.encodePacked(keys[2])))
        );
        assertEq(key1, uint256(keccak256(abi.encodePacked(keys[1]))));
        assertEq(val1, vals[1]);
    }
}
