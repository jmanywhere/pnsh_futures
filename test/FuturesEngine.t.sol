//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/amm/AmmTwapOracle.sol";
import "../src/amm/AmmFactory.sol";
import "../src/AddressRegistry.sol";
import "../src/amm/AmmRouter02.sol";
import "../src/amm/lib/WETH.sol";
import "../src/FuturesEngine.sol";
import "../src/FuturesYieldEngine.sol";
import "../src/FuturesVault.sol";
import "../src/Treasury.sol";
import "../src/TreasuryConvertible.sol";
import "../src/Sweeper.sol";

contract TestFuturesEngine is Test {
    FuturesEngine public futuresEngine;
    FuturesYieldEngine public futuresYieldEngine;

    FuturesVault public futuresVault;
    TreasuryConvertible public collateralPcrTreasury;
    TreasuryConvertible public collateralBufferPool;
    TreasuryConvertible public collateralTreasury;
    Treasury public coreTreasury;
    Treasury public coreLpTreasury;
    Sweeper public sweeper;

    WETH public weth;
    AmmFactory public ammFactory;
    AmmRouter public ammRouter;
    IAmmPair public coreLp;

    AddressRegistry public registry;

    ERC20PresetFixedSupply public collateralToken;
    ERC20PresetFixedSupply public coreToken;

    address[] public users;

    function setUp() public {
        users.push(makeAddr("user0"));
        users.push(makeAddr("user1"));
        users.push(makeAddr("user2"));
        users.push(makeAddr("user3"));

        weth = new WETH();
        ammFactory = new AmmFactory(address(this));
        ammRouter = new AmmRouter(address(ammFactory), address(weth));

        vm.deal(users[0], 100 ether);

        vm.startPrank(users[0]);

        collateralToken = new ERC20PresetFixedSupply(
            "collateralToken",
            "collat",
            1_000_000_000 ether,
            address(users[0])
        );
        coreToken = new ERC20PresetFixedSupply(
            "coreToken",
            "core",
            1_000_000_000 ether,
            address(users[0])
        );
        collateralPcrTreasury = new TreasuryConvertible(collateralToken);
        collateralBufferPool = new TreasuryConvertible(collateralToken);
        collateralTreasury = new TreasuryConvertible(collateralToken);
        coreTreasury = new Treasury(coreToken);

        coreLp = IAmmPair(
            ammFactory.createPair(address(collateralToken), address(coreToken))
        );
        coreLpTreasury = new Treasury(coreToken);

        registry = new AddressRegistry();

        futuresVault = new FuturesVault();
        sweeper = new Sweeper(registry);
        futuresYieldEngine = new FuturesYieldEngine(registry);
        futuresEngine = new FuturesEngine(registry);

        bytes32[] memory registryKeys = new bytes32[](10);
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
        address[] memory registryVals = new address[](10);
        registryVals[0] = address(futuresVault);
        registryVals[1] = address(futuresYieldEngine);
        registryVals[2] = address(collateralToken);
        registryVals[3] = address(collateralTreasury);
        registryVals[4] = address(collateralBufferPool);
        registryVals[5] = address(collateralPcrTreasury);
        registryVals[6] = address(ammRouter);
        registryVals[7] = address(coreToken);
        registryVals[8] = address(coreTreasury);
        registryVals[9] = address(coreLpTreasury);
        registry.setMulti(registryKeys, registryVals);

        AmmTwapOracle oracle = new AmmTwapOracle(address(ammFactory), 4 hours);
        address[] memory toWhitelistOnOracle = new address[](1);
        toWhitelistOnOracle[0] = address(futuresYieldEngine);
        oracle.addAddressesToWhitelist(toWhitelistOnOracle);

        coreToken.approve(address(ammRouter), type(uint256).max);
        collateralToken.approve(address(ammRouter), type(uint256).max);
        ammRouter.addLiquidity(
            address(coreToken),
            address(collateralToken),
            100 ether,
            100 ether,
            0,
            0,
            address(this),
            block.timestamp
        );

        address[] memory path = new address[](2);
        path[0] = address(collateralToken);
        path[1] = address(coreToken);

        //Otherwise the oracle update will revert when getting the price0CumulativeLast
        vm.warp(block.timestamp + 1 hours);

        futuresYieldEngine.setPathCollateralToCore(path);
        futuresYieldEngine.updateOracle(oracle);

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

        vm.stopPrank();
    }

    function test_constructorSetup() public {
        assertEq(users[0], futuresEngine.owner());

        assertEq(
            address(futuresVault),
            address(futuresEngine.registryFuturesVault())
        );
        assertEq(
            address(collateralToken),
            address(futuresEngine.registryCollateralToken())
        );
        assertEq(
            address(futuresYieldEngine),
            address(futuresEngine.registryFuturesYieldEngine())
        );
        assertEq(
            address(collateralToken),
            address(futuresEngine.registryCollateralToken())
        );
        assertEq(
            address(collateralTreasury),
            address(futuresEngine.registryCollateralTreasury())
        );
        assertEq(
            address(collateralBufferPool),
            address(futuresEngine.registryCollateralBufferPool())
        );
        assertEq(
            address(collateralPcrTreasury),
            address(futuresEngine.registryCollateralPcrTreasury())
        );
    }

    function test_minDeposit() public {
        vm.prank(users[0]);
        collateralToken.transfer(users[1], 2_000_000 ether);

        vm.startPrank(users[1]);
        collateralToken.approve(address(futuresEngine), type(uint256).max);
        vm.expectRevert(bytes("amount less than minimum deposit"));
        futuresEngine.deposit(25 ether - 1);
        vm.expectRevert(bytes("max balance exceeded"));
        futuresEngine.deposit(1_000_000 ether + 1);

        futuresEngine.deposit(25 ether);
        vm.stopPrank();

        (uint256 limiterRate, uint256 adjustedAmount) = futuresEngine.available(
            users[1]
        );
        FuturesUser memory user = futuresEngine.getUser(users[1]);
        FuturesGlobals memory info = futuresEngine.getInfo();

        assertEq(limiterRate, 0);
        assertEq(adjustedAmount, 0);

        assertTrue(user.exists);
        assertEq(user.deposits, 25 ether);
        assertEq(user.compoundDeposits, 0);
        assertEq(user.currentBalance, 25 ether);
        assertEq(user.currentApr, 182.5e18 / 8); //1 tick
        assertEq(user.payouts, 0);
        assertEq(user.rewards, 0);
        assertEq(user.lastTime, block.timestamp);

        assertEq(info.totalUsers, 1);
        assertEq(info.totalDeposited, 25 ether);
        assertEq(info.totalCompoundDeposited, 0);
        assertEq(info.totalClaimed, 0);
        assertEq(info.totalRewards, 0);
        assertEq(info.totalTxs, 1);
        assertEq(info.currentBalance, 25 ether);
    }

    function test_maxAprDeposit() public {
        test_minDeposit();

        vm.prank(users[1]);
        futuresEngine.deposit(200 ether);

        (uint256 limiterRate, uint256 adjustedAmount) = futuresEngine.available(
            users[1]
        );
        FuturesUser memory user = futuresEngine.getUser(users[1]);
        FuturesGlobals memory info = futuresEngine.getInfo();

        assertEq(limiterRate, 0);
        assertEq(adjustedAmount, 0);

        assertTrue(user.exists);
        assertEq(user.deposits, 225 ether);
        assertEq(user.compoundDeposits, 0);
        assertEq(user.currentBalance, 225 ether);
        assertEq(user.currentApr, 182.5e18); //8 tick
        assertEq(user.payouts, 0);
        assertEq(user.rewards, 0);
        assertEq(user.lastTime, block.timestamp);

        assertEq(info.totalUsers, 1);
        assertEq(info.totalDeposited, 225 ether);
        assertEq(info.totalCompoundDeposited, 0);
        assertEq(info.totalClaimed, 0);
        assertEq(info.totalRewards, 0);
        assertEq(info.totalTxs, 2);
        assertEq(info.currentBalance, 225 ether);
    }

    function test_halfAprDeposit() public {
        test_maxAprDeposit();

        vm.prank(users[1]);
        futuresEngine.deposit(100 ether);

        (uint256 limiterRate, uint256 adjustedAmount) = futuresEngine.available(
            users[1]
        );
        FuturesUser memory user = futuresEngine.getUser(users[1]);
        FuturesGlobals memory info = futuresEngine.getInfo();

        assertEq(limiterRate, 0);
        assertEq(adjustedAmount, 0);

        assertTrue(user.exists);
        assertEq(user.deposits, 325 ether);
        assertEq(user.compoundDeposits, 0);
        assertEq(user.currentBalance, 325 ether);
        assertEq(user.currentApr, 182.5e18 / 2); //4 tick
        assertEq(user.payouts, 0);
        assertEq(user.rewards, 0);
        assertEq(user.lastTime, block.timestamp);

        assertEq(info.totalUsers, 1);
        assertEq(info.totalDeposited, 325 ether);
        assertEq(info.totalCompoundDeposited, 0);
        assertEq(info.totalClaimed, 0);
        assertEq(info.totalRewards, 0);
        assertEq(info.totalTxs, 3);
        assertEq(info.currentBalance, 325 ether);
    }

    function test_1DayClaim() public {
        test_halfAprDeposit();

        address[] memory collateralToCorePath = new address[](2);
        collateralToCorePath[0] = address(collateralToken);
        collateralToCorePath[1] = address(coreToken);
        vm.prank(users[0]);
        sweeper.sweep(collateralToCorePath);

        vm.warp(block.timestamp + 24 hours);
        uint256 userInitialBal = collateralToken.balanceOf(users[1]);
        (, uint256 initialAvailable) = futuresEngine.available(users[1]);

        vm.prank(users[1]);
        futuresEngine.claim();

        uint256 userFinalBal = collateralToken.balanceOf(users[1]);
        (, uint256 finalAvailable) = futuresEngine.available(users[1]);

        FuturesUser memory user = futuresEngine.getUser(users[1]);
        FuturesGlobals memory info = futuresEngine.getInfo();

        assertEq(initialAvailable, userFinalBal - userInitialBal);
        assertEq(finalAvailable, 0);
        uint256 expectedVal = (24 hours) *
            ((325 ether * (182.5e18 / 2)) / (365 * 100e18) / 24 hours);
        assertLe(initialAvailable, expectedVal);
        assertGe(initialAvailable, expectedVal - 100_000);
        assertEq(initialAvailable, 0.812499999999984 ether);

        assertTrue(user.exists);
        assertEq(user.deposits, 325 ether);
        assertEq(user.compoundDeposits, 0);
        assertEq(user.currentBalance, 325 ether - initialAvailable);
        assertEq(user.currentApr, 182.5e18 / 2); //4 tick
        assertEq(user.payouts, initialAvailable);
        assertEq(user.rewards, 0);
        assertEq(user.lastTime, block.timestamp);

        assertEq(info.totalUsers, 1);
        assertEq(info.totalDeposited, 325 ether);
        assertEq(info.totalCompoundDeposited, 0);
        assertEq(info.totalClaimed, initialAvailable);
        assertEq(info.totalRewards, 0);
        assertEq(info.totalTxs, 4);
        assertEq(info.currentBalance, 325 ether - initialAvailable);
    }
}
