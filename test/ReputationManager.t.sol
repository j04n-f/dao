// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/ReputationManager.sol";
import "../src/AccessManager.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract BaseTest is Test {
    ReputationManager public reputationManager;
    AccessManager public accessManager;
    address public owner;
    address public manager;
    address public user;

    uint64 MANAGER = 42;

    function setUp() public {
        owner = address(0x1);
        manager = address(0x2);
        user = address(0x3);

        accessManager = AccessManager(
            Upgrades.deployUUPSProxy("AccessManager.sol", abi.encodeCall(AccessManager.initialize, (owner)))
        );
        reputationManager = ReputationManager(
            Upgrades.deployUUPSProxy(
                "ReputationManager.sol", abi.encodeCall(ReputationManager.initialize, (address(accessManager)))
            )
        );

        bytes4[] memory selectors = new bytes4[](4);

        selectors[0] = bytes4(keccak256("reward(address,uint256)"));
        selectors[1] = bytes4(keccak256("penalize(address,uint256)"));
        selectors[2] = bytes4(keccak256("pause()"));
        selectors[3] = bytes4(keccak256("unpause()"));

        vm.startPrank(owner);
        accessManager.grantRole(MANAGER, manager, 0);
        accessManager.setTargetFunctionRole(address(reputationManager), selectors, MANAGER);
        vm.stopPrank();
    }
}

contract ReputationManagerTest is BaseTest {
    function test_Initialize() public view {
        assertEq(reputationManager.reputationOf(user), 0);
    }

    function test_Reward() public {
        vm.startPrank(manager);
        reputationManager.reward(user, 100);
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 100);
    }

    function test_Penalize() public {
        vm.startPrank(manager);
        reputationManager.reward(user, 100);
        reputationManager.penalize(user, 50);
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 50);
    }
}

contract ReputationManagerPauseTest is BaseTest {
    function test_RevertWhen_RewardPaused() public {
        vm.startPrank(manager);
        reputationManager.pause();
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        reputationManager.reward(user, 100);
        vm.stopPrank();
    }

    function test_RevertWhen_PenalizePaused() public {
        vm.startPrank(manager);
        reputationManager.pause();
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        reputationManager.penalize(user, 100);
        vm.stopPrank();
    }

    function test_RewardUnpause() public {
        vm.startPrank(manager);
        reputationManager.pause();
        reputationManager.unpause();
        reputationManager.reward(user, 100);
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 100);
    }

    function test_PenalizeUnpause() public {
        vm.startPrank(manager);
        reputationManager.pause();
        reputationManager.unpause();
        reputationManager.reward(user, 100);
        reputationManager.penalize(user, 50);
        vm.stopPrank();
        assertEq(reputationManager.reputationOf(user), 50);
    }
}

contract ReputationManagerAccessTest is BaseTest {
    function test_RevertWhen_UnauthorizedReward() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AccessManagedUnauthorized(address)")), user));
        reputationManager.reward(user, 100);
        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedPenalize() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AccessManagedUnauthorized(address)")), user));
        reputationManager.penalize(user, 100);
        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedPause() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AccessManagedUnauthorized(address)")), user));
        reputationManager.pause();
        vm.stopPrank();
    }

    function test_RevertWhen_UnauthorizedUnpause() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("AccessManagedUnauthorized(address)")), user));
        reputationManager.unpause();
        vm.stopPrank();
    }
}
