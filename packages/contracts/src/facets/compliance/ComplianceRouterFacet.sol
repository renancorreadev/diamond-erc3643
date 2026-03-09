// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IComplianceModule} from "../../interfaces/compliance/IComplianceModule.sol";
import {LibAssetStorage, AssetStorage, AssetConfig} from "../../storage/LibAssetStorage.sol";
import {LibReasonCodes} from "../../libraries/LibReasonCodes.sol";

/**
 * @title ComplianceRouterFacet
 * @author Renan Correa <renan.correa@hubweb3.com>
 * @notice Routes compliance checks to the per-tokenId compliance module.
 *         Returns `(bool ok, bytes32 reason)` for debuggable transfer validation.
 * @dev Called by ERC1155Facet during transfers. If no module is set for a tokenId,
 *      the transfer is allowed by default (module = address(0) → ok).
 * @custom:security-contact renan.correa@hubweb3.com
 */
contract ComplianceRouterFacet {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ComplianceRouterFacet__AssetNotRegistered(uint256 tokenId);

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    /// @notice Post-transfer hook — forwards to the compliance module
    /// @param tokenId The asset class transferred
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Transfer amount
    function transferred(uint256 tokenId, address from, address to, uint256 amount) external {
        address module = _getModule(tokenId);
        if (module != address(0)) {
            IComplianceModule(module).transferred(tokenId, from, to, amount);
        }
    }

    /// @notice Post-mint hook — forwards to the compliance module
    /// @param tokenId The asset class minted
    /// @param to Receiver address
    /// @param amount Mint amount
    function minted(uint256 tokenId, address to, uint256 amount) external {
        address module = _getModule(tokenId);
        if (module != address(0)) {
            IComplianceModule(module).minted(tokenId, to, amount);
        }
    }

    /// @notice Post-burn hook — forwards to the compliance module
    /// @param tokenId The asset class burned
    /// @param from Address burned from
    /// @param amount Burn amount
    function burned(uint256 tokenId, address from, uint256 amount) external {
        address module = _getModule(tokenId);
        if (module != address(0)) {
            IComplianceModule(module).burned(tokenId, from, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Validates a transfer against the tokenId's compliance module
    /// @param tokenId The asset class being transferred
    /// @param from Sender address
    /// @param to Receiver address
    /// @param amount Transfer amount
    /// @param data Additional transfer context
    /// @return ok True if transfer is allowed
    /// @return reason Bytes32 reason code (0x0 if ok)
    function canTransfer(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external view returns (bool ok, bytes32 reason) {
        AssetStorage storage as_ = LibAssetStorage.layout();
        AssetConfig storage config = as_.configs[tokenId];

        if (!config.exists) {
            revert ComplianceRouterFacet__AssetNotRegistered(tokenId);
        }

        address module = config.complianceModule;
        if (module == address(0)) {
            return (true, LibReasonCodes.REASON_OK);
        }

        return IComplianceModule(module).canTransfer(tokenId, from, to, amount, data);
    }

    /// @notice Returns the compliance module address for a tokenId
    /// @param tokenId The asset class to query
    /// @return module The compliance module address (address(0) if none)
    function getComplianceModule(uint256 tokenId) external view returns (address module) {
        module = LibAssetStorage.layout().configs[tokenId].complianceModule;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getModule(uint256 tokenId) internal view returns (address) {
        return LibAssetStorage.layout().configs[tokenId].complianceModule;
    }
}
