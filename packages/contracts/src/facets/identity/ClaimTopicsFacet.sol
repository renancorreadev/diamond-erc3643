// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibIdentityStorage, IdentityStorage} from "../../storage/LibIdentityStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error ClaimTopicsFacet__ProfileNotFound(uint32 profileId);
error ClaimTopicsFacet__Unauthorized();
error ClaimTopicsFacet__EmptyClaimTopics();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title ClaimTopicsFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Manages identity profiles — each profile defines which ERC-735
///         claim topics are required for an investor to be considered verified.
///         Multiple tokenIds can share one profile, reducing operational cost.
///         Profile version is bumped on every change to invalidate the cache.
/// @custom:security-contact renan.correa@hubweb3.com
contract ClaimTopicsFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event ProfileUpdated(uint32 indexed profileId);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new identity profile with an initial set of claim topics.
    ///         Returns the assigned profileId (auto-incremented from 1).
    function createProfile(uint256[] calldata claimTopics) external returns (uint32 profileId) {
        _enforceClaimIssuerOrOwner();
        if (claimTopics.length == 0) revert ClaimTopicsFacet__EmptyClaimTopics();

        IdentityStorage storage s = LibIdentityStorage.layout();
        // profileCount starts at 0; first profile gets id = 1
        profileId = ++s.profileCount;
        s.profiles[profileId].requiredClaimTopics = claimTopics;
        s.profiles[profileId].version = 1;

        emit ProfileUpdated(profileId);
    }

    /// @notice Replaces the claim topics for an existing profile.
    ///         Bumps profile version to invalidate all verification caches.
    function setProfileClaimTopics(uint32 profileId, uint256[] calldata claimTopics) external {
        _enforceClaimIssuerOrOwner();
        _requireProfile(profileId);
        if (claimTopics.length == 0) revert ClaimTopicsFacet__EmptyClaimTopics();

        IdentityStorage storage s = LibIdentityStorage.layout();
        s.profiles[profileId].requiredClaimTopics = claimTopics;
        ++s.profiles[profileId].version;

        emit ProfileUpdated(profileId);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getProfileClaimTopics(uint32 profileId)
        external
        view
        returns (uint256[] memory)
    {
        _requireProfile(profileId);
        return LibIdentityStorage.layout().profiles[profileId].requiredClaimTopics;
    }

    function getProfileVersion(uint32 profileId) external view returns (uint64) {
        return LibIdentityStorage.layout().profiles[profileId].version;
    }

    function profileExists(uint32 profileId) external view returns (bool) {
        return profileId > 0 && profileId <= LibIdentityStorage.layout().profileCount;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // solhint-disable-next-line ordering
    bytes32 internal constant CLAIM_ISSUER_ROLE = keccak256("CLAIM_ISSUER_ROLE");

    function _enforceClaimIssuerOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isIssuer = LibAccessStorage.layout().roles[CLAIM_ISSUER_ROLE][msg.sender];
        if (!isOwner && !isIssuer) revert ClaimTopicsFacet__Unauthorized();
    }

    function _requireProfile(uint32 profileId) internal view {
        if (profileId == 0 || profileId > LibIdentityStorage.layout().profileCount) {
            revert ClaimTopicsFacet__ProfileNotFound(profileId);
        }
    }
}
