// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;
import "./Whitelist.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "./interfaces/IFuturesTreasury.sol";

contract Treasury is Whitelist, IFuturesTreasury {
    IERC20 public token; // address of the BEP20 token traded on this contract

    //There can  be a general purpose treasury for any BEP20 token
    constructor(IERC20 tokenAddr) Whitelist(msg.sender) {
        token = IERC20(tokenAddr);
    }

    function withdraw(uint256 _amount) public onlyWhitelisted {
        require(token.transfer(_msgSender(), _amount));
    }

    function withdrawTo(address _to, uint256 _amount) public onlyWhitelisted {
        require(token.transfer(_to, _amount));
    }
}
