// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibIdentityStorage, IdentityStorage} from "../../storage/LibIdentityStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error TrustedIssuerFacet__ProfileNotFound(uint32 profileId);
error TrustedIssuerFacet__ZeroAddress();
error TrustedIssuerFacet__AlreadyTrusted(uint32 profileId, address issuer);
error TrustedIssuerFacet__NotTrusted(uint32 profileId, address issuer);
error TrustedIssuerFacet__Unauthorized();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title TrustedIssuerFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Manages the trusted claim issuers per identity profile.
///         Only claims attested by a trusted issuer count toward verification.
///         Adding/removing an issuer bumps the profile version to invalidate cache.
/// @custom:security-contact renan.correa@hubweb3.com
contract TrustedIssuerFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TrustedIssuerAdded(uint32 indexed profileId, address indexed issuer);
    event TrustedIssuerRemoved(uint32 indexed profileId, address indexed issuer);
    event VerificationCacheInvalidated(address indexed wallet, uint32 indexed profileId);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Marks `issuer` as trusted for claims in `profileId`.
    ///         Bumps profile version — all cached verifications for this profile
    ///         are implicitly invalidated on next isVerified() call.
    function addTrustedIssuer(uint32 profileId, address issuer) external {
        _enforceClaimIssuerOrOwner();
        _requireProfile(profileId);
        if (issuer == address(0)) revert TrustedIssuerFacet__ZeroAddress();

        IdentityStorage storage s = LibIdentityStorage.layout();
        if (s.profiles[profileId].trustedIssuers[issuer]) {
            revert TrustedIssuerFacet__AlreadyTrusted(profileId, issuer);
        }
        s.profiles[profileId].trustedIssuers[issuer] = true;
        ++s.profiles[profileId].version;

        emit TrustedIssuerAdded(profileId, issuer);
    }

    /// @notice Removes `issuer` from the trusted set of `profileId`.
    ///         Bumps profile version to invalidate cache.
    function removeTrustedIssuer(uint32 profileId, address issuer) external {
        _enforceClaimIssuerOrOwner();
        _requireProfile(profileId);

        IdentityStorage storage s = LibIdentityStorage.layout();
        if (!s.profiles[profileId].trustedIssuers[issuer]) {
            revert TrustedIssuerFacet__NotTrusted(profileId, issuer);
        }
        s.profiles[profileId].trustedIssuers[issuer] = false;
        ++s.profiles[profileId].version;

        emit TrustedIssuerRemoved(profileId, issuer);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isTrustedIssuer(uint32 profileId, address issuer) external view returns (bool) {
        return LibIdentityStorage.layout().profiles[profileId].trustedIssuers[issuer];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line ordering
    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    function _enforceClaimIssuerOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isIssuer = LibAccessStorage.layout().roles[CLAIM_ISSUER_ROLE][msg.sender];
        if (!isOwner && !isIssuer) revert TrustedIssuerFacet__Unauthorized();
    }

    function _requireProfile(uint32 profileId) internal view {
        if (profileId == 0 || profileId > LibIdentityStorage.layout().profileCount) {
            revert TrustedIssuerFacet__ProfileNotFound(profileId);
        }
    }
}
