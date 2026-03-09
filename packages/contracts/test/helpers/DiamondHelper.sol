// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../../src/Diamond.sol";
import {DiamondCutFacet} from "../../src/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../../src/facets/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../../src/facets/OwnershipFacet.sol";
import {IDiamond, IDiamondCut, IDiamondLoupe} from "../../src/interfaces/IDiamond.sol";
import {DiamondInit} from "../../src/initializers/DiamondInit.sol";

contract DiamondHelper is Test {
    struct DeployedDiamond {
        Diamond diamond;
        DiamondCutFacet cutFacet;
        DiamondLoupeFacet loupeFacet;
        OwnershipFacet ownershipFacet;
    }

    function deployDiamond(address owner) internal returns (DeployedDiamond memory d) {
        d.cutFacet = new DiamondCutFacet();
        d.loupeFacet = new DiamondLoupeFacet();
        d.ownershipFacet = new OwnershipFacet();
        DiamondInit diamondInit = new DiamondInit();

        d.diamond = new Diamond(owner, address(d.cutFacet));

        // Add DiamondLoupeFacet
        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));

        // Add OwnershipFacet
        bytes4[] memory ownershipSelectors = new bytes4[](4);
        ownershipSelectors[0] = bytes4(keccak256("transferOwnership(address)"));
        ownershipSelectors[1] = bytes4(keccak256("acceptOwnership()"));
        ownershipSelectors[2] = bytes4(keccak256("owner()"));
        ownershipSelectors[3] = bytes4(keccak256("pendingOwner()"));

        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](2);
        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(d.loupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });
        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(d.ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        vm.prank(owner);
        IDiamondCut(address(d.diamond)).diamondCut(
            cuts, address(diamondInit), abi.encodeCall(DiamondInit.init, ())
        );
    }
}
