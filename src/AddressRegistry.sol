// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/utils/structs/EnumerableMap.sol";

contract AddressRegistry is Ownable {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    EnumerableMap.UintToAddressMap _addresses;

    constructor() Ownable() {}

    function setMulti(
        bytes32[] calldata keyHashes,
        address[] calldata to
    ) public onlyOwner {
        require(
            keyHashes.length == to.length,
            "Parameter lengths must be equal"
        );
        for (uint i; i < keyHashes.length; i++) {
            set(keyHashes[i], to[i]);
        }
    }

    function setMulti(
        string[] calldata keys,
        address[] calldata to
    ) public onlyOwner {
        require(keys.length == to.length, "Parameter lengths must be equal");
        for (uint i; i < keys.length; i++) {
            set(keccak256(abi.encodePacked(keys[i])), to[i]);
        }
    }

    function set(bytes32 keyHash, address to) public onlyOwner returns (bool) {
        return _addresses.set(uint256(keyHash), to);
    }

    function set(
        string calldata key,
        address to
    ) external onlyOwner returns (bool) {
        return set(keccak256(abi.encodePacked(key)), to);
    }

    function remove(bytes32 keyHash) public onlyOwner returns (bool) {
        return _addresses.remove(uint256(keyHash));
    }

    function remove(string calldata key) external onlyOwner returns (bool) {
        return remove(keccak256(abi.encodePacked(key)));
    }

    function length() external view returns (uint256) {
        return _addresses.length();
    }

    //does not revert, even if key is not registered
    function tryGet(bytes32 keyHash) public view returns (bool, address) {
        return _addresses.tryGet(uint256(keyHash));
    }

    //does not revert, even if key is not registered
    function tryGet(string calldata key) external view returns (bool, address) {
        return tryGet(keccak256(abi.encodePacked(key)));
    }

    //reverts if key is not registered
    function get(bytes32 keyHash) public view returns (address) {
        return _addresses.get(uint256(keyHash));
    }

    //reverts if key is not registered
    function get(string calldata key) external view returns (address) {
        return get(keccak256(abi.encodePacked(key)));
    }

    function at(uint256 index) external view returns (uint256, address) {
        return _addresses.at(index);
    }

    function contains(bytes32 keyHash) public view returns (bool) {
        return _addresses.contains(uint256(keyHash));
    }

    function contains(string calldata key) external view returns (bool) {
        return contains(keccak256(abi.encodePacked(key)));
    }

    //VIEW ONLY: HIGH GAS
    function getKeysWithHighGasCost() external view returns (bytes32[] memory) {
        uint256[] memory keyHashesUint = _addresses.keys();
        bytes32[] memory keyHashes;

        /// @solidity memory-safe-assembly
        assembly {
            keyHashes := keyHashesUint
        }
        return keyHashes;
    }
}
