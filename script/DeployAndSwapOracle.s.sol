//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "../src/amm/AmmTwapOracle.sol";
import "../src/AddressRegistry.sol";
import "../src/interfaces/IAmmFactory.sol";
import "../src/FuturesYieldEngine.sol";
import "forge-std/Script.sol";

contract UpdateOracle is Script {
    IAmmFactory public ammFactory =
        IAmmFactory(0x6725F303b657a9451d8BA641348b6761A6CC7a17);

    function run() public {
        AddressRegistry registry = AddressRegistry(
            0xd87dC2e297aa0eCD07a0e442363240D833a86c53
        );
        address fyeAddress = registry.get(
            keccak256(abi.encodePacked("FUTURES_YIELD_ENGINE"))
        );
        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = fyeAddress;
        FuturesYieldEngine fye = FuturesYieldEngine(fyeAddress);
        vm.startBroadcast();

        AmmTwapOracle oracle = new AmmTwapOracle(address(ammFactory), 4 hours);
        oracle.addAddressesToWhitelist(whitelistAddresses);
        fye.updateOracle(oracle);
        vm.stopBroadcast();
    }
}
