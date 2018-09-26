pragma solidity >=0.4.23;

import "../BitcoinHex.sol";


// this will allow us to initialize block timestamp or wrap any internal functions and make them assessible to white box testing
contract BitcoinHexStub is BitcoinHex {
  constructor(
    address _originContract,
    bytes32 _rootUtxoMerkleTreeHash,
    uint256 _maximumRedeemable,
    uint256 _UTXOCountAtFork
  ) 
    public 
    BitcoinHex(
      _originContract,
      _rootUtxoMerkleTreeHash,
      _maximumRedeemable,
      _UTXOCountAtFork
    )
  {}    
}
