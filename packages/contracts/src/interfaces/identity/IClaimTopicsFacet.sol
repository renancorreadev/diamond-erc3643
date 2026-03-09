// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IClaimTopicsFacet {
    function createProfile(uint256[] calldata claimTopics) external returns (uint32 profileId);
    function setProfileClaimTopics(uint32 profileId, uint256[] calldata claimTopics) external;
    function getProfileClaimTopics(uint32 profileId) external view returns (uint256[] memory);
    function getProfileVersion(uint32 profileId) external view returns (uint64);
    function profileExists(uint32 profileId) external view returns (bool);
}
