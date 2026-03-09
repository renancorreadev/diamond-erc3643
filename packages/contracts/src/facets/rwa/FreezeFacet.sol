// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {LibFreezeStorage, FreezeStorage} from "../../storage/LibFreezeStorage.sol";
import {LibAccessStorage} from "../../storage/LibAccessStorage.sol";

/*//////////////////////////////////////////////////////////////
                            ERRORS
//////////////////////////////////////////////////////////////*/

error FreezeFacet__Unauthorized();
error FreezeFacet__ZeroAddress();

/*//////////////////////////////////////////////////////////////
                            CONTRACT
//////////////////////////////////////////////////////////////*/

/// @title FreezeFacet
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Freeze controls at three levels (architecture §3 — RWA Operations):
///         - Global wallet freeze: blocks address across ALL assets
///         - Asset-level freeze: blocks address for ONE tokenId
///         - Partial freeze: locks an amount within a wallet's free partition
///         - Lockup expiry: time-locks tokens until a timestamp
///         Caller must be Diamond owner or TRANSFER_AGENT.
/// @custom:security-contact renan.correa@hubweb3.com
contract FreezeFacet {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Architecture §8 — exact event signatures required for indexer.
    event WalletFrozen(address indexed wallet, bool frozen);
    event AssetFrozen(uint256 indexed tokenId, address indexed wallet, bool frozen);
    event PartialFreeze(uint256 indexed tokenId, address indexed wallet, uint256 amount);
    event LockupSet(uint256 indexed tokenId, address indexed wallet, uint64 expiry);

    /*//////////////////////////////////////////////////////////////
                    GLOBAL WALLET FREEZE
    //////////////////////////////////////////////////////////////*/

    /// @notice Freezes or unfreezes a wallet globally across all tokenIds.
    function setWalletFrozen(address wallet, bool frozen) external {
        _enforceTransferAgentOrOwner();
        if (wallet == address(0)) revert FreezeFacet__ZeroAddress();
        LibFreezeStorage.layout().globalFreeze[wallet] = frozen;
        emit WalletFrozen(wallet, frozen);
    }

    /*//////////////////////////////////////////////////////////////
                    ASSET-LEVEL WALLET FREEZE
    //////////////////////////////////////////////////////////////*/

    /// @notice Freezes or unfreezes a wallet for a specific tokenId.
    function setAssetWalletFrozen(uint256 tokenId, address wallet, bool frozen) external {
        _enforceTransferAgentOrOwner();
        if (wallet == address(0)) revert FreezeFacet__ZeroAddress();
        LibFreezeStorage.layout().assetFreeze[tokenId][wallet] = frozen;
        emit AssetFrozen(tokenId, wallet, frozen);
    }

    /*//////////////////////////////////////////////////////////////
                        PARTIAL FREEZE
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the exact amount frozen within a wallet's free partition.
    ///         Does not fully freeze the wallet — only reduces transferable balance.
    function setFrozenAmount(uint256 tokenId, address wallet, uint256 amount) external {
        _enforceTransferAgentOrOwner();
        if (wallet == address(0)) revert FreezeFacet__ZeroAddress();
        LibFreezeStorage.layout().frozenAmount[tokenId][wallet] = amount;
        emit PartialFreeze(tokenId, wallet, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            LOCKUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets a lockup expiry timestamp for a wallet on a tokenId.
    ///         Tokens cannot be transferred until block.timestamp > expiry.
    ///         Pass expiry = 0 to remove lockup.
    function setLockupExpiry(uint256 tokenId, address wallet, uint64 expiry) external {
        _enforceTransferAgentOrOwner();
        if (wallet == address(0)) revert FreezeFacet__ZeroAddress();
        LibFreezeStorage.layout().lockupExpiry[tokenId][wallet] = expiry;
        emit LockupSet(tokenId, wallet, expiry);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true if the wallet is globally frozen.
    function isWalletFrozen(address wallet) external view returns (bool) {
        return LibFreezeStorage.layout().globalFreeze[wallet];
    }

    /// @notice Returns true if the wallet is frozen for a specific tokenId.
    function isAssetWalletFrozen(uint256 tokenId, address wallet) external view returns (bool) {
        return LibFreezeStorage.layout().assetFreeze[tokenId][wallet];
    }

    /// @notice Returns the frozen amount for a wallet on a tokenId.
    function getFrozenAmount(uint256 tokenId, address wallet) external view returns (uint256) {
        return LibFreezeStorage.layout().frozenAmount[tokenId][wallet];
    }

    /// @notice Returns the lockup expiry timestamp for a wallet on a tokenId.
    function getLockupExpiry(uint256 tokenId, address wallet) external view returns (uint64) {
        return LibFreezeStorage.layout().lockupExpiry[tokenId][wallet];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    bytes32 internal constant TRANSFER_AGENT = keccak256("TRANSFER_AGENT");

    function _enforceTransferAgentOrOwner() internal view {
        bool isOwner = msg.sender == LibDiamond.contractOwner();
        bool isAgent = LibAccessStorage.layout().roles[TRANSFER_AGENT][msg.sender];
        if (!isOwner && !isAgent) revert FreezeFacet__Unauthorized();
    }
}
