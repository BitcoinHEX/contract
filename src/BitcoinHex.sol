pragma solidity ^0.4.23;
import "./token/StakeableToken.sol";

contract BitcoinHex is StakeableToken {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;

    constructor () public {
        totalSupply_ = 0;
    }
}
