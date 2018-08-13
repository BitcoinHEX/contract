
# BitcoinHex

## Contracts
Please see the [contracts/](contracts) directory.

## Develop
Contracts are written in Solidity and tested using Truffle. Library contracts sourced from OpenZeppelin.org.

### Dependencies

#### secrets.js
This file is **NOT** checked in. You will need to supply a secrets.js that includes an InfuraKey and private key for accountPK. 
Sample format:
```
var infuraKey = "get-this-from-infura-io";
var accountPK = "your-64-character-private-hex-key-goes-here-do-not-share-with-others";
var mainnetPK = accountPK;
var ropstenPK = accountPK;

module.exports = {infuraKey: infuraKey, mainnetPK: mainnetPK, ropstenPK:ropstenPK};
```

### Installation
```bash
yarn
```

### Compilation
```bash
yarn compile
```

### Testing
```bash
yarn test
```

### Stress Testing
Due to the need for more accounts, ganache-cli is used as a test blockchain for stress tests. This means that ganache-cli must be started before running stress tests.
```
yarn start:blockchain
```
After the blockchain is started, stress tests can be run using (in another terminal window):
```
yarn test:stress
```
*IMPORTANT NOTE:* Due to limitations of bignumber.js used by truffle, account ether balances will cause the tests to fail after a certain number of iterations. If you run into this problem, simply restart ganache-cli

### Docs for wallet/app developers
[See here](ABI.md) for description of each public function.

### External Documentation
- [ethereum](https://www.ethereum.org/)
- [openzeppelin](https://openzeppelin.org/)
- [solidity](https://solidity.readthedocs.io/)
- [truffle](http://truffleframework.com/)
- [testrpc](https://github.com/ethereumjs/testrpc)

# Token Specs, Lifecycle Bonuses, Reductions, & Modifiers
This is meant to be a brief explanation of each modifier which is implemented/will be implemented in the BHX token contract.

## Brief Overview
**TODO: make sure that 1% is actually an acceptable interest rate**

BitcoinHex is an ERC20 token which will fork Bitcoin UTXOs onto the ethereum blockchain. This is achieved through merkle proofs and eliptic curve recovery. 

Merkle Proofs allow for proving that a specific UTXO does indeed exist on the Bitcoin blockchain. 

Eliptic Curve Recovery allows for verifying an address. Due to the nature of public keys for both Bitcoin and Ethereum, one is able to verify ownership of said UTXOs on the Bitcoin blockchain on ethereum.

The primary utility of BitcoinHex is trustless interest which can be utilized by locking tokens (staking) for a designated amount of time. At the end of the lock time, tokens as well as the compounded interest can be redeemed. Interest rate periods are 10 days and the interest rate is 1%.

The target inflation rate is 3.5% per annum (excluding initial bonus rewards).

There are a variety of rewards and penalties applied during the first 50 weeks to encourage adoption and encourage fair distribution of BHX tokens. These are explained in detail in the following sections:
1. Staking Modifiers
1. Redemption Modifiers

## Specifications
**TODO: fill in missing fields and decide what test network to deploy on**

Property | Value
-- | --
Token Type | ERC20
TotalSupply | Starts at 0 increases with redemptions through Bitcoin UTXOs at specified fork
Decimals | 18
Name | BitcoinHex
Symbol | BHX
Mainnet Address | TBA
Rinkeby Address | TBA
Mainnet Etherscan Verified Contract | [TBA](https://etherscan.io)
Rinkeby Etherscan Verified Contract | [TBA](https://rinkeby.etherscan.io)
Bitcoin block fork | TBA

## Lifecycle
There are three main stages in the lifecycle of BHX. These stages are:
1. token launch
1. bonus period
1. bonus end

### Token Launch
During this time, a Bitcoin block fork has been selected and the root merkle hash has been updated to exclude unwanted UTXOS (Mt.Gox etc.).

The token is launched and a launchTime is selected. Once when the launchTime has occurred, redeeming can begin. Passing the launchTime marks the start of the **bonus period**.

### Bonus Period
The bonus period is a period of 50 weeks where additional rewards are given when a user redeems and/or stakes tokens. This 50 week period starts at the `launchTime` designated in the contract and ends 50 weeks later.

During this time, users can redeem tokens from Bitcoin UTXOs and can stake redeemed tokens to participate in additional rewards given during the bonus period. Regular compounding interest is also given out during this time.

### Bonus End
After the bonus time, regular operations begin. During this period, there are no longer any additional bonuses. The only way that additional tokens are created/rewarded is through interest gained from staking.

Tokens can no longer be redeemed at this point either.

### Perspective From a User
1. token is deployed
1. `launchTime` passes
1. user redeems tokens within 1 week
    * user receives rewards for redeeming quickly 
        * 1st week redeem means 10% speed bonus
    * user receives no penalty for redeeming quickly 
        * redeeming during first week means 0% we are all satoshi reduction
    * user receives no pentalty due not overly large redeem amount
        * less than 1k BHX tokens redeemed means no silly whale reduction
1. user immediately stakes redeemed tokens for 30 days (3 periods)
1. 30 days pass
1. user redeems interest
    * bonus redemption rewards are applied within 50 week period (current week is week 3)
        * viral bonus is applied (see redemption modifiers section)
        * critical mass bonus is applied (see redemption modifiers section)
        * we are all satoshi bonus is applied (see redemption modifiers section)
    * compound interest calculated for 3 periods is applied
    * user receives sum of:
        * original staked tokens
        * compounded interest
        * bonus rewards
1. time goes on and it is now  50 weeks since launch
1. user stakes tokens for 30 days (3 periods)
1. 30 days pass
1. user redeems interest
    * no bonus redemption rewards are applied
        * contract is now past bonus period
    * compound interest calculated for 3 periods is applied
    * user receives sum of:
        * original staked tokens
        * compounded interest


## Staking Modifiers
These modifiers apply when staking coins after they have been redeemed. Staking modifiers can be divided into two sub-categories: Limited Time and Continuous.

### Limited Time Staking Modifiers
All limited time staking modifiers apply only during the first 50 weeks after `launchTime`. After 50 weeks, only continuous staking modifiers will apply.

#### We are All Satoshi (bonus)
This bonus is based off of total unclaimed tokens for each week in the 50 week period. When staking during the 50 week bonus period, a bonus of 2% of total unclaimed tokens for that week is given as a bonus in addition to staking rewards. This bonus compounds with regular staking rewards (compound interest).

Calculations for this bonus occur as follows:
```
uint256 startWeek = stake.stakeTime.sub(launchTime).div(7 days);

uint256 weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);

for (uint256 i = startWeek; i < weeksSinceLaunch; i++) {
    rewards = rewards.add(unclaimedCoinsByWeek[i].mul(stake.stakeAmount).div(50));
}
```

This reward is not compounded, but applied after compounded interest.

#### Critical Mass Bonus
This is a bonus awarded linearly from 0% - 10% based on how much adoption has taken place. The bonus is a percent of total tokens redeemed out of maximum redeemable. This percent is applied to the staking rewards to get the Critical Mass bonus value.

This reward is not compounded, but applied after compounded interest.

#### Viral Bonus
This is a bonus awarded linearly from 0% - 10% how many active Bitcoin users have redeemed. The bonus is a percent of total tokens redeemed out of total Bitcoin circulating at fork. This percent is applied to the staking rewards to get the Viral bonus value.

This reward is not compounded, but applied after compounded interest.

#### ThanksForTheBonuses
All limited time staking bonuses applied for a staker are also given to origin address. 

### Continuous Staking Modifiers
These modifiers apply even after the first 50 weeks after `launchTime`.

#### Diminishing Interest
As more tokens are staked for interest, the interest rate is adjusted downwards, resulting in a smaller actual interest rate.

## Redemption Modifiers
These are modifiers which apply when initially redeeming from Bitcoin block UTXOs.

### Limited Time Redemption
Token Redemption through Bitcoin block UTXOs are redeemable only for the first 50 weeks. Redemption after 50 weeks is not possible.

### GoxMeNot
**TODO: are there other coins that are removed from this block?**

This modifier is indirectly applied through modifying the root merkle hash supplied to the contract constructor. This merkle tree hash is derived from the block where the fork takes place. The updated merkle root hash removes Mt.Gox UTXOs from the block. This prevents said parties from being able to claim from said UTXOs.

This modifier is not explicitly declared anywhere in the contract but is enacted through the root merkle hash supplied.

### SillyWhale
SillyWhale modifies the amount of tokens being redeemed at any time within the first 50 weeks. Any redemption amount over 1000 tokens will be penalized starting at 50% and going up to 75% linearly. Maximum penalty occurs at 10000 tokens.

Bitcoins and BHX tokens are redeemed at a 1:10 ratio in order to convert decimals to standard token decimals
```
1e8 satoshis == 1 bitcoin == 1e18 BHX wei == 1 BHX token
```

This can be arbitrarily subverted by splitting up coins before redeeming.

### Referral Bonus
A 5% referral bonus can be credited to a referrer at no cost to redeemer when redeeming. User's can self-refer. The 5% is taken from the redemption amount including bonuses.

### WeAreAllSatoshi (reduction)
Redemption reductions are applied increasing every week after `launchTime` until the reduction reaches 100% at week 50. At week 50 redemptions are no longer possible. This is described in the following table:

Weeks Since Launch (w) | Percent Reduction
-- | --
0 | 0
1 | 2
2 | 4
3 | 6
... | ...
47 | 94
48 | 96
49 | 98
50 | 100


### Speed Bonus
Speed bonuses are given as a bonus based on token reddem amount AFTER the WeAreAllSatoshi reduction. The table below describes bonus percentages for each week in the initial 50 week bonus period.

Weeks Since Launch (w) | Percent Bonus
-- | --
w < 1 | 10%
w > 1 && w < 3 | 9%
w > 3 && w < 5 | 8%
w > 5 && w < 7 | 7%
w > 7 && w < 10 | 6%
w > 10 && w < 14 | 5%
w > 14 && w < 18 | 4%
w > 18 && w < 24 | 3%
w > 24 && w < 32 | 2%
w > 32 && w < 45 | 1%
w > 45 | 0%

# TODOS
- [ ] fuzzy test stakes
- [ ] implement affiliate links for staking (post bonus affiliate rewards)