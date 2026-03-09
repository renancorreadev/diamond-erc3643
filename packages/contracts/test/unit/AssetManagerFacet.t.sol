// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {AssetConfig} from "../../src/storage/LibAssetStorage.sol";
import {IAssetManager} from "../../src/interfaces/token/IAssetManager.sol";

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
}

interface IAsset {
    function registerAsset(IAssetManager.RegisterAssetParams calldata p) external;
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

contract AssetManagerFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IAsset internal asset;
    IAccessControl internal ac;

    bytes32 internal constant COMPLIANCE_ADMIN = keccak256("COMPLIANCE_ADMIN");

    address internal issuer = makeAddr("issuer");
    address internal module = makeAddr("module");
    uint256 internal constant TOKEN_ID = 1;

    IAssetManager.RegisterAssetParams internal baseParams;

    function setUp() public {
        d = deployDiamond(owner);
        asset = IAsset(address(d.diamond));
        ac = IAccessControl(address(d.diamond));

        baseParams = IAssetManager.RegisterAssetParams({
            tokenId: TOKEN_ID,
            name: "Real Estate Fund A",
            symbol: "REFA",
            uri: "ipfs://QmXxx",
            supplyCap: 1_000_000e18,
            identityProfileId: 1,
            complianceModule: module,
            issuer: issuer,
            allowedCountries: new uint16[](0)
        });
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_AssetNotExistsByDefault() public view {
        assertFalse(asset.assetExists(TOKEN_ID));
    }

    function test_RegisteredTokenIdsEmptyByDefault() public view {
        assertEq(asset.getRegisteredTokenIds().length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        REGISTER ASSET
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanRegisterAsset() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);

        assertTrue(asset.assetExists(TOKEN_ID));
        AssetConfig memory cfg = asset.getAssetConfig(TOKEN_ID);
        assertEq(cfg.name, "Real Estate Fund A");
        assertEq(cfg.symbol, "REFA");
        assertEq(cfg.uri, "ipfs://QmXxx");
        assertEq(cfg.supplyCap, 1_000_000e18);
        assertEq(cfg.totalSupply, 0);
        assertEq(cfg.identityProfileId, 1);
        assertEq(cfg.complianceModule, module);
        assertEq(cfg.issuer, issuer);
        assertFalse(cfg.paused);
        assertTrue(cfg.exists);
    }

    function test_RegisterAsset_AddsToRegisteredList() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);

        uint256[] memory ids = asset.getRegisteredTokenIds();
        assertEq(ids.length, 1);
        assertEq(ids[0], TOKEN_ID);
    }

    function test_RegisterAsset_EmitsAssetRegistered() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, true, address(d.diamond));
        emit AssetRegistered(TOKEN_ID, issuer, 1);
        asset.registerAsset(baseParams);
    }

    function test_RegisterAsset_EmitsComplianceModuleSet() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(d.diamond));
        emit ComplianceModuleSet(TOKEN_ID, module);
        asset.registerAsset(baseParams);
    }

    function test_ComplianceAdminCanRegisterAsset() public {
        address admin = makeAddr("admin");
        vm.prank(owner);
        ac.grantRole(COMPLIANCE_ADMIN, admin);

        vm.prank(admin);
        asset.registerAsset(baseParams);
        assertTrue(asset.assetExists(TOKEN_ID));
    }

    function test_RegisterMultipleAssets() public {
        IAssetManager.RegisterAssetParams memory p2 = baseParams;
        p2.tokenId = 2;
        p2.symbol = "REFB";

        vm.startPrank(owner);
        asset.registerAsset(baseParams);
        asset.registerAsset(p2);
        vm.stopPrank();

        assertEq(asset.getRegisteredTokenIds().length, 2);
        assertTrue(asset.assetExists(1));
        assertTrue(asset.assetExists(2));
    }

    function test_RevertWhen_RegisterDuplicateTokenId() public {
        vm.startPrank(owner);
        asset.registerAsset(baseParams);
        vm.expectRevert(
            abi.encodeWithSignature("AssetManagerFacet__AlreadyRegistered(uint256)", TOKEN_ID)
        );
        asset.registerAsset(baseParams);
        vm.stopPrank();
    }

    function test_RevertWhen_RegisterWithZeroIssuer() public {
        baseParams.issuer = address(0);
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("AssetManagerFacet__ZeroAddress()"));
        asset.registerAsset(baseParams);
    }

    function test_RevertWhen_RegisterWithEmptyName() public {
        baseParams.name = "";
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("AssetManagerFacet__EmptyString()"));
        asset.registerAsset(baseParams);
    }

    function test_RevertWhen_RegisterWithEmptySymbol() public {
        baseParams.symbol = "";
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("AssetManagerFacet__EmptyString()"));
        asset.registerAsset(baseParams);
    }

    function test_RevertWhen_UnauthorizedRegisters() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("AssetManagerFacet__Unauthorized()"));
        asset.registerAsset(baseParams);
    }

    /*//////////////////////////////////////////////////////////////
                        SET COMPLIANCE MODULE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetComplianceModule() public {
        address newModule = makeAddr("newModule");
        vm.prank(owner);
        asset.registerAsset(baseParams);

        vm.prank(owner);
        asset.setComplianceModule(TOKEN_ID, newModule);
        assertEq(asset.getAssetConfig(TOKEN_ID).complianceModule, newModule);
    }

    function test_SetComplianceModule_EmitsEvent() public {
        address newModule = makeAddr("newModule");
        vm.prank(owner);
        asset.registerAsset(baseParams);

        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(d.diamond));
        emit ComplianceModuleSet(TOKEN_ID, newModule);
        asset.setComplianceModule(TOKEN_ID, newModule);
    }

    function test_SetComplianceModuleToZero_RemovesRestrictions() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setComplianceModule(TOKEN_ID, address(0));
        assertEq(asset.getAssetConfig(TOKEN_ID).complianceModule, address(0));
    }

    function test_RevertWhen_SetModuleOnUnregistered() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("AssetManagerFacet__NotRegistered(uint256)", TOKEN_ID)
        );
        asset.setComplianceModule(TOKEN_ID, module);
    }

    /*//////////////////////////////////////////////////////////////
                        SET IDENTITY PROFILE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetIdentityProfile() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setIdentityProfile(TOKEN_ID, 99);
        assertEq(asset.getAssetConfig(TOKEN_ID).identityProfileId, 99);
    }

    function test_RevertWhen_SetProfileOnUnregistered() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("AssetManagerFacet__NotRegistered(uint256)", TOKEN_ID)
        );
        asset.setIdentityProfile(TOKEN_ID, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            SET ISSUER
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetIssuer() public {
        address newIssuer = makeAddr("newIssuer");
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setIssuer(TOKEN_ID, newIssuer);
        assertEq(asset.getAssetConfig(TOKEN_ID).issuer, newIssuer);
    }

    function test_RevertWhen_ComplianceAdminSetsIssuer() public {
        address admin = makeAddr("admin");
        vm.prank(owner);
        ac.grantRole(COMPLIANCE_ADMIN, admin);
        vm.prank(owner);
        asset.registerAsset(baseParams);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        asset.setIssuer(TOKEN_ID, makeAddr("x"));
    }

    /*//////////////////////////////////////////////////////////////
                            SET SUPPLY CAP
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetSupplyCap() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setSupplyCap(TOKEN_ID, 500e18);
        assertEq(asset.getAssetConfig(TOKEN_ID).supplyCap, 500e18);
    }

    function test_SetSupplyCapToZero_IsUnlimited() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setSupplyCap(TOKEN_ID, 0);
        assertEq(asset.getAssetConfig(TOKEN_ID).supplyCap, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        SET ALLOWED COUNTRIES
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetAllowedCountries() public {
        uint16[] memory countries = new uint16[](2);
        countries[0] = 76;  // Brazil
        countries[1] = 840; // United States

        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setAllowedCountries(TOKEN_ID, countries);

        AssetConfig memory cfg = asset.getAssetConfig(TOKEN_ID);
        assertEq(cfg.allowedCountries.length, 2);
        assertEq(cfg.allowedCountries[0], 76);
        assertEq(cfg.allowedCountries[1], 840);
    }

    function test_SetAllowedCountriesEmpty_AllowsAll() public {
        uint16[] memory countries = new uint16[](0);
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setAllowedCountries(TOKEN_ID, countries);
        assertEq(asset.getAssetConfig(TOKEN_ID).allowedCountries.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                            SET URI
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanSetUri() public {
        vm.prank(owner);
        asset.registerAsset(baseParams);
        vm.prank(owner);
        asset.setAssetUri(TOKEN_ID, "ipfs://QmNewHash");
        assertEq(asset.getAssetConfig(TOKEN_ID).uri, "ipfs://QmNewHash");
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_RegisterAndQueryAsset(uint256 tokenId, uint256 supplyCap) public {
        vm.assume(tokenId != 0);

        IAssetManager.RegisterAssetParams memory p = IAssetManager.RegisterAssetParams({
            tokenId: tokenId,
            name: "Fuzz Asset",
            symbol: "FUZZ",
            uri: "",
            supplyCap: supplyCap,
            identityProfileId: 0,
            complianceModule: address(0),
            issuer: issuer,
            allowedCountries: new uint16[](0)
        });

        vm.prank(owner);
        asset.registerAsset(p);

        assertTrue(asset.assetExists(tokenId));
        assertEq(asset.getAssetConfig(tokenId).supplyCap, supplyCap);
        assertEq(asset.getAssetConfig(tokenId).totalSupply, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AssetRegistered(uint256 indexed tokenId, address indexed issuer, uint32 profileId);
    event AssetConfigUpdated(uint256 indexed tokenId);
    event ComplianceModuleSet(uint256 indexed tokenId, address indexed module);
}
