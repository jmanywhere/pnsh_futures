// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";

import {AmmTwapOracle} from "../src/amm/AmmTwapOracle.sol";
import {AddressRegistry} from "../src/AddressRegistry.sol";
import {IAmmFactory} from "../src/interfaces/IAmmFactory.sol";
import {IAmmRouter02} from "../src/interfaces/IAmmRouter02.sol";
import {FuturesYieldEngine} from "../src/FuturesYieldEngine.sol";
import {Treasury} from "../src/Treasury.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

contract FixStuff is Script {
    IAmmRouter02 router =
        IAmmRouter02(0xb920817FdFC97fb1ec8eC90Fc8A282c351d35554);
    IAmmFactory factory = IAmmFactory(router.factory());
    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address NSH = 0x68102693d38b848B7cf5B5A1d2678F63E299198c;

    function run() public {
        address pair = factory.getPair(USDT, NSH);
        bytes32[] memory registryEditKeys = new bytes32[](1);
        address[] memory registryEditValues = new address[](1);
        registryEditKeys[0] = keccak256(abi.encodePacked("CORE_LP_TREASURY"));
        AddressRegistry registry = AddressRegistry(
            0xF8Ed98ff26df5aD9F71f6CA98B5010f0f29eee6F
        );
        vm.startBroadcast();
        Treasury lpTreasury = new Treasury(IERC20(pair));
        registryEditValues[0] = address(lpTreasury);
        registry.setMulti(registryEditKeys, registryEditValues);

        AmmTwapOracle oracle = AmmTwapOracle(
            0xba0e85a8E06c2d3f3bb2f2b307deBA9DBcd5F873
        );
        FuturesYieldEngine fye = FuturesYieldEngine(
            0xC7231f6b7aA37c14A953CB5a0aAd7a654b527d13
        );
        registryEditValues[0] = address(fye);
        oracle.addAddressesToWhitelist(registryEditValues);
        fye.updateOracle(oracle);
        vm.stopBroadcast();
    }
}
