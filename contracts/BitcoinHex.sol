pragma solidity ^0.4.23;
import "./StakeableToken.sol";


contract BitcoinHex is StakeableToken {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;

    constructor (address _originAddress) 
        public
    {
        totalSupply_ = 0;
        // solium-disable-next-line security/no-block-members
        launchTime = block.timestamp;
        origin = msg.sender; // Change before launch
        rootUTXOMerkleTreeHash = 0x0; // Change before launch
        maximumRedeemable = 0; // Change before launch
        totalBTCCirculationAtFork = 17078787*(10**8); // Change before launch
    }
}
