pragma solidity ^0.4.23;

import "./UTXORedeemableToken.sol";

contract StakeableToken is UTXORedeemableToken {
    using SafeMath for uint256;

    event Mint(address indexed _address, uint _reward);

    uint256 launchTime;

    uint256 stakers = 0;
    uint256 stakedCoins = 0;

    struct stakeStruct {
        uint256 amount;
        uint256 time;
        uint256 unlockTime;
        uint256 stakersAtStart;
        uint256 stakedCoinsAtStart;
    }

    mapping(address => stakeStruct) staked;

    function compound(uint256 _principle, uint256 _periods, uint256 _interestRateTimesHundred) internal pure returns (uint256) {
        // Needs Sanity Check
        return (_principle * (1000 + _interestRateTimesHundred) ** _periods)/(1000 ** _periods);
    }

    function stake(uint256 _value, uint256 _unlockTime) public {
        require(staked[msg.sender].amount == 0);
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        staked[msg.sender] = stakeStruct(uint128(_value), block.timestamp, _unlockTime, stakers, stakedCoins);
        stakers = stakers.add(1);
        stakedCoins = stakedCoins.add(_value);
    }

    function calculateLazyRewards() public view returns (uint256) {

    }

    function calculateViralRewards() public view returns (uint256) {

    }

    function calculateCritMassRewards() public view returns (uint256) {

    }

    function calculateStakingRewards() public view returns (uint256) {
        uint256 interestRateTimesHundred = 100;
        
    }

    function calculateRewards() public view returns (uint256) {
        uint256 rewards = 0;
        return rewards;
    }

    function mint() public returns (bool) {
        require(staked[msg.sender].amount > 0);
        require(block.timestamp > staked[msg.sender].unlockTime);
        stakers = stakers.sub(1);
        stakedCoins = stakedCoins.sub(staked[msg.sender].amount);
        uint256 rewards = calculateRewards();
        delete staked[msg.sender];
        emit Mint(msg.sender, rewards);
        return true;
    }
}
