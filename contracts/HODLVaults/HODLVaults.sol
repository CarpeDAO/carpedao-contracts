// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/drafts/IERC20Permit.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./IHODLVaults.sol";

contract HODLVaults is IHODLVaults, ERC721, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public depositFeeManager;
    address public depositFeeTo;
    uint256 public depositFeeMultiplier; // Multiplied by 10000

    uint256 private nextDepositId;
    mapping(uint256 => Deposit) public override deposits;

    constructor() ERC721("HODL Vaults", "HODL") {
        depositFeeManager = msg.sender;
        emit SetDepositFeeManagerLog(msg.sender);

        depositFeeTo = msg.sender;
        emit SetDepositFeeToLog(msg.sender);

        depositFeeMultiplier = 30;
        emit SetDepositFeeMultiplierLog(30);
    }

    function deposit(
        IERC20 _token,
        uint256 _depositAmount,
        uint256 _withdrawTimestamp,
        string calldata _tokenURI
    ) external override nonReentrant {
        require(
            _withdrawTimestamp > block.timestamp,
            "Funds need to be locked for some time"
        );

        uint256 balanceBefore = _token.balanceOf(address(this));
        _token.safeTransferFrom(msg.sender, address(this), _depositAmount);
        uint256 balanceAfter = _token.balanceOf(address(this));

        require(
            balanceAfter > balanceBefore,
            "Deposit amount must be positive"
        );

        uint256 depositAmount = balanceAfter - balanceBefore;
        uint256 fee = depositAmount.mul(depositFeeMultiplier) / 10000;
        if (fee > 0) {
            depositAmount = depositAmount - fee;

            address feeTo = depositFeeTo;
            if (feeTo != address(0)) {
                _token.safeTransfer(feeTo, fee);
            }
        }

        uint256 depositId = nextDepositId;
        nextDepositId = depositId.add(1);

        deposits[depositId] = Deposit({
            token: _token,
            amount: depositAmount,
            depositTimestamp: block.timestamp,
            withdrawTimestamp: _withdrawTimestamp
        });

        _safeMint(msg.sender, depositId);
        _setTokenURI(depositId, _tokenURI);

        emit DepositLog(
            address(_token),
            msg.sender,
            depositAmount,
            _withdrawTimestamp - block.timestamp
        );
    }

    function depositWithPermit(
        IERC20 _token,
        uint256 _depositAmount,
        uint256 _withdrawTimestamp,
        string calldata _tokenURI,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override {
        IERC20Permit(address(_token)).permit(
            msg.sender,
            address(this),
            _depositAmount,
            _deadline,
            _v,
            _r,
            _s
        );
        this.deposit(_token, _depositAmount, _withdrawTimestamp, _tokenURI);
    }

    function increaseDeposit(uint256 _depositIndex, uint256 _depositAmount)
        external
        override
        nonReentrant
    {
        Deposit memory userDeposit = deposits[_depositIndex];

        require(
            block.timestamp < userDeposit.withdrawTimestamp,
            "Deposit is not locked"
        );

        uint256 balanceBefore = userDeposit.token.balanceOf(address(this));
        userDeposit.token.safeTransferFrom(
            msg.sender,
            address(this),
            _depositAmount
        );
        uint256 balanceAfter = userDeposit.token.balanceOf(address(this));

        require(
            balanceAfter > balanceBefore,
            "Deposit amount must be positive"
        );

        uint256 depositAmount = balanceAfter - balanceBefore;
        uint256 fee = depositAmount.mul(depositFeeMultiplier) / 10000;
        if (fee > 0) {
            depositAmount = depositAmount - fee;

            address feeTo = depositFeeTo;
            if (feeTo != address(0)) {
                userDeposit.token.safeTransfer(feeTo, fee);
            }
        }

        deposits[_depositIndex].amount = userDeposit.amount.add(depositAmount);

        emit IncreaseDepositLog(msg.sender, _depositIndex, depositAmount);
    }

    function increaseDepositWithPermit(
        uint256 _depositIndex,
        uint256 _depositAmount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external override {
        IERC20Permit(address(deposits[_depositIndex].token)).permit(
            msg.sender,
            address(this),
            _depositAmount,
            _deadline,
            _v,
            _r,
            _s
        );
        this.increaseDeposit(_depositIndex, _depositAmount);
    }

    function withdraw(uint256 _depositIndex) public override nonReentrant {
        require(
            msg.sender == ownerOf(_depositIndex),
            "User is not the owner of the deposit"
        );

        Deposit memory userDeposit = deposits[_depositIndex];

        require(
            block.timestamp >= userDeposit.withdrawTimestamp,
            "Deposit is still locked"
        );

        delete deposits[_depositIndex];

        _burn(_depositIndex);

        userDeposit.token.safeTransfer(msg.sender, userDeposit.amount);

        emit WithdrawLog(msg.sender, _depositIndex);
    }

    function batchWithdraw(uint256[] calldata _depositIndexes)
        external
        override
    {
        for (uint256 i = 0; i < _depositIndexes.length; i++) {
            withdraw(_depositIndexes[i]);
        }
    }

    // Set the deposit fee manager.
    function setDepositFeeManager(address _newDepositFeeManager) external {
        require(
            msg.sender == depositFeeManager,
            "Only for deposit fee manager"
        );

        depositFeeManager = _newDepositFeeManager;

        emit SetDepositFeeManagerLog(_newDepositFeeManager);
    }

    // Set the destination address for the deposit fees.
    function setDepositFeeTo(address _newDepositFeeTo) external {
        require(
            msg.sender == depositFeeManager,
            "Only for deposit fee manager"
        );

        depositFeeTo = _newDepositFeeTo;

        emit SetDepositFeeToLog(_newDepositFeeTo);
    }

    // Set deposit fee amount.
    function setDepositFeeMultiplier(uint256 _newDepositFeeMultiplier)
        external
    {
        require(
            msg.sender == depositFeeManager,
            "Only for deposit fee manager"
        );

        require(_newDepositFeeMultiplier <= 100, "Maximum fee is 1%");

        depositFeeMultiplier = _newDepositFeeMultiplier;

        emit SetDepositFeeMultiplierLog(_newDepositFeeMultiplier);
    }
}
