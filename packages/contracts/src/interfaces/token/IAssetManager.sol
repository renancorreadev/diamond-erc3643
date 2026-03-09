// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AssetConfig} from "../../storage/LibAssetStorage.sol";

interface IAssetManager {
    struct RegisterAssetParams {
        uint256 tokenId;
        string name;
        string symbol;
        string uri;
        uint256 supplyCap;
        uint32 identityProfileId;
        address complianceModule;
        address issuer;
        uint16[] allowedCountries;
    }

    function registerAsset(RegisterAssetParams calldata params) external;
    function setComplianceModule(uint256 tokenId, address module) external;
    function setIdentityProfile(uint256 tokenId, uint32 profileId) external;
    function setIssuer(uint256 tokenId, address issuer) external;
    function setSupplyCap(uint256 tokenId, uint256 cap) external;
    function setAllowedCountries(uint256 tokenId, uint16[] calldata countries) external;
    function setAssetUri(uint256 tokenId, string calldata uri) external;

    function getAssetConfig(uint256 tokenId) external view returns (AssetConfig memory);
    function getRegisteredTokenIds() external view returns (uint256[] memory);
    function assetExists(uint256 tokenId) external view returns (bool);
}
