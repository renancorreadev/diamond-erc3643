// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamond} from "../interfaces/IDiamond.sol";

/*//////////////////////////////////////////////////////////////
                        ERRORS
//////////////////////////////////////////////////////////////*/

error LibDiamond__OnlyOwner();
error LibDiamond__NoSelectorsProvided();
error LibDiamond__FacetAddressIsZero();
error LibDiamond__FacetAddressIsNotZeroOnRemove();
error LibDiamond__SelectorAlreadyExists(bytes4 selector);
error LibDiamond__SelectorDoesNotExist(bytes4 selector);
error LibDiamond__SelectorFromWrongFacet(bytes4 selector);
error LibDiamond__InitCallFailed(address init, bytes data);
error LibDiamond__CannotReplaceSameSelector();
error LibDiamond__NoContractCode(address target);

/*//////////////////////////////////////////////////////////////
                        STORAGE
//////////////////////////////////////////////////////////////*/

struct FacetAddressAndPosition {
    address facetAddress;
    uint96 functionSelectorPosition;
}

struct FacetFunctionSelectors {
    bytes4[] functionSelectors;
    uint256 facetAddressPosition;
}

struct DiamondStorage {
    /// selector => (facetAddress, position in facetFunctionSelectors.functionSelectors)
    mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
    /// facetAddress => selectors + position in facetAddresses
    mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
    /// list of all facet addresses
    address[] facetAddresses;
    /// ERC-165 supported interfaces
    mapping(bytes4 => bool) supportedInterfaces;
    /// owner of the diamond
    address contractOwner;
}

/*//////////////////////////////////////////////////////////////
                        LIBRARY
//////////////////////////////////////////////////////////////*/

library LibDiamond {
    bytes32 internal constant DIAMOND_STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage");

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function setContractOwner(address _newOwner) internal {
        DiamondStorage storage ds = diamondStorage();
        address previousOwner = ds.contractOwner;
        ds.contractOwner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    function contractOwner() internal view returns (address) {
        return diamondStorage().contractOwner;
    }

    function enforceIsContractOwner() internal view {
        if (msg.sender != diamondStorage().contractOwner) revert LibDiamond__OnlyOwner();
    }

    /*//////////////////////////////////////////////////////////////
                            DIAMOND CUT
    //////////////////////////////////////////////////////////////*/

    function diamondCut(
        IDiamond.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            IDiamond.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamond.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamond.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamond.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress,
                    _diamondCut[facetIndex].functionSelectors
                );
            }
        }
        emit IDiamond.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert LibDiamond__NoSelectorsProvided();
        if (_facetAddress == address(0)) revert LibDiamond__FacetAddressIsZero();

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition =
            uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert LibDiamond__SelectorAlreadyExists(selector);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert LibDiamond__NoSelectorsProvided();
        if (_facetAddress == address(0)) revert LibDiamond__FacetAddressIsZero();

        DiamondStorage storage ds = diamondStorage();
        uint96 selectorPosition =
            uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);

        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }

        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) revert LibDiamond__CannotReplaceSameSelector();
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) revert LibDiamond__NoSelectorsProvided();
        if (_facetAddress != address(0)) revert LibDiamond__FacetAddressIsNotZeroOnRemove();

        DiamondStorage storage ds = diamondStorage();
        for (uint256 i; i < _functionSelectors.length; i++) {
            bytes4 selector = _functionSelectors[i];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(ds, oldFacetAddress, selector);
        }
    }

    function addFacet(DiamondStorage storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress);
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
    }

    function addFunction(
        DiamondStorage storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(
        DiamondStorage storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        if (_facetAddress == address(0)) revert LibDiamond__SelectorDoesNotExist(_selector);
        enforceIsNotDiamondItself(_facetAddress);

        uint256 selectorPosition =
            ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition =
            ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;

        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector =
                ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] =
                lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition =
                uint96(selectorPosition);
        }

        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];

        if (lastSelectorPosition == 0) {
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition =
                ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition =
                    facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) return;
        enforceHasContractCode(_init);
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                assembly {
                    let errorSize := mload(error)
                    revert(add(32, error), errorSize)
                }
            }
            revert LibDiamond__InitCallFailed(_init, _calldata);
        }
    }

    function enforceHasContractCode(address _contract) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if (contractSize == 0) revert LibDiamond__NoContractCode(_contract);
    }

    function enforceIsNotDiamondItself(address _facetAddress) internal view {
        if (_facetAddress == address(this)) {
            revert LibDiamond__SelectorFromWrongFacet(bytes4(0));
        }
    }
}
