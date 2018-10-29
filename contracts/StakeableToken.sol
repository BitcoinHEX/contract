pragma solidity ^0.4.24;
import "./UTXORedeemableToken.sol";

contract StakeableToken is UTXORedeemableToken {
  /**
   * @dev PUBLIC FACING: Calculates total bonuses for a given stake
   * @param _stake Stake to calculate bonuses for
   * @return bonus amount
   */
  function calculateBonuses(
    StakeStruct _stake
  ) public returns (uint256) {

  }

  /**
   * @dev PUBLIC FACING: Calculates stake payouts for a given stake
   * @param _stake Stake to calculate payout for
   * @return payout amount
   */
  function calculatePayout(
    StakeStruct _stake
  ) public returns (uint256) {

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
    address _staker = msg.sender;

    // Calculate Unlock time
    uint256 _unlockTime = block.timestamp.add(_stakePeriods.mul(10 days));

    // Make sure staker has enough funds
    require(balances[_staker] >= _value);
    // ensure that unlock time is not more than approx 10 years
    require(_unlockTime <= block.timestamp.add(maxStakingTimeInSeconds));
    // ensure that unlock time is more than 10 days
    require(_unlockTime >= block.timestamp.add(oneInterestPeriodInSeconds));
    // Check if weekly data needs to be updated
    storeWeeklyUnclaimedCoins();

    // Move coins to staking address to store
    _transfer(_staker, stakingAddress, _value);

    // maxOfTotalSupplyVSMaxRedeemableAtStart = Maximum redeemable supply, or total supply, whichever one is larger
    // Prevent early stakers from being penalised for being early
    uint256 maxOfTotalSupplyVSMaxRedeemableAtStart = totalSupply_;
    if (totalSupply_ < _maximumRedeemable) {
      maxOfTotalSupplyVSMaxRedeemableAtStart = _maximumRedeemable;
    }

    // Create Stake
    staked[_staker].push(
      StakeStruct(
        _value, 
        block.timestamp, 
        _unlockTime, 
        totalStakedCoins.add(_value),
        maxOfTotalSupplyVSMaxRedeemableAtStart
      )
    );

    // ensure that the new stake will return interest
    require(calculatePayout(_staker, staked[_staker].length.sub(1)) > 0);

    // Add staked coins to global stake counter
    totalStakedCoins = totalStakedCoins.add(_value);

    return true;
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
