// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IBytecodeCompressor {
    function publishCompressedBytecode(
        bytes calldata _bytecode,
        bytes calldata _rawCompressedData
    ) external payable returns (bytes32 bytecodeHash);
}
