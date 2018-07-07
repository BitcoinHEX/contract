pragma solidity ^0.4.23;
import "./StakeableToken.sol";


contract BitcoinHex is StakeableToken {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;

    constructor (
        address _originAddress,
        bytes32 _rootUtxoMerkleTreeHash,
        uint256 _maximumRedeemable,
        uint256 _totalBtcCirculationAtFork
    ) 
        public
    {
        launchTime = block.timestamp;
        origin = _originAddress;
        rootUtxoMerkleTreeHash = _rootUtxoMerkleTreeHash;
        maximumRedeemable = _maximumRedeemable;
        totalBtcCirculationAtFork = _totalBtcCirculationAtFork;
    }
}
