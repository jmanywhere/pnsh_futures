//SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "../src/amm/AmmFactory.sol";
import "../src/AddressRegistry.sol";
import "../src/amm/AmmRouter02.sol";
import "../src/amm/lib/WETH.sol";
import "../src/Sweeper.sol";
import "../src/Treasury.sol";
import "../src/TreasuryConvertible.sol";

contract TestSweeper is Test {
    Sweeper public sweeper;

    WETH public weth;
    AmmFactory public ammFactory;
    AmmRouter public ammRouter;
    IAmmPair public coreLp;

    Treasury public coreTreasury;
    Treasury public coreLpTreasury;
    TreasuryConvertible public collateralTreasury;

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
            1_000 ether,
            address(users[0])
        );
        collateralTreasury = new TreasuryConvertible(collateralToken);
        coreToken = new ERC20PresetFixedSupply(
            "coreToken",
            "core",
            1_000 ether,
            address(users[0])
        );
        coreTreasury = new Treasury(coreToken);

        registry = new AddressRegistry();
        sweeper = new Sweeper(registry);

        coreLp = IAmmPair(
            ammFactory.createPair(address(collateralToken), address(coreToken))
        );

        bytes32[] memory registryKeys = new bytes32[](6);
        registryKeys[0] = keccak256(abi.encodePacked("AMM_ROUTER"));
        registryKeys[1] = keccak256(abi.encodePacked("COLLATERAL_TOKEN"));
        registryKeys[2] = keccak256(abi.encodePacked("CORE_TOKEN"));
        registryKeys[3] = keccak256(abi.encodePacked("CORE_TREASURY"));
        registryKeys[4] = keccak256(abi.encodePacked("CORE_LP_TREASURY"));
        registryKeys[5] = keccak256(abi.encodePacked("COLLATERAL_TREASURY"));
        address[] memory registryVals = new address[](6);
        registryVals[0] = address(ammRouter);
        registryVals[1] = address(collateralToken);
        registryVals[2] = address(coreToken);
        registryVals[3] = address(coreTreasury);
        registryVals[4] = address(coreLpTreasury);
        registryVals[5] = address(collateralTreasury);

        registry.setMulti(registryKeys, registryVals);

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

        address[] memory toWhitelist = new address[](1);
        toWhitelist[0] = address(sweeper);
        collateralTreasury.addAddressesToWhitelist(toWhitelist);

        vm.stopPrank();
    }

    function test_constructorSetup() public {
        assertEq(users[0], sweeper.owner());

        assertEq(address(ammRouter), address(sweeper.registryAmmRouter()));
        assertEq(
            address(collateralToken),
            address(sweeper.registryCollateralToken())
        );
        assertEq(address(coreToken), address(sweeper.registryCoreToken()));
        assertEq(
            address(coreTreasury),
            address(sweeper.registryCoreTreasury())
        );
        assertEq(
            address(coreLpTreasury),
            address(sweeper.registryCoreLpTreasury())
        );
        assertEq(
            address(collateralTreasury),
            address(sweeper.registryCollateralTreasury())
        );
    }

    function test_sweep() public {
        vm.startPrank(users[0]);
        collateralToken.transfer(address(collateralTreasury), 100 ether);
        address[] memory collateralToCorePath = new address[](2);
        collateralToCorePath[0] = address(collateralToken);
        collateralToCorePath[1] = address(coreToken);
        sweeper.sweep(collateralToCorePath);

        //all collateral from initial liquidity and from the sweep should be in the lp
        assertEq(collateralToken.balanceOf(address(coreLp)), 200 ether);
    }
}
