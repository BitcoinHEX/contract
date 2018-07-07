pragma solidity ^0.4.23;
import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {

    event Mint(address indexed _address, uint _reward);

    uint256 public totalBtcCirculationAtFork;

    uint256 public totalStakedCoins;

    struct StakeStruct {
        uint256 stakeAmount;
        uint256 stakeTime;
        uint256 unlockTime;
        uint256 totalStakedCoinsAtStart;
    }

    mapping(address => StakeStruct[]) public staked;

    function compound(
        uint256 _principle, 
        uint256 _periods, 
        uint256 _interestRateTimesHundred
    ) 
        internal 
        pure 
        returns (uint256) 
    {
        /* Calculate compound interest */
        return (_principle * (100 + _interestRateTimesHundred) ** _periods)/(100 ** _periods);
    }

    function startStake(
        uint256 _value, 
        uint256 _unlockTime
    ) 
        external 
    {
        address _staker = msg.sender;

        /* Make sure staker has enough funds */
        require(balances[_staker] >= _value);
        /* ensure unlockTime is in the future */
        require(_unlockTime >= block.timestamp.add(10 days));
        /* ensure that unlock time is not more than approx 10 years */
        require(_unlockTime <= block.timestamp.add(10 days * 3650));

        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        /* Remove balance from sender */
        balances[_staker] = balances[_staker].sub(_value);
        balances[address(this)] = balances[address(this)].add(_value);
        emit Transfer(_staker, address(this), _value);

        /* Create Stake */
        staked[_staker].push(
          StakeStruct(
            _value, 
            block.timestamp, 
            _unlockTime, 
            totalStakedCoins
          )
        );

        /* Add staked coins to global stake counter */
        totalStakedCoins = totalStakedCoins.add(_value);
    }

    function calculateWeAreAllSatoshiRewards(
        StakeStruct _stake
    ) 
        internal 
        view 
        returns (uint256)
    {
        uint256 _rewards = 0;
        /* Calculate what week stake was opened */
        uint256 startWeek = _stake.stakeTime
            .sub(launchTime)
            .div(7 days);

        /* Calculate current week */
        uint256 weeksSinceLaunch = block.timestamp
            .sub(launchTime)
            .div(7 days);

        /* Award 2% of unclaimed coins at end of every week */
        for (uint256 _i = startWeek; _i < weeksSinceLaunch; _i++) {
            _rewards = _rewards
                .add(unclaimedCoinsByWeek[_i]
                .mul(_stake.stakeAmount)
                .div(50));
        }

        return _rewards;
    }

    function calculateViralRewards(
        uint256 _rewards
    ) 
        internal 
        view 
        returns (uint256)
    {
        /* Add bonus percentage to _rewards from 0-10% based on adoption */
        return _rewards
            .mul(totalRedeemed)
            .div(totalBtcCirculationAtFork)
            .div(10);
    }

    function calculateCritMassRewards(
        uint256 _rewards
    ) 
        internal 
        view 
        returns (uint256)
    {
        /* Add bonus percentage to _rewards from 0-10% based on adoption */
        return _rewards
            .mul(totalRedeemed)
            .div(maximumRedeemable)
            .div(10);
    }

    function calculateStakingRewards(
        StakeStruct _stake
    ) 
        internal 
        view 
        returns (uint256)
    {
        /* Base interest rate */
        uint256 interestRateTimesHundred = 100;

        /* Calculate Adoption Percent Scaler */
        uint256 scaler = _stake.totalStakedCoinsAtStart
            .mul(100)
            .div(totalSupply_);

        /* Adjust interest rate by scaler */
        interestRateTimesHundred = interestRateTimesHundred.div(scaler);

        /* Calculate Periods */
        uint256 periods = block.timestamp
            .sub(_stake.stakeTime)
            .div(10 days);

        /* Compound */
        uint256 compoundRound = compound(_stake.stakeAmount, periods, interestRateTimesHundred);

        /* Calculate final staking rewards with time bonus */
        return compoundRound
            .mul(periods)
            .div(1000)
            .add(compoundRound)
            .sub(_stake.stakeAmount);
    }

    function calculateAdditionalRewards(
        StakeStruct _stake, 
        uint256 _initRewards
    ) 
        internal 
        view 
        returns (uint256)
    {
        uint256 _rewards = 0;
        _rewards = _initRewards.add(calculateWeAreAllSatoshiRewards(_stake));
        _rewards = _rewards
            .add(calculateViralRewards(_rewards))
            .add(calculateCritMassRewards(_rewards));

        return _rewards;
    }

    // paginate?
    function getCurrentStaked(
        address _staker
    ) 
        external 
        view 
        returns(uint256)
    {
        uint256 _stakes = 0;

        for (uint256 _i; _i < staked[_staker].length; _i++) {
            /* Add Stake Amount */
            _stakes = _stakes.add(staked[_staker][_i].stakeAmount);
            /* Check if stake has matured */
            if (block.timestamp > staked[_staker][_i].unlockTime) {
                /* Calculate Rewards */
                _stakes = _stakes.add(
                    calculateAdditionalRewards(
                        staked[_staker][_i], 
                        calculateStakingRewards(staked[_staker][_i])
                    )
                );
            }
        }

        return _stakes;
    }

    // TODO: check if this needs to be paginated somehow due to gas limits....
    function claimStakingRewards(
        address _staker
    ) 
        external 
    {
        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        for (uint256 _i = 0; _i < staked[_staker].length; _i++) {
            /* Check if stake has matured */
            if (block.timestamp > staked[_staker][_i].unlockTime) {
                /* Remove StakedCoins from global counter */
                totalStakedCoins = totalStakedCoins
                    .sub(staked[_staker][_i].stakeAmount);

                /* Sub staked coins from contract */
                balances[address(this)] = balances[address(this)]
                    .sub(staked[_staker][_i].stakeAmount);
                
                /* Add staked coins to staker */
                balances[_staker] = balances[_staker]
                    .add(staked[_staker][_i].stakeAmount);

                emit Transfer(
                    address(this), 
                    _staker, 
                    staked[_staker][_i].stakeAmount
                );

                /* Calculate Rewards */
                uint256 _stakingRewards = calculateStakingRewards(staked[_staker][_i]);
                uint256 _rewards = _stakingRewards.add(
                    calculateAdditionalRewards(
                        staked[_staker][_i], 
                        _stakingRewards
                    )
                );

                /* Award staking rewards to staker */
                balances[_staker] = balances[_staker].add(_rewards);

                /* Award rewards to origin contract */
                balances[origin] = balances[origin]
                    .add(_rewards
                    .sub(_stakingRewards));

                /* Increase supply */
                totalSupply_ = totalSupply_.add(_rewards.mul(2));

                /* Remove Stake */
                delete staked[_staker][_i];

                emit Mint(_staker, _rewards);
            }
        }
    }
}
