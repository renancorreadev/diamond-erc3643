// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITrustedIssuerFacet {
    function addTrustedIssuer(uint32 profileId, address issuer) external;
    function removeTrustedIssuer(uint32 profileId, address issuer) external;
    function isTrustedIssuer(uint32 profileId, address issuer) external view returns (bool);
}
