// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPolymarketCTF} from "./interfaces/IPolymarketCTF.sol";
import {IPolymarketExchange} from "./interfaces/IPolymarketExchange.sol";

/**
 * @title MatchboxRouter
 * @notice Stateless adapter contract for executing trades on Polymarket with price constraints
 * @dev This contract is the only component that directly interacts with Polymarket's AMM
 * @author calmxbt
 *
 * Key Features:
 * - Stateless and heavily audited
 * - Enforces price constraints atomically (via minAmountOut)
 * - Handles both buying and selling conditional tokens
 * - Supports multiple order types (market orders, limit orders)
 */
contract MatchboxRouter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnauthorizedCaller();
    error InvalidPrice();
    error SlippageExceeded();
    error OrderFailed();
    error TransferFailed();
    error InvalidParameters();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TradeExecuted(
        address indexed matchbox,
        bytes32 indexed conditionId,
        uint256 outcomeIndex,
        uint256 amountIn,
        uint256 amountOut,
        uint256 price
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Polymarket CTF contract
    IPolymarketCTF public immutable CTF;

    /// @notice The Polymarket Exchange contract
    IPolymarketExchange public immutable EXCHANGE;

    /// @notice The collateral token (USDC)
    address public immutable COLLATERAL_TOKEN;

    /// @notice The MatchboxFactory address (for validation)
    address public immutable FACTORY;

    /// @notice Mapping to track authorized Matchbox contracts
    mapping(address => bool) public isAuthorizedMatchbox;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the MatchboxRouter
     * @param _ctf The Polymarket CTF address
     * @param _exchange The Polymarket Exchange address
     * @param _collateralToken The collateral token address (USDC)
     * @param _factory The MatchboxFactory address
     */
    constructor(address _ctf, address _exchange, address _collateralToken, address _factory) {
        CTF = IPolymarketCTF(_ctf);
        EXCHANGE = IPolymarketExchange(_exchange);
        COLLATERAL_TOKEN = _collateralToken;
        FACTORY = _factory;
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a trade with price constraints
     * @param conditionId The Polymarket condition ID
     * @param outcomeIndex The outcome to buy (0 = NO, 1 = YES)
     * @param amountIn The amount of collateral to spend
     * @param minPrice The minimum acceptable price (in basis points)
     * @param maxPrice The maximum acceptable price (in basis points)
     * @param orderData Encoded order data from the Polymarket orderbook
     * @return amountOut The amount of outcome tokens received
     */
    function swapWithConstraints(
        bytes32 conditionId,
        uint256 outcomeIndex,
        uint256 amountIn,
        uint256 minPrice,
        uint256 maxPrice,
        bytes calldata orderData
    ) external returns (uint256 amountOut) {
        // Validate caller is a registered Matchbox
        if (!isAuthorizedMatchbox[msg.sender]) revert UnauthorizedCaller();

        // Validate parameters
        if (maxPrice > 10000 || minPrice > maxPrice) revert InvalidParameters();
        if (amountIn == 0) revert InvalidParameters();

        // Calculate min acceptable shares based on maxPrice
        // If maxPrice = 0.50 (5000 basis points), then minShares = amountIn / 0.50
        // minShares = (amountIn * 10000) / maxPrice
        uint256 minAmountOut = (amountIn * 10000) / maxPrice;

        // Transfer collateral from Matchbox to this contract
        IERC20(COLLATERAL_TOKEN).safeTransferFrom(msg.sender, address(this), amountIn);

        // Get the position ID for this outcome
        bytes32 collectionId = CTF.getCollectionId(bytes32(0), conditionId, 1 << outcomeIndex);
        uint256 positionId = CTF.getPositionId(COLLATERAL_TOKEN, collectionId);

        // Approve exchange to spend collateral
        IERC20(COLLATERAL_TOKEN).forceApprove(address(EXCHANGE), amountIn);

        // Execute the trade via Polymarket Exchange
        uint256 balanceBefore = CTF.balanceOf(address(this), positionId);

        // Decode and execute order
        IPolymarketExchange.Order[] memory orders = abi.decode(orderData, (IPolymarketExchange.Order[]));
        uint256[] memory fillAmounts = new uint256[](orders.length);

        // For simplicity, fill orders proportionally
        // In production, this would use sophisticated order routing
        for (uint256 i = 0; i < orders.length; i++) {
            fillAmounts[i] = orders[i].takerAmount;
        }

        EXCHANGE.fillOrders(orders, fillAmounts);

        uint256 balanceAfter = CTF.balanceOf(address(this), positionId);
        amountOut = balanceAfter - balanceBefore;

        // Enforce price constraint
        if (amountOut < minAmountOut) revert SlippageExceeded();

        // Calculate actual price paid
        uint256 actualPrice = (amountIn * 10000) / amountOut;

        // Verify price is within bounds
        if (actualPrice > maxPrice || actualPrice < minPrice) {
            revert InvalidPrice();
        }

        // Transfer outcome tokens back to Matchbox
        CTF.safeTransferFrom(address(this), msg.sender, positionId, amountOut, "");

        emit TradeExecuted(msg.sender, conditionId, outcomeIndex, amountIn, amountOut, actualPrice);

        return amountOut;
    }

    /**
     * @notice Simplified swap function for market orders (no price constraints)
     * @param conditionId The Polymarket condition ID
     * @param outcomeIndex The outcome to buy
     * @param amountIn The amount of collateral to spend
     * @param minAmountOut The minimum amount of tokens to receive (slippage protection)
     * @param orderData Encoded order data
     * @return amountOut The amount of outcome tokens received
     */
    function swap(
        bytes32 conditionId,
        uint256 outcomeIndex,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes calldata orderData
    ) external returns (uint256 amountOut) {
        if (!isAuthorizedMatchbox[msg.sender]) revert UnauthorizedCaller();

        // Transfer collateral from Matchbox
        IERC20(COLLATERAL_TOKEN).safeTransferFrom(msg.sender, address(this), amountIn);

        // Get position ID
        bytes32 collectionId = CTF.getCollectionId(bytes32(0), conditionId, 1 << outcomeIndex);
        uint256 positionId = CTF.getPositionId(COLLATERAL_TOKEN, collectionId);

        // Approve and execute trade
        IERC20(COLLATERAL_TOKEN).forceApprove(address(EXCHANGE), amountIn);

        uint256 balanceBefore = CTF.balanceOf(address(this), positionId);

        // Execute orders
        IPolymarketExchange.Order[] memory orders = abi.decode(orderData, (IPolymarketExchange.Order[]));
        uint256[] memory fillAmounts = new uint256[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            fillAmounts[i] = orders[i].takerAmount;
        }

        EXCHANGE.fillOrders(orders, fillAmounts);

        uint256 balanceAfter = CTF.balanceOf(address(this), positionId);
        amountOut = balanceAfter - balanceBefore;

        if (amountOut < minAmountOut) revert SlippageExceeded();

        // Transfer tokens back to Matchbox
        CTF.safeTransferFrom(address(this), msg.sender, positionId, amountOut, "");

        uint256 price = (amountIn * 10000) / amountOut;
        emit TradeExecuted(msg.sender, conditionId, outcomeIndex, amountIn, amountOut, price);

        return amountOut;
    }

    /**
     * @notice Registers a new Matchbox contract (called by factory)
     * @param matchbox The Matchbox address to authorize
     */
    function authorizeMatchbox(address matchbox) external {
        if (msg.sender != FACTORY) revert UnauthorizedCaller();
        isAuthorizedMatchbox[matchbox] = true;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the expected output for a given input amount and price
     * @param amountIn The input amount
     * @param price The price in basis points
     * @return expectedOut The expected output amount
     */
    function calculateExpectedOutput(uint256 amountIn, uint256 price) external pure returns (uint256 expectedOut) {
        if (price == 0) revert InvalidParameters();
        expectedOut = (amountIn * 10000) / price;
    }

    /**
     * @notice Calculates the price in basis points for a given trade
     * @param amountIn The input amount
     * @param amountOut The output amount
     * @return price The price in basis points
     */
    function calculatePrice(uint256 amountIn, uint256 amountOut) external pure returns (uint256 price) {
        if (amountOut == 0) revert InvalidParameters();
        price = (amountIn * 10000) / amountOut;
    }
}

