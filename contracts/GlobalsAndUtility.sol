pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract GlobalsAndUtility is ERC20 {
  using SafeMath for uint256;
  
  /* Origin Address */
  address internal origin;

  /* ERC20 Constants */
  string public constant name = "BitcoinHex"; 
  string public constant symbol = "BHX";
  uint public constant decimals = 8;

  /* Store time of launch for contract */
  uint256 internal launchTime;

  /* Total tokens redeemed so far. */
  uint256 public totalRedeemed = 0;
  uint256 public redeemedCount = 0;

  /* Root hash of the UTXO Merkle tree */
  bytes32 public rootUtxoMerkleTreeHash;

  /* Redeemed UTXOs. */
  mapping(bytes32 => bool) internal redeemedUTXOs;

  /* Store last week storeWeeklyData() ran */
  uint256 internal lastUpdatedWeek;

  /* Store last period storePeriodData() ran */
  uint256 internal lastUpdatedPeriod;

  /* Weekly data */
  struct WeeklyDataStuct {
    uint256 unclaimedCoins;
    uint256 totalStaked;
  }
  mapping(uint256 => WeeklyDataStuct) internal weeklyData;

  /* Accumulated Emergency unstake pool to go into next period pool */
  uint256 internal emergencyUnstakePool;

  /* Period data */
  struct PeriodDataStuct {
    uint256 payoutRoundAmount;
    uint256 totalStaked;
  }
  mapping(uint256 => PeriodDataStuct) internal periodData;

  /* Total number of UTXO's at fork */
  uint256 internal UTXOCountAtFork;

  /* Maximum redeemable coins at fork */
  uint256 internal maximumRedeemable;

  /* Stakes Storage */
  struct StakeStruct {
    uint256 amount;
    uint256 stakeShares;
    uint256 stakeTime;
    uint256 unlockTime;
  }
  mapping(address => StakeStruct[]) public staked;
  uint256 public totalStakedCoins;
  uint256 public totalStakeShares;
  uint256 internal constant maxStakingTime = 365 days * 10; // Solidity automatically converts 'days' to seconds
  uint256 internal constant oneInterestPeriod = 10 days; // Solidity automatically converts 'days' to seconds

  /**
   * @dev Calculates maximum of Total Supply and MaxRedeemable, this is to keep calculations in the early rounds sane
   * @return Maximum of Total Supply and MaxRedeemable
   */
  function maxOfTotalSupplyVSMaxRedeemable() internal view returns (uint256) {
    uint256 _maxOfTotalSupplyVSMaxRedeemable = totalSupply();
    if (totalSupply() < maximumRedeemable) {
      _maxOfTotalSupplyVSMaxRedeemable = maximumRedeemable;
    }
    return _maxOfTotalSupplyVSMaxRedeemable;
  }

  /**
   * @dev Converts timestamp to number of weeks into contract
   * @param _timestamp timestamp to convert
   * @return number of weeks into contract
   */
  function timestampToWeeks(
    uint256 _timestamp
  ) internal view returns (uint256) {
    return (_timestamp.sub(launchTime).div(7 days));
  }

  /**
   * @dev Checks number of weeks since launch of contract
   * @return number of weeks since launch
   */
  function weeksSinceLaunch() internal view returns (uint256) {
    return (timestampToWeeks(block.timestamp));
  }

  /**
   * @dev Converts timestamp to number of periods into contract
   * @param _timestamp timestamp to convert
   * @return number of periods into contract
   */
  function timestampToPeriods(
    uint256 _timestamp
  ) internal view returns (uint256) {
    return (_timestamp.sub(launchTime).div(10 days));
  }

  /**
  * @dev Checks number of periods since launch of contract
  * @return number of periods since launch
  */
  function periodsSinceLaunch() internal view returns (uint256) {
    return (timestampToPeriods(block.timestamp));
  }

  /**
   * @dev PUBLIC FACING: Checks if we're still in claims period
   * @return true/false is in claims period
   */
  function isClaimsPeriod() public view returns (bool) {
    return (weeksSinceLaunch() < 50);
  }

  /**
   * @dev PUBLIC FACING: Store weekly coin data
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
   * @dev PUBLIC FACING: Store period coin data
   */
  function storePeriodData() public {
    for (lastUpdatedPeriod; periodsSinceLaunch() > lastUpdatedPeriod; lastUpdatedPeriod++) {

      /* Calculate payout round */
      uint256 _payoutRound = maxOfTotalSupplyVSMaxRedeemable().div(1046); // Gives approximately 0.09561% inflation per period, which equals 3.5% per year inflation

      /* Calculate Viral and Crit rewards */
      if (isClaimsPeriod()) {
        _payoutRound = _payoutRound.add(
          /* VIRAL REWARDS: Add bonus percentage to _rewards from 0-10% based on adoption */
          _payoutRound.mul(redeemedCount).div(UTXOCountAtFork).div(10)
        ).add (
          /* CRIT MASS REWARDS: Add bonus percentage to _rewards from 0-10% based on adoption */
          _payoutRound.mul(totalRedeemed).div(maximumRedeemable).div(10)
        );

        /* Pay crit and viral to origin */
        _mint(origin, _payoutRound.mul(redeemedCount).div(UTXOCountAtFork).div(10)); // VIRAL
        _mint(origin, _payoutRound.mul(totalRedeemed).div(maximumRedeemable).div(10)); // CRIT
      }

      /* Add emergency unstake pool to payout round */
      _payoutRound = _payoutRound.add(emergencyUnstakePool);
      emergencyUnstakePool = 0;

      /* Store data */
      periodData[lastUpdatedPeriod.add(1)] = PeriodDataStuct(
          _payoutRound,
          totalStakedCoins
      );
    }
  }

  /**
   * @dev PUBLIC FACING: A convenience function to get supply and staked (true supply).
   * @return True Supply
  */
  function geTrueSupply() public view returns (uint256) {
    return totalSupply().add(totalStakedCoins);
  }
}