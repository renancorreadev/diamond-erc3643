// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {IModularCompliance} from "../interfaces/IModularCompliance.sol";

/*//////////////////////////////////////////////////////////////
                        STORAGE STRUCTS
//////////////////////////////////////////////////////////////*/

/// @dev Per-tokenId metadata and compliance configuration
struct TokenData {
    string name;
    string symbol;
    string uri;
    uint256 totalSupply;
    bool paused;
    IIdentityRegistry identityRegistry;
    IModularCompliance compliance;
}

/// @dev Root storage struct. Stored at a deterministic slot to avoid
///      collision between Diamond facets.
/// @dev slot: keccak256("diamond.erc3643.app.storage") - 1
struct AppStorage {
    /*──────────────── ERC-1155 ────────────────*/
    /// tokenId => owner => balance
    mapping(uint256 => mapping(address => uint256)) balances;
    /// owner => operator => approved
    mapping(address => mapping(address => bool)) operatorApprovals;

    /*──────────────── ERC-3643 per tokenId ────────────────*/
    /// tokenId => TokenData (name, symbol, compliance, registry…)
    mapping(uint256 => TokenData) tokens;
    /// tokenId => account => globally frozen
    mapping(uint256 => mapping(address => bool)) frozen;
    /// tokenId => account => amount frozen (partial)
    mapping(uint256 => mapping(address => uint256)) frozenAmounts;

    /*──────────────── Roles ────────────────*/
    /// Agents can mint/burn/forcedTransfer/freeze
    mapping(address => bool) agents;
    address contractOwner;
    address pendingOwner;

    /*──────────────── Token registry ────────────────*/
    /// List of all registered tokenIds
    uint256[] tokenIds;
    /// tokenId => exists
    mapping(uint256 => bool) tokenExists;
}

/*//////////////////////////////////////////////////////////////
                        LIBRARY
//////////////////////////////////////////////////////////////*/

library LibAppStorage {
    /// @dev Deterministic storage slot:
    ///      bytes32(uint256(keccak256("diamond.erc3643.app.storage")) - 1)
    bytes32 internal constant APP_STORAGE_POSITION =
        0xdd9aa6d9a13f4b1ab40d6d6cc45cef6b5f7e2c3e88ee876b49a44bb3c1a3f533;

    function diamondStorage() internal pure returns (AppStorage storage s) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }
}
