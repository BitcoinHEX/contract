pragma solidity ^0.4.23;
import "./StakeableToken.sol";
import 'zeppelin-solidity/contracts/ownership/Ownable.sol';

contract BitcoinHex is StakeableToken, Ownable {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;

    constructor () public {
        totalSupply_ = 0;
        launchTime = block.timestamp;
        owner = msg.sender;
    }
}
