// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibAssetStorage, AssetStorage, AssetConfig} from "../../storage/LibAssetStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";
import {IAssetManager} from "../../interfaces/token/IAssetManager.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error AssetManagerFacet__AlreadyRegistered(uint256 tokenId);
error AssetManagerFacet__NotRegistered(uint256 tokenId);
error AssetManagerFacet__ZeroAddress();
error AssetManagerFacet__EmptyString();
error AssetManagerFacet__Unauthorized();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title AssetManagerFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Manages per-tokenId asset configuration (architecture §3 — Level 2).
///         Each tokenId is an independent asset class with its own regulatory config:
///         identity profile, compliance module, issuer, supply cap, and jurisdictions.
///         Caller: Diamond owner or COMPLIANCE_ADMIN for config changes.
/// @custom:security-contact renan.correa@hubweb3.com
contract AssetManagerFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetRegistered(uint256 indexed tokenId, address indexed issuer, uint32 profileId);
    event AssetConfigUpdated(uint256 indexed tokenId);
    event ComplianceModuleSet(uint256 indexed tokenId, address indexed module);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers a new asset class (tokenId) with its full regulatory config.
    ///         Accepts a params struct to avoid stack-too-deep on 9 arguments.
    function registerAsset(IAssetManager.RegisterAssetParams calldata p) external {
        _enforceComplianceAdminOrOwner();
        if (p.issuer == address(0)) revert AssetManagerFacet__ZeroAddress();
        if (bytes(p.name).length == 0) revert AssetManagerFacet__EmptyString();
        if (bytes(p.symbol).length == 0) revert AssetManagerFacet__EmptyString();

        AssetStorage storage s = LibAssetStorage.layout();
        if (s.configs[p.tokenId].exists) revert AssetManagerFacet__AlreadyRegistered(p.tokenId);

        AssetConfig storage cfg = s.configs[p.tokenId];
        cfg.name = p.name;
        cfg.symbol = p.symbol;
        cfg.uri = p.uri;
        cfg.supplyCap = p.supplyCap;
        cfg.totalSupply = 0;
        cfg.identityProfileId = p.identityProfileId;
        cfg.complianceModule = p.complianceModule;
        cfg.issuer = p.issuer;
        cfg.paused = false;
        cfg.exists = true;
        cfg.allowedCountries = p.allowedCountries;

        s.registeredTokenIds.push(p.tokenId);

        emit AssetRegistered(p.tokenId, p.issuer, p.identityProfileId);
        if (p.complianceModule != address(0)) {
            emit ComplianceModuleSet(p.tokenId, p.complianceModule);
        }
    }

    /// @notice Replaces the compliance module for a tokenId.
    ///         Pass address(0) to remove module (unrestricted transfers).
    function setComplianceModule(uint256 tokenId, address module) external {
        _enforceComplianceAdminOrOwner();
        _requireRegistered(tokenId);
        LibAssetStorage.layout().configs[tokenId].complianceModule = module;
        emit ComplianceModuleSet(tokenId, module);
    }

    /// @notice Updates the identity profile used for KYC verification on this asset.
    function setIdentityProfile(uint256 tokenId, uint32 profileId) external {
        _enforceComplianceAdminOrOwner();
        _requireRegistered(tokenId);
        LibAssetStorage.layout().configs[tokenId].identityProfileId = profileId;
        emit AssetConfigUpdated(tokenId);
    }

    /// @notice Updates the authorized minter (issuer) for a tokenId.
    ///         Only Diamond owner can change issuer — higher privilege than COMPLIANCE_ADMIN.
    function setIssuer(uint256 tokenId, address issuer) external {
        LibDiamond.enforceIsContractOwner();
        _requireRegistered(tokenId);
        if (issuer == address(0)) revert AssetManagerFacet__ZeroAddress();
        LibAssetStorage.layout().configs[tokenId].issuer = issuer;
        emit AssetConfigUpdated(tokenId);
    }

    /// @notice Updates the supply cap. Pass 0 for unlimited.
    function setSupplyCap(uint256 tokenId, uint256 cap) external {
        _enforceComplianceAdminOrOwner();
        _requireRegistered(tokenId);
        LibAssetStorage.layout().configs[tokenId].supplyCap = cap;
        emit AssetConfigUpdated(tokenId);
    }

    /// @notice Replaces the allowed jurisdictions for a tokenId.
    ///         Pass empty array to allow all countries.
    function setAllowedCountries(uint256 tokenId, uint16[] calldata countries) external {
        _enforceComplianceAdminOrOwner();
        _requireRegistered(tokenId);
        LibAssetStorage.layout().configs[tokenId].allowedCountries = countries;
        emit AssetConfigUpdated(tokenId);
    }

    /// @notice Updates the metadata URI for a tokenId.
    function setAssetUri(uint256 tokenId, string calldata uri) external {
        _enforceComplianceAdminOrOwner();
        _requireRegistered(tokenId);
        LibAssetStorage.layout().configs[tokenId].uri = uri;
        emit AssetConfigUpdated(tokenId);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the full AssetConfig for a tokenId.
    function getAssetConfig(uint256 tokenId) external view returns (AssetConfig memory) {
        return LibAssetStorage.layout().configs[tokenId];
    }

    /// @notice Returns all registered tokenIds in registration order.
    function getRegisteredTokenIds() external view returns (uint256[] memory) {
        return LibAssetStorage.layout().registeredTokenIds;
    }

    /// @notice Returns true if the tokenId has been registered.
    function assetExists(uint256 tokenId) external view returns (bool) {
        return LibAssetStorage.layout().configs[tokenId].exists;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");

    function _enforceComplianceAdminOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isAdmin = LibAccessStorage.layout().roles[COMPLIANCE_ADMIN][msg.sender];
        if (!isOwner && !isAdmin) revert AssetManagerFacet__Unauthorized();
    }

    function _requireRegistered(uint256 tokenId) internal view {
        if (!LibAssetStorage.layout().configs[tokenId].exists) {
            revert AssetManagerFacet__NotRegistered(tokenId);
        }
    }
}
