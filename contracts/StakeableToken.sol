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
   * @dev PUBLIC FACING: Calculates normal stake payouts for a given stake
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
  ) public {

  }

  /**
   * @dev PUBLIC FACING: Closes a stake
   * @param _stakeIndex Index of stake to close
   */
  function endStake(
    uint256 _stakeIndex
  ) public {

  }
}
