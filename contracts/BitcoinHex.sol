pragma solidity ^0.4.23;
import "./StakeableToken.sol";

contract BitcoinHex is StakeableToken {
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
