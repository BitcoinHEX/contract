pragma solidity ^0.4.23;
import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {

    event Mint(address indexed _address, uint _reward);

    uint256 public totalBtcCirculationAtFork;

    uint256 public totalStakedCoins;
    uint256 public interestRatePercent;

    struct StakeStruct {
        uint256 stakeAmount;
        uint256 stakeTime;
        uint256 unlockTime;
        uint256 totalStakedCoinsAtStart;
    }

    mapping(address => StakeStruct[]) public staked;

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

    function compound(
        uint256 _principle,
        uint256 _periods,
        uint256 _rate
    )
        public
        pure
        returns (uint256)
    {
        uint256 _maxGroupPeriods = 30;
        uint256 _remainingPeriods = _periods % _maxGroupPeriods;
        uint256 _groupings = _periods.div(_maxGroupPeriods);
    
        uint256 _compounded = _principle.div(1e10);
        for(uint256 _i = 0; _i < _groupings; _i = _i.add(1)) {
            _compounded = _compounded
                .mul(uint256(100).add(_rate) ** 30)
                .div(100 ** 30);
        }

        _compounded = _compounded
            .mul(uint256(100).add(_rate) ** _remainingPeriods)
            .div(100 ** _remainingPeriods);
        
        return _compounded.mul(1e10);
    }

    function calculateWeAreAllSatoshiRewards(
        address _staker,
        uint256 _stakeIndex
    ) 
        public 
        view 
        returns (uint256)
    {
        StakeStruct storage _stake = staked[_staker][_stakeIndex];
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

    // TODO: this must operate on weekly claims
    function calculateViralRewards(
        uint256 _rewards
    ) 
        public 
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
        public 
        view 
        returns (uint256)
    {
        /* Add bonus percentage to _rewards from 0-10% based on adoption */
        return _rewards
            .mul(totalRedeemed)
            .div(maximumRedeemable)
            .div(10);
    }

    function calculateSpeedBonus(
        address _staker,
        uint256 _stakeIndex,
        uint256 _rewards
    )
        public
        view
        returns (uint256)
    {
        uint256 _stakeTime = staked[_staker][_stakeIndex].stakeTime;
        uint256 _weeksSinceLaunch = _stakeTime
            .sub(launchTime)
            .div(7 days);

        // bonus based on 10 percent being max 
        uint256 _scaler = uint256(10) // max bonus percent
            .sub( // sub calculated portion of max bonus percent
                _weeksSinceLaunch
                .mul(100) // raise by 100 due to integer division
                .div(50) // max weeks
                .mul(10) // max bonus percent
                .div(100) // lower by 200 after calculations
            );

        return _rewards.mul(_scaler).div(100);
    }

    function calculateAdditionalRewards(
        address _staker,
        uint256 _stakeIndex, 
        uint256 _initRewards
    ) 
        public 
        view 
        returns (uint256)
    {
        // only give rewards if within first 50 weeks
        if (block.timestamp.sub(launchTime).div(7 days) <= 50) {
            uint256 _rewards = 0;
            _rewards = _initRewards.add(calculateWeAreAllSatoshiRewards(_staker, _stakeIndex));
            _rewards = _rewards
                .add(calculateViralRewards(_rewards))
                .add(calculateCritMassRewards(_rewards))
                .add(calculateSpeedBonus(_staker, _stakeIndex, _rewards));

            return _rewards;
        } else {
            return 0;
        }
    }

    function calculateStakingRewards(
        address _staker,
        uint256 _stakeIndex
    ) 
        public 
        view 
        returns (uint256)
    {
        StakeStruct storage _stake = staked[_staker][_stakeIndex];
        /* Base interest rate */
        uint256 _interestRateTimesHundred = interestRatePercent.mul(100);

        // calculate percent of staked coins vs totalSupply to use for interest rate reduction
        uint256 _scaler = _stake.totalStakedCoinsAtStart
            .mul(100)
            .div(totalSupply_);

        /* reduce interest rate by percent of tokens staked against totalSupply */
        _interestRateTimesHundred = _interestRateTimesHundred.div(_scaler);

        /* Calculate Periods */
        uint256 _periods = block.timestamp
            .sub(_stake.stakeTime)
            .div(10 days);

        /* Compound */
        uint256 _compounded = compound(
            _stake.stakeAmount, 
            _periods, 
            _interestRateTimesHundred
        );

        /* Calculate final staking rewards with time bonus */
        return _compounded.sub(_stake.stakeAmount);
    }

    // paginate?
    function getCurrentStaked(
        address _staker
    )
        external 
        view 
        returns (uint256)
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
                        _staker,
                        _i,
                        calculateStakingRewards(_staker, _i)
                    )
                );
            }
        }

        return _stakes;
    }

    // TODO: paginate or make single use
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
                uint256 _stakingRewards = calculateStakingRewards(_staker, _i);
                uint256 _rewards = _stakingRewards.add(
                    calculateAdditionalRewards(
                        _staker,
                        _i,
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
