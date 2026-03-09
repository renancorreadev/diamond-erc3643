// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error OwnershipFacet__NotPendingOwner();
error OwnershipFacet__ZeroAddress();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title OwnershipFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Ownable2Step ownership management for the Diamond.
///         Transfer requires two steps: nominate then accept.
/// @custom:security-contact renan.correa@hubweb3.com
contract OwnershipFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new owner is nominated
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when ownership transfer is completed
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                        STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Nominates a new owner. Must be accepted by the nominee.
    /// @param _newOwner Address to nominate as the next owner
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        if (_newOwner == address(0)) revert OwnershipFacet__ZeroAddress();
        AppStorage storage s = LibAppStorage.layout();
        s.pendingOwner = _newOwner;
        emit OwnershipTransferStarted(LibDiamond.contractOwner(), _newOwner);
    }

    /// @notice Accepts the ownership nomination. Must be called by the pending owner.
    function acceptOwnership() external {
        AppStorage storage s = LibAppStorage.layout();
        if (msg.sender != s.pendingOwner) revert OwnershipFacet__NotPendingOwner();
        address previousOwner = LibDiamond.contractOwner();
        LibDiamond.setContractOwner(msg.sender);
        s.pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current Diamond owner
    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    /// @notice Returns the pending owner (awaiting acceptance)
    function pendingOwner() external view returns (address) {
        return LibAppStorage.layout().pendingOwner;
    }
}
