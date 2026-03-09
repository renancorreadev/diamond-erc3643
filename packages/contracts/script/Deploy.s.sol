// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console2} from "forge-std/Script.sol";

import {Diamond} from "../src/Diamond.sol";
import {DiamondInit} from "../src/initializers/DiamondInit.sol";
import {DiamondCutFacet} from "../src/facets/core/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/facets/core/DiamondLoupeFacet.sol";
import {OwnershipFacet} from "../src/facets/core/OwnershipFacet.sol";
import {IDiamond, IDiamondCut, IDiamondLoupe} from "../src/interfaces/core/IDiamond.sol";
// solhint-disable-next-line import-path-check
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title Deploy
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Deploys the Diamond proxy with core facets and initializes ERC-165 interfaces.
///
/// Usage (local):
///   anvil &
///   forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast -vvvv
///
/// Usage (production — never use plain --private-key):
///   cast wallet import deployer --interactive
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --account deployer --broadcast -vvvv
contract Deploy is Script {
    function run() external {
        address owner = vm.envOr("OWNER_ADDRESS", msg.sender);

        vm.startBroadcast();

        // 1. Deploy facets
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        DiamondInit diamondInit = new DiamondInit();

        console2.log("DiamondCutFacet  :", address(cutFacet));
        console2.log("DiamondLoupeFacet:", address(loupeFacet));
        console2.log("OwnershipFacet   :", address(ownershipFacet));
        console2.log("DiamondInit      :", address(diamondInit));

        // 2. Deploy Diamond — registers DiamondCutFacet internally
        Diamond diamond = new Diamond(owner, address(cutFacet));
        console2.log("Diamond          :", address(diamond));

        // 3. Build cuts for remaining core facets
        IDiamond.FacetCut[] memory cuts = new IDiamond.FacetCut[](2);

        cuts[0] = IDiamond.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _loupeSelectors()
        });

        cuts[1] = IDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: _ownershipSelectors()
        });

        // 4. Execute cut + initialize ERC-165 interfaces via delegatecall
        IDiamondCut(address(diamond)).diamondCut(
            cuts,
            address(diamondInit),
            abi.encodeCall(DiamondInit.init, ())
        );

        vm.stopBroadcast();

        // 5. Verify
        _verify(diamond, cutFacet, loupeFacet, ownershipFacet, owner);
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
        sels[4] = IERC165.supportsInterface.selector;
    }

    function _ownershipSelectors() internal pure returns (bytes4[] memory sels) {
        sels = new bytes4[](4);
        sels[0] = OwnershipFacet.transferOwnership.selector;
        sels[1] = OwnershipFacet.acceptOwnership.selector;
        sels[2] = OwnershipFacet.owner.selector;
        sels[3] = OwnershipFacet.pendingOwner.selector;
    }

    /*//////////////////////////////////////////////////////////////
                            POST-DEPLOY ASSERTIONS
    //////////////////////////////////////////////////////////////*/

    function _verify(
        Diamond diamond,
        DiamondCutFacet cutFacet,
        DiamondLoupeFacet loupeFacet,
        OwnershipFacet ownershipFacet,
        address expectedOwner
    ) internal view {
        address[] memory facetAddrs = IDiamondLoupe(address(diamond)).facetAddresses();
        require(facetAddrs.length == 3, "Deploy: wrong facet count");

        require(
            IDiamondLoupe(address(diamond)).facetAddress(IDiamondCut.diamondCut.selector)
                == address(cutFacet),
            "Deploy: cut facet mismatch"
        );
        require(
            IDiamondLoupe(address(diamond)).facetAddress(IDiamondLoupe.facets.selector)
                == address(loupeFacet),
            "Deploy: loupe facet mismatch"
        );
        require(
            IDiamondLoupe(address(diamond)).facetAddress(OwnershipFacet.owner.selector)
                == address(ownershipFacet),
            "Deploy: ownership facet mismatch"
        );

        require(
            IERC165(address(diamond)).supportsInterface(type(IERC165).interfaceId),
            "Deploy: missing IERC165"
        );
        require(
            IERC165(address(diamond)).supportsInterface(type(IDiamondCut).interfaceId),
            "Deploy: missing IDiamondCut"
        );
        require(
            IERC165(address(diamond)).supportsInterface(type(IDiamondLoupe).interfaceId),
            "Deploy: missing IDiamondLoupe"
        );

        require(
            OwnershipFacet(address(diamond)).owner() == expectedOwner,
            "Deploy: wrong owner"
        );

        console2.log("Verification OK");
        console2.log("Owner            :", expectedOwner);
        console2.log("Facets registered:", facetAddrs.length);
    }
}
