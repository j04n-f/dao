// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ReputationManager is
    Initializable,
    ERC1155Upgradeable,
    AccessManagedUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    UUPSUpgradeable
{
    uint256 private constant REPUTATION = 0;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAuthority) public initializer {
        __ERC1155_init("");
        __AccessManaged_init(initialAuthority);
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __UUPSUpgradeable_init();
    }

    function reputationOf(address _addrs) external view returns (uint256) {
        return balanceOf(_addrs, REPUTATION);
    }

    function reward(address _addrs, uint256 _reputation) external restricted whenNotPaused {
        _mint(_addrs, REPUTATION, _reputation, "");
    }

    function penalize(address _addrs, uint256 _reputation) external restricted whenNotPaused {
        _burn(_addrs, REPUTATION, _reputation);
    }

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155Upgradeable, ERC1155PausableUpgradeable)
    {
        super._update(from, to, ids, values);
    }
}
