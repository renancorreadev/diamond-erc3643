// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IIdentity {
    function keyHasPurpose(bytes32 _key, uint256 _purpose) external view returns (bool);
}

/// @title IIdentityRegistry
/// @notice Maps investor wallets to their ONCHAINID and country code.
///         Used by the compliance layer to verify identity before transfers.
interface IIdentityRegistry {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event IdentityRegistered(address indexed investorAddress, IIdentity indexed identity);
    event IdentityRemoved(address indexed investorAddress, IIdentity indexed identity);
    event IdentityUpdated(IIdentity indexed oldIdentity, IIdentity indexed newIdentity);
    event CountryUpdated(address indexed investorAddress, uint16 indexed country);

    /*//////////////////////////////////////////////////////////////
                            STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    function registerIdentity(address _userAddress, IIdentity _identity, uint16 _country)
        external;

    function deleteIdentity(address _userAddress) external;

    function updateCountry(address _userAddress, uint16 _country) external;

    function updateIdentity(address _userAddress, IIdentity _identity) external;

    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        IIdentity[] calldata _identities,
        uint16[] calldata _countries
    ) external;

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function contains(address _userAddress) external view returns (bool);

    /// @notice Returns true if the wallet has a valid ONCHAINID with all
    ///         required claims from trusted issuers.
    function isVerified(address _userAddress) external view returns (bool);

    function identity(address _userAddress) external view returns (IIdentity);

    function investorCountry(address _userAddress) external view returns (uint16);
}
