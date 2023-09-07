// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

///@dev Simple onchain referral storage
interface IReferralData {
    function updateReferral(address referrer) external;

    ///@dev Return the referral of the sender
    function myReferrer() external view returns (address);

    //@dev Return true if referrer of user is sender
    function isMyReferral(address _user) external view returns (bool);

    //@dev Return true if user has a referrer
    function hasReferrer(address _user) external view returns (bool);

    ///@dev Return the referral of a participant
    function referrerOf(address participant) external view returns (address);

    ///@dev Return the referral count of a participant
    function referralCountOf(address _user) external view returns (uint256);
}