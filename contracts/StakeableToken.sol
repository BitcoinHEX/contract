pragma solidity ^0.4.24;

import "./UTXORedeemableToken.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract StakeableToken is UTXORedeemableToken {
  using SafeMath for uint256;
  
  /**
   * @dev PUBLIC FACING: Calculates total bonuses for a given stake
   * @param _stakeTime param of Stake to calculate bonuses for
   * @param _unlockTime param of Stake to calculate bonuses for
   * @param _amount param of Stake to calculate bonuses for
   * @return bonus amount
   */
  function calculateBonuses(
    uint256 _stakeTime,
    uint256 _unlockTime,
    uint256 _amount
  ) public returns (uint256) {
    uint256 _bonus;
    return _bonus;
  }

  /**
   * @dev PUBLIC FACING: Calculates stake payouts for a given stake
   * @param _stakeTime param of Stake to calculate bonuses for
   * @param _unlockTime param of Stake to calculate bonuses for
   * @param _amount param of Stake to calculate bonuses for
   * @return payout amount
   */
  function calculatePayout(
    uint256 _stakeTime,
    uint256 _unlockTime,
    uint256 _amount
  ) public returns (uint256) {
    uint256 _payout = 0;

    /* Calculate what period stake was opened */
    uint256 _startPeriod = _stakeTime.sub(launchTime).div(10 days);

    /* Calculate what period stake was closed */
    uint256 _endPeriod = _unlockTime.sub(launchTime).div(10 days);

    /* Loop though each period and tally payout */
    for (uint256 _i = _startPeriod; _i < _endPeriod; _i++) {
      /* Calculate payout from week */
      uint256 _periodPayout = periodData[_i].payoutRoundAmount.mul(_amount).div(periodData[_i].totalStaked);

      /* Add to tally */
      _payout = _payout.add(_periodPayout);
    }

    return _payout;
  }

  /**
   * @dev PUBLIC FACING: Open a stake
   * @param _satoshis Amount of satoshi to stake
   * @param _periods Number of 10 day periods to stake
   */
  function startStake(
    uint256 _satoshis,
    uint256 _periods
  ) external {
    /* Calculate Unlock time */
    uint256 _unlockTime = block.timestamp.add(_periods.mul(10 days));

    /* Make sure staker has enough funds */
    require(balanceOf(msg.sender) >= _satoshis);
    
    /* ensure that unlock time is not more than approx 10 years */
    require(_unlockTime <= block.timestamp.add(maxStakingTimeInSeconds));

    /* ensure that unlock time is more than 10 days */
    require(_unlockTime >= block.timestamp.add(oneInterestPeriodInSeconds));

    /* Check if log data needs to be updated */
    storeWeeklyData();
    storePeriodData();

    /* Create Stake */
    staked[msg.sender].push(
      StakeStruct(
        _satoshis,
        block.timestamp,
        _unlockTime
      )
    );

    /* Add staked coins to global stake counter */
    totalStakedCoins = totalStakedCoins.add(_satoshis);

    /* Move coins to staking address to store */
    _transfer(msg.sender, stakingAddress, _satoshis);
  }

  /**
   * @dev PUBLIC FACING: Closes a stake
   * @param _stakeIndex Index of stake to close
   */
  function endStake(
    uint256 _stakeIndex
  ) external {

  }
}
