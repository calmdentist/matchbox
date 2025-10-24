// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {MatchboxRouter} from "../src/MatchboxRouter.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockPolymarketCTF} from "./mocks/MockPolymarketCTF.sol";
import {MockPolymarketExchange} from "./mocks/MockPolymarketExchange.sol";
import {IPolymarketExchange} from "../src/interfaces/IPolymarketExchange.sol";

/**
 * @title MatchboxRouterTest
 * @notice Test suite for MatchboxRouter contract
 */
contract MatchboxRouterTest is Test {
    MatchboxRouter public router;
    MockERC20 public usdc;
    MockPolymarketCTF public ctf;
    MockPolymarketExchange public exchange;

    address public factory = address(0xF);
    address public matchbox = address(0xA);

    bytes32 constant CONDITION_A = keccak256("CONDITION_A");

    function setUp() public {
        // Deploy mocks
        usdc = new MockERC20("USDC", "USDC", 6);
        ctf = new MockPolymarketCTF();
        exchange = new MockPolymarketExchange();

        // Deploy router
        router = new MatchboxRouter(address(ctf), address(exchange), address(usdc), factory);

        // Authorize a matchbox
        vm.prank(factory);
        router.authorizeMatchbox(matchbox);

        // Mint USDC to matchbox
        usdc.mint(matchbox, 1000e6);
    }

    function testAuthorizeMatchbox() public {
        address newMatchbox = address(0xB);

        vm.prank(factory);
        router.authorizeMatchbox(newMatchbox);

        assertTrue(router.isAuthorizedMatchbox(newMatchbox), "Should be authorized");
    }

    function testAuthorizeMatchboxUnauthorized() public {
        address newMatchbox = address(0xB);

        vm.prank(address(0x999));
        vm.expectRevert(MatchboxRouter.UnauthorizedCaller.selector);
        router.authorizeMatchbox(newMatchbox);
    }

    function testCalculateExpectedOutput() public {
        uint256 amountIn = 100e6; // 100 USDC
        uint256 price = 5000; // 0.50

        uint256 expectedOut = router.calculateExpectedOutput(amountIn, price);

        // expectedOut = (100e6 * 10000) / 5000 = 200e6
        assertEq(expectedOut, 200e6, "Should calculate correct output");
    }

    function testCalculatePrice() public {
        uint256 amountIn = 100e6; // 100 USDC
        uint256 amountOut = 200e6; // 200 shares

        uint256 price = router.calculatePrice(amountIn, amountOut);

        // price = (100e6 * 10000) / 200e6 = 5000 (0.50)
        assertEq(price, 5000, "Should calculate correct price");
    }

    function testCalculateExpectedOutputInvalidPrice() public {
        vm.expectRevert(MatchboxRouter.InvalidParameters.selector);
        router.calculateExpectedOutput(100e6, 0);
    }

    function testCalculatePriceInvalidAmount() public {
        vm.expectRevert(MatchboxRouter.InvalidParameters.selector);
        router.calculatePrice(100e6, 0);
    }

    function testSwapUnauthorizedMatchbox() public {
        address unauthorizedMatchbox = address(0xC);

        IPolymarketExchange.Order[] memory orders = new IPolymarketExchange.Order[](0);
        bytes memory orderData = abi.encode(orders);

        vm.prank(unauthorizedMatchbox);
        vm.expectRevert(MatchboxRouter.UnauthorizedCaller.selector);
        router.swap(CONDITION_A, 1, 100e6, 150e6, orderData);
    }

    function testSwapWithConstraintsInvalidParameters() public {
        IPolymarketExchange.Order[] memory orders = new IPolymarketExchange.Order[](0);
        bytes memory orderData = abi.encode(orders);

        vm.prank(matchbox);

        // Test maxPrice > 10000
        vm.expectRevert(MatchboxRouter.InvalidParameters.selector);
        router.swapWithConstraints(CONDITION_A, 1, 100e6, 4000, 15000, orderData);

        // Test minPrice > maxPrice
        vm.expectRevert(MatchboxRouter.InvalidParameters.selector);
        router.swapWithConstraints(CONDITION_A, 1, 100e6, 7000, 5000, orderData);

        // Test amountIn = 0
        vm.expectRevert(MatchboxRouter.InvalidParameters.selector);
        router.swapWithConstraints(CONDITION_A, 1, 0, 4000, 6000, orderData);
    }

    function testImmutableVariables() public {
        assertEq(address(router.ctf()), address(ctf), "CTF should match");
        assertEq(address(router.exchange()), address(exchange), "Exchange should match");
        assertEq(router.collateralToken(), address(usdc), "Collateral token should match");
        assertEq(router.factory(), factory, "Factory should match");
    }
}

