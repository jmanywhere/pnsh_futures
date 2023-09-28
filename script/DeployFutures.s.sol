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
    IAmmFactory public ammFactory =
        IAmmFactory(0x6725F303b657a9451d8BA641348b6761A6CC7a17);
    IAmmRouter02 public ammRouter =
        IAmmRouter02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
    //Collateral (https://testnet.bnbchain.org/faucet-smart)
    IERC20 public usdt = IERC20(0x337610d27c682E347C9cD60BD4b3b107C9d34dDd);
    //Core token
    IERC20 public pnsh = IERC20(address(0x0));

    /*
    //MAINNET CONTRACTS
    IAmmFactory ammFactory = IAmmFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    IAmmRouter02 ammRouter = IAmmRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    //Collateral 
    IERC20 usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    //Core token
    IERC20 pnsh = IERC20(0x0);
    */

    function run() public {
        vm.startBroadcast();

        //DO NOT DEPLOY NEW PNSH/USDT CONTRACT IF ONE IS ALREADY ON THE NETWORK (COMMENT OUT)
        pnsh = new ERC20PresetMinterPauser("test-pNSH", "tpNSH");
        usdt = new ERC20PresetMinterPauser("test-USDT", "tUSDT");

        //Pancakeswap dex operations
        IAmmPair coreLp = IAmmPair(
            ammFactory.createPair(address(usdt), address(pnsh))
        );
        AmmTwapOracle oracle = new AmmTwapOracle(address(ammFactory), 4 hours);

        //Create treasuries
        TreasuryConvertible collateralPcrTreasury = new TreasuryConvertible(
            usdt
        );
        TreasuryConvertible collateralBufferPool = new TreasuryConvertible(
            usdt
        );
        TreasuryConvertible collateralTreasury = new TreasuryConvertible(usdt);
        Treasury coreTreasury = new Treasury(pnsh);
        Treasury coreLpTreasury = new Treasury(pnsh);

        //Core contracts
        AddressRegistry registry = new AddressRegistry();
        FuturesVault futuresVault = new FuturesVault();
        Sweeper sweeper = new Sweeper(registry);
        FuturesYieldEngine futuresYieldEngine = new FuturesYieldEngine(
            registry
        );
        FuturesEngine futuresEngine = new FuturesEngine(registry);

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
        registryVals[7] = address(pnsh);
        registryVals[8] = address(coreTreasury);
        registryVals[9] = address(coreLpTreasury);
        registryVals[10] = address(sweeper);
        registryVals[11] = address(futuresEngine);
        registryVals[12] = address(oracle);
        registryVals[13] = address(coreLp);
        registry.setMulti(registryKeys, registryVals);

        //Set whitelistings

        address[] memory toWhitelistOnCollateralTreasury = new address[](1);
        toWhitelistOnCollateralTreasury[0] = address(sweeper);
        collateralTreasury.addAddressesToWhitelist(
            toWhitelistOnCollateralTreasury
        );

        address[] memory toWhitelistOnBufferPool = new address[](1);
        toWhitelistOnBufferPool[0] = address(futuresYieldEngine);
        collateralBufferPool.addAddressesToWhitelist(toWhitelistOnBufferPool);

        address[] memory toWhitelistOnCoreTreasury = new address[](1);
        toWhitelistOnCoreTreasury[0] = address(futuresYieldEngine);
        coreTreasury.addAddressesToWhitelist(toWhitelistOnCoreTreasury);

        address[] memory toWhitelistOnFuturesVault = new address[](1);
        toWhitelistOnFuturesVault[0] = address(futuresEngine);
        futuresVault.addAddressesToWhitelist(toWhitelistOnFuturesVault);

        address[] memory toWhitelistOnFuturesYieldEngine = new address[](1);
        toWhitelistOnFuturesYieldEngine[0] = address(futuresEngine);
        futuresYieldEngine.addAddressesToWhitelist(
            toWhitelistOnFuturesYieldEngine
        );

        vm.stopBroadcast();

        //IMPORTANT: These methods need to be called some time after post deployment and the core LP has been added.
        //This sets up the oracle for the purchase and liquidation of the core tokens.
        //NOTE: After the script has run, the sender can mint the test core/collateral tokens to create the LP if those have not been replaced with the actual tokens in the script
        /*

        futuresYieldEngine.setPathCollateralToCore(path);
        futuresYieldEngine.updateOracle(oracle);

        */
    }
}
