// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MatchboxFactory} from "../src/MatchboxFactory.sol";
import {MatchboxRouter} from "../src/MatchboxRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPolymarketCTF} from "./mocks/MockPolymarketCTF.sol";
import {MockPolymarketExchange} from "./mocks/MockPolymarketExchange.sol";

/**
 * @title MatchboxFactoryTest
 * @notice Test suite for MatchboxFactory contract
 */
contract MatchboxFactoryTest is Test {
    MatchboxFactory public factory;
    MatchboxRouter public router;
    MockERC20 public usdc;
    MockPolymarketCTF public ctf;
    MockPolymarketExchange public exchange;

    address public alice = address(0x1);
    address public bob = address(0x2);

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USDC", "USDC", 6);
        ctf = new MockPolymarketCTF();
        exchange = new MockPolymarketExchange();

        // Calculate factory address before deployment (for router constructor)
        // Factory will be deployed at the next nonce
        address predictedFactory = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        // Deploy router with predicted factory address
        router = new MatchboxRouter(
            address(ctf),
            address(exchange),
            address(usdc),
            predictedFactory
        );

        // Deploy factory (must be next deployment after router)
        factory = new MatchboxFactory(address(router), address(ctf), address(usdc));

        // Verify factory address matches prediction
        assertEq(address(factory), predictedFactory, "Factory address mismatch");
    }

    function testCreateMatchbox() public {
        vm.startPrank(alice);

        bytes32 salt = bytes32(uint256(1));
        address matchbox = factory.createMatchbox(salt);

        // Verify matchbox was created
        assertTrue(matchbox != address(0), "Matchbox should be created");
        assertTrue(factory.isMatchbox(matchbox), "Should be registered as matchbox");

        // Verify owner's matchboxes list
        address[] memory aliceMatchboxes = factory.getMatchboxesForOwner(alice);
        assertEq(aliceMatchboxes.length, 1, "Alice should have 1 matchbox");
        assertEq(aliceMatchboxes[0], matchbox, "Should be correct matchbox");

        // Verify total matchboxes
        assertEq(factory.getTotalMatchboxes(), 1, "Should have 1 total matchbox");

        vm.stopPrank();
    }

    function testCreateMultipleMatchboxes() public {
        vm.startPrank(alice);

        address matchbox1 = factory.createMatchbox(bytes32(uint256(1)));
        address matchbox2 = factory.createMatchbox(bytes32(uint256(2)));

        address[] memory aliceMatchboxes = factory.getMatchboxesForOwner(alice);
        assertEq(aliceMatchboxes.length, 2, "Alice should have 2 matchboxes");
        assertTrue(matchbox1 != matchbox2, "Matchboxes should be different");

        vm.stopPrank();
    }

    function testPredictMatchboxAddress() public {
        bytes32 salt = bytes32(uint256(1));

        address predicted = factory.predictMatchboxAddress(alice, salt);

        vm.prank(alice);
        address actual = factory.createMatchbox(salt);

        assertEq(predicted, actual, "Predicted address should match actual");
    }

    function testGetAllMatchboxes() public {
        // Create matchboxes from different users
        vm.prank(alice);
        factory.createMatchbox(bytes32(uint256(1)));

        vm.prank(bob);
        factory.createMatchbox(bytes32(uint256(1)));

        address[] memory allMatchboxes = factory.getAllMatchboxes(0, 10);
        assertEq(allMatchboxes.length, 2, "Should have 2 matchboxes");

        // Test pagination
        address[] memory firstMatchbox = factory.getAllMatchboxes(0, 1);
        assertEq(firstMatchbox.length, 1, "Should return 1 matchbox");

        address[] memory secondMatchbox = factory.getAllMatchboxes(1, 1);
        assertEq(secondMatchbox.length, 1, "Should return 1 matchbox");

        assertTrue(firstMatchbox[0] != secondMatchbox[0], "Should return different matchboxes");
    }

    function testGetImplementation() public {
        address impl = factory.getImplementation();
        assertTrue(impl != address(0), "Implementation should be set");
    }

    function testFactoryWithInvalidParameters() public {
        vm.expectRevert(MatchboxFactory.InvalidParameters.selector);
        new MatchboxFactory(address(0), address(ctf), address(usdc));

        vm.expectRevert(MatchboxFactory.InvalidParameters.selector);
        new MatchboxFactory(address(router), address(0), address(usdc));

        vm.expectRevert(MatchboxFactory.InvalidParameters.selector);
        new MatchboxFactory(address(router), address(ctf), address(0));
    }
}

