// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// solhint-disable no-inline-assembly

/// @dev Per-tokenId regulatory configuration.
///      `identityProfileId` points to a reusable profile in LibIdentityStorage
///      so multiple tokenIds can share the same KYC/AML requirements,
///      reducing deployment and operational cost.
struct AssetConfig {
    string name;
    string symbol;
    string uri;
    uint256 supplyCap;         // 0 = unlimited
    uint256 totalSupply;       // current minted supply for this tokenId
    uint32 identityProfileId;  // → LibIdentityStorage.profiles[id]
    address complianceModule;  // → IComplianceModule
    address issuer;            // authorised minter for this asset
    bool paused;
    bool exists;
    uint16[] allowedCountries; // ISO 3166-1 numeric; empty = all allowed
}

struct AssetStorage {
    mapping(uint256 => AssetConfig) configs;
    uint256[] registeredTokenIds;
}

/// @title LibAssetStorage
/// @notice Namespaced per-tokenId asset storage for the Diamond.
///         slot = keccak256("diamond.rwa.asset.storage") - 1
library LibAssetStorage {
    bytes32 internal constant POSITION =
        0x715f14664c3dc6471d9524868696b43c245e0aba6f0c77ed9e2dea380113fffb;

    function layout() internal pure returns (AssetStorage storage s) {
        bytes32 position = POSITION;
        assembly {
            s.slot := position
        }
    }
}
