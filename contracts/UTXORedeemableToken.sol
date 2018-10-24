pragma solidity ^0.4.25;

import "./GlobalsAndUtility.sol";
import "./UTXOClaimValidation.sol";

contract UTXORedeemableToken is GlobalsAndUtility, UTXOClaimValidation {
    function calculateBonuses(uint256 amount) public view returns (uint256) {

    }

    function verifyClaim() public view returns (bool) {

    }

    function claim(address _staker) public returns (bool) {

    }
}