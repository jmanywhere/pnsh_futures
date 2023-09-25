// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/math/Math.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "./FuturesVault.sol";
//import "./interfaces/IReferralReport.sol";
import "./interfaces/IFuturesTreasury.sol";
import "./interfaces/IFuturesYieldEngine.sol";
import "./AddressRegistry.sol";
import "./interfaces/IAmmTwapOracle.sol";

//@dev  Business logic for Futures
//Engine can be swapped out if upgrades are needed
//Only yield infrastructure and vault can be updated
//TODO: Needs IReferralReport implementation
contract FuturesEngine is Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    AddressRegistry private immutable _registry;

    //Financial Model
    uint256 public constant REFERENCE_APR = 182.5e18; //0.5% daily
    uint256 public constant MAX_BALANCE = 1_000_000 ether; //1M
    uint256 public constant MAX_TICKS = 8; //Multiply by min deposit to get max APR of 0.5% daily
    uint256 public constant MIN_DEPOSIT = 25e18; //200+ deposits; will compound available rewards
    uint256 public constant MAX_AVAILABLE = 50000e18; //50K max claim daily, 10 days missed claims
    uint256 public constant MAX_PAYOUTS = (MAX_BALANCE * 5e18) / 2e18; //2.5M

    //events
    event Deposit(address indexed user, uint256 amount);
    event CompoundDeposit(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 amount);
    event Transfer(
        address indexed user,
        address indexed newUser,
        uint256 currentBalance
    );
    event RewardDistribution(
        address referrer,
        address user,
        uint referrerReward,
        uint userReward
    );

    //@dev Creates a FuturesEngine
    constructor(AddressRegistry registry) Ownable() {
        _registry = registry;
    }

    //Administrative//

    ///  Views  ///

    //@dev Get User info
    function getUser(address _user) external view returns (FuturesUser memory) {
        return registryFuturesVault().getUser(_user);
    }

    //@dev Get contract snapshot
    function getInfo() external view returns (FuturesGlobals memory) {
        return registryFuturesVault().getGlobals();
    }

    ////  User Functions ////

    //@dev Deposit BUSD in exchange for TRUNK at the current TWAP price
    function deposit(uint _amount) external {
        //keep oracle up to date
        IAmmTwapOracle(registryFuturesYieldEngine().oracle()).updateAll();

        //Only the key holder can invest their funds
        address user = msg.sender;

        FuturesVault vault = registryFuturesVault();

        FuturesUser memory userData = vault.getUser(user);
        FuturesGlobals memory globalsData = vault.getGlobals();

        require(_amount >= MIN_DEPOSIT, "amount less than minimum deposit");
        require(
            userData.currentBalance + _amount <= MAX_BALANCE,
            "max balance exceeded"
        );
        require(userData.payouts <= MAX_PAYOUTS, "max payouts exceeded");

        uint ticks = MAX_TICKS.min(_amount / MIN_DEPOSIT); //1 to 8 ticks for apr
        uint userApr = (REFERENCE_APR * ticks) / 8;

        uint share = _amount / 100;

        //50% buy pNSH + 25% mint pNSH/collat lp
        uint treasuryAmount = share * 75;
        // 15% to Bufferpool
        uint bufferAmount = share * 15;
        // 10% to PCR
        uint pcrAmount = _amount - treasuryAmount - bufferAmount;

        IERC20 collateralToken = registryCollateralToken();
        collateralToken.safeTransferFrom(
            user,
            registryCollateralTreasury(),
            treasuryAmount
        );
        collateralToken.safeTransferFrom(
            user,
            registryCollateralBufferPool(),
            bufferAmount
        );
        collateralToken.safeTransferFrom(
            user,
            registryCollateralPcrTreasury(),
            pcrAmount
        );

        //update user stats
        if (userData.exists == false) {
            //attempt to migrate user
            userData.exists = true;
            globalsData.totalUsers += 1;

            //commit updates
            vault.commitUser(user, userData);
            vault.commitGlobals(globalsData);
        }

        //if user has an existing balance see if we have to claim yield before proceeding
        //optimistically claim yield before reset
        //if there is a balance we potentially have yield
        if (userData.currentBalance > 0) {
            _compoundYield(user);

            //reload user data after a mutable function
            userData = vault.getUser(user);
            globalsData = vault.getGlobals();
        }

        //update user
        userData.deposits += _amount;
        userData.lastTime = block.timestamp;
        userData.currentBalance += _amount;
        userData.currentApr = userApr;

        globalsData.totalDeposited += _amount;
        globalsData.currentBalance += _amount;
        globalsData.totalTxs += 1;

        //commit updates
        vault.commitUser(user, userData);
        vault.commitGlobals(globalsData);

        //events
        emit Deposit(user, _amount);
    }

    //@dev Claims earned interest for the caller
    function claim() external returns (bool success) {
        //keep oracle up to date
        IAmmTwapOracle(registryFuturesYieldEngine().oracle()).updateAll();
        //Only the owner of funds can claim funds
        address user = msg.sender;

        FuturesVault vault = registryFuturesVault();
        FuturesUser memory userData = vault.getUser(user);

        //checks
        require(userData.exists, "User is not registered");
        require(
            userData.currentBalance > 0,
            "balance is required to earn yield"
        );

        success = _distributeYield(user);
    }

    /*
    //@dev Implements the IReferralReport interface which is called by the FarmEngine yield function back to the caller
    function rewardDistribution(
        address _referrer,
        address _user,
        uint _referrerReward,
        uint _userReward
    ) external {
        //checks
        require(
            msg.sender == address(yieldEngine),
            "caller must be registered yield engine"
        );
        require(
            _referrer != address(0) && _user != address(0),
            "non-zero addresses required"
        );

        //Load data
        FuturesUser memory userData = vault.getUser(_user);
        FuturesUser memory referrerData = vault.getUser(_referrer);
        FuturesGlobals memory globalsData = vault.getGlobals();

        //track exclusive rewards which are paid out via Stampede airdrops
        referrerData.rewards += _referrerReward;
        userData.rewards += _userReward;

        //track total rewards
        globalsData.totalRewards += (_referrerReward + _userReward);

        //commit updates
        vault.commitUser(_user, userData);
        vault.commitUser(_referrer, referrerData);
        vault.commitGlobals(globalsData);

        emit RewardDistribution(_referrer, _user, _referrerReward, _userReward);
    }
*/
    //@dev Returns tax bracket and adjusted amount based on the bracket
    function available(
        address _user
    ) public view returns (uint256 _limiterRate, uint256 _adjustedAmount) {
        //Load data
        FuturesVault vault = registryFuturesVault();
        FuturesUser memory userData = vault.getUser(_user);

        //calculate gross available
        uint256 share;

        if (userData.currentBalance > 0) {
            //Using 1e18 we capture all significant digits when calculating available divs
            share =
                (userData.currentBalance * userData.currentApr) / //payout is asymptotic and uses the current balance //convert to daily apr
                (365 * 100e18) /
                24 hours; //divide the profit by payout rate and seconds in the day;
            _adjustedAmount = share * (block.timestamp - userData.lastTime);

            _adjustedAmount = MAX_AVAILABLE.min(_adjustedAmount); //minimize red candles
        }

        //apply compound rate limiter
        uint256 _compSurplus = 0;
        if (userData.compoundDeposits > userData.deposits) {
            _compSurplus = userData.compoundDeposits - userData.deposits;
        }

        if (_compSurplus < 50000e18) {
            _limiterRate = 0;
        } else if (50000e18 <= _compSurplus && _compSurplus < 250000e18) {
            _limiterRate = 10;
        } else if (250000e18 <= _compSurplus && _compSurplus < 500000e18) {
            _limiterRate = 15;
        } else if (500000e18 <= _compSurplus && _compSurplus < 750000e18) {
            _limiterRate = 25;
        } else if (750000e18 <= _compSurplus && _compSurplus < 1000000e18) {
            _limiterRate = 35;
        } else if (_compSurplus >= 1000000e18) {
            _limiterRate = 50;
        }

        _adjustedAmount = (_adjustedAmount * (100 - _limiterRate)) / 100;

        // payout greater than the balance just pay the balance
        if (_adjustedAmount > userData.currentBalance) {
            _adjustedAmount = userData.currentBalance;
        }
    }

    //   Internal Functions  //

    //@dev Checks if yield is available and distributes before performing additional operations
    //distributes only when yield is positive
    //inputs are validated by external facing functions
    function _distributeYield(address _user) private returns (bool success) {
        FuturesVault vault = registryFuturesVault();
        IFuturesYieldEngine yieldEngine = registryFuturesYieldEngine();
        FuturesUser memory userData = vault.getUser(_user);
        FuturesGlobals memory globalsData = vault.getGlobals();

        //get available
        (, uint256 _amount) = available(_user);

        // payout remaining allowable divs if exceeds
        if (userData.payouts + _amount > MAX_PAYOUTS) {
            if (MAX_PAYOUTS > userData.payouts) {
                _amount = MAX_PAYOUTS - userData.payouts;
            } else {
                _amount = 0;
            }
            _amount = _amount.min(userData.currentBalance); //withdraw up to the current balance
        }

        //attempt to payout yield and update stats;
        if (_amount > 0) {
            _amount = yieldEngine.yield(_user, _amount);

            if (_amount > 0) {
                //second check with delivered yield
                //user stats
                userData.payouts += _amount;
                userData.currentBalance = userData.currentBalance - _amount;
                userData.lastTime = block.timestamp;

                //total stats
                globalsData.totalClaimed += _amount;
                globalsData.totalTxs += 1;
                if (globalsData.currentBalance > _amount) {
                    globalsData.currentBalance =
                        globalsData.currentBalance -
                        _amount;
                } else {
                    globalsData.currentBalance = 0;
                }

                //commit updates
                vault.commitUser(_user, userData);
                vault.commitGlobals(globalsData);

                //log events
                emit Claim(_user, _amount);

                return true;
            }
        }

        //default
        return false;
    }

    //@dev Checks if yield is available and compound before performing additional operations
    //compound only when yield is positive
    function _compoundYield(address _user) private returns (bool success) {
        FuturesVault vault = registryFuturesVault();
        FuturesUser memory userData = vault.getUser(_user);
        FuturesGlobals memory globalsData = vault.getGlobals();

        //get available
        (, uint256 _amount) = available(_user);

        // payout remaining allowable divs if exceeds
        if (userData.payouts + _amount > MAX_PAYOUTS) {
            _amount = MAX_PAYOUTS - userData.payouts;
        }

        //attempt to compound yield and update stats;
        if (_amount > 0) {
            //user stats
            userData.deposits += 0; //compounding is not a deposit; here for clarity
            userData.compoundDeposits += _amount;
            userData.payouts += _amount;
            userData.currentBalance += _amount;
            userData.lastTime = block.timestamp;

            //total stats
            globalsData.totalDeposited += 0; //compounding  doesn't move the needle; here for clarity
            globalsData.totalCompoundDeposited += _amount;
            globalsData.totalClaimed += _amount;
            globalsData.currentBalance += _amount;
            globalsData.totalTxs += 1;

            //commit updates
            vault.commitUser(_user, userData);
            vault.commitGlobals(globalsData);

            //log events
            emit Claim(_user, _amount);
            emit CompoundDeposit(_user, _amount);

            return true;
        } else {
            //do nothing upon failure
            return false;
        }
    }

    //@dev Transfer account to another wallet address
    function transfer(address _newUser) external {
        address user = msg.sender;
        FuturesVault vault = registryFuturesVault();

        FuturesUser memory userData = vault.getUser(user);
        FuturesUser memory newData = vault.getUser(_newUser);
        FuturesGlobals memory globalsData = vault.getGlobals();

        //Only the owner can transfer
        require(userData.exists, "user must exists");
        require(
            newData.exists == false && _newUser != address(0),
            "new address must not exist"
        );

        //Transfer
        newData.exists = true;
        newData.deposits = userData.deposits;
        newData.currentBalance = userData.currentBalance;
        newData.currentApr = userData.currentApr;
        newData.payouts = userData.payouts;
        newData.compoundDeposits = userData.compoundDeposits;
        newData.rewards = userData.rewards;
        newData.lastTime = block.timestamp; //manually claim if required

        //Zero out old account
        userData.exists = false;
        userData.deposits = 0;
        userData.currentBalance = 0;
        userData.currentApr = 0;
        userData.compoundDeposits = 0;
        userData.payouts = 0;
        userData.rewards = 0;
        userData.lastTime = 0;

        //house keeping
        globalsData.totalTxs += 1;

        //commit
        vault.commitUser(user, userData);
        vault.commitUser(_newUser, newData);
        vault.commitGlobals(globalsData);

        //log
        emit Transfer(user, _newUser, newData.currentBalance);
    }

    function registryFuturesVault() public view returns (FuturesVault) {
        return
            FuturesVault(
                _registry.get(keccak256(abi.encodePacked("FUTURES_VAULT")))
            );
    }

    function registryFuturesYieldEngine()
        public
        view
        returns (IFuturesYieldEngine)
    {
        return
            IFuturesYieldEngine(
                _registry.get(
                    keccak256(abi.encodePacked("FUTURES_YIELD_ENGINE"))
                )
            );
    }

    function registryCollateralToken() public view returns (IERC20) {
        return
            IERC20(
                _registry.get(keccak256(abi.encodePacked("COLLATERAL_TOKEN")))
            );
    }

    function registryCollateralTreasury() public view returns (address) {
        return
            _registry.get(keccak256(abi.encodePacked("COLLATERAL_TREASURY")));
    }

    function registryCollateralBufferPool() public view returns (address) {
        return
            _registry.get(keccak256(abi.encodePacked("COLLATERAL_BUFFERPOOL")));
    }

    function registryCollateralPcrTreasury() public view returns (address) {
        return
            _registry.get(
                keccak256(abi.encodePacked("COLLATERAL_PCR_TREASURY"))
            );
    }
}
