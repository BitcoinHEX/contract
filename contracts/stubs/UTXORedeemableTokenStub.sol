pragma solidity ^0.4.23;

import "../UTXORedeemableToken.sol";


contract UTXORedeemableTokenStub is UTXORedeemableToken {
  constructor(
    address _origin,
    uint256 _launchTime,
    bytes32 _rootUtxoMerkleTreeHash,
    uint256 _maximumRedeemable

  )
    public
  {
    origin = _origin;
    launchTime = _launchTime;
    rootUtxoMerkleTreeHash = _rootUtxoMerkleTreeHash;
    maximumRedeemable = _maximumRedeemable;
  }
}