// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;
import "./Whitelist.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

contract Treasury is Whitelist {
    IERC20 public token; // address of the BEP20 token traded on this contract

    //There can  be a general purpose treasury for any BEP20 token
    constructor(IERC20 tokenAddr) public Ownable() {
        token = IToken(tokenAddr);
    }

    function withdraw(uint256 _amount) public onlyWhitelisted {
        require(token.transfer(_msgSender(), _amount));
    }
}
