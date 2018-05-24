
# BitcoinHex [BitcoinHex](http://bitcoinhex.com)

## Contracts
Please see the [contracts/](contracts) directory.

## Overview
There is several contracs to make note of: `BitcoinHex.sol` `MerkleProof.sol` `StakeableToken.sol` `UTXORedeemableToken.sol`

### Explanation 
This is a fork of Bitcoin on the  constructor accepts a string for the name of the ringMaster. Sufficient gas should be supplied.
1. set/get Available Seat Count
1. Define Performance struct and maintain Performance[] performances as well as getPerformance
1. Maintain a mapping(address => uint256) internal tickets;
1. Provide a function () payable public fallback function to assign msg.sender a number of tickets based on msg.value.


### Distribution
Bitcoin holders get BitcoinHEX tokens on ethereum at 1:1 ratio or better.

### Bitcoin is the largest, most established and most secure cryptocurrency in the world
Bitcoin forks reward Bitcoin holders with new tokens. Bitcoin forks are so valuable that there's a "cold storage index" which tracks the value of Bitcoin plus all the forks it can claim.

### Bitcoin forks often become very valuable very quickly
Bitcoin Cash, launched less than a year ago is worth 17% of a Bitcoin today. On May 14th, 2018 an example of some Bitcoin forks market caps: This is all in under 1 year.
```
Value (in millions)	Bitcoin Fork
$23662				Cash
$961				Gold
$612				Diamond
$496				Private
$119				Dark
$26					Atom
$26					Green
```

### Open source is great
Bitcoin was built on several open source software components (berkleyDB,openssl, Qt, etc.) It's often better to combine the parts you need off the shelf than to write it all from scratch.

### Forks are great starting places
1. Security
	If your choices are, start from scratch, or start from a battle tested, secure tech, it's safer to start where someone else left off.
1. User Onboarding
	A currency no one uses is bad currency. Forks have an easier time at getting users because they work very similarly to the Bitcoin people are used to. Who better to jumpstart the adoption of your new currency than the people who've proven they're interested in crypto by holding Bitcoin?

### Claiming
A snapshot of the Bitcoin UTXO will be taken. The UTXO set will be flattened for gas efficiency, and the Merkle tree root of that set will be embedded in an ERC20 token contract to allow Bitcoin holders to redeem their tokens.

### Bonuses
Along with tokens gained by holding Bitcoin, a number of bonus tokens are available to claimers:
1/10th of claim as bonus, reduced by 2% every week after release
Refer others and get the equivalent of 5% of their claim as a bonus
More to come

## Develop
Contracts are written in [Solidity][solidity] and tested using [Truffle][truffle] and [testrpc][testrpc]. Library contracts sourced from [OpenZeppelin.org][openzeppelin].

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

### Compilation
```bash
# Install Truffle, testrpc, and dependency packages:
$ npm install
$ truffle compile
$ truffle test
```



[ethereum]: https://www.ethereum.org/
[openzeppelin]: https://openzeppelin.org/
[solidity]: https://solidity.readthedocs.io/
[truffle]: http://truffleframework.com/
[testrpc]: https://github.com/ethereumjs/testrpc
