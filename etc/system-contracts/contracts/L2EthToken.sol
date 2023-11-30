// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20} from "./openzeppelin/token/ERC20/ERC20.sol";
import {MSG_VALUE_SYSTEM_CONTRACT, DEPLOYER_SYSTEM_CONTRACT, BOOTLOADER_FORMAL_ADDRESS, L1_MESSENGER_CONTRACT} from "./Constants.sol";
import {SystemContractHelper} from "./libraries/SystemContractHelper.sol";
import {IMailbox} from "./interfaces/IMailbox.sol";

/**
 * @author Matter Labs
 * @notice Native ETH contract.
 * @dev It does NOT provide interfaces for personal interaction with tokens like `transfer`, `approve`, and `transferFrom`.
 * Instead, this contract is used by the bootloader and `MsgValueSimulator`/`ContractDeployer` system contracts
 * to perform the balance changes while simulating the `msg.value` Ethereum behavior.
 */
contract L2EthToken is ERC20 {
    /// @notice The total amount of tokens that have been minted.
    uint256 public _totalSupply;

    modifier onlyBootloader() {
        require(msg.sender == BOOTLOADER_FORMAL_ADDRESS, "Callable only by the bootloader");
        _;
    }

    event Mint(address indexed account, uint256 amount);

    event Withdrawal(address indexed _l2Sender, address indexed _l1Receiver, uint256 _amount);

    event WithdrawalWithMessage(
        address indexed _l2Sender,
        address indexed _l1Receiver,
        uint256 _amount,
        bytes _additionalData
    );

    constructor() ERC20(name(), symbol()) {
    }

    /// @notice Transfer tokens from one address to another.
    /// @param _from The address to transfer the ETH from.
    /// @param _to The address to transfer the ETH to.
    /// @param _amount The amount of ETH in wei being transferred.
    /// @dev This function can be called only by trusted system contracts.
    /// @dev This function also emits "Transfer" event, which might be removed
    /// later on.
    function transferFromTo(address _from, address _to, uint256 _amount) external {
        require(
            msg.sender == MSG_VALUE_SYSTEM_CONTRACT ||
                msg.sender == address(DEPLOYER_SYSTEM_CONTRACT) ||
                msg.sender == BOOTLOADER_FORMAL_ADDRESS,
            "Only system contracts with special access can call this method"
        );

        uint256 fromBalance = balanceOf(_from);
        require(fromBalance >= _amount, "Transfer amount exceeds balance");
        transferFrom(_from, _to, _amount);

        emit Transfer(_from, _to, _amount);
    }

    /// @notice Increase the total supply of tokens and balance of the receiver.
    /// @dev This method is only callable by the bootloader.
    /// @param _account The address which to mint the funds to.
    /// @param _amount The amount of ETH in wei to be minted.
    function mint(address _account, uint256 _amount) external onlyBootloader {
        _totalSupply += _amount;
        _mint(_account, _amount);
        emit Mint(_account, _amount);
    }

    /// @notice Initiate the ETH withdrawal, funds will be available to claim on L1 `finalizeEthWithdrawal` method.
    /// @param _l1Receiver The address on L1 to receive the funds.
    function withdraw(address _l1Receiver) external payable {
        uint256 amount = _burnMsgValue();

        // Send the L2 log, a user could use it as proof of the withdrawal
        bytes memory message = _getL1WithdrawMessage(_l1Receiver, amount);
        L1_MESSENGER_CONTRACT.sendToL1(message);

        emit Withdrawal(msg.sender, _l1Receiver, amount);
    }

    /// @notice Initiate the ETH withdrawal, with the sent message. The funds will be available to claim on L1 `finalizeEthWithdrawal` method.
    /// @param _l1Receiver The address on L1 to receive the funds.
    /// @param _additionalData Additional data to be sent to L1 with the withdrawal.
    function withdrawWithMessage(address _l1Receiver, bytes memory _additionalData) external payable {
        uint256 amount = _burnMsgValue();

        // Send the L2 log, a user could use it as proof of the withdrawal
        bytes memory message = _getExtendedWithdrawMessage(_l1Receiver, amount, msg.sender, _additionalData);
        L1_MESSENGER_CONTRACT.sendToL1(message);

        emit WithdrawalWithMessage(msg.sender, _l1Receiver, amount, _additionalData);
    }

    /// @dev The function burn the sent `msg.value`.
    /// NOTE: Since this contract holds the mapping of all ether balances of the system,
    /// the sent `msg.value` is added to the `this` balance before the call.
    /// So the balance of `address(this)` is always bigger or equal to the `msg.value`!
    function _burnMsgValue() internal returns (uint256 amount) {
        amount = msg.value;

        // Silent burning of the ether
        unchecked {
            // This is safe, since this contract holds the ether balances, and if user
            // send a `msg.value` it will be added to the contract (`this`) balance.
            _burn(address(this), amount);
            _totalSupply -= amount;
        }
    }

    /// @dev Get the message to be sent to L1 to initiate a withdrawal.
    function _getL1WithdrawMessage(address _to, uint256 _amount) internal pure returns (bytes memory) {
        return abi.encodePacked(IMailbox.finalizeEthWithdrawal.selector, _to, _amount);
    }

    /// @dev Get the message to be sent to L1 to initiate a withdrawal.
    function _getExtendedWithdrawMessage(
        address _to,
        uint256 _amount,
        address _sender,
        bytes memory _additionalData
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(IMailbox.finalizeEthWithdrawal.selector, _to, _amount, _sender, _additionalData);
    }

    /// @dev This method has not been stabilized and might be
    /// removed later on.
    function name() public view virtual override returns (string memory) {
        return "Lambda";
    }

    /// @dev This method has not been stabilized and might be
    /// removed later on.
    function symbol() public view virtual override returns (string memory) {
        return "LBD";
    }

    /// @dev This method has not been stabilized and might be
    /// removed later on.
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
