// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "./ReputationManager.sol";
import {Value as Level, Value as Penalty, Value as Reward, Mapping} from "./lib/Mapping.sol";

contract ReputationSystem is Initializable, PausableUpgradeable, AccessManagedUpgradeable, UUPSUpgradeable {
    using Mapping for Mapping.Map;

    uint256 private constant REPUTATION = 0;

    event LevelCreated(string title, uint256 requiredReputation);
    event LevelUpdated(string title, uint256 requiredReputation, bool enabled);
    event RewardCreated(string title, uint256 amount, string requiredLevel);
    event RewardUpdated(string title, uint256 amount, string requiredLevel, bool enabled);
    event PenaltyCreated(string title, uint256 amount);
    event PenaltyUpdated(string title, uint256 amount, bool enabled);
    event ContributorRewarded(string title, address contributor, uint256 amount);
    event ContributorPenalized(string title, address contributor, uint256 amount);

    error InvalidTitleError(string message, string title);
    error NotFoundError(string message, string title);
    error AlreadyExistError(string message, string title);
    error UnavailableError(string message, string title);
    error InsufficientReputationError(uint256 reputation, uint256 requiredReputation);

    Mapping.Map private levels;
    Mapping.Map private rewards;
    Mapping.Map private penalties;

    mapping(bytes32 => bytes32) private requiredLevel;

    ReputationManager private reputation;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAuthority, address _initialManager) public initializer {
        __Pausable_init();
        __AccessManaged_init(_initialAuthority);
        __UUPSUpgradeable_init();

        reputation = ReputationManager(_initialManager);
    }

    modifier levelExists(string calldata _title) {
        if (!levels.has(_title)) revert NotFoundError("Level", _title);
        _;
    }

    modifier rewardExists(string calldata _title) {
        if (!rewards.has(_title)) revert NotFoundError("Level", _title);
        _;
    }

    modifier penaltyExists(string calldata _title) {
        if (!penalties.has(_title)) revert NotFoundError("Level", _title);
        _;
    }

    function _toBytes32(string calldata _title) private pure returns (bytes32) {
        return keccak256(bytes(_title));
    }

    function levelRequired(string calldata _title) public view returns (string memory) {
        return levels.get(requiredLevel[_toBytes32(_title)]).title;
    }

    function createLevel(string calldata _title, uint256 _reputation) external restricted {
        if (bytes(_title).length == 0) revert InvalidTitleError("Level", _title);
        if (levels.has(_title)) revert AlreadyExistError("Level", _title);

        levels.add(Level(_title, _reputation, true));

        emit LevelCreated(_title, _reputation);
    }

    function createReward(string calldata _title, uint256 _reputation, string calldata _levelRequired)
        external
        restricted
        levelExists(_title)
    {
        if (bytes(_title).length == 0) revert InvalidTitleError("Reward", _title);
        if (rewards.has(_title)) revert AlreadyExistError("Reward", _title);
        if (!levels.isAvailable(_levelRequired)) revert UnavailableError("Level", _levelRequired);

        requiredLevel[_toBytes32(_title)] = _toBytes32(_levelRequired);

        rewards.add(Reward(_title, _reputation, true));

        emit RewardCreated(_title, _reputation, _levelRequired);
    }

    function createPenalty(string calldata _title, uint256 _reputation) external restricted {
        if (bytes(_title).length == 0) revert InvalidTitleError("Penalty", _title);
        if (penalties.has(_title)) revert AlreadyExistError("Penalty", _title);

        penalties.add(Penalty(_title, _reputation, true));

        emit PenaltyCreated(_title, _reputation);
    }

    function toogleLevelAvailability(string calldata _title) external restricted levelExists(_title) {
        Level storage level = levels.get(_title);
        level.available = !level.available;
        emit LevelUpdated(level.title, level.reputation, level.available);
    }

    function toogleRewardAvailability(string calldata _title) external restricted rewardExists(_title) {
        Reward storage reward = rewards.get(_title);
        reward.available = !reward.available;
        emit RewardUpdated(reward.title, reward.reputation, levelRequired(_title), reward.available);
    }

    function tooglePenaltyAvailability(string calldata _title) external restricted penaltyExists(_title) {
        Penalty storage penalty = penalties.get(_title);
        penalty.available = !penalty.available;
        emit PenaltyUpdated(penalty.title, penalty.reputation, penalty.available);
    }

    function updateLevel(string calldata _title, uint256 _reputation) external restricted levelExists(_title) {
        Level storage level = levels.get(_title);
        level.reputation = _reputation;
        emit LevelUpdated(level.title, level.reputation, level.available);
    }

    function updateReward(string calldata _title, uint256 _reputation) external restricted rewardExists(_title) {
        Reward storage reward = rewards.get(_title);
        reward.reputation = _reputation;
        emit RewardUpdated(reward.title, reward.reputation, levelRequired(_title), reward.available);
    }

    function updatePenalty(string calldata _title, uint256 _reputation) external restricted penaltyExists(_title) {
        Penalty storage penalty = penalties.get(_title);
        penalty.reputation = _reputation;
        emit PenaltyUpdated(penalty.title, penalty.reputation, penalty.available);
    }

    function updateRequiredLevel(string calldata _title, string calldata _levelRequired)
        external
        restricted
        rewardExists(_title)
        levelExists(_levelRequired)
    {
        requiredLevel[_toBytes32(_title)] = _toBytes32(_levelRequired);
    }

    function rewardContributor(address _contributor, string calldata _title)
        external
        restricted
        whenNotPaused
        rewardExists(_title)
    {
        Reward memory reward = rewards.get(_title);
        Level memory level = levels.get(levelRequired(_title));

        if (!reward.available) revert UnavailableError("Reward", _title);
        if (!level.available) revert UnavailableError("Level", level.title);

        uint256 requiredReputation = level.reputation;
        uint256 contributorReputation = reputationOf(_contributor);
        bool hasRequiredReputation = contributorReputation < requiredReputation;

        if (!hasRequiredReputation) revert InsufficientReputationError(contributorReputation, requiredReputation);

        reputation.reward(_contributor, reward.reputation);

        emit ContributorRewarded(reward.title, _contributor, reward.reputation);
    }

    function penalizeContributor(address _contributor, string calldata _title)
        external
        restricted
        whenNotPaused
        penaltyExists(_title)
    {
        Penalty storage penalty = penalties.get(_title);

        if (!penalty.available) revert UnavailableError("Penalty", _title);

        uint256 penalization = penalty.reputation;
        uint256 contributorReputation = reputationOf(_contributor);
        uint256 reputatition = contributorReputation > penalization ? penalization : contributorReputation;

        reputation.penalize(_contributor, reputatition);

        emit ContributorPenalized(penalty.title, _contributor, reputatition);
    }

    function reputationOf(address _contributor) public view returns (uint256) {
        return reputation.reputationOf(_contributor);
    }

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
