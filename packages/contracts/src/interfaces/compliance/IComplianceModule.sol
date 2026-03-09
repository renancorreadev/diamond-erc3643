// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IComplianceModule
/// @author Renan Correa <renan.correa@hubweb3.com>
/// @notice Per-tokenId compliance module interface. Each module returns
///         `(bool ok, bytes32 reason)` to enable debuggable transfer validation.
/// @dev Compliance modules are plugged into each tokenId via AssetConfig.complianceModule.
///      The ComplianceRouterFacet dispatches calls to the appropriate module.
/// @custom:security-contact renan.correa@hubweb3.com
interface IComplianceModule {
    /// @notice Post-transfer hook called after balance mutation
    /// @param tokenId The asset class transferred
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Transfer amount
    function transferred(uint256 tokenId, address from, address to, uint256 amount) external;

    /// @notice Post-mint hook
    /// @param tokenId The asset class minted
    /// @param to Receiver address
    /// @param amount Mint amount
    function minted(uint256 tokenId, address to, uint256 amount) external;

    /// @notice Post-burn hook
    /// @param tokenId The asset class burned
    /// @param from Address burned from
    /// @param amount Burn amount
    function burned(uint256 tokenId, address from, uint256 amount) external;

    /// @notice Validates whether a transfer is allowed
    /// @param tokenId The asset class being transferred
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Transfer amount
    /// @param data Additional transfer context
    /// @return ok True if the transfer is allowed
    /// @return reason Reason code (0x0 if ok, keccak256-hashed constant otherwise)
    function canTransfer(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external view returns (bool ok, bytes32 reason);
}
