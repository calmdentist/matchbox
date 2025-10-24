// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockPolymarketCTF
 * @notice Mock implementation of Polymarket's Conditional Token Framework for testing
 */
contract MockPolymarketCTF {
    mapping(address => mapping(uint256 => uint256)) public balances;
    mapping(bytes32 => uint256) public payoutDenominators;
    mapping(bytes32 => mapping(uint256 => uint256)) public payoutNumeratorsMap;

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value
    );

    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return balances[account][id];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes calldata) external {
        balances[from][id] -= value;
        balances[to][id] += value;
        emit TransferSingle(msg.sender, from, to, id, value);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        balances[to][id] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);
    }

    function redeemPositions(
        address collateralToken,
        bytes32 parentCollectionId,
        bytes32 conditionId,
        uint256[] calldata indexSets
    ) external {
        // Simplified redemption logic for testing
        // In reality, this would burn conditional tokens and return collateral
    }

    function getOutcomeSlotCount(bytes32 conditionId) external pure returns (uint256) {
        return 2; // Binary markets
    }

    function payoutNumerators(bytes32 conditionId, uint256 index) external view returns (uint256) {
        return payoutNumeratorsMap[conditionId][index];
    }

    function payoutDenominator(bytes32 conditionId) external view returns (uint256) {
        return payoutDenominators[conditionId];
    }

    function getCollectionId(bytes32 parentCollectionId, bytes32 conditionId, uint256 indexSet)
        external
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(parentCollectionId, conditionId, indexSet));
    }

    function getPositionId(address collateralToken, bytes32 collectionId) external pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(collateralToken, collectionId)));
    }

    // Test helper to resolve a market
    function resolveMarket(bytes32 conditionId, uint256 winningOutcome) external {
        payoutDenominators[conditionId] = 1;
        payoutNumeratorsMap[conditionId][winningOutcome] = 1;
    }
}

