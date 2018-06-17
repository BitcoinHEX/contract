pragma solidity >=0.4.23;

import "../BitcoinHex.sol";


// this will allow us to initialize block timestamp or wrap any internal functions and make them assessible to white box testing
contract BitcoinHexStub is BitcoinHex {
    constructor(
        address _originContract,
        uint256 _launchTime,
        bytes32 _rootUTXOMerkleTreeHash,
        uint256 _maximumRedeemable,
        uint256 _totalBTCCirculationAtFork
    ) 
      public 
      BitcoinHex(
          _originContract,
          _launchTime,
          _rootUTXOMerkleTreeHash,
          _maximumRedeemable,
          _totalBTCCirculationAtFork
      )
    {}    
}
