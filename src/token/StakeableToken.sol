pragma solidity ^0.4.23;

import "./UTXORedeemableToken.sol";

contract StakeableToken is UTXORedeemableToken {
    event Mint(address indexed _address, uint _reward);

    uint32 stakers = 0;
    uint256 stakedCoins = 0;

    struct stakeStruct {
        uint256 amount;
        uint256 time;
        uint256 unlockTime;
        uint32 stakers;
        uint256 stakedCoins;
    }

    mapping(address => stakeStruct) staked;

    function stake(uint256 _value, uint256 _unlockTime) public {
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        staked[msg.sender] = stakeStruct(uint128(_value), block.timestamp, _unlockTime, stakers, stakedCoins);
        stakers = stakers + 1;
        stakedCoins = stakedCoins + _value;
    }

    function calculateViralRewards() public view returns (uint256) {

    }

    function calculateCritMassRewards() public view returns (uint256) {

    }

    function calculateStakingRewards() public view returns (uint256) {

    }

    function calculateRewards() public view returns (uint256) {
        uint256 rewards = 0;
        return rewards;
    }

    function mint() public returns (bool) {
        require(staked[msg.sender].amount > 0);
        require(block.timestamp > staked[msg.sender].unlockTime);
        stakers = stakers - 1;
        uint256 rewards = calculateRewards();
        delete staked[msg.sender];
        emit Mint(msg.sender, rewards);
        return true;
    }
}
