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
const infuraKey = 'get-this-from-infura-io'
const accountPK = 'your-64-character-private-hex-key-goes-here-do-not-share-with-others'
const mainnetPK = accountPK
const ropstenPK = accountPK

module.exports = {
  infuraKey: infuraKey,
  mainnetPK: mainnetPK,
  ropstenPK: ropstenPK
}
```

### Installation
```bash
npm install
```

### Compilation
```bash
npm run compile
```

### Testing
```bash
npm run test
```