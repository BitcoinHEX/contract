pragma solidity ^0.4.23;
import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {

  event Mint(address indexed _address, uint _reward);

  uint256 public totalBtcCirculationAtFork;
  uint256 public totalStakedCoins;
  uint256 public constant interestRatePercent = 1;

  struct StakeStruct {
    uint256 stakeAmount;
    uint256 stakeTime;
    uint256 unlockTime;
    uint256 totalStakedCoinsAtStart;
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
    @param _array an array of StakeStructs
    @param _index index of the item to delete
  */
  function removeArrayEntry(
    StakeStruct[] storage _array,
    uint256 _index
  )
    internal
  {
    // set last item to index of item we want to get rid of
    _array[_index] = _array[_array.length.sub(1)];
    // remove last item in array now that safely copied to index of deleted item
    _array.length = _array.length.sub(1);
  }

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
    uint256 _maxGroupPeriods = 30;
    uint256 _remainingPeriods = _periods % _maxGroupPeriods;
    uint256 _groupings = _periods.div(_maxGroupPeriods);
    uint256 _compounded = _principle.div(1e10);

    for(uint256 _i = 0; _i < _groupings; _i = _i.add(1)) {
      _compounded = _compounded
        .mul(_rate ** _remainingPeriods)
        .div(1e4 ** _remainingPeriods);
    }

    _compounded = _compounded
      .mul(_rate ** _remainingPeriods)
      .div(1e4 ** _remainingPeriods);

    return _compounded.mul(1e10);
  }

  // TODO: HEAVILY test this in order to ensure that there are no integer overflows
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

    // calculate percent of staked coins vs totalSupply to use for interest rate reduction
    uint256 _scaler = _stake.totalStakedCoinsAtStart != 0 
      ? _stake.totalStakedCoinsAtStart
        .mul(100)
        .div(totalSupply_)
      : 1;

    // reduce interest rate by scaler
    uint256 _scaledInterestRate = _interestRateTimesHundred.div(_scaler);
    // bring up by 1e4 in order to get an accurate percent
    uint256 _interestRate = _scaledInterestRate.add(1e4);
    // Calculate Periods
    uint256 _periods = _stake.unlockTime
      .sub(_stake.stakeTime)
      .div(10 days);
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
    uint256 _stakeTime,
    uint256 _unlockTime
  ) 
    public 
    view 
    returns (uint256)
  {
    uint256 _rewards = 0;
    /* Calculate what week stake was opened */
    uint256 _startWeek = _stakeTime
      .sub(launchTime)
      .div(7 days);

    uint256 _endWeek = _unlockTime
      .sub(launchTime)
      .div(7 days);

    uint256 _rewardableEndWeek = _endWeek > 50 ? 50 : _endWeek;

    // Award 2% of unclaimed coins at end of every week
    for (uint256 _i = _startWeek; _i < _rewardableEndWeek; _i++) {
      _rewards = _rewards.add(unclaimedCoinsByWeek[_i].div(50));
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
      .mul(totalRedeemed)
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

  /**
    @notice Used in case user creates excessive stakes and array iteration hits gasLimit.
    @param _staker user for which to check stakes
    @param _startIndex get stakes from location
    @param _endIndex get stakes up to location
  */
  function getCurrentStakedAtIndexes(
    address _staker,
    uint256 _startIndex,
    uint256 _endIndex
  )
    public
    view
    returns (uint256)
  {
    require(_startIndex <= _endIndex);
    require(_endIndex < staked[_staker].length);

    StakeStruct[] storage _stakes = staked[_staker];
    if (_startIndex == _endIndex) {
      return _stakes[_startIndex].stakeAmount;
    }

    uint256 _totalStaked = 0;
    uint256 _i = _startIndex;
    while (_i <= _endIndex) {
      _totalStaked = _totalStaked.add(_stakes[_i].stakeAmount);
      _i = _i.add(1);
    }

    return _totalStaked;
  }

  /**
    @notice Safe for users who have no placed excessive amounts of stakes.
    @param _staker the user address for which to check current staked
  */
  function getCurrentStaked(
    address _staker
  )
    external
    view 
    returns (uint256)
  {
    if (staked[_staker].length == 0) {
      return 0;
    }

    return getCurrentStakedAtIndexes(_staker, 0, staked[_staker].length.sub(1));
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
    // ensure unlockTime is in the future
    require(_unlockTime >= block.timestamp.add(10 days));
    // ensure that unlock time is not more than approx 10 years
    require(_unlockTime <= block.timestamp.add(10 * 365 days));

    // Check if weekly data needs to be updated
    storeWeekUnclaimed();

    // Remove balance from sender
    balances[_staker] = balances[_staker].sub(_value);
    balances[address(this)] = balances[address(this)].add(_value);

    // Create Stake
    staked[_staker].push(
      StakeStruct(
        _value, 
        block.timestamp, 
        _unlockTime, 
        totalStakedCoins
      )
    );

    // Add staked coins to global stake counter
    totalStakedCoins = totalStakedCoins.add(_value);

    return true;
  }

  event Test(uint value);
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
    StakeStruct storage _stake = staked[_staker][_stakeIndex];
    require(block.timestamp >= _stake.unlockTime);
    // Check if weekly data needs to be updated
    storeWeekUnclaimed();

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

    // Remove Stake
    removeArrayEntry(staked[_staker], _stakeIndex); 
    
    // Remove StakedCoins from global counter
    totalStakedCoins = totalStakedCoins
      .sub(_startingStake);
    emit Test(_startingStake);

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
    totalSupply_ = totalSupply_.add(_additionalRewards.mul(2));

    emit Mint(_staker, _additionalRewards);
    emit Mint(origin, _additionalRewards);
  }

  /**
    @notice Used for claiming multiple stakes. Another user can 
    claim a stake on another user's behalf. All rewards and original stake go to original staker.
    Useful for if _staker does not have any gas and someone else is claiming for them.
    @param _staker user address for who is making the claim
    @param _startIndex claim stakes from this location
    @param _endIndex claim stakes up to this location
  */
  function claimMultipleStakingRewards(
    address _staker,
    uint256 _startIndex,
    uint256 _endIndex
  ) 
    external 
    returns (bool)
  {
    // ensure that indexes are in array bounds
    require(_startIndex <= _endIndex);
    require(_endIndex <= staked[_staker].length);

    for (uint256 _i = _startIndex; _i < _endIndex; _i++) {
      // Check if stake has matured
      if (block.timestamp > staked[_staker][_i].unlockTime) {
        claimSingleStakingReward(_staker, _i);
      }
    }

    return true;
  }

  /********************
  *start end functions*
  ********************/
}
