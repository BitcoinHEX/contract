pragma solidity >=0.4.23;

import '../../contracts/BitcoinHex.sol';

// this will allow us to initialize block timestamp or wrap any internal functions and make them assessible to white box testing
contract MockToken is BitcoinHex {
    constructor() public BitcoinHex(){}    
}
