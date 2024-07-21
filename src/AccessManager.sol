// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract AccessManager is Initializable, PausableUpgradeable, AccessManagerUpgradeable, UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAuthority) public initializer {
        __Pausable_init();
        __AccessManager_init(_initialAuthority);
        __UUPSUpgradeable_init();
    }

    // TODO: Who can upgrade?
    function _authorizeUpgrade(address newImplementation) internal override {}
}
