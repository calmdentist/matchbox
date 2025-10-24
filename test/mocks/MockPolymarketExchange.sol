// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IPolymarketExchange} from "../../src/interfaces/IPolymarketExchange.sol";

/**
 * @title MockPolymarketExchange
 * @notice Mock implementation of Polymarket's Exchange for testing
 */
contract MockPolymarketExchange {
    // Simple mock that simulates filling orders
    uint256 public mockPrice = 5000; // 0.50 in basis points

    function fillOrder(IPolymarketExchange.Order calldata order, uint256 fillAmount) external {
        // Mock implementation - in reality would match orders
    }

    function fillOrders(IPolymarketExchange.Order[] calldata orders, uint256[] calldata fillAmounts) external {
        // Mock implementation - in reality would match multiple orders
    }

    function getOrderStatus(
        bytes32 /* orderHash */
    )
        external
        pure
        returns (uint256)
    {
        return 0;
    }

    function setMockPrice(uint256 _price) external {
        mockPrice = _price;
    }
}

