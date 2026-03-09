// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../../src/Diamond.sol";
import {DiamondCutFacet} from "../../src/facets/core/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/facets/core/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/facets/core/OwnershipFacet.sol";
import {AccessControlFacet} from "../../src/facets/security/AccessControlFacet.sol";
import {PauseFacet} from "../../src/facets/security/PauseFacet.sol";
import {EmergencyFacet} from "../../src/facets/security/EmergencyFacet.sol";
import {FreezeFacet} from "../../src/facets/rwa/FreezeFacet.sol";
import {AssetManagerFacet} from "../../src/facets/token/AssetManagerFacet.sol";
import {IDiamond, IDiamondCut, IDiamondLoupe} from "../../src/interfaces/core/IDiamond.sol";
import {DiamondInit} from "../../src/initializers/DiamondInit.sol";

contract DiamondHelper is Test {
    struct DeployedDiamond {
        Diamond diamond;
        DiamondCutFacet cutFacet;
        DiamondLoupeFacet loupeFacet;
        OwnershipFacet ownershipFacet;
        AccessControlFacet accessControlFacet;
        PauseFacet pauseFacet;
        EmergencyFacet emergencyFacet;
        FreezeFacet freezeFacet;
        AssetManagerFacet assetManagerFacet;
    }

    function deployDiamond(address owner) internal returns (DeployedDiamond memory d) {
        d.cutFacet = new DiamondCutFacet();
        d.loupeFacet = new DiamondLoupeFacet();
        d.ownershipFacet = new OwnershipFacet();
        d.accessControlFacet = new AccessControlFacet();
        d.pauseFacet = new PauseFacet();
        d.emergencyFacet = new EmergencyFacet();
        d.freezeFacet = new FreezeFacet();
        d.assetManagerFacet = new AssetManagerFacet();
        DiamondInit diamondInit = new DiamondInit();

        d.diamond = new Diamond(owner, address(d.cutFacet));

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](7);

        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(d.loupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _loupeSelectors()
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(d.ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _ownershipSelectors()
        });
        cuts[2] = IDiamond.FacetCut({
            facetAddress: address(d.accessControlFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _accessControlSelectors()
        });
        cuts[3] = IDiamond.FacetCut({
            facetAddress: address(d.pauseFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _pauseSelectors()
        });
        cuts[4] = IDiamond.FacetCut({
            facetAddress: address(d.emergencyFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _emergencySelectors()
        });
        cuts[5] = IDiamond.FacetCut({
            facetAddress: address(d.freezeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _freezeSelectors()
        });
        cuts[6] = IDiamond.FacetCut({
            facetAddress: address(d.assetManagerFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _assetManagerSelectors()
        });

        vm.prank(owner);
        IDiamondCut(address(d.diamond)).diamondCut(
            cuts, address(diamondInit), abi.encodeCall(DiamondInit.init, ())
        );
    }

    /*//////////////////////////////////////////////////////////////
                        SELECTOR BUILDERS
    //////////////////////////////////////////////////////////////*/

    function _loupeSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](5);
        sels[0] = IDiamondLoupe.facets.selector;
        sels[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        sels[2] = IDiamondLoupe.facetAddresses.selector;
        sels[3] = IDiamondLoupe.facetAddress.selector;
        sels[4] = bytes4(keccak256("supportsInterface(bytes4)"));
    }

    function _ownershipSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](4);
        sels[0] = OwnershipFacet.transferOwnership.selector;
        sels[1] = OwnershipFacet.acceptOwnership.selector;
        sels[2] = OwnershipFacet.owner.selector;
        sels[3] = OwnershipFacet.pendingOwner.selector;
    }

    function _accessControlSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](6);
        sels[0] = AccessControlFacet.grantRole.selector;
        sels[1] = AccessControlFacet.revokeRole.selector;
        sels[2] = AccessControlFacet.renounceRole.selector;
        sels[3] = AccessControlFacet.setRoleAdmin.selector;
        sels[4] = AccessControlFacet.hasRole.selector;
        sels[5] = AccessControlFacet.getRoleAdmin.selector;
    }

    function _pauseSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](6);
        sels[0] = PauseFacet.pauseProtocol.selector;
        sels[1] = PauseFacet.unpauseProtocol.selector;
        sels[2] = PauseFacet.pauseAsset.selector;
        sels[3] = PauseFacet.unpauseAsset.selector;
        sels[4] = PauseFacet.isProtocolPaused.selector;
        sels[5] = PauseFacet.isAssetPaused.selector;
    }

    function _emergencySelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](2);
        sels[0] = EmergencyFacet.emergencyPause.selector;
        sels[1] = EmergencyFacet.isEmergencyPaused.selector;
    }

    function _freezeSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](8);
        sels[0] = FreezeFacet.setWalletFrozen.selector;
        sels[1] = FreezeFacet.setAssetWalletFrozen.selector;
        sels[2] = FreezeFacet.setFrozenAmount.selector;
        sels[3] = FreezeFacet.setLockupExpiry.selector;
        sels[4] = FreezeFacet.isWalletFrozen.selector;
        sels[5] = FreezeFacet.isAssetWalletFrozen.selector;
        sels[6] = FreezeFacet.getFrozenAmount.selector;
        sels[7] = FreezeFacet.getLockupExpiry.selector;
    }

    function _assetManagerSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](10);
        sels[0] = AssetManagerFacet.registerAsset.selector;
        sels[1] = AssetManagerFacet.setComplianceModule.selector;
        sels[2] = AssetManagerFacet.setIdentityProfile.selector;
        sels[3] = AssetManagerFacet.setIssuer.selector;
        sels[4] = AssetManagerFacet.setSupplyCap.selector;
        sels[5] = AssetManagerFacet.setAllowedCountries.selector;
        sels[6] = AssetManagerFacet.setAssetUri.selector;
        sels[7] = AssetManagerFacet.getAssetConfig.selector;
        sels[8] = AssetManagerFacet.getRegisteredTokenIds.selector;
        sels[9] = AssetManagerFacet.assetExists.selector;
    }
}
