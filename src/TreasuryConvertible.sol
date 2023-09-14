// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "./Treasury.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract TreasuryConvertible is Treasury {
    using SafeERC20 for IERC20;

    bool public isConvertOpen = true;

    //Convertible version, for changing the base stablecoin
    constructor(IERC20 tokenAddr) Treasury(tokenAddr) {
        token = IERC20(tokenAddr);
    }

    //@dev WARNING: Before calling convert, the AddressRegistry should be updated with the new stablecoin.
    function convert(
        IERC20 newTokenAddr,
        address newTokenSender,
        address oldTokenReceiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(isConvertOpen, "Convert locked");
        uint256 wad = token.balanceOf(address(this));
        token.safeTransfer(oldTokenReceiver, wad);
        newTokenAddr.safeTransferFrom(newTokenSender, address(this), wad);
    }

    function permanentlyLockConvert() external onlyRole(DEFAULT_ADMIN_ROLE) {
        isConvertOpen = false;
    }
}
