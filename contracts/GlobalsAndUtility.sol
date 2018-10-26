pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract GlobalsAndUtility is ERC20 {
  /* Origin Address */
  address internal origin;

  /* Conversion Constants */
  uint256 internal constant bhweiToBH = 10**18;
  uint256 internal constant bhweiToBHSatoshi = 10**10;

  /* ERC20 Constants */
  string public constant name = "BitcoinHex"; 
  string public constant symbol = "BHX";
  uint public constant decimals = 18;

  /* Store time of launch for contract */
  uint256 internal launchTime;

  /* Store end of 50 week period */
  uint256 internal endOfClaimPeriod;

  /* Total tokens redeemed so far. */
  uint256 public totalRedeemed = 0;
  uint256 public redeemedCount = 0;

  /* Maximum redeemable tokens, must be initialized by token constructor. */
  uint256 internal maximumRedeemable;

  /* Root hash of the UTXO Merkle tree, must be initialized by token constructor. */
  bytes32 public rootUtxoMerkleTreeHash;

  /* Redeemed UTXOs. */
  mapping(bytes32 => bool) internal redeemedUTXOs;

  /* Store last week storeWeeklyData() ran */
  uint256 internal lastUpdatedWeek;

  /* Weekly data */
  struct WeeklyDataStuct {
    uint256 unclaimedCoins;
    uint256 totalStaked;
  }
  mapping(uint256 => WeeklyDataStuct) internal weeklyData;

  /* Total number of UTXO's at fork */
  uint256 internal UTXOCountAtFork;

  /* Maximum redeemable coins at fork */
  uint256 internal _maximumRedeemable;

  /* Stakes Storage */
  struct StakeStruct {
    uint256 stakeAmount;
    uint256 stakeTime;
    uint256 unlockTime;
    uint256 totalStakedCoinsAtStart;
    uint256 maxOfTotalSupplyVSMaxRedeemableAtStart;
  }
  mapping(address => StakeStruct[]) public staked;
  uint256 public totalStakedCoins;
  uint256 internal constant maxStakingTimeInSeconds = 365 days * 10; // Solidity automatically converts 'days' to seconds
  uint256 internal constant oneInterestPeriodInSeconds = 10 days; // Solidity automatically converts 'days' to seconds

  /**
   * @dev Checks number of weeks since launch of contract
   * @return number of weeks winse launch
   */
  function weeksSinceLaunch() internal view returns(uint256) {
    return (block.timestamp.sub(launchTime).div(7 days));
  }

  /**
   * @dev Checks if we're still in claims period
   * @return true/false is in claims period
   */
  function isClaimsPeriod() internal view returns(bool) {
    return (block.timestamp < endOfClaimPeriod);
  }

  /**
   * @dev Store weekly coin data
   */
  function storeWeeklyData() public {
    for (lastUpdatedWeek; weeksSinceLaunch() > lastUpdatedWeek; lastUpdatedWeek++) {
      uint256 _unclaimedCoins = maximumRedeemable.sub(totalRedeemed);
      weeklyData[lastUpdatedWeek.add(1)] = WeeklyDataStuct(
          _unclaimedCoins,
          totalStakedCoins
      );
      _mint(origin, _unclaimedCoins.div(50));
    }
  }

  /**
   * @dev A convenience function to get circulating supply.
   * @return
  */
  function getCirculatingSupply() public view returns (uint256) {
    return totalSupply_.sub(totalStakedCoins);
  }
}