// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ReputationManager.sol";
import "../src/ReputationSystem.sol";
import "../src/AccessManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BaseTest is Test {
    ReputationManager public reputationManager;
    ReputationSystem public reputationSystem;
    AccessManager public accessManager;
    address public owner;
    address public manager;
    address public system;
    address public user;

    uint64 MANAGER = 42;
    uint64 SYSTEM = 50;

    function setUp() public {
        owner = address(0x1);
        manager = address(0x2);
        system = address(0x2);
        user = address(0x3);

        accessManager = AccessManager(
            Upgrades.deployUUPSProxy("AccessManager.sol", abi.encodeCall(AccessManager.initialize, (owner)))
        );
        reputationManager = ReputationManager(
            Upgrades.deployUUPSProxy(
                "ReputationManager.sol", abi.encodeCall(ReputationManager.initialize, (address(accessManager)))
            )
        );
        reputationSystem = ReputationSystem(
            Upgrades.deployUUPSProxy(
                "ReputationSystem.sol",
                abi.encodeCall(ReputationSystem.initialize, (address(accessManager), address(reputationManager)))
            )
        );

        vm.startPrank(owner);

        bytes4[] memory systemSelectors = new bytes4[](8);

        systemSelectors[0] = bytes4(keccak256("createLevel(string,uint256)"));
        systemSelectors[1] = bytes4(keccak256("createReward(string,uint256,string)"));
        systemSelectors[2] = bytes4(keccak256("createPenalty(string,uint256)"));
        systemSelectors[3] = bytes4(keccak256("rewardContributor(address,string)"));
        systemSelectors[4] = bytes4(keccak256("penalizeContributor(address,string)"));
        systemSelectors[5] = bytes4(keccak256("toggleLevelAvailability(string)"));
        systemSelectors[6] = bytes4(keccak256("toggleRewardAvailability(string)"));
        systemSelectors[7] = bytes4(keccak256("togglePenaltyAvailability(string)"));

        accessManager.grantRole(MANAGER, manager, 0);
        accessManager.setTargetFunctionRole(address(reputationSystem), systemSelectors, MANAGER);

        bytes4[] memory managerSelectors = new bytes4[](2);

        managerSelectors[0] = bytes4(keccak256("reward(address,uint256)"));
        managerSelectors[1] = bytes4(keccak256("penalize(address,uint256)"));

        accessManager.grantRole(SYSTEM, address(reputationSystem), 0);
        accessManager.setTargetFunctionRole(address(reputationManager), managerSelectors, SYSTEM);

        vm.stopPrank();
    }
}

contract ReputationSystemTest is BaseTest {
    function test_Initialize() public view {
        assertEq(reputationSystem.reputationOf(user), 0);
    }

    function test_CreateLevel() public {
        vm.prank(manager);
        reputationSystem.createLevel("Level 1", 100);

        Level memory level = reputationSystem.getLevel("Level 1");

        assertEq(level.title, "Level 1");
        assertEq(level.reputation, 100);
        assertEq(level.available, true);
    }

    function test_RevertWhen_CreateLevel_AlreadyExists() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.AlreadyExistError.selector, "Level", "Level 1"));
        reputationSystem.createLevel("Level 1", 100);
        vm.stopPrank();
    }

    function test_RevertWhen_CreateLevel_InvalidTitle() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.InvalidTitleError.selector, "Level", ""));
        reputationSystem.createLevel("", 100);
        vm.stopPrank();
    }

    function test_CreateReward() public {
        vm.prank(manager);
        reputationSystem.createLevel("Level 1", 100);

        vm.prank(manager);
        reputationSystem.createReward("Reward 1", 100, "Level 1");

        Level memory level = reputationSystem.getReward("Reward 1");

        assertEq(level.title, "Reward 1");
        assertEq(level.reputation, 100);
        assertEq(level.available, true);
    }

    function test_RevertWhen_CreateReward_LevelNotExists() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.NotFoundError.selector, "Level", "Level 2"));
        reputationSystem.createReward("Reward 1", 100, "Level 2");
        vm.stopPrank();
    }

    function test_RevertWhen_CreateReward_UnavailableLevel() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        reputationSystem.toggleLevelAvailability("Level 1");
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.UnavailableError.selector, "Level", "Level 1"));
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        vm.stopPrank();
    }

    function test_RevertWhen_CreateReward_AlreadyExists() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.AlreadyExistError.selector, "Reward", "Reward 1"));
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        vm.stopPrank();
    }

    function test_RevertWhen__CreateReward_InvalidTitle() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.InvalidTitleError.selector, "Reward", ""));
        reputationSystem.createReward("", 100, "Level 1");
        vm.stopPrank();
    }

    function test_CreatePenalty() public {
        vm.prank(manager);
        reputationSystem.createPenalty("Penalty 1", 100);

        Penalty memory penalty = reputationSystem.getPenalty("Penalty 1");

        assertEq(penalty.title, "Penalty 1");
        assertEq(penalty.reputation, 100);
        assertEq(penalty.available, true);
    }

    function test_RevertWhen_CreatePenalty_AlreadyExists() public {
        vm.startPrank(manager);
        reputationSystem.createPenalty("Penalty 1", 100);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.AlreadyExistError.selector, "Penalty", "Penalty 1"));
        reputationSystem.createPenalty("Penalty 1", 100);
        vm.stopPrank();
    }

    function test_RevertWhen_CreatePenalty_InvalidTitle() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.InvalidTitleError.selector, "Penalty", ""));
        reputationSystem.createPenalty("", 100);
        vm.stopPrank();
    }

    function test_ToggleLevelAvailability() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        reputationSystem.toggleLevelAvailability("Level 1");
        Level memory level = reputationSystem.getLevel("Level 1");
        assertEq(level.available, false);
        reputationSystem.toggleLevelAvailability("Level 1");
        level = reputationSystem.getLevel("Level 1");
        assertEq(level.available, true);
        vm.stopPrank();
    }

    function test_RevertWhen_ToggleLevelAvailability_NotFound() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.NotFoundError.selector, "Level", "Level 1"));
        reputationSystem.toggleLevelAvailability("Level 1");
        vm.stopPrank();
    }

    function test_ToggleRewardAvailability() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 100);
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        reputationSystem.toggleRewardAvailability("Reward 1");
        Level memory level = reputationSystem.getReward("Reward 1");
        assertEq(level.available, false);
        reputationSystem.toggleRewardAvailability("Reward 1");
        level = reputationSystem.getReward("Reward 1");
        assertEq(level.available, true);
        vm.stopPrank();
    }

    function test_RevertWhen_ToggleRewardAvailability_NotFound() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.NotFoundError.selector, "Reward", "Reward 1"));
        reputationSystem.toggleRewardAvailability("Reward 1");
        vm.stopPrank();
    }

    function test_TogglePenaltyAvailability() public {
        vm.startPrank(manager);
        reputationSystem.createPenalty("Penalty 1", 100);
        reputationSystem.togglePenaltyAvailability("Penalty 1");
        Level memory level = reputationSystem.getPenalty("Penalty 1");
        assertEq(level.available, false);
        reputationSystem.togglePenaltyAvailability("Penalty 1");
        level = reputationSystem.getPenalty("Penalty 1");
        assertEq(level.available, true);
        vm.stopPrank();
    }

    function test_RevertWhen_TogglePenaltyAvailability_NotFound() public {
        vm.startPrank(manager);
        vm.expectRevert(abi.encodeWithSelector(ReputationSystem.NotFoundError.selector, "Penalty", "Penalty 1"));
        reputationSystem.togglePenaltyAvailability("Penalty 1");
        vm.stopPrank();
    }

    function test_RewardContributor() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 0);
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        reputationSystem.rewardContributor(user, "Reward 1");
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 100);
    }

    function test_PenalizeContributor() public {
        vm.startPrank(manager);
        reputationSystem.createLevel("Level 1", 0);
        reputationSystem.createReward("Reward 1", 100, "Level 1");
        reputationSystem.createPenalty("Penalty 1", 50);
        reputationSystem.rewardContributor(user, "Reward 1");
        reputationSystem.penalizeContributor(user, "Penalty 1");
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 50);
    }
}
