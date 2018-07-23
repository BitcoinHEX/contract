pragma solidity ^0.4.23;
import "./UTXORedeemableToken.sol";


contract StakeableToken is UTXORedeemableToken {

  event Mint(address indexed _address, uint _reward);
  // TODO: remove this
  event Test(string label, uint256 testValue);

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
        .mul(uint256(1).add(_rate) ** _remainingPeriods)
        .div(100 ** _remainingPeriods);
    }

    _compounded = _compounded
      .mul(uint256(1).add(_rate) ** _remainingPeriods)
      .div(100 ** _remainingPeriods);

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
    // Base interest rate
    uint256 _interestRateTimesHundred = interestRatePercent.mul(100);

    // calculate percent of staked coins vs totalSupply to use for interest rate reduction
    uint256 _scaler = _stake.totalStakedCoinsAtStart != 0 
      ? _stake.totalStakedCoinsAtStart
        .mul(100)
        .div(totalSupply_)
      : 1;
    // reduce interest rate by percent of tokens staked against totalSupply
    _interestRateTimesHundred = _interestRateTimesHundred.div(_scaler);

    // Calculate Periods
    uint256 _periods = _stake.unlockTime
      .sub(_stake.stakeTime)
      .div(10 days);
    // Compound
    uint256 _compounded = compound(
      _stake.stakeAmount, 
      _periods, 
      _interestRateTimesHundred
    );

    // Calculate final staking rewards with time bonus
    return _compounded.sub(_stake.stakeAmount);
  }

  // TODO: double check this works as intended...
  function calculateWeAreAllSatoshiRewards(
    uint256 _stakeAmount,
    uint256 _stakeTime
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

    // Calculate current week
    uint256 _weeksSinceLaunch = block.timestamp
      .sub(launchTime)
      .div(7 days);

    // Award 2% of unclaimed coins at end of every week
    for (uint256 _i = _startWeek; _i < _weeksSinceLaunch; _i++) {
      _rewards = _rewards
        .add(unclaimedCoinsByWeek[_i]
        .mul(_stakeAmount)
        .div(50));
    }

    return _rewards;
  }

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
    // view 
    returns (uint256)
  {
    StakeStruct storage _stake = staked[_staker][_stakeIndex];
    // only give rewards if within first 50 weeks
    if (_stake.stakeTime.sub(launchTime).div(7 days) <= 50) {
      // Check if weekly data needs to be updated
      storeWeekUnclaimed();
      uint256 _weAreAllSatoshiRewards = calculateWeAreAllSatoshiRewards(
        _stake.stakeAmount, 
        _stake.stakeTime
      );
      uint256 _viralRewards = calculateViralRewards(_stake.stakeAmount);
      uint256 _critMassRewards = calculateCritMassRewards(_stake.stakeAmount);
      uint256 _rewards = _weAreAllSatoshiRewards
        .add(_viralRewards)
        .add(_critMassRewards);

      emit Test("we are all satoshi", _weAreAllSatoshiRewards);
      emit Test("viral", _viralRewards);
      emit Test("crit mass", _critMassRewards);

      return _rewards;
    } else {
      return 0;
    }
  }

  function getStakedEntry(
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

    if (_startIndex == _endIndex) {
      return getStakedEntry(_staker, _startIndex);
    }

    uint256 _stakes = 0;
    for (
      uint256 _stakeIndex = _startIndex; 
      _startIndex < _endIndex; 
      _stakeIndex = _stakeIndex.add(1)
    ) {
      _stakes = _stakes.add(getStakedEntry(_staker, _stakeIndex));
    }

    return _stakes;
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
    require(_unlockTime <= block.timestamp.add(10 days * 3650));

    // Check if weekly data needs to be updated
    storeWeekUnclaimed();

    // Remove balance from sender
    balances[_staker] = balances[_staker].sub(_value);
    balances[address(this)] = balances[address(this)].add(_value);
    emit Transfer(_staker, address(this), _value);

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
    require(block.timestamp > _stake.unlockTime);

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

    emit Test("staking rewards", _stakingRewards);
    emit Test("additional rewards", _additionalRewards);
    emit Test("total rewards + stake", _rewards);

    // Remove Stake
    removeArrayEntry(staked[_staker], _stakeIndex); 
    
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
