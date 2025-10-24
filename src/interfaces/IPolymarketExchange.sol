// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPolymarketExchange
 * @notice Interface for Polymarket's Exchange (CLOB or AMM)
 * @dev This represents the trading interface for buying/selling conditional tokens
 */
interface IPolymarketExchange {
    /**
     * @notice Order structure for signed orders
     */
    struct Order {
        bytes32 salt;
        address maker;
        address signer;
        address taker;
        uint256 tokenId;
        uint256 makerAmount;
        uint256 takerAmount;
        uint256 expiration;
        uint256 nonce;
        uint256 feeRateBps;
        uint8 side; // 0 = BUY, 1 = SELL
        uint8 signatureType;
        bytes signature;
    }

    /**
     * @notice Fills a signed order
     * @param order The order to fill
     * @param fillAmount The amount to fill
     */
    function fillOrder(Order calldata order, uint256 fillAmount) external;

    /**
     * @notice Batch fills multiple orders
     * @param orders Array of orders to fill
     * @param fillAmounts Array of amounts to fill for each order
     */
    function fillOrders(Order[] calldata orders, uint256[] calldata fillAmounts) external;

    /**
     * @notice Gets the filled amount for an order
     * @param orderHash The hash of the order
     * @return The filled amount
     */
    function getOrderStatus(bytes32 orderHash) external view returns (uint256);
}

