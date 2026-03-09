// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IIdentityRegistryFacet
/// @notice Profile-based identity registry for the Diamond.
///         Maps wallets to ONCHAINID contracts + country codes.
///         Verification is per (wallet, profileId) pair, enabling one registry
///         to serve multiple asset classes with different KYC requirements.
interface IIdentityRegistryFacet {
    function registerIdentity(address wallet, address identity, uint16 country) external;
    function deleteIdentity(address wallet) external;
    function updateIdentity(address wallet, address identity) external;
    function updateCountry(address wallet, uint16 country) external;
    function batchRegisterIdentity(
        address[] calldata wallets,
        address[] calldata identities,
        uint16[] calldata countries
    ) external;

    /// @notice Returns true if wallet has a valid ONCHAINID with all required claims
    ///         for `profileId`, using the verification cache when possible.
    function isVerified(address wallet, uint32 profileId) external view returns (bool);
    function getIdentity(address wallet) external view returns (address);
    function getCountry(address wallet) external view returns (uint16);
    function contains(address wallet) external view returns (bool);
}
