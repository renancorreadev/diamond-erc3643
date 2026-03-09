// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

/// @dev Regulatory profile: defines WHICH claims are required and
///      WHICH issuers are trusted to attest them.
///      Designed to be reused across multiple tokenIds (e.g. "accredited investor").
///      `version` is bumped on any change, invalidating the verification cache.
struct IdentityProfile {
    uint256[] requiredClaimTopics;
    mapping(address => bool) trustedIssuers;
    uint64 version;
}

struct IdentityStorage {
    /// wallet → ONCHAINID contract
    mapping(address => address) walletToIdentity;
    /// wallet → ISO 3166-1 numeric country code
    mapping(address => uint16) walletCountry;
    /// wallet → version counter (bumped on identity update)
    mapping(address => uint64) identityVersion;
    /// profileId → regulatory profile
    mapping(uint32 => IdentityProfile) profiles;
    /// wallet → profileId → cached verification result
    mapping(address => mapping(uint32 => bool)) verifiedCache;
    /// wallet → profileId → identity version at cache time
    mapping(address => mapping(uint32 => uint64)) cacheIdentityVersion;
    /// wallet → profileId → profile version at cache time
    mapping(address => mapping(uint32 => uint64)) cacheProfileVersion;
    uint32 profileCount;
}

/// @title LibIdentityStorage
/// @notice Namespaced identity storage for the Diamond.
///         slot = keccak256("diamond.rwa.identity.storage") - 1
library LibIdentityStorage {
    bytes32 internal constant POSITION =
        0xb301aa8172310cb299b51011e8e8be41f21916ff640c952e834ef2501a47d375;

    function layout() internal pure returns (IdentityStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
