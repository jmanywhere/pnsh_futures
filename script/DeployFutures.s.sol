// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/amm/AmmTwapOracle.sol";
import "../src/interfaces/IAmmFactory.sol";
import "../src/interfaces/IAmmRouter02.sol";
import "../src/interfaces/IWETH.sol";
import "../src/AddressRegistry.sol";
import "../src/FuturesEngine.sol";
import "../src/FuturesYieldEngine.sol";
import "../src/FuturesVault.sol";
import "../src/Treasury.sol";
import "../src/TreasuryConvertible.sol";
import "../src/Sweeper.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract DeployFutures is Script {
    //TESTNET CONTRACTS
    //Pancakeswap
    IAmmRouter02 public ammRouter =
        IAmmRouter02(0xb920817FdFC97fb1ec8eC90Fc8A282c351d35554);
    IAmmFactory public ammFactory = IAmmFactory(ammRouter.factory());
    //usdt
    IERC20 public usdt =
        IERC20(address(0x55d398326f99059fF775485246999027B3197955));
    //Core token
    IERC20 public nsh = IERC20(0x68102693d38b848B7cf5B5A1d2678F63E299198c);

    IAmmPair public coreLp =
        IAmmPair(ammFactory.getPair(address(usdt), address(nsh)));

    function run() public {
        vm.startBroadcast();
        //DO NOT DEPLOY NEW PNSH/USDT CONTRACT IF ONE IS ALREADY ON THE NETWORK (COMMENT OUT)
        // pnsh = new ERC20PresetMinterPauser("test-pNSH", "tpNSH");
        // usdt = new ERC20PresetMinterPauser("test-USDT", "tUSDT");

        //Pancakeswap dex operations
        AmmTwapOracle oracle = new AmmTwapOracle(address(ammFactory), 4 hours);
        console.log("Oracle address: %s", address(oracle));
        //Create treasuries
        TreasuryConvertible collateralPcrTreasury = new TreasuryConvertible(
            usdt
        );
        console.log(
            "Collateral PCR Treasury address: %s",
            address(collateralPcrTreasury)
        );
        TreasuryConvertible collateralBufferPool = new TreasuryConvertible(
            usdt
        );
        console.log(
            "Collateral Buffer Pool address: %s",
            address(collateralBufferPool)
        );
        TreasuryConvertible collateralTreasury = new TreasuryConvertible(usdt);
        console.log(
            "Collateral Treasury address: %s",
            address(collateralTreasury)
        );
        Treasury coreTreasury = new Treasury(nsh);
        console.log("Core Treasury address: %s", address(coreTreasury));
        Treasury coreLpTreasury = new Treasury(IERC20(address(coreLp)));
        console.log("Core LP Treasury address: %s", address(coreLpTreasury));

        //Core contracts
        AddressRegistry registry = new AddressRegistry();
        console.log("Registry address: %s", address(registry));
        FuturesVault futuresVault = new FuturesVault();
        console.log("Futures Vault address: %s", address(futuresVault));
        Sweeper sweeper = new Sweeper(registry);
        console.log("Sweeper address: %s", address(sweeper));
        FuturesYieldEngine futuresYieldEngine = new FuturesYieldEngine(
            registry
        );
        console.log(
            "Futures Yield Engine address: %s",
            address(futuresYieldEngine)
        );
        FuturesEngine futuresEngine = new FuturesEngine(registry);
        console.log("Futures Engine address: %s", address(futuresEngine));

        //Add contracts to registry, where they can be access by the entire ecosystem from one place
        bytes32[] memory registryKeys = new bytes32[](14);
        registryKeys[0] = keccak256(abi.encodePacked("FUTURES_VAULT"));
        registryKeys[1] = keccak256(abi.encodePacked("FUTURES_YIELD_ENGINE"));
        registryKeys[2] = keccak256(abi.encodePacked("COLLATERAL_TOKEN"));
        registryKeys[3] = keccak256(abi.encodePacked("COLLATERAL_TREASURY"));
        registryKeys[4] = keccak256(abi.encodePacked("COLLATERAL_BUFFERPOOL"));
        registryKeys[5] = keccak256(
            abi.encodePacked("COLLATERAL_PCR_TREASURY")
        );
        registryKeys[6] = keccak256(abi.encodePacked("AMM_ROUTER"));
        registryKeys[7] = keccak256(abi.encodePacked("CORE_TOKEN"));
        registryKeys[8] = keccak256(abi.encodePacked("CORE_TREASURY"));
        registryKeys[9] = keccak256(abi.encodePacked("CORE_LP_TREASURY"));
        registryKeys[10] = keccak256(abi.encodePacked("SWEEPER"));
        registryKeys[11] = keccak256(abi.encodePacked("FUTURES_ENGINE"));
        registryKeys[12] = keccak256(abi.encodePacked("CORE_LP_ORACLE"));
        registryKeys[13] = keccak256(abi.encodePacked("CORE_LP_TOKEN"));
        address[] memory registryVals = new address[](14);
        registryVals[0] = address(futuresVault);
        registryVals[1] = address(futuresYieldEngine);
        registryVals[2] = address(usdt);
        registryVals[3] = address(collateralTreasury);
        registryVals[4] = address(collateralBufferPool);
        registryVals[5] = address(collateralPcrTreasury);
        registryVals[6] = address(ammRouter);
        registryVals[7] = address(nsh);
        registryVals[8] = address(coreTreasury);
        registryVals[9] = address(coreLpTreasury);
        registryVals[10] = address(sweeper);
        registryVals[11] = address(futuresEngine);
        registryVals[12] = address(oracle);
        registryVals[13] = address(coreLp);
        registry.setMulti(registryKeys, registryVals);

        //Set whitelistings

        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = address(sweeper);
        collateralTreasury.addAddressesToWhitelist(whitelistAddresses);

        whitelistAddresses[0] = address(futuresYieldEngine);
        collateralBufferPool.addAddressesToWhitelist(whitelistAddresses);

        whitelistAddresses[0] = address(futuresYieldEngine);
        coreTreasury.addAddressesToWhitelist(whitelistAddresses);

        whitelistAddresses[0] = address(futuresEngine);
        futuresVault.addAddressesToWhitelist(whitelistAddresses);

        whitelistAddresses[0] = address(futuresEngine);
        futuresYieldEngine.addAddressesToWhitelist(whitelistAddresses);
        //IMPORTANT: These methods need to be called some time after post deployment and the core LP has been added.
        //This sets up the oracle for the purchase and liquidation of the core tokens.
        //NOTE: After the script has run, the sender can mint the test core/collateral tokens to create the LP if those have not been replaced with the actual tokens in the script
        {
            updateOracleInfo(oracle, futuresYieldEngine);
        }
        ////--------------------------------
        vm.stopBroadcast();
    }

    function updateOracleInfo(
        AmmTwapOracle oracle,
        FuturesYieldEngine fye
    ) private {
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(nsh);
        fye.setPathCollateralToCore(path);

        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = address(fye);
        oracle.addAddressesToWhitelist(whitelistAddresses);
        fye.updateOracle(oracle);
    }
}
