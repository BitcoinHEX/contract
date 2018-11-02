pragma solidity ^0.4.24;

import "./StakeableToken.sol";

contract BitcoinHex is StakeableToken {
  constructor (
    address _originAddress,
    bytes32 _rootUtxoMerkleTreeHash,
    uint256 _maximumRedeemable,
    uint256 _UTXOCountAtFork
  ) public {
    launchTime = block.timestamp;
    origin = _originAddress;
    rootUtxoMerkleTreeHash = _rootUtxoMerkleTreeHash;
    maximumRedeemable = _maximumRedeemable;
    UTXOCountAtFork = _UTXOCountAtFork;
  }
}
