pragma solidity ^0.4.23;

import "../../node_modules/openzeppelin-solidity/contracts/MerkleProof.sol";


contract MerkleProofStub {

  function testVerifyProof(
    bytes32[] _proof,
    bytes32 _root,
    bytes32 _leaf
  )
    external
    pure
    returns (bool)
  {
    return MerkleProof.verifyProof(
      _proof,
      _root,
      _leaf
    );
  }
}