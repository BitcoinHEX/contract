pragma solidity ^0.4.23;

import "./UTXORedeemableToken.sol";

contract StakeableToken is UTXORedeemableToken {
    event Mint(address indexed _address, uint _reward);

    uint32 stakeRewardPercent10Days = 1;
    uint32 stakers = 0;
    uint256 stakedCoins = 0;

    struct stakeStruct{
        uint256 amount;
        uint256 time;
        uint32 stakers;
        uint256 stakedCoins;
    }

    mapping(address => stakeStruct[]) staked;

    function stake(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        staked[msg.sender].push(stakeStruct(uint128(_value), block.timestamp, stakers, stakedCoins));
        stakers = stakers + 1;
        stakedCoins = stakedCoins + _value;
    }

    function mint() public returns (bool) {
        require(staked[msg.sender].length > 0);
        stakers = stakers - 1;
        uint256 rewards = 0;
        for (uint i = 0; i < staked[msg.sender].length; i++){
            uint periods = staked[msg.sender][i].time / block.timestamp / 10 days;
            for (uint x = 0; x < periods; x++){
                rewards = (staked[msg.sender][i].amount + rewards) + (staked[msg.sender][i].amount + rewards) / 100 * stakeRewardPercent10Days;
            }
        }
        delete staked[msg.sender];
        emit Mint(msg.sender, rewards);
        return true;
    }
}
