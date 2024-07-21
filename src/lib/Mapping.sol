// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

struct Value {
    string title;
    uint256 reputation;
    bool available;
}

library Mapping {
    struct Map {
        mapping(bytes32 => Value) values;
        mapping(bytes32 => bool) inserted;
    }

    function _toBytes32(string calldata _title) private pure returns (bytes32) {
        return keccak256(bytes(_title));
    }

    function isAvailable(Map storage _map, string calldata _title) public view returns (bool) {
        return _map.values[_toBytes32(_title)].available;
    }

    function get(Map storage _map, string calldata _title) public view returns (Value storage) {
        return _map.values[_toBytes32(_title)];
    }

    function get(Map storage _map, bytes32 _title) public view returns (Value storage) {
        return _map.values[_title];
    }

    function add(Map storage _map, Value calldata _val) public {
        bytes32 key = _toBytes32(_val.title);
        if (!_map.inserted[key]) _map.inserted[key] = true;
        _map.values[key] = _val;
    }

    function has(Map storage _map, string calldata _title) public view returns (bool) {
        return _map.inserted[_toBytes32(_title)];
    }
}
