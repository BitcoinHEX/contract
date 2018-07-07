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
}