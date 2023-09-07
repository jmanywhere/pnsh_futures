// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;
import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/utils/math/Math.sol";
import "./interfaces/IFuturesYieldEngine.sol";
import "./structs/StructsFutures.sol";
import "./Whitelist.sol";
import "./AddressRegistry.sol";
import "./interfaces/IFuturesTreasury.sol";
import "./interfaces/IAmmRouter02.sol";
import "./interfaces/IReferralReport.sol";
//import "./interfaces/IReferralData.sol";
//import "./interfaces/ISponsorData.sol";
import "./interfaces/IAmmTwapOracle.sol";

contract FuturesYieldEngine is Whitelist, IFuturesYieldEngine {
    using SafeERC20 for IERC20;
    using Math for uint256;

    AddressRegistry private _registry;

    IFuturesTreasury public immutable collateralBufferPool;
    IFuturesTreasury public immutable collateralTreasury;
    IFuturesTreasury public immutable coreTreasury;
    IERC20 public immutable collateralToken;
    IERC20 public immutable coreToken;

    bool public forceLiquidity = true;

    IAmmRouter02 public collateralRouter;

    //IReferralData public referralData;
    //ISponsorData public sponsorData;

    IAmmTwapOracle public oracle;

    event UpdateCollateralRouter(address indexed addr);
    /*event NewSponsorship(
        address indexed from,
        address indexed to,
        uint256 amount
    );*/

    event UpdateOracle(address indexed addr);
    //event UpdateReferralData(address indexed addr);
    //event UpdateSponsorData(address indexed addr);
    event UpdateForceLiquidity(bool value, bool newValue);

    /* ========== INITIALIZER ========== */

    constructor() Whitelist(msg.sender) {
        //init reg
        _registry = new AddressRegistry();

        //setup the core tokens
        coreToken = IERC20(_registry.coreAddress());
        collateralToken = IERC20(_registry.collateralAddress());

        //the collateral router can be upgraded in the future
        collateralRouter = IAmmRouter02(_registry.routerAddress());

        //treasury setup
        collateralTreasury = IFuturesTreasury(
            _registry.collateralTreasuryAddress()
        );

        collateralBufferPool = IFuturesTreasury(
            _registry.collateralBufferAddress()
        );
        coreTreasury = IFuturesTreasury(_registry.coreTreasuryAddress());
    }

    //@dev Update the referral data for partner rewards
    /*
    function updateReferralData(
        address referralDataAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            referralDataAddress != address(0),
            "Require valid non-zero addresses"
        );

        referralData = IReferralData(referralDataAddress);

        emit UpdateReferralData(referralDataAddress);
    }

    //@dev Update the sponsor data used to distribute gifted / rewarded bonds
    function updateSponsorData(
        address sponsorDataAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            sponsorDataAddress != address(0),
            "Require valid non-zero addresses"
        );

        sponsorData = ISponsorData(sponsorDataAddress);

        emit UpdateSponsorData(sponsorDataAddress);
    }*/

    //@dev Forces the yield engine to topoff liquidity in the collateral buffer on every tx
    //a test harness
    function updateForceLiquidity(
        bool _force
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit UpdateForceLiquidity(forceLiquidity, _force);
        forceLiquidity = _force;
    }

    //@dev Update Core collateral liquidity can move from one contract location to another across major PCS releases
    function updateCollateralRouter(
        address _router
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_router != address(0), "Router must be set");
        collateralRouter = IAmmRouter02(_router);

        emit UpdateCollateralRouter(_router);
    }

    //@dev Update the oracle used for price info
    function updateOracle(
        address oracleAddress
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            oracleAddress != address(0),
            "Require valid non-zero addresses"
        );

        //the main oracle
        oracle = IAmmTwapOracle(oracleAddress);

        address[] memory path = new address[](3);
        path[0] = address(collateralToken);
        path[1] = collateralRouter.WETH();
        path[2] = address(coreToken);

        //make sure our path for liquidation is registered
        oracle.updatePath(path);

        emit UpdateOracle(oracleAddress);
    }

    /********** Whitelisted Fuctions **************************************************/

    //@dev Claim and payout using the reserve
    //Sender must implement IReferralReport to succeed
    function yield(
        address _user,
        uint256 _amount
    ) external onlyWhitelisted returns (uint yieldAmount) {
        if (_amount == 0) {
            return 0;
        }

        //CollateralBuffer should be large enough to support daily yield
        uint256 cbShare = collateralToken.balanceOf(
            address(collateralBufferPool)
        ) / 100;

        //if yield is greater than 1%
        if (_amount > cbShare || forceLiquidity) {
            (, uint _coreAmount) = estimateCollateralToCore(_amount);
            _liquidateCore(
                address(collateralBufferPool),
                (_coreAmount * 110) / 100
            ); //Add an additional 10% to the BufferPool

            //account for TWAP inconsistency; the end user balance will only go down by the delivered amount
            //the buffer will never be overrun
            _amount = _amount.min(
                collateralToken.balanceOf(address(collateralBufferPool))
            );
        }

        /*
        //Calculate user referral rewards
        uint _referrals = _amount / 100;

        //Add referral bonus for referrer, 1%
        _processReferralBonus(_user, _referrals, msg.sender);
        */

        //Send collateral to user
        collateralBufferPool.withdrawTo(_user, _amount);

        return _amount;
    }

    /********** Internal Fuctions **************************************************/
    /*
    //@dev Add referral bonus if applicable
    function _processReferralBonus(
        address _user,
        uint256 _amount,
        address referralReport
    ) private {
        address _referrer = referralData.referrerOf(_user);

        //Need to have an upline
        if (_referrer == address(0)) {
            return;
        }

        //partners split 50/50
        uint256 _share = _amount / 2;

        //We operate side effect free and just add to pending sponsorships
        sponsorData.add(_referrer, _share);
        sponsorData.add(_user, _share);

        //Report the reward distribution to the caller
        IReferralReport report = IReferralReport(referralReport);
        report.rewardDistribution(_referrer, _user, _share, _share);

        emit NewSponsorship(_user, _referrer, _share);
        emit NewSponsorship(_referrer, _user, _share);
    }*/

    function estimateCollateralToCore(
        uint collateralAmount
    ) public view returns (uint wethAmount, uint coreAmount) {
        //Convert from collateral to core using oracle
        address[] memory path = new address[](3);
        path[0] = address(collateralToken);
        path[1] = collateralRouter.WETH();
        path[2] = address(coreToken);

        uint[] memory amounts = oracle.consultAmountsOut(
            collateralAmount,
            path
        );

        //Use core router to get amount of coreTokens required to cover
        wethAmount = amounts[1];
        coreAmount = amounts[2];
    }

    //@dev liquidate core tokens from the treasury to the destination
    function _liquidateCore(
        address destination,
        uint256 _amount
    ) private returns (uint collateralAmount) {
        //Convert from collateral to backed
        address[] memory path = new address[](3);

        path[0] = address(coreToken);
        path[1] = collateralRouter.WETH();
        path[2] = address(collateralToken);

        //withdraw from treasury
        coreTreasury.withdraw(_amount);

        //approve & swap
        coreToken.safeApprove(address(collateralRouter), _amount);

        uint initialBalance = collateralToken.balanceOf(destination);

        collateralRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            0,
            path,
            destination,
            block.timestamp
        );

        collateralAmount =
            collateralToken.balanceOf(destination) -
            initialBalance;
    }
}
