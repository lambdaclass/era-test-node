// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

contract Counter {
    uint256 public counter;

    function increment() public {
        counter += 1;
    }
}
