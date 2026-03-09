// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
}

interface IPause {
    function pauseProtocol() external;
    function unpauseProtocol() external;
    function pauseAsset(uint256 tokenId) external;
    function unpauseAsset(uint256 tokenId) external;
    function isProtocolPaused() external view returns (bool);
    function isAssetPaused(uint256 tokenId) external view returns (bool);
}

contract PauseFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IPause internal pause;
    IAccessControl internal ac;

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        d = deployDiamond(owner);
        pause = IPause(address(d.diamond));
        ac = IAccessControl(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_ProtocolNotPausedByDefault() public view {
        assertFalse(pause.isProtocolPaused());
    }

    /*//////////////////////////////////////////////////////////////
                            GLOBAL PAUSE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanPauseProtocol() public {
        vm.prank(owner);
        pause.pauseProtocol();
        assertTrue(pause.isProtocolPaused());
    }

    function test_PauseProtocol_EmitsEmergencyPause() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false, address(d.diamond));
        emit EmergencyPause(owner);
        pause.pauseProtocol();
    }

    function test_OwnerCanUnpauseProtocol() public {
        vm.startPrank(owner);
        pause.pauseProtocol();
        pause.unpauseProtocol();
        vm.stopPrank();
        assertFalse(pause.isProtocolPaused());
    }

    function test_Unpause_EmitsEvent() public {
        vm.startPrank(owner);
        pause.pauseProtocol();
        vm.expectEmit(true, false, false, false, address(d.diamond));
        emit ProtocolUnpaused(owner);
        pause.unpauseProtocol();
        vm.stopPrank();
    }

    function test_RevertWhen_PauseAlreadyPaused() public {
        vm.startPrank(owner);
        pause.pauseProtocol();
        vm.expectRevert(abi.encodeWithSignature("PauseFacet__AlreadyPaused()"));
        pause.pauseProtocol();
        vm.stopPrank();
    }

    function test_RevertWhen_UnpauseWhenNotPaused() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("PauseFacet__NotPaused()"));
        pause.unpauseProtocol();
    }

    function test_RevertWhen_NonOwnerPausesProtocol() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        pause.pauseProtocol();
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET-LEVEL PAUSE
    //////////////////////////////////////////////////////////////*/

    // Asset pause tests require a registered asset — PauseFacet checks exists flag.
    // Since AssetManagerFacet is not yet deployed, we test the error path here
    // and the happy path will be covered in integration tests (feat/asset-manager).

    function test_RevertWhen_PauseUnregisteredAsset() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSignature("PauseFacet__AssetNotRegistered(uint256)", 1)
        );
        pause.pauseAsset(1);
    }

    function test_RevertWhen_UnauthorizedPausesAsset() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("PauseFacet__Unauthorized()"));
        pause.pauseAsset(1);
    }

    function test_PauserRoleCanAttemptAssetPause() public {
        address pauser = makeAddr("pauser");
        vm.prank(owner);
        ac.grantRole(PAUSER_ROLE, pauser);

        // Asset not registered — but access check passes, revert is AssetNotRegistered
        vm.prank(pauser);
        vm.expectRevert(
            abi.encodeWithSignature("PauseFacet__AssetNotRegistered(uint256)", 42)
        );
        pause.pauseAsset(42);
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_OnlyOwnerCanPauseProtocol(address caller) public {
        vm.assume(caller != owner);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("LibDiamond__OnlyOwner()"));
        pause.pauseProtocol();
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EmergencyPause(address indexed triggeredBy);
    event ProtocolUnpaused(address indexed by);
}
