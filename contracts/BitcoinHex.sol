pragma solidity ^0.4.23;
import "./StakeableToken.sol";


contract BitcoinHex is StakeableToken {
    string public name = "BitcoinHex"; 
    string public symbol = "BHX";
    uint public decimals = 18;

    constructor (address _originContract) 
        public
    {
        totalSupply_ = 0;
        // solium-disable-next-line security/no-block-members
        launchTime = block.timestamp;
        rootUTXOMerkleTreeHash = 0x0; // Change before launch
        maximumRedeemable = 0; // Change before launch
        totalBTCCirculationAtFork = 17078787*(10**8); // Change before launch
        originContract = _originContract;

        /* Precomputed Speed Bonus Values weekToSpeedBonusTimesHundred = 10*0.95^week+100 */
        /* weekToSpeedBonusTimesHundred[0] = 110;
        weekToSpeedBonusTimesHundred[1] = 109;
        weekToSpeedBonusTimesHundred[2] = 109;
        weekToSpeedBonusTimesHundred[3] = 108;
        weekToSpeedBonusTimesHundred[4] = 108;
        weekToSpeedBonusTimesHundred[5] = 107;
        weekToSpeedBonusTimesHundred[6] = 107;
        weekToSpeedBonusTimesHundred[7] = 106;
        weekToSpeedBonusTimesHundred[8] = 106;
        weekToSpeedBonusTimesHundred[9] = 106;
        weekToSpeedBonusTimesHundred[10] = 105;
        weekToSpeedBonusTimesHundred[11] = 105;
        weekToSpeedBonusTimesHundred[12] = 105;
        weekToSpeedBonusTimesHundred[13] = 105;
        weekToSpeedBonusTimesHundred[14] = 104;
        weekToSpeedBonusTimesHundred[15] = 104;
        weekToSpeedBonusTimesHundred[16] = 104;
        weekToSpeedBonusTimesHundred[17] = 104;
        weekToSpeedBonusTimesHundred[18] = 103;
        weekToSpeedBonusTimesHundred[19] = 103;
        weekToSpeedBonusTimesHundred[20] = 103;
        weekToSpeedBonusTimesHundred[21] = 103;
        weekToSpeedBonusTimesHundred[22] = 103;
        weekToSpeedBonusTimesHundred[23] = 103;
        weekToSpeedBonusTimesHundred[24] = 102;
        weekToSpeedBonusTimesHundred[25] = 102;
        weekToSpeedBonusTimesHundred[26] = 102;
        weekToSpeedBonusTimesHundred[27] = 102;
        weekToSpeedBonusTimesHundred[28] = 102;
        weekToSpeedBonusTimesHundred[29] = 102;
        weekToSpeedBonusTimesHundred[30] = 102;
        weekToSpeedBonusTimesHundred[31] = 102;
        weekToSpeedBonusTimesHundred[32] = 101;
        weekToSpeedBonusTimesHundred[33] = 101;
        weekToSpeedBonusTimesHundred[34] = 101;
        weekToSpeedBonusTimesHundred[35] = 101;
        weekToSpeedBonusTimesHundred[36] = 101;
        weekToSpeedBonusTimesHundred[37] = 101;
        weekToSpeedBonusTimesHundred[38] = 101;
        weekToSpeedBonusTimesHundred[39] = 101;
        weekToSpeedBonusTimesHundred[40] = 101;
        weekToSpeedBonusTimesHundred[41] = 101;
        weekToSpeedBonusTimesHundred[42] = 101;
        weekToSpeedBonusTimesHundred[43] = 101;
        weekToSpeedBonusTimesHundred[44] = 101;
        weekToSpeedBonusTimesHundred[45] = 100;
        weekToSpeedBonusTimesHundred[46] = 100;
        weekToSpeedBonusTimesHundred[47] = 100;
        weekToSpeedBonusTimesHundred[48] = 100;
        weekToSpeedBonusTimesHundred[49] = 100; */
    }
}
