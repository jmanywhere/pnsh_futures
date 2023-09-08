// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

//TODO: Make registry updateable, with ability to add new addresses (use mapping)

contract AddressRegistry {
    address public coreAddress =
        address(0xE283D0e3B8c102BAdF5E8166B73E02D96d92F688); //protocol token
    address public coreTreasuryAddress =
        address(0xAF0980A0f52954777C491166E7F40DB2B6fBb4Fc); //protocol token Treasury
    address public collateralAddress =
        address(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56); //collateral token
    address public collateralTreasury =
        address(0xCb5a02BB3a38e92E591d323d6824586608cE8cE4); //collateral token Treasury
    address public pcrTreasury =
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E); //genesis mint of NUSD
    address public yieldEngine =
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E); //Futures yield engine
    address public futuresVault =
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E); //Futures vault
    address public collateralRedemptionAddress =
        address(0xD3B4fB63e249a727b9976864B28184b85aBc6fDf); //collateral token Redemption Pool
    address public collateralBufferPool =
        address(0xd9dE89efB084FfF7900Eac23F2A991894500Ec3E); //collateral token Buffer Pool
    address public backedAddress =
        address(0xdd325C38b12903B727D16961e61333f4871A70E0); //protocol Stablecoin
    address public backedTreasuryAddress =
        address(0xaCEf13009D7E5701798a0D2c7cc7E07f6937bfDd); //protocol Stablecoin Treasury
    address public backedLPAddress =
        address(0xf15A72B15fC4CAeD6FaDB1ba7347f6CCD1E0Aede); //protocol Stablecoin/BUSD LP
    address public routerAddress =
        address(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    //PCS Factory - 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73
}
