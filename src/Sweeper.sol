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
        IFuturesTreasury collateralTreasury = IFuturesTreasury(
            _registry.collateralTreasury()
        );

        IERC20 collateralToken = IERC20(_registry.collateralAddress());
        IERC20 coreToken = IERC20(_registry.coreAddress());
        IAmmRouter02 collateralRouter = IAmmRouter02(_registry.routerAddress());

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
            _registry.coreTreasuryAddress(),
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
            _registry.coreLpTreasuryAddress(), //address to,
            block.timestamp //uint256 deadline
        );
    }

    function recoverERC20(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(
            _msgSender(),
            IERC20(tokenAddress).balanceOf(address(this))
        );
    }
}
