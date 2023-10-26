// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "forge-std/Script.sol";
import "../src/TokenBase.sol";

contract DeployTokenBase is Script {
    string _name = "Nebula";
    string _ticker = "NSH";
    uint256 _initialSupply = 0 ether;
    bool _isMintable = true;
    bool _isTaxable = false;

    function run() public {
        vm.startBroadcast();
        new TokenBase(_name, _ticker, _initialSupply, _isMintable, _isTaxable);
        vm.stopBroadcast();
    }
}
