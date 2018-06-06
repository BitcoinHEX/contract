pragma solidity ^0.4.23;

import "./UTXORedeemableToken.sol";
import "../node_modules/zeppelin-solidity/contracts/math/SafeMath.sol";

contract StakeableToken is UTXORedeemableToken {
    using SafeMath for uint256;

    event Mint(address indexed _address, uint _reward);

    uint256 totalBTCCirculationAtFork;

    uint256 stakedCoins;

    struct stakeStruct {
        uint256 stakeAmount;
        uint256 stakeTime;
        uint256 unlockTime;
        uint256 stakedCoinsAtStart;
    }

    mapping(address => stakeStruct[]) staked;

    function compound(uint256 _principle, uint256 _periods, uint256 _interestRateTimesHundred) internal pure returns (uint256) {
        // Needs Sanity Check
        return (_principle * (1000 + _interestRateTimesHundred) ** _periods)/(1000 ** _periods);
    }

    function startStake(uint256 _value, uint256 _unlockTime) public {
        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        /* Check if sender has sufficient balance */
        require(_value <= balances[msg.sender]);

        /* Remove balance from sender */
        balances[msg.sender] = balances[msg.sender].sub(_value);

        /* Create Stake */
        staked[msg.sender].push(stakeStruct(uint128(_value), block.timestamp, _unlockTime, stakedCoins));

        /* Add staked coins to global stake counter */
        stakedCoins = stakedCoins.add(_value);
    }

    function calculateWeAreAllSatoshiRewards(stakeStruct stake) internal view returns (uint256 rewards) {
        /* Calculate what week stake was opened */
        uint256 startWeek = stake.stakeTime.sub(launchTime).div(7 days);

        /* Calculate current week */
        uint256 weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);

        /* Award 2% of unclaimed coins at end of every week */
        for (uint256 i = startWeek; i < weeksSinceLaunch; i++){
            rewards = rewards.add(weekData[i].unclaimedCoins.mul(stake.stakeAmount).div(50));
        }
    }

    function calculateViralRewards(uint256 rewards) internal view returns (uint256) {
        /* Add bonus percentage to rewards from 0-10% based on adoption */
        return rewards.mul(totalRedeemed).div(totalBTCCirculationAtFork).div(10);
    }

    function calculateCritMassRewards(uint256 rewards) internal view returns (uint256) {
        /* Add bonus percentage to rewards from 0-10% based on adoption */
        return rewards.mul(totalRedeemed).div(maximumRedeemable).div(10);
    }

    function calculateStakingRewards(stakeStruct stake) internal view returns (uint256) {
        /* Base interest rate */
        uint256 interestRateTimesHundred = 100;

        /* Calculate Adoption Percent Scaler */
        uint256 scaler = stake.stakedCoinsAtStart.mul(100).div(totalSupply_);

        /* Adjust interest rate by scaler */
        interestRateTimesHundred = interestRateTimesHundred.div(scaler);

        /* Calculate Periods */
        uint256 periods = block.timestamp.sub(stake.stakeTime).div(10 days);

        /* Compound */
        uint256 compoundRound = compound(stake.stakeAmount, periods, interestRateTimesHundred);

        /* Calculate final staking rewards with time bonus */
        return compoundRound.mul(periods).div(1000).add(compoundRound).sub(stake.stakeAmount);
        
    }

    function calculateRewards(stakeStruct stake) internal view returns (uint256) {
        uint256 rewards = 0;
        rewards = rewards
        .add(calculateStakingRewards(stake))
        .add(calculateWeAreAllSatoshiRewards(stake));
        rewards = rewards
        .add(calculateViralRewards(rewards))
        .add(calculateCritMassRewards(rewards));
        return rewards;
    }

    function mint() public returns (bool) {
        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        for(uint256 i; i < staked[msg.sender].length; i++){
            /* Check if stake has matured */
            if(block.timestamp > staked[msg.sender][i].unlockTime){
                /* Remove StakedCoins from global counter */
                stakedCoins = stakedCoins.sub(staked[msg.sender][i].stakeAmount);

                /* Add staked coins to staker */
                balances[msg.sender] = balances[msg.sender].add(staked[msg.sender][i].stakeAmount);

                /* Calculate Rewards */
                uint256 rewards = calculateRewards(staked[msg.sender][i]);

                /* Award staking rewards to staker */
                balances[msg.sender] = balances[msg.sender].add(rewards);

                /* Award staking rewards to origin contract */
                balances[owner] = balances[owner].add(rewards);

                /* Increase supply */
                totalSupply_ = totalSupply_.add(rewards.mul(2));

                /* Remove Stake */
                delete staked[msg.sender][i];

                emit Mint(msg.sender, rewards);
            }
        }
    }
}
