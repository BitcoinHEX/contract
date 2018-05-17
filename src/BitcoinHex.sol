pragma solidity ^0.4.18;
import "./StandardToken.sol";

contract BitcoinHex is StandardToken {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;
    uint public INITIAL_SUPPLY = 10000 * (10 ** decimals);
    uint256 public totalSupply;

    constructor () public {
        totalSupply = INITIAL_SUPPLY;
        balances[msg.sender] = INITIAL_SUPPLY;
    }
}
