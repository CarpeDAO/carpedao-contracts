// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./IAggregatorV3.sol";
import "../HODLVaults/IHODLVaults.sol";

contract CARPEDistributor {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 constant maximumTimeLocked = 5 * 360 days; // 5 circle years

    IERC20 public immutable carpeToken;
    IHODLVaults public immutable hodlVaults;

    address public tokenWhitelister;

    struct TokenInfo {
        IAggregatorV3 priceFeed; // https://docs.chain.link/docs/ethereum-addresses
        uint8 decimals;
    }

    mapping(IERC20 => TokenInfo) public tokenWhitelist;

    mapping(uint256 => uint256) public depositClaimedTimestamp;

    constructor(IERC20 _carpeTokenContract, IHODLVaults _hodlVaultsContract) {
        carpeToken = _carpeTokenContract;
        hodlVaults = _hodlVaultsContract;

        tokenWhitelister = msg.sender;
        emit SetTokenWhitelisterLog(msg.sender);
    }

    event CarpeRewardLog(
        address indexed userAddress,
        uint256 indexed depositIndex,
        uint256 carpeAmount
    );

    // Claim CARPE token rewards for a given HODL vault deposit.
    function claimTokens(uint256 _depositIndex) public {
        require(
            depositClaimedTimestamp[_depositIndex] == 0,
            "Governance tokens already claimed for that deposit"
        );

        require(
            msg.sender == hodlVaults.ownerOf(_depositIndex),
            "User is not the owner of the deposit"
        );

        (
            IERC20 depositToken,
            uint256 depositAmount,
            uint256 depositTimestamp,
            uint256 withdrawTimestamp
        ) = hodlVaults.deposits(_depositIndex);

        uint256 carpeReward = calculateCarpeReward(
            depositToken,
            depositAmount,
            withdrawTimestamp - depositTimestamp
        );

        require(carpeReward > 0, "No reward to withdraw");

        depositClaimedTimestamp[_depositIndex] = block.timestamp;

        carpeToken.safeTransfer(msg.sender, carpeReward);

        emit CarpeRewardLog(msg.sender, _depositIndex, carpeReward);
    }

    // Claim CARPE token rewards for multiple HODL vault deposits.
    function claimBatchTokens(uint256[] calldata _depositIndexes) external {
        for (uint256 i = 0; i < _depositIndexes.length; i++) {
            claimTokens(_depositIndexes[i]);
        }
    }

    // Calculate CARPE token rewards for a given HODL vault deposit.
    function calculateCarpeReward(
        IERC20 _depositToken,
        uint256 _depositAmount,
        uint256 _timeLocked
    ) public view returns (uint256) {
        TokenInfo memory tokenInfo = tokenWhitelist[_depositToken];
        if (address(tokenInfo.priceFeed) == address(0)) {
            return 0;
        }

        (, int256 price, , , ) = tokenInfo.priceFeed.latestRoundData();

        uint256 timeLocked = _timeLocked;
        if (timeLocked > maximumTimeLocked) {
            timeLocked = maximumTimeLocked;
        }

        // depositInDollars = (_depositAmount / 10**decimals) * (price / 10**8)
        // rewardAmountInEther = depositInDollars * (timeLocked ** 2) / 10**18
        // rewardAmountInWei = rewardAmountInEther * 10**18
        uint256 rewardAmount = _depositAmount
            .mul(uint256(price))
            .mul(timeLocked)
            .mul(timeLocked)
            .div(10**(tokenInfo.decimals + 8));

        uint256 carpeBalance = carpeToken.balanceOf(address(this));
        if (rewardAmount > carpeBalance) {
            rewardAmount = carpeBalance;
        }

        return rewardAmount;
    }

    event UpdateTokenWhitelistLog(address indexed token, address priceFeed);

    // Update the price feed contract for a given token. Set to address zero to disable.
    function updateTokenWhitelist(IERC20 _token, IAggregatorV3 _newPriceFeed)
        external
    {
        require(msg.sender == tokenWhitelister, "Only for token whitelister");

        if (address(_newPriceFeed) == address(0)) {
            delete tokenWhitelist[_token];
        } else {
            tokenWhitelist[_token] = TokenInfo({
                priceFeed: _newPriceFeed,
                decimals: ERC20(address(_token)).decimals()
            });
        }

        emit UpdateTokenWhitelistLog(address(_token), address(_newPriceFeed));
    }

    event SetTokenWhitelisterLog(address newDepositFeeTo);

    // Set the token whitelister address.
    function setTokenWhitelister(address _newTokenWhitelister) external {
        require(msg.sender == tokenWhitelister, "Only for token whitelister");

        tokenWhitelister = _newTokenWhitelister;

        emit SetTokenWhitelisterLog(_newTokenWhitelister);
    }
}
