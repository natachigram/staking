// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Import WETH interface
import "./interfaces/IWETH.sol";

contract StakingContract is ERC20, ERC20Burnable {
    using SafeERC20 for IERC20;

    // Staker info
    struct Staker {
        uint256 deposited;
        uint256 timeOfLastUpdate;
        uint256 unclaimedRewards;
        bool autoCompound;
    }

    // Rewards per hour. A fraction calculated as x/10,000,000 to get the percentage
    uint256 public rewardsPerHour = 1400; // 14% APR

    // Minimum amount to stake
    uint256 public minStake = 10 ** 18; // 1 ETH in wei

    // Compounding frequency limit in seconds (30 days)
    uint256 public compoundFreq = 2592000;

    // Fee for auto-compounding (1%)
    uint256 public compoundingFee = 1;

    // Address of the WETH contract
    address public wethAddress;

    // Mapping of address to Staker info
    mapping(address => Staker) internal stakers;

    // Constructor function
    constructor(address _wethAddress) ERC20("YourTokenName", "YTN") {
        wethAddress = _wethAddress;
    }

    // Deposit ETH and mint receipt tokens
    function deposit(bool _autoCompound) external payable {
        require(msg.value >= minStake, "Amount smaller than minimum deposit");
        uint256 ethAmount = msg.value;

        // Convert ETH to WETH
        IWETH(wethAddress).deposit{value: ethAmount}();
        IWETH(wethAddress).transfer(address(this), ethAmount);

        // Calculate and mint receipt tokens
        uint256 receiptTokens = (ethAmount * 10) / 1; // 1:10 ratio
        _mint(msg.sender, receiptTokens);

        if (stakers[msg.sender].deposited == 0) {
            stakers[msg.sender].timeOfLastUpdate = block.timestamp;
            stakers[msg.sender].autoCompound = _autoCompound; // Set auto compound flag
        }
        stakers[msg.sender].deposited += ethAmount;
    }

    // Compound rewards by converting to WETH and staking
    function compoundRewards() external payable {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");
        require(compoundRewardsTimer(msg.sender) == 0, "Compounding too soon");
        require(stakers[msg.sender].autoCompound, "Auto compound not enabled");

        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        uint256 fee = (rewards * compoundingFee) / 100;
        uint256 amountToCompound = rewards - fee;

        // Add rewards to the deposit
        stakers[msg.sender].deposited += amountToCompound;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = 0;

        // Convert rewards to WETH
        IWETH(wethAddress).deposit{value: amountToCompound}();
        IWETH(wethAddress).transfer(address(this), amountToCompound);

        // Transfer the compounding fee as a reward to the caller
        payable(msg.sender).transfer(fee);
    }

    // Calculate and mint rewards tokens
    function claimRewards() external {
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        require(rewards > 0, "You have no rewards");

        stakers[msg.sender].unclaimedRewards = 0;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;

        _mint(msg.sender, rewards);
    }

    // Withdraw specified amount of staked tokens and convert to ETH
    function withdraw(uint256 _amount) external {
        require(
            stakers[msg.sender].deposited >= _amount,
            "Can't withdraw more than you have"
        );
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalToWithdraw = _amount + rewards;

        // Convert to ETH and transfer
        IWETH(wethAddress).withdraw(totalToWithdraw);
        payable(msg.sender).transfer(totalToWithdraw);

        stakers[msg.sender].deposited -= _amount;
        stakers[msg.sender].timeOfLastUpdate = block.timestamp;
        stakers[msg.sender].unclaimedRewards = rewards;
    }

    // Withdraw all stake and rewards and mint them to the msg.sender
    function withdrawAll() external {
        require(stakers[msg.sender].deposited > 0, "You have no deposit");
        uint256 rewards = calculateRewards(msg.sender) +
            stakers[msg.sender].unclaimedRewards;
        uint256 totalToWithdraw = stakers[msg.sender].deposited + rewards;

        // Convert to ETH and transfer
        IWETH(wethAddress).withdraw(totalToWithdraw);
        payable(msg.sender).transfer(totalToWithdraw);

        stakers[msg.sender].deposited = 0;
        stakers[msg.sender].timeOfLastUpdate = 0;
        stakers[msg.sender].unclaimedRewards = 0;
    }

    // Function useful for the front-end that returns user stake and rewards by address
    function getDepositInfo(
        address _user
    ) public view returns (uint256 _stake, uint256 _rewards) {
        _stake = stakers[_user].deposited;
        _rewards =
            calculateRewards(_user) +
            stakers[msg.sender].unclaimedRewards;
        return (_stake, _rewards);
    }

    // Utility function that returns the timer for restaking rewards
    function compoundRewardsTimer(
        address _user
    ) public view returns (uint256 _timer) {
        if (stakers[_user].timeOfLastUpdate + compoundFreq <= block.timestamp) {
            return 0;
        } else {
            return
                (stakers[_user].timeOfLastUpdate + compoundFreq) -
                block.timestamp;
        }
    }

    // Calculate the rewards since the last update on Deposit info
    function calculateRewards(
        address _staker
    ) internal view returns (uint256 rewards) {
        return (((((block.timestamp - stakers[_staker].timeOfLastUpdate) *
            stakers[_staker].deposited) * rewardsPerHour) / 3600) / 10000000);
    }
}
