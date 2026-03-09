// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title LibReasonCodes
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Standardised reason codes for compliance module responses.
///         Each code is a keccak256 hash to avoid collisions.
/// @custom:security-contact renan.correa@hubweb3.com
library LibReasonCodes {
    bytes32 internal constant REASON_OK = 0x0;
    bytes32 internal constant REASON_INVESTOR_NOT_VERIFIED = keccak256("INVESTOR_NOT_VERIFIED");
    bytes32 internal constant REASON_RECEIVER_NOT_VERIFIED = keccak256("RECEIVER_NOT_VERIFIED");
    bytes32 internal constant REASON_COUNTRY_RESTRICTED = keccak256("COUNTRY_RESTRICTED");
    bytes32 internal constant REASON_HOLDING_LIMIT = keccak256("HOLDING_LIMIT_EXCEEDED");
    bytes32 internal constant REASON_LOCKUP_ACTIVE = keccak256("LOCKUP_ACTIVE");
    bytes32 internal constant REASON_ASSET_PAUSED = keccak256("ASSET_PAUSED");
    bytes32 internal constant REASON_WALLET_FROZEN = keccak256("WALLET_FROZEN");
    bytes32 internal constant REASON_SUPPLY_CAP = keccak256("SUPPLY_CAP_EXCEEDED");
    bytes32 internal constant REASON_TRANSFER_WINDOW = keccak256("OUTSIDE_TRANSFER_WINDOW");
}
