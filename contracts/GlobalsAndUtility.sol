pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";

contract GlobalsAndUtility is StandardToken {
    /* Origin Address */
    address origin;

    /* Store time of launch for contract */
    uint256 public launchTime;

    /* Store last week storeWeeklyUnclaimedCoins() ran */
    uint256 lastUpdatedWeek;

    /* Total tokens redeemed so far. */
    uint256 public totalRedeemed = 0;
    uint256 public redeemedCount = 0;

    /* Maximum redeemable tokens, must be initialized by token constructor. */
    uint256 maximumRedeemable;

    /* Root hash of the UTXO Merkle tree, must be initialized by token constructor. */
    bytes32 rootUtxoMerkleTreeHash;

    /* Redeemed UTXOs. */
    mapping(bytes32 => bool) public redeemedUTXOs;

    /* Weekly unclaimed coins data */
    struct WeeklyDataStuct {
        uint256 unclaimedCoins;
        uint256 totalStaked;
    }
    mapping(uint256 => WeeklyDataStuct) public unclaimedCoinsByWeek;

    /* Total number of UTXO's at fork */
    uint256 UTXOCountAtFork;

    /* Maximum redeemable coins at fork */
    uint256 _maximumRedeemable;

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
    uint256 constant maxStakingTimeInSeconds = 365 days * 10; // Solidity atumatically converts 'days' to seconds
    uint256 constant oneInterestPeriodInSeconds = 10 days; // Solidity atumatically converts 'days' to seconds

    function storeWeeklyUnclaimedCoins() public {
        uint256 _weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);
        for (lastUpdatedWeek; _weeksSinceLaunch > lastUpdatedWeek; lastUpdatedWeek++) {
        uint256 _unclaimedCoins = maximumRedeemable.sub(totalRedeemed);
        unclaimedCoinsByWeek[_weeksSinceLaunch] = WeeklyDataStuct(
            _unclaimedCoins,
            totalStakedCoins
        );
        balances[origin] = balances[origin]
            .add(_unclaimedCoins.div(50));
        }
    }
}