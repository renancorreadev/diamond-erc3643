// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibAppStorage, AppStorage} from "../../libraries/LibAppStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error EmergencyFacet__Unauthorized();
error EmergencyFacet__AlreadyPaused();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title EmergencyFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Circuit breaker that operates outside the normal timelock.
///         Allows PAUSER_ROLE holders to trigger a global pause instantly
///         in response to a security incident — no multisig delay required.
///         Unpausing always requires the Diamond owner (governance path).
/// @custom:security-contact renan.correa@hubweb3.com
contract EmergencyFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EmergencyPause(address indexed triggeredBy);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Instantly pauses the entire protocol.
    ///         Callable by Diamond owner OR any PAUSER_ROLE holder.
    ///         Does NOT require multisig or timelock — emergency use only.
    function emergencyPause() external {
        _enforcePauserOrOwner();
        AppStorage storage s = LibAppStorage.layout();
        if (s.globalPaused) revert EmergencyFacet__AlreadyPaused();
        s.globalPaused = true;
        emit EmergencyPause(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if the protocol is globally paused.
    function isEmergencyPaused() external view returns (bool) {
        return LibAppStorage.layout().globalPaused;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function _enforcePauserOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isPauser = LibAccessStorage.layout().roles[PAUSER_ROLE][msg.sender];
        if (!isOwner && !isPauser) revert EmergencyFacet__Unauthorized();
    }
}
