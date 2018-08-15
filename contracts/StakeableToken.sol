pragma solidity ^0.4.23;
import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {

  event Mint(address indexed _address, uint _reward);

  uint256 public totalBtcCirculationAtFork;
  uint256 public constant interestRatePercent = 1;
  uint256 public constant maxStakingTimeInSeconds = 365 days * 10;
  uint256 public constant oneInterestPeriodInSeconds = 10 days;

  struct StakeStruct {
    uint256 stakeAmount;
    uint256 stakeTime;
    uint256 unlockTime;
    uint256 totalStakedCoinsAtStart;
    uint256 totalSupplyAtStart;
  }

  mapping(address => StakeStruct[]) public staked;

  /************************
  *start utility functions*
  ************************/

  function getUserStakes(address _staker)
    public
    view
    returns (uint256[], uint256[], uint256[], uint256[])
  {
    uint256 _stakesLength = staked[_staker].length;
    uint256[] memory _stakeAmount = new uint256[](_stakesLength);
    uint256[] memory _stakeTime = new uint256[](_stakesLength);
    uint256[] memory _unlockTime = new uint256[](_stakesLength);
    uint256[] memory _totalStakedCoinsAtStart = new uint256[](_stakesLength);

    for (uint256 _i = 0; _i < _stakesLength; _i++) {
      StakeStruct storage stake = staked[_staker][_i];
      _stakeAmount[_i] = stake.stakeAmount;
      _stakeTime[_i] = stake.stakeTime;
      _unlockTime[_i] = stake.unlockTime;
      _totalStakedCoinsAtStart[_i] = stake.totalStakedCoinsAtStart;
    }

    return (_stakeAmount, _stakeTime, _unlockTime, _totalStakedCoinsAtStart);
  }

  function getWeeksSinceLaunch()
    public
    view
    returns (uint256)
  {
    return block.timestamp > launchTime 
      ? block.timestamp.sub(launchTime).div(7 days) 
      : 0;
  }

  function isDuringBonusPeriod()
    public
    view
    returns (bool)
  {
    return getWeeksSinceLaunch() <= 50;
  }

  /** 
    @dev Moves last item in array to location of item to be removed,
    overwriting array item. Shortens array length by 1, removing now
    duplicate item at end of array.
    @param _staker staker address for accessing array
    @param _stakeIndex index of the item to delete
  */
  function removeArrayEntry(
    address _staker,
    uint256 _stakeIndex
  )
    public
  {
    StakeStruct[] storage _stakedArray = staked[_staker];
    // set last item to index of item we want to get rid of
    _stakedArray[_stakeIndex] = _stakedArray[_stakedArray.length.sub(1)];
    // remove last item in array now that safely copied to index of deleted item
    _stakedArray.length = _stakedArray.length.sub(1);
  }

  // TODO: HEAVILY test this in order to ensure that there are no integer overflows
  /**
    @dev compound groups up compounding periods by 30 in order to avoid  
    uint overflows when taking (100 + rate) ** periods. Accuracy is also brought by
    10 decimals in order to avoid uint overflows when 
    taking compounded * ((100  + rate) ** periods).

    @param _principle base amount being compounded
    @param _periods amount of periods to compound principle
    @param _rate rate given as uint percent 
  */
  function compound(
    uint256 _principle,
    uint256 _periods,
    uint256 _rate
  )
    public
    pure
    returns (uint256)
  {
    uint256 _maxGroupPeriods = 10;
    uint256 _remainingPeriods = _periods % _maxGroupPeriods;
    uint256 _groupings = _periods.div(_maxGroupPeriods);
    uint256 _compounded = _principle.div(1e10);

    for(uint256 _i = 0; _i < _groupings; _i = _i.add(1)) {
      _compounded = _compounded
        .mul(_rate ** _maxGroupPeriods)
        .div(1e4 ** _maxGroupPeriods);
    }

    if (_remainingPeriods != 0) {
      _compounded = _compounded
        .mul(_rate ** _remainingPeriods)
        .div(1e4 ** _remainingPeriods);
    }

    return _compounded.mul(1e10);
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

    // raise by 100 in order to adjust with scaler
    uint256 _interestRateTimesHundred = interestRatePercent.mul(100);

    // default _scaler to 1
    uint256 _scaler = 1;
    // default _scaledInterestRate to 100
    uint256 _scaledInterestRate = 100;
    // calculate percent of staked coins vs totalSupply to use for interest rate reduction
    if (_stake.totalStakedCoinsAtStart != 0) {
      uint256 _scalerCandidate = _stake.totalStakedCoinsAtStart
        .mul(100)
        .div(_stake.totalSupplyAtStart);
      
      _scaler = _scalerCandidate > 0 ? _scalerCandidate : 1;

      // reduce interest rate by scaler
      uint256 _scaledInterestRateCandidate = _interestRateTimesHundred.div(_scaler);

      _scaledInterestRate = _scaledInterestRateCandidate > 0 
        ? _scaledInterestRateCandidate 
        : 1;
    }

    // bring up by 1e4 in order to get an accurate percent
    uint256 _interestRate = _scaledInterestRate.add(1e4);
    // Calculate Periods
    uint256 _periods = _stake.unlockTime
      .sub(_stake.stakeTime)
      .div(oneInterestPeriodInSeconds);
    // Compound
    uint256 _compounded = compound(
      _stake.stakeAmount, 
      _periods, 
      _interestRate
    );

    // Calculate final staking rewards with time bonus
    return _compounded.sub(_stake.stakeAmount);
  }

  function calculateWeAreAllSatoshiRewards(
    uint256 _stakeAmount,
    uint256 _stakeTime,
    uint256 _unlockTime
  ) 
    public 
    view 
    returns (uint256)
  {
    uint256 _rewards = 0;
    /* Calculate what week stake was opened */
    uint256 _startWeekCandidate = _stakeTime
      .sub(launchTime)
      .div(7 days);

    // rewards are not deducted nor given during first week
    uint256 _startWeek = _startWeekCandidate == 0 ? 1 : _startWeekCandidate;

    uint256 _endWeek = _unlockTime
      .sub(launchTime)
      .div(7 days);

    uint256 _rewardableEndWeek = _endWeek > 50 ? 50 : _endWeek;

    // Award 2% of unclaimed coins at end of every week
    for (uint256 _i = _startWeek; _i < _rewardableEndWeek; _i++) {
      uint256 _rewardRatio = _stakeAmount
        .mul(100)
        .div(satoshiRewardDataByWeek[_i].totalStaked);

      uint256 _satoshiRewardWeek = satoshiRewardDataByWeek[_i].unclaimedCoins
        .div(50)
        .mul(_rewardRatio)
        .div(100);

      _rewards = _rewards.add(_satoshiRewardWeek);
    }

    return _rewards;
  }

  // TODO: double check that we want to make this public... if so... is it ok that
  // it shows non zero amounts for users outside of bonus period?
  function calculateViralRewards(
    uint256 _stakeAmount
  ) 
    public 
    view 
    returns (uint256)
  {
    // Add bonus percentage to _rewards from 0-10% based on adoption
    return _stakeAmount
      .mul(redeemedCount)
      .div(totalBtcCirculationAtFork)
      .div(10);
  }

  function calculateCritMassRewards(
    uint256 _stakeAmount
  ) 
    public 
    view 
    returns (uint256)
  {
    // Add bonus percentage to _rewards from 0-10% based on adoption
    return _stakeAmount
      .mul(totalRedeemed)
      .div(maximumRedeemable)
      .div(10);
  }

  /**
    @dev Additional rewards should only be given within first 50 weeks.
   */
  function calculateAdditionalRewards(
    address _staker,
    uint256 _stakeIndex
  ) 
    public 
    view 
    returns (uint256)
  {
    StakeStruct storage _stake = staked[_staker][_stakeIndex];
    // only give rewards if within first 50 weeks
    if (_stake.stakeTime.sub(launchTime).div(7 days) <= 50) {
      uint256 _weAreAllSatoshiRewards = calculateWeAreAllSatoshiRewards(
        _stake.stakeAmount,
        _stake.stakeTime,
        _stake.unlockTime
      );
      uint256 _viralRewards = calculateViralRewards(_stake.stakeAmount);
      uint256 _critMassRewards = calculateCritMassRewards(_stake.stakeAmount);
      uint256 _rewards = _weAreAllSatoshiRewards
        .add(_viralRewards)
        .add(_critMassRewards);

      return _rewards;
    } else {
      return 0;
    }

    return 0;
  }

  /**
    @notice available for use directly when there are too many stakes to do in a single operation
  */
  function getStakedAtIndexes(
    address _staker,
    uint256 _startIndex,
    uint256 _endIndex
  )
    public
    view
    returns (uint256)
  {
    uint256 _maxIndex = staked[_staker].length - 1;
    require(_endIndex <= _maxIndex);
    require(_startIndex >= 0);
    uint256 _totalStaked;
    // ensure that there are stakes to be retreived
    if (staked[_staker].length == 0) {
      return 0;
    }

    // return single stake if indexes are the same
    if( _startIndex == _endIndex) {
      return staked[_staker][0].stakeAmount;
    }

    for (uint256 _i = _startIndex; _i <= _endIndex; _i++) {
      _totalStaked = _totalStaked.add(staked[_staker][_i].stakeAmount);
    }

    return _totalStaked;
  }

  /**
    @notice This function might fail if there are too many stakes for a user. Use getStakedAtIndexes if this is the case.
  */
  function getTotalUserStaked(
    address _staker
  )
    public
    view
    returns (uint256)
  {
    return getStakedAtIndexes(_staker, 0, staked[_staker].length - 1);
  }

  function calculateSingleStakePlusRewards(
    address _staker,
    uint256 _stakeIndex
  )
    public
    view
    returns (uint256)
  {
    uint256 _stake = staked[_staker][_stakeIndex].stakeAmount;
    
    if (block.timestamp > staked[_staker][_stakeIndex].unlockTime) {
      return _stake.add(
          calculateAdditionalRewards(
            _staker,
            _stakeIndex
          )
      );
    } else {
      return _stake;
    }
  }

  /**********************
  *end utility functions*
  **********************/

  /*********************
  *start user functions*
  *********************/

  /** 
    @notice start a stake in order to claim rewards at later unlock time.
    Additional rewards only payable within first 50 weeks.
    @param _value amount of tokens to lock
    @param _unlockTime unix timestamp date for when to unlock tokens
  */
  function startStake(
    uint256 _value, 
    uint256 _unlockTime
  ) 
    external
    returns (bool)
  {
    address _staker = msg.sender;

    // Make sure staker has enough funds
    require(balances[_staker] >= _value);
    // ensure that unlock time is not more than approx 10 years
    require(_unlockTime <= block.timestamp.add(maxStakingTimeInSeconds));
    // Check if weekly data needs to be updated
    storeSatoshiWeekData();

    // Remove balance from sender
    balances[_staker] = balances[_staker].sub(_value);
    balances[address(this)] = balances[address(this)].add(_value);

    // Create Stake
    staked[_staker].push(
      StakeStruct(
        _value, 
        block.timestamp, 
        _unlockTime, 
        totalStakedCoins,
        totalSupply_
      )
    );

    // ensure that the new stake will return interest
    require(calculateStakingRewards(_staker, staked[_staker].length.sub(1)) > 0);

    // Add staked coins to global stake counter
    totalStakedCoins = totalStakedCoins.add(_value);

    return true;
  }
  
  /**
    @notice Used for claiming a single stake. Another user can claim a stake on another 
    user's behalf. All rewards and original stake go to original staker.
    Useful for if _staker does not have any gas and someone else is claiming for them.
    @param _staker user address for who is making the claim
    @param _stakeIndex location of the stake to claim
  */
  function claimSingleStakingReward(
    address _staker,
    uint256 _stakeIndex
  )
    public
    returns (bool)
  {
    StakeStruct memory _stake = staked[_staker][_stakeIndex]; 
    require(block.timestamp >= _stake.unlockTime);
    // Check if weekly data needs to be updated
    storeSatoshiWeekData();

    uint256 _startingStake = _stake.stakeAmount;
    // Calculate Rewards
    uint256 _stakingRewards = calculateStakingRewards(
      _staker, 
      _stakeIndex
    );
    uint256 _additionalRewards = calculateAdditionalRewards(
      _staker,
      _stakeIndex
    );
    uint256 _rewards = _startingStake
      .add(_stakingRewards)
      .add(_additionalRewards);
    
    // Remove StakedCoins from global counter
    totalStakedCoins = totalStakedCoins
      .sub(_startingStake);

    // Sub staked coins from contract
    balances[address(this)] = balances[address(this)]
      .sub(_startingStake);
    
    // Add staked coins to staker
    balances[_staker] = balances[_staker]
      .add(_rewards);

    // Award rewards to origin contract
    balances[origin] = balances[origin]
      .add(_additionalRewards);

    emit Transfer(
      address(this), 
      _staker, 
      _stake.stakeAmount
    );

    // Increase supply
    totalSupply_ = totalSupply_.add(_stakingRewards);
    totalSupply_ = totalSupply_.add(_additionalRewards.mul(2));

    emit Mint(_staker, _additionalRewards.add(_stakingRewards));
    emit Mint(origin, _additionalRewards);

    // Remove Stake
    removeArrayEntry(_staker, _stakeIndex);

    return true;
  }

  // TODO: make this private
  /**
    @notice Used for claiming multiple stakes. Another user can 
    claim a stake on another user's behalf. All rewards and original stake go to original staker.
    Useful for if _staker does not have any gas and someone else is claiming for them.
    @param _staker user address for who is making the claim
    @param _startIndex claim stakes from this location
    @param _endIndex claim stakes up to this location
  */
  function claimMultipleStakingRewards( // this is no longer truthful when using removeArrayEntry... hm....
    address _staker,
    uint256 _startIndex,
    uint256 _endIndex
  ) 
    public 
    returns (bool)
  {
    // ensure that indexes are in array bounds
    require(_startIndex <= _endIndex);
    require(_endIndex < staked[_staker].length);

    uint256 _i = _startIndex;
    while (_i <= _endIndex) {
      // Check if stake has matured
      // all stakes can be claimed using 0 index due to arrays reorganizing every time one is removed
      if (block.timestamp >= staked[_staker][0].unlockTime) {
        claimSingleStakingReward(_staker, 0);
        _i = _i.add(1);
      }
    }

    return true;
  }

  function claimAllStakingRewards(
    address _staker
  )
    external
    returns (bool)
  {
    uint256 _stakeArrayLength = staked[_staker].length;
    uint256 _processedCount = 0;
    uint256 _cursor = 0;
    if (_stakeArrayLength == 0) {
      return false;
    }

    while (_processedCount < _stakeArrayLength) {
      _cursor = _cursor.add(1) > staked[_staker].length
        ? 0
        : _cursor;

      if (block.timestamp >= staked[_staker][_cursor].unlockTime) {
        claimSingleStakingReward(_staker, _cursor);
      }

      _processedCount = _processedCount.add(1);
      _cursor = _cursor.add(1);
    }

    return true;
  }

  /********************
  *start end functions*
  ********************/
}
