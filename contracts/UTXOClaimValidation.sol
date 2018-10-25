pragma solidity ^0.4.24;

import "./GlobalsAndUtility.sol";
import "../node_modules/openzeppelin-solidity/contracts/cryptography/MerkleProof.sol";

contract UTXOClaimValidation is GlobalsAndUtility {
  /**
   * @dev Extract a bytes32 subarray from an arbitrary length bytes array.
   * @param _data Bytes array from which to extract the subarray
   * @param _pos Starting position from which to copy
   * @return Extracted length 32 byte array
   */
  function extract(
    bytes _data, uint256 _pos
  ) private pure returns (bytes32) {
    bytes32 _result;
    for (uint256 _i = 0; _i < 32; _i++) {
      _result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000) & _data[_i + _pos]) >> (_i * 8);
    }
    return _result;
  }

  
  /**
   * @dev Validate that a provided ECSDA signature was signed by the specified address
   * @param _hash Hash of signed data
   * @param _v v parameter of ECDSA signature
   * @param _r r parameter of ECDSA signature
   * @param _s s parameter of ECDSA signature
   * @param _expected Address claiming to have created this signature
   * @return Whether or not the signature was valid
   */
  function validateSignature(
    bytes32 _hash,
    uint8 _v,
    bytes32 _r,
    bytes32 _s,
    address _expected,
    bool _addPrefix
  ) public pure returns (bool) {
    bytes32 _formattedHash;

    if (!_addPrefix) {
      _formattedHash = _hash;
    } else {
      bytes memory _prefix = "\x19Ethereum Signed Message:\n32"; // accomodate geth method of signing data with prefixed message
      _formattedHash = keccak256(abi.encodePacked(_prefix, _hash));
    }

    return ecrecover(
      _formattedHash, 
      _v, 
      _r, 
      _s
    ) == _expected;
  }

  /**
   * @dev Validate that the hash of a provided address was signed by the ECDSA public key associated with the specified Ethereum address
   * @param _addr Address signed
   * @param _pubKey Uncompressed ECDSA public key claiming to have created this signature
   * @param _v v parameter of ECDSA signature
   * @param _r r parameter of ECDSA signature
   * @param _s s parameter of ECDSA signature
   * @return Whether or not the signature was valid
   */
  function ecdsaVerify(
    address _addr, 
    bytes _pubKey, 
    uint8 _v, 
    bytes32 _r, 
    bytes32 _s
  ) public pure returns (bool) {
    return validateSignature(
      sha256(abi.encodePacked(_addr)),  // hash
      _v, 
      _r, 
      _s, 
      pubKeyToEthereumAddress(_pubKey), // expected
      false // do not prepend message
    );
  }

  /**
   * @dev Convert an uncompressed ECDSA public key into an Ethereum address
   * @param _pubKey Uncompressed ECDSA public key to convert
   * @return Ethereum address generated from the ECDSA public key
   */
  function pubKeyToEthereumAddress(
    bytes _pubKey
  ) public pure returns (address) {
    return address(
      uint256(keccak256(_pubKey)) & 0x000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    );
  }

  /**
   * @dev Calculate the Bitcoin-style address associated with an ECDSA public key
   * @param _pubKey ECDSA public key to convert
   * @param _isCompressed Whether or not the Bitcoin address was generated from a compressed key
   * @return Raw Bitcoin address (no base58-check encoding)
   */
  function pubKeyToBitcoinAddress(
    bytes _pubKey, 
    bool _isCompressed
  ) public pure returns (bytes20) {
    /* Helpful references:
       - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses 
       - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
    */

    /* x coordinate - first 32 bytes of public key */
    uint256 _x = uint256(extract(_pubKey, 0));
    /* y coordinate - second 32 bytes of public key */
    uint256 _y = uint256(extract(_pubKey, 32)); 
    uint8 _startingByte;
    if (_isCompressed) {
      /* Hash the compressed public key format. */
      _startingByte = _y % 2 == 0 ? 0x02 : 0x03;
      return ripemd160(
        abi.encodePacked(sha256(abi.encodePacked(_startingByte, _x)))
      );
    } else {
      /* Hash the uncompressed public key format. */
      _startingByte = 0x04;
      return ripemd160(
        abi.encodePacked(sha256(abi.encodePacked(_startingByte, _x, _y)))
      );
    }
  }

  /**
   * @dev Verify a Merkle proof using the UTXO Merkle tree
   * @param _proof Generated Merkle tree proof
   * @param _merkleLeafHash Hash asserted to be present in the Merkle tree
   * @return Whether or not the proof is valid
   */
  function verifyProof(
    bytes32[] _proof, 
    bytes32 _merkleLeafHash
  ) public view returns (bool) {
    return MerkleProof.verify(_proof, rootUtxoMerkleTreeHash, _merkleLeafHash);
  }

  /**
   * @dev PUBLIC FACING: Verify that a UTXO with the specified Merkle leaf hash can be redeemed
   * @param _merkleLeafHash Merkle tree hash of the UTXO to be checked
   * @param _proof Merkle tree proof
   * @return Whether or not the UTXO with the specified hash can be redeemed
   */
  function canRedeemUtxoHash(
    bytes32 _merkleLeafHash, 
    bytes32[] _proof
  ) public view returns (bool) {
    /* Check that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
    return(
      (redeemedUTXOs[_merkleLeafHash] == false) && 
      verifyProof(_proof, _merkleLeafHash)
    );
  }

  /**
   * @dev PUBLIC FACING: Convenience helper function to check if a UTXO can be redeemed
   * @param _originalAddress Raw Bitcoin address (no base58-check encoding)
   * @param _satoshis Amount of UTXO in satoshis
   * @param _proof Merkle tree proof
   * @return Whether or not the UTXO can be redeemed
   */
  function canRedeemUtxo(
    bytes20 _originalAddress,
    uint256 _satoshis,
    bytes32[] _proof
  ) public view returns (bool) {
    /* Calculate the hash of the Merkle leaf associated with this UTXO. */
    bytes32 merkleLeafHash = keccak256(
      abi.encodePacked(
        _originalAddress, 
        _satoshis
      )
    );
  
    /* Verify the proof. */
    return canRedeemUtxoHash(merkleLeafHash, _proof);
  }
}