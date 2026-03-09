// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage, AppStorage} from "../libraries/LibAppStorage.sol";
import {LibAssetStorage, AssetStorage} from "../storage/LibAssetStorage.sol";
import {LibAccessStorage} from "../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error PauseFacet__AlreadyPaused();
error PauseFacet__NotPaused();
error PauseFacet__AssetAlreadyPaused(uint256 tokenId);
error PauseFacet__AssetNotPaused(uint256 tokenId);
error PauseFacet__AssetNotRegistered(uint256 tokenId);
error PauseFacet__Unauthorized();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title PauseFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Two-level pause: global protocol and per-tokenId asset.
///         Global pause: Diamond owner only.
///         Asset pause: Diamond owner or PAUSER_ROLE.
/// @custom:security-contact renan.correa@hubweb3.com
contract PauseFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event EmergencyPause(address indexed triggeredBy);
    event ProtocolUnpaused(address indexed by);
    event AssetPaused(uint256 indexed tokenId, address indexed by);
    event AssetUnpaused(uint256 indexed tokenId, address indexed by);

    /*//////////////////////////////////////////////////////////////
                            GLOBAL PAUSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses all transfers across the entire protocol.
    ///         Only the Diamond owner can trigger this.
    function pauseProtocol() external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.layout();
        if (s.globalPaused) revert PauseFacet__AlreadyPaused();
        s.globalPaused = true;
        emit EmergencyPause(msg.sender);
    }

    /// @notice Unpauses the protocol.
    ///         Only the Diamond owner can call this.
    function unpauseProtocol() external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.layout();
        if (!s.globalPaused) revert PauseFacet__NotPaused();
        s.globalPaused = false;
        emit ProtocolUnpaused(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        ASSET-LEVEL PAUSE
    //////////////////////////////////////////////////////////////*/

    /// @notice Pauses transfers for a specific tokenId.
    ///         Caller must be Diamond owner or hold PAUSER_ROLE.
    function pauseAsset(uint256 tokenId) external {
        _enforcePauserOrOwner();
        AssetStorage storage s = LibAssetStorage.layout();
        if (!s.configs[tokenId].exists) revert PauseFacet__AssetNotRegistered(tokenId);
        if (s.configs[tokenId].paused) revert PauseFacet__AssetAlreadyPaused(tokenId);
        s.configs[tokenId].paused = true;
        emit AssetPaused(tokenId, msg.sender);
    }

    /// @notice Unpauses transfers for a specific tokenId.
    ///         Caller must be Diamond owner or hold PAUSER_ROLE.
    function unpauseAsset(uint256 tokenId) external {
        _enforcePauserOrOwner();
        AssetStorage storage s = LibAssetStorage.layout();
        if (!s.configs[tokenId].exists) revert PauseFacet__AssetNotRegistered(tokenId);
        if (!s.configs[tokenId].paused) revert PauseFacet__AssetNotPaused(tokenId);
        s.configs[tokenId].paused = false;
        emit AssetUnpaused(tokenId, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if the protocol is globally paused.
    function isProtocolPaused() external view returns (bool) {
        return LibAppStorage.layout().globalPaused;
    }

    /// @notice Returns true if a specific tokenId is paused.
    function isAssetPaused(uint256 tokenId) external view returns (bool) {
        return LibAssetStorage.layout().configs[tokenId].paused;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function _enforcePauserOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isPauser = LibAccessStorage.layout().roles[PAUSER_ROLE][msg.sender];
        if (!isOwner && !isPauser) revert PauseFacet__Unauthorized();
    }
}
