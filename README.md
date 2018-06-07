
# BitcoinHex

## Contracts
Please see the [contracts/](contracts) directory.

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
$ npm install
$ npm run compile
$ npm run test
```

### Docs for wallet/app developers
[See here](ABI.md) for description of each public function.

### External Documentation
[ethereum](https://www.ethereum.org/)
[openzeppelin](https://openzeppelin.org/)
[solidity](https://solidity.readthedocs.io/)
[truffle](http://truffleframework.com/)
[testrpc](https://github.com/ethereumjs/testrpc)
