// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "../libraries/TransactionHelper.sol";

contract TransactionHelperTest {
    using TransactionHelper for Transaction;

    function encodeHash(Transaction calldata _transaction) public view returns (bytes32 resultHash) {
        resultHash = _transaction.encodeHash();
    }
}
