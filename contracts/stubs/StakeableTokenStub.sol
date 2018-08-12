pragma solidity ^0.4.23;

import "../StakeableToken.sol";


contract StakeableTokenStub is StakeableToken {
  constructor (
    address _origin,
    uint256 _launchTime,
    bytes32 _rootUtxoMerkleTreeHash,
    uint256 _totalBtcCirculationAtFork,
    uint256 _maximumRedeemable
  ) 
    public
  {
    origin = _origin;
    launchTime = _launchTime;
    rootUtxoMerkleTreeHash = _rootUtxoMerkleTreeHash;
    totalBtcCirculationAtFork = _totalBtcCirculationAtFork;
    maximumRedeemable = _maximumRedeemable;
  }

  // only uesd for testing: easily mint more tokens for stress tests
  function mintTokens(
    address _address,
    uint256 _amount
  )
    public
    returns (bool)
  {
    balances[_address] = balances[_address].add(_amount);
    totalSupply_ = totalSupply_.add(_amount);
    emit Mint(_address, _amount);
    emit Transfer(address(0), _address, _amount);

    return true;
  }

  function setRedeemedCount(
    uint256 _count
  )
    public
    returns (bool)
  {
    redeemedCount = _count;
  }

  function setMaxRedeemable(
    uint256 _maxRedeemable
  )
    public
    returns (bool)
  {
    maximumRedeemable = _maxRedeemable;
  }

  function setTotalRedeemed(
    uint256 _totalRedeemed
  )
    public
    returns (bool)
  {
    totalRedeemed = _totalRedeemed;
  }
}