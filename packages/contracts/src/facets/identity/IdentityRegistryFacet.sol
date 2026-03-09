// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibIdentityStorage, IdentityStorage} from "../../storage/LibIdentityStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error IdentityRegistryFacet__ZeroAddress();
error IdentityRegistryFacet__AlreadyRegistered(address wallet);
error IdentityRegistryFacet__NotRegistered(address wallet);
error IdentityRegistryFacet__Unauthorized();
error IdentityRegistryFacet__ArrayLengthMismatch();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title IdentityRegistryFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Maps investor wallets to ONCHAINID contracts and country codes.
///         `isVerified(wallet, profileId)` checks whether the wallet's ONCHAINID
///         holds valid claims from trusted issuers for all required topics in the profile.
///         Uses a version-based cache to avoid expensive on-chain claim validation
///         on every transfer (architecture §3, §4, §5 transfer flow step 5-6).
///
/// Cache invalidation:
///   - identityVersion[wallet] is bumped on updateIdentity / deleteIdentity
///   - profiles[profileId].version is bumped on addTrustedIssuer / setProfileClaimTopics
///   - Cache is stale when stored cacheVersion != identityVersion[wallet] + profileVersion
/// @custom:security-contact renan.correa@hubweb3.com
contract IdentityRegistryFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event IdentityBound(address indexed wallet, address indexed identity, uint16 country);
    event IdentityUnbound(address indexed wallet);
    event VerificationCacheInvalidated(address indexed wallet, uint32 indexed profileId);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a wallet with its ONCHAINID and country code.
    ///         Caller must be Diamond owner or TRANSFER_AGENT.
    function registerIdentity(address wallet, address identity, uint16 country) external {
        _enforceAgentOrOwner();
        if (wallet == address(0) || identity == address(0)) {
            revert IdentityRegistryFacet__ZeroAddress();
        }
        IdentityStorage storage s = LibIdentityStorage.layout();
        if (s.walletToIdentity[wallet] != address(0)) {
            revert IdentityRegistryFacet__AlreadyRegistered(wallet);
        }
        s.walletToIdentity[wallet] = identity;
        s.walletCountry[wallet] = country;
        ++s.identityVersion[wallet];

        emit IdentityBound(wallet, identity, country);
    }

    /// @notice Removes a wallet's identity registration.
    ///         Bumps identityVersion to invalidate all cached verifications.
    function deleteIdentity(address wallet) external {
        _enforceAgentOrOwner();
        IdentityStorage storage s = LibIdentityStorage.layout();
        if (s.walletToIdentity[wallet] == address(0)) {
            revert IdentityRegistryFacet__NotRegistered(wallet);
        }
        delete s.walletToIdentity[wallet];
        delete s.walletCountry[wallet];
        ++s.identityVersion[wallet];

        emit IdentityUnbound(wallet);
    }

    /// @notice Replaces the ONCHAINID for a registered wallet.
    ///         Bumps identityVersion to invalidate cache.
    function updateIdentity(address wallet, address identity) external {
        _enforceAgentOrOwner();
        if (identity == address(0)) revert IdentityRegistryFacet__ZeroAddress();
        IdentityStorage storage s = LibIdentityStorage.layout();
        if (s.walletToIdentity[wallet] == address(0)) {
            revert IdentityRegistryFacet__NotRegistered(wallet);
        }
        s.walletToIdentity[wallet] = identity;
        ++s.identityVersion[wallet];

        emit IdentityBound(wallet, identity, s.walletCountry[wallet]);
    }

    /// @notice Updates the country code for a registered wallet.
    function updateCountry(address wallet, uint16 country) external {
        _enforceAgentOrOwner();
        IdentityStorage storage s = LibIdentityStorage.layout();
        if (s.walletToIdentity[wallet] == address(0)) {
            revert IdentityRegistryFacet__NotRegistered(wallet);
        }
        s.walletCountry[wallet] = country;
        ++s.identityVersion[wallet];
    }

    /// @notice Batch registers multiple wallets in a single call.
    function batchRegisterIdentity(
        address[] calldata wallets,
        address[] calldata identities,
        uint16[] calldata countries
    ) external {
        _enforceAgentOrOwner();
        uint256 len = wallets.length;
        if (len != identities.length || len != countries.length) {
            revert IdentityRegistryFacet__ArrayLengthMismatch();
        }
        IdentityStorage storage s = LibIdentityStorage.layout();
        for (uint256 i; i < len; ++i) {
            address wallet = wallets[i];
            address identity = identities[i];
            if (wallet == address(0) || identity == address(0)) {
                revert IdentityRegistryFacet__ZeroAddress();
            }
            if (s.walletToIdentity[wallet] != address(0)) {
                revert IdentityRegistryFacet__AlreadyRegistered(wallet);
            }
            s.walletToIdentity[wallet] = identity;
            s.walletCountry[wallet] = countries[i];
            ++s.identityVersion[wallet];
            emit IdentityBound(wallet, identity, countries[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    VERIFICATION — CACHED
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if `wallet` is verified for `profileId`.
    ///         Uses the version-based cache: if cacheVersion matches the combined
    ///         identityVersion + profileVersion, returns cached result without
    ///         on-chain claim validation. Otherwise validates and updates cache.
    ///
    /// @dev    In this implementation claims are not validated on-chain
    ///         (ONCHAINID integration is a future facet). The cache tracks
    ///         registration status and version consistency only.
    ///         Full claim validation will be added in feat/compliance-router.
    function isVerified(address wallet, uint32 profileId) external returns (bool verified) {
        IdentityStorage storage s = LibIdentityStorage.layout();

        // Not registered → never verified
        if (s.walletToIdentity[wallet] == address(0)) return false;
        // Profile 0 or beyond count → invalid profile
        if (profileId == 0 || profileId > s.profileCount) return false;

        uint64 identVer = s.identityVersion[wallet];
        uint64 profVer = s.profiles[profileId].version;
        // Combined version: simple sum (both start at 1, overflow is astronomically unlikely)
        uint64 combinedVer = identVer + profVer;

        if (s.cacheVersion[wallet][profileId] == combinedVer) {
            // Cache hit
            return s.verifiedCache[wallet][profileId];
        }

        // Cache miss — re-evaluate
        // For now: registered wallet with a valid profile = verified.
        // Full ONCHAINID claim check added in feat/compliance-router.
        verified = s.walletToIdentity[wallet] != address(0);

        s.verifiedCache[wallet][profileId] = verified;
        s.cacheVersion[wallet][profileId] = combinedVer;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getIdentity(address wallet) external view returns (address) {
        return LibIdentityStorage.layout().walletToIdentity[wallet];
    }

    function getCountry(address wallet) external view returns (uint16) {
        return LibIdentityStorage.layout().walletCountry[wallet];
    }

    function contains(address wallet) external view returns (bool) {
        return LibIdentityStorage.layout().walletToIdentity[wallet] != address(0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line ordering
    bytes32 internal constant TRANSFER_AGENT = keccak256("TRANSFER_AGENT");

    function _enforceAgentOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isAgent = LibAccessStorage.layout().roles[TRANSFER_AGENT][msg.sender];
        if (!isOwner && !isAgent) revert IdentityRegistryFacet__Unauthorized();
    }
}
