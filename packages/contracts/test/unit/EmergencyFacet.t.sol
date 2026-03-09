// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondHelper} from "../helpers/DiamondHelper.sol";

interface IAccessControl {
    function grantRole(bytes32 role, address account) external;
}

interface IEmergency {
    function emergencyPause() external;
    function isEmergencyPaused() external view returns (bool);
}

contract EmergencyFacetTest is DiamondHelper {
    DeployedDiamond internal d;
    address internal owner = makeAddr("owner");
    IEmergency internal emergency;
    IAccessControl internal ac;

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function setUp() public {
        d = deployDiamond(owner);
        emergency = IEmergency(address(d.diamond));
        ac = IAccessControl(address(d.diamond));
    }

    /*//////////////////////////////////////////////////////////////
                            INITIAL STATE
    //////////////////////////////////////////////////////////////*/

    function test_NotPausedByDefault() public view {
        assertFalse(emergency.isEmergencyPaused());
    }

    /*//////////////////////////////////////////////////////////////
                        EMERGENCY PAUSE
    //////////////////////////////////////////////////////////////*/

    function test_OwnerCanEmergencyPause() public {
        vm.prank(owner);
        emergency.emergencyPause();
        assertTrue(emergency.isEmergencyPaused());
    }

    function test_PauserRoleCanEmergencyPause() public {
        address pauser = makeAddr("pauser");
        vm.prank(owner);
        ac.grantRole(PAUSER_ROLE, pauser);

        vm.prank(pauser);
        emergency.emergencyPause();
        assertTrue(emergency.isEmergencyPaused());
    }

    function test_EmergencyPause_EmitsEvent() public {
        vm.prank(owner);
        vm.expectEmit(true, false, false, false, address(d.diamond));
        emit EmergencyPause(owner);
        emergency.emergencyPause();
    }

    function test_RevertWhen_AlreadyPaused() public {
        vm.startPrank(owner);
        emergency.emergencyPause();
        vm.expectRevert(abi.encodeWithSignature("EmergencyFacet__AlreadyPaused()"));
        emergency.emergencyPause();
        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedCallsEmergencyPause() public {
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSignature("EmergencyFacet__Unauthorized()"));
        emergency.emergencyPause();
    }

    /// @dev EmergencyFacet writes to the same globalPaused slot as PauseFacet.
    ///      Verifies storage is shared via LibAppStorage.
    function test_EmergencyPause_SharedStorageWithPauseFacet() public {
        vm.prank(owner);
        emergency.emergencyPause();

        // PauseFacet.isProtocolPaused() reads same slot
        (bool ok, bytes memory data) =
            address(d.diamond).staticcall(abi.encodeWithSignature("isProtocolPaused()"));
        assertTrue(ok);
        assertTrue(abi.decode(data, (bool)));
    }

    /*//////////////////////////////////////////////////////////////
                                FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_OnlyPauserOrOwnerCanEmergencyPause(address caller) public {
        vm.assume(caller != owner);
        // caller has no role
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("EmergencyFacet__Unauthorized()"));
        emergency.emergencyPause();
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EmergencyPause(address indexed triggeredBy);
}
