// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";
import {MockComplianceModule} from "../helpers/MockComplianceModule.sol";
import {ComplianceRouterFacet} from "../../src/facets/compliance/ComplianceRouterFacet.sol";
import {AssetManagerFacet} from "../../src/facets/token/AssetManagerFacet.sol";
import {IAssetManager} from "../../src/interfaces/token/IAssetManager.sol";
import {LibReasonCodes} from "../../src/libraries/LibReasonCodes.sol";

contract ComplianceRouterFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    ComplianceRouterFacet internal router;
    AssetManagerFacet internal am;
    MockComplianceModule internal mockModule;

    uint256 internal constant TOKEN_ID = 1;

    function setUp() public {
        d = deployDiamond(owner);
        router = ComplianceRouterFacet(address(d.diamond));
        am = AssetManagerFacet(address(d.diamond));
        mockModule = new MockComplianceModule();

        // Register asset with no compliance module
        uint16[] memory countries = new uint16[](0);
        vm.prank(owner);
        am.registerAsset(
            IAssetManager.RegisterAssetParams({
                tokenId: TOKEN_ID,
                name: "Test",
                symbol: "TST",
                uri: "https://test.com",
                supplyCap: 0,
                identityProfileId: 0,
                complianceModule: address(0),
                issuer: owner,
                allowedCountries: countries
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                        CAN TRANSFER — NO MODULE
    //////////////////////////////////////////////////////////////*/

    function test_CanTransfer_NoModule_ReturnsTrue() public view {
        (bool ok, bytes32 reason) = router.canTransfer(TOKEN_ID, alice, bob, 100, "");
        assertTrue(ok);
        assertEq(reason, LibReasonCodes.REASON_OK);
    }

    /*//////////////////////////////////////////////////////////////
                    CAN TRANSFER — WITH MODULE
    //////////////////////////////////////////////////////////////*/

    function test_CanTransfer_ModuleApproves() public {
        _setModule(address(mockModule));

        (bool ok, bytes32 reason) = router.canTransfer(TOKEN_ID, alice, bob, 100, "");
        assertTrue(ok);
        assertEq(reason, bytes32(0));
    }

    function test_CanTransfer_ModuleRejects() public {
        _setModule(address(mockModule));
        mockModule.setResult(false, LibReasonCodes.REASON_COUNTRY_RESTRICTED);

        (bool ok, bytes32 reason) = router.canTransfer(TOKEN_ID, alice, bob, 100, "");
        assertFalse(ok);
        assertEq(reason, LibReasonCodes.REASON_COUNTRY_RESTRICTED);
    }

    function test_CanTransfer_ModuleRejects_HoldingLimit() public {
        _setModule(address(mockModule));
        mockModule.setResult(false, LibReasonCodes.REASON_HOLDING_LIMIT);

        (bool ok, bytes32 reason) = router.canTransfer(TOKEN_ID, alice, bob, 1_000_000, "");
        assertFalse(ok);
        assertEq(reason, LibReasonCodes.REASON_HOLDING_LIMIT);
    }

    /*//////////////////////////////////////////////////////////////
                    CAN TRANSFER — UNREGISTERED ASSET
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_CanTransfer_AssetNotRegistered() public {
        vm.expectRevert(
            abi.encodeWithSignature("ComplianceRouterFacet__AssetNotRegistered(uint256)", 999)
        );
        router.canTransfer(999, alice, bob, 100, "");
    }

    /*//////////////////////////////////////////////////////////////
                        POST-TRANSFER HOOKS
    //////////////////////////////////////////////////////////////*/

    function test_Transferred_NoModule_Noop() public {
        // Should not revert when no module
        router.transferred(TOKEN_ID, alice, bob, 100);
    }

    function test_Transferred_ForwardsToModule() public {
        _setModule(address(mockModule));

        router.transferred(TOKEN_ID, alice, bob, 100);
        assertEq(mockModule.transferredCount(), 1);
    }

    function test_Minted_ForwardsToModule() public {
        _setModule(address(mockModule));

        router.minted(TOKEN_ID, alice, 500);
        assertEq(mockModule.mintedCount(), 1);
    }

    function test_Burned_ForwardsToModule() public {
        _setModule(address(mockModule));

        router.burned(TOKEN_ID, alice, 200);
        assertEq(mockModule.burnedCount(), 1);
    }

    function test_Minted_NoModule_Noop() public {
        router.minted(TOKEN_ID, alice, 500);
    }

    function test_Burned_NoModule_Noop() public {
        router.burned(TOKEN_ID, alice, 200);
    }

    /*//////////////////////////////////////////////////////////////
                        GET COMPLIANCE MODULE
    //////////////////////////////////////////////////////////////*/

    function test_GetComplianceModule_ReturnsZero_WhenNotSet() public view {
        assertEq(router.getComplianceModule(TOKEN_ID), address(0));
    }

    function test_GetComplianceModule_ReturnsModule() public {
        _setModule(address(mockModule));
        assertEq(router.getComplianceModule(TOKEN_ID), address(mockModule));
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_CanTransfer_ReasonPropagation(bool ok_, bytes32 reason_) public {
        _setModule(address(mockModule));
        mockModule.setResult(ok_, reason_);

        (bool ok, bytes32 reason) = router.canTransfer(TOKEN_ID, alice, bob, 100, "");
        assertEq(ok, ok_);
        assertEq(reason, reason_);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _setModule(address module) internal {
        vm.prank(owner);
        am.setComplianceModule(TOKEN_ID, module);
    }
}
