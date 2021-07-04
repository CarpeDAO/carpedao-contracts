// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IHODLVaults is IERC721 {
    struct Deposit {
        IERC20 token;
        uint256 amount;
        uint256 depositTimestamp;
        uint256 withdrawTimestamp;
    }

    function deposits(uint256 _depositIndex)
        external
        returns (
            IERC20 _depositToken,
            uint256 _depositAmount,
            uint256 _depositTimestamp,
            uint256 _withdrawTimestamp
        );

    function deposit(
        IERC20 _token,
        uint256 _depositAmount,
        uint256 _withdrawTimestamp,
        string calldata _tokenURI
    ) external;

    function depositWithPermit(
        IERC20 _token,
        uint256 _depositAmount,
        uint256 _withdrawTimestamp,
        string calldata _tokenURI,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function increaseDeposit(uint256 _depositIndex, uint256 _depositAmount)
        external;

    function increaseDepositWithPermit(
        uint256 _depositIndex,
        uint256 _depositAmount,
        uint256 deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    function withdraw(uint256 _depositIndex) external;

    function batchWithdraw(uint256[] calldata _depositIndexes) external;

    event DepositLog(
        address indexed userAddress,
        address indexed token,
        uint256 amount,
        uint256 timeLocked
    );

    event IncreaseDepositLog(
        address indexed userAddress,
        uint256 indexed depositIndex,
        uint256 amount
    );

    event WithdrawLog(address indexed userAddress, uint256 depositIndex);

    event SetDepositFeeManagerLog(address newDepositFeeManager);

    event SetDepositFeeToLog(address newDepositFeeTo);

    event SetDepositFeeMultiplierLog(uint256 newDepositFeeMultiplier);
}
