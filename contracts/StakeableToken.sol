pragma solidity ^0.4.24;
import "./UTXORedeemableToken.sol";

contract StakeableToken is UTXORedeemableToken {
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
