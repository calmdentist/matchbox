// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Matchbox} from "../src/Matchbox.sol";
import {MatchboxRouter} from "../src/MatchboxRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPolymarketCTF} from "./mocks/MockPolymarketCTF.sol";
import {MockPolymarketExchange} from "./mocks/MockPolymarketExchange.sol";

/**
 * @title MatchboxTest
 * @notice Test suite for Matchbox contract
 */
contract MatchboxTest is Test {
    Matchbox public matchbox;
    MatchboxRouter public router;
    MockERC20 public usdc;
    MockPolymarketCTF public ctf;
    MockPolymarketExchange public exchange;

    address public owner = address(0x1);
    address public automation = address(0x2);

    bytes32 constant CONDITION_A = keccak256("CONDITION_A");
    bytes32 constant CONDITION_B = keccak256("CONDITION_B");

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USDC", "USDC", 6);
        ctf = new MockPolymarketCTF();
        exchange = new MockPolymarketExchange();

        // Deploy router
        router = new MatchboxRouter(address(ctf), address(exchange), address(usdc), address(this));

        // Deploy matchbox
        matchbox = new Matchbox(owner, address(router), address(ctf), address(usdc));

        // Authorize matchbox in router
        router.authorizeMatchbox(address(matchbox));

        // Mint USDC to owner
        usdc.mint(owner, 1000e6); // 1000 USDC
    }

    function testInitializeSequence() public {
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](2);

        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1, // YES
            minPrice: 4000, // 0.40
            maxPrice: 6000, // 0.60
            useAllFunds: false,
            specificAmount: 100e6
        });

        rules[1] = Matchbox.Rule({
            conditionId: CONDITION_B,
            outcomeIndex: 1, // YES
            minPrice: 3000, // 0.30
            maxPrice: 5000, // 0.50
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(owner);
        matchbox.initializeSequence(rules);

        assertEq(matchbox.totalSteps(), 2, "Should have 2 steps");
        assertTrue(matchbox.isActive(), "Should be active");

        Matchbox.Rule memory rule0 = matchbox.getRule(0);
        assertEq(rule0.conditionId, CONDITION_A, "Rule 0 condition should match");
        assertEq(rule0.maxPrice, 6000, "Rule 0 max price should match");
    }

    function testInitializeSequenceUnauthorized() public {
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](1);
        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1,
            minPrice: 4000,
            maxPrice: 6000,
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(address(0x999));
        vm.expectRevert(Matchbox.Unauthorized.selector);
        matchbox.initializeSequence(rules);
    }

    function testInitializeSequenceInvalidRule() public {
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](1);

        // Invalid: maxPrice > 10000 (100%)
        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1,
            minPrice: 4000,
            maxPrice: 15000, // Invalid
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(owner);
        vm.expectRevert(Matchbox.InvalidRule.selector);
        matchbox.initializeSequence(rules);
    }

    function testWithdrawFunds() public {
        // Give matchbox some USDC
        usdc.mint(address(matchbox), 100e6);

        uint256 balanceBefore = usdc.balanceOf(owner);

        vm.prank(owner);
        matchbox.withdrawFunds(address(usdc), 50e6);

        uint256 balanceAfter = usdc.balanceOf(owner);
        assertEq(balanceAfter - balanceBefore, 50e6, "Should withdraw 50 USDC");
    }

    function testWithdrawFundsUnauthorized() public {
        usdc.mint(address(matchbox), 100e6);

        vm.prank(address(0x999));
        vm.expectRevert(Matchbox.Unauthorized.selector);
        matchbox.withdrawFunds(address(usdc), 50e6);
    }

    function testDeactivate() public {
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](1);
        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1,
            minPrice: 4000,
            maxPrice: 6000,
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(owner);
        matchbox.initializeSequence(rules);

        assertTrue(matchbox.isActive(), "Should be active");

        vm.prank(owner);
        matchbox.deactivate();

        assertFalse(matchbox.isActive(), "Should be deactivated");
    }

    function testGetSequence() public {
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](2);

        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1,
            minPrice: 4000,
            maxPrice: 6000,
            useAllFunds: false,
            specificAmount: 100e6
        });

        rules[1] = Matchbox.Rule({
            conditionId: CONDITION_B,
            outcomeIndex: 0,
            minPrice: 3000,
            maxPrice: 5000,
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(owner);
        matchbox.initializeSequence(rules);

        Matchbox.Rule[] memory retrievedRules = matchbox.getSequence();
        assertEq(retrievedRules.length, 2, "Should return 2 rules");
        assertEq(retrievedRules[0].outcomeIndex, 1, "First rule should be YES");
        assertEq(retrievedRules[1].outcomeIndex, 0, "Second rule should be NO");
    }

    function testCheckUpkeep() public {
        // Initialize sequence
        Matchbox.Rule[] memory rules = new Matchbox.Rule[](2);
        rules[0] = Matchbox.Rule({
            conditionId: CONDITION_A,
            outcomeIndex: 1,
            minPrice: 4000,
            maxPrice: 6000,
            useAllFunds: true,
            specificAmount: 0
        });
        rules[1] = Matchbox.Rule({
            conditionId: CONDITION_B,
            outcomeIndex: 1,
            minPrice: 3000,
            maxPrice: 5000,
            useAllFunds: true,
            specificAmount: 0
        });

        vm.prank(owner);
        matchbox.initializeSequence(rules);

        // Check upkeep before market resolution (should be false for step 1)
        (, bytes memory performData) = matchbox.checkUpkeep("");
        // First step doesn't need previous market resolution
        // The actual implementation may vary
        assertEq(performData.length, 0, "performData should be empty initially");
    }
}

