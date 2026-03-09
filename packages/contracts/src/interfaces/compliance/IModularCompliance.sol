// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IModularCompliance
/// @notice Pluggable compliance engine. Each tokenId binds its own instance
///         (or shares one). Modules are added/removed dynamically.
interface IModularCompliance {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event TokenBound(address indexed token);
    event TokenUnbound(address indexed token);
    event ModuleAdded(address indexed module);
    event ModuleRemoved(address indexed module);

    /*//////////////////////////////////////////////////////////////
                            STATE-CHANGING
    //////////////////////////////////////////////////////////////*/

    function bindToken(address _token) external;
    function unbindToken(address _token) external;
    function addModule(address _module) external;
    function removeModule(address _module) external;

    /// @notice Called after a successful transfer (post-hook).
    function transferred(address _from, address _to, uint256 _amount) external;

    /// @notice Called after a successful mint (post-hook).
    function created(address _to, uint256 _amount) external;

    /// @notice Called after a successful burn (post-hook).
    function destroyed(address _from, uint256 _amount) external;

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns true only if ALL modules approve the transfer.
    function canTransfer(address _from, address _to, uint256 _amount)
        external
        view
        returns (bool);

    function getModules() external view returns (address[] memory);

    function isModuleBound(address _module) external view returns (bool);

    function getTokenBound() external view returns (address);
}
