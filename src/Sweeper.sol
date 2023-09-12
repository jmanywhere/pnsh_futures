// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "./interfaces/IAmmRouter02.sol";
import "./interfaces/IFuturesTreasury.sol";
import "./AddressRegistry.sol";

contract Sweeper is Ownable {
    using SafeERC20 for IERC20;
    AddressRegistry private immutable _registry;

    constructor(AddressRegistry registry) Ownable() {
        _registry = registry;
    }

    function sweep() external onlyOwner {
        IFuturesTreasury collateralTreasury = registryCollateralTreasury();

        IERC20 collateralToken = registryCollateralToken();
        IERC20 coreToken = registryCoreToken();
        IAmmRouter02 collateralRouter = registryAmmRouter();

        //Spend 5/6 on core (2/3 on core, 1/6 on core lp)
        collateralTreasury.withdraw(
            collateralToken.balanceOf(address(collateralTreasury))
        );
        collateralToken.approve(
            address(collateralRouter),
            collateralToken.balanceOf(address(this))
        );
        address[] memory path = new address[](3);
        path[0] = address(collateralToken);
        path[1] = collateralRouter.WETH();
        path[2] = address(coreToken);
        uint256 amount = (collateralToken.balanceOf(address(this)) * 5) / 6;

        collateralRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, //amountIn,
            0, //amountOutMin,
            path, //path,
            address(this), //to,
            block.timestamp //deadline
        );
        //send 4/5 to treasury (2/3 of the original asset)
        coreToken.transfer(
            registryCoreTreasury(),
            (coreToken.balanceOf(address(this)) * 4) / 5
        );

        //Spend remaining 1/6 on liquidity
        collateralRouter.addLiquidity(
            address(coreToken), //address tokenA,
            address(collateralToken), //address tokenB,
            coreToken.balanceOf(address(this)), //uint256 amountADesired,
            collateralToken.balanceOf(address(this)), //uint256 amountBDesired,
            0, //uint256 amountAMin,
            0, //uint256 amountBMin,
            registryCoreLpTreasury(), //address to,
            block.timestamp //uint256 deadline
        );
    }

    function recoverERC20(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(
            _msgSender(),
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }

    function registryAmmRouter() public view returns (IAmmRouter02) {
        return
            IAmmRouter02(
                _registry.get(keccak256(abi.encodePacked("AMM_ROUTER")))
            );
    }

    function registryCollateralToken() public view returns (IERC20) {
        return
            IERC20(
                _registry.get(keccak256(abi.encodePacked("COLLATERAL_TOKEN")))
            );
    }

    function registryCoreToken() public view returns (IERC20) {
        return IERC20(_registry.get(keccak256(abi.encodePacked("CORE_TOKEN"))));
    }

    function registryCoreTreasury() public view returns (address) {
        return _registry.get(keccak256(abi.encodePacked("CORE_TREASURY")));
    }

    function registryCoreLpTreasury() public view returns (address) {
        return _registry.get(keccak256(abi.encodePacked("CORE_LP_TREASURY")));
    }

    function registryCollateralTreasury()
        public
        view
        returns (IFuturesTreasury)
    {
        return
            IFuturesTreasury(
                _registry.get(
                    keccak256(abi.encodePacked("COLLATERAL_TREASURY"))
                )
            );
    }
}
