pragma solidity ^0.4.23;
import "./StakeableToken.sol";
import "zeppelin-solidity/contracts/ownership/Ownable.sol";

contract BitcoinHex is StakeableToken, Ownable {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 8;

    constructor () public {
        totalSupply_ = 0;
        launchTime = block.timestamp;
        owner = msg.sender;
        rootUTXOMerkleTreeHash = 0x0; // Change before launch
        maximumRedeemable = 0; // Change before launch
        
    }
}
