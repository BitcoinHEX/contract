pragma solidity ^0.4.24;

import "./UTXOClaimValidation.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract UTXORedeemableToken is UTXOClaimValidation {
  using SafeMath for uint256;
  
  /**
  * @dev Calculates speed bonus for claiming early
  * @param _satoshis Amount of UTXO in satoshis
  * @return Speed bonus amount
  */
  function getSpeedBonus(uint256 _satoshis) internal view returns (uint256) {
    uint256 hundred = 100;
    uint256 scalar = hundred.sub(weeksSinceLaunch().mul(2)); // This math breaks after 50 weeks, claims disabled after 50 weeks, no issue
    return (_satoshis.mul(scalar).div(1000));
  }

  /**
  * @dev Returns adjusted claim amount based on weeks passed since launch
  * @param _satoshis Amount of UTXO in satoshis
  * @return Adjusted claim amount
  */
  function getLateClaimAdjustedAmount(uint256 _satoshis) internal view returns (uint256) {
    return _satoshis.mul(weeksSinceLaunch().mul(2)).div(100); // This math breaks after 50 weeks, claims disabled after 50 weeks, no issue
  }

  /**
  * @dev PUBLIC FACING: Get post-adjustment redeem amount if claim of x satoshis redeemed
  * @param _satoshis Amount of UTXO in satoshis
  * @return 1: Adjusted claim amount; 2: Total claim bonuses
  */
  function getRedeemAmount(uint256 _satoshis) public view returns (uint256, uint256) {
    uint256 _amount = getLateClaimAdjustedAmount(_satoshis);
    uint256 _bonus = getSpeedBonus(_amount);
    return (_amount, _bonus);
  }

  /**
   * @dev PUBLIC FACING: Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
   * @param _satoshis Amount of UTXO in satoshis
   * @param _proof Merkle tree proof
   * @param _pubKey Uncompressed ECDSA public key to which the UTXO was sent
   * @param _isCompressed Whether the Bitcoin address was generated from a compressed public key
   * @param _v v parameter of ECDSA signature
   * @param _r r parameter of ECDSA signature
   * @param _s s parameter of ECDSA signature
   * @param _referrer (optional, send 0x0 for no referrer) addresss of referring persons
   * @return The number of tokens redeemed, if successful
   */
  function redeemUTXO(
    uint256 _satoshis,
    bytes32[] _proof,
    bytes _pubKey,
    bool _isCompressed,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    address _referrer
  ) public returns (uint256) {
    /* Disable claims after 50 weeks */
    require(isClaimsPeriod());

    /* Calculate original Bitcoin-style address associated with the provided public key. */
    bytes20 _originalAddress = pubKeyToBitcoinAddress(_pubKey, _isCompressed);

    /* Calculate the UTXO Merkle leaf hash. */
    bytes32 _merkleLeafHash = keccak256(
      abi.encodePacked(
        _originalAddress, 
        _satoshis
      )
    );

     /* Verify that the UTXO can be redeemed. */
    require(canRedeemUtxoHash(_merkleLeafHash, _proof));

    /* Check if log data needs to be updated */
    storeWeeklyData();
    storePeriodData();

    /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
    require(
      ecdsaVerify(
        msg.sender, 
        _pubKey, 
        _v, 
        _r, 
        _s
      )
    );

    /* Sanity check. */
    require(totalRedeemed.add(_tokensRedeemed) <= maximumRedeemable);

    /* Track total redeemed tokens. This needs to be logged before scaling */
    totalRedeemed = totalRedeemed.add(_satoshis);

    /* Mark the UTXO as redeemed. */
    redeemedUTXOs[_merkleLeafHash] = true;

    /* Fetch value of claim */
    (uint256 _tokensRedeemed, uint256 _bonuses) = getRedeemAmount(_satoshis);

    /* Credit the redeemer, and award bonuses to origin. */ 
    _mint(msg.sender, _tokensRedeemed.add(_bonuses));
    _mint(origin, _bonuses);

    /* Increment Redeem Count to track viral rewards */
    redeemedCount = redeemedCount.add(1);

    /* Mark the transfer event. */
    emit Transfer(address(0), msg.sender, _tokensRedeemed.add(_bonuses));
    emit Transfer(address(0), origin, _bonuses);

    /* Check if non-zero referral address has been passed */
    if (_referrer != address(0)) {
      /* Credit referrer and origin */
      _mint(_referrer, _tokensRedeemed);
      _mint(origin, _tokensRedeemed.div(20));
    }
    
    /* Return the number of tokens redeemed. */
    return _tokensRedeemed.add(_bonuses);
  }
}