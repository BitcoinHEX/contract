/*

  UTXO redeemable token.

  This is a token extension to allow porting a Bitcoin or Bitcoin-fork sourced UTXO set to an ERC20 token through redemption of individual UTXOs in the token contract.
    
  Owners of UTXOs in a chosen final set (where "owner" is simply anyone who could have spent the UTXO) are allowed to redeem (mint) a number of tokens proportional to the satoshi amount of the UTXO.

  Notes

    - This method *does not* provision for special Bitcoin scripts (e.g. multisig addresses).
    - Pending transactions are public, so the UTXO redemption transaction must work *only* for an Ethereum address belonging to the same person who owns the UTXO.
      This is enforced by requiring that the redeeemer sign their Ethereum address with their Bitcoin (original-chain) private key.
    - We cannot simply store the UTXO set, as that would be far too expensive. Instead we compute a Merkle tree for the entire UTXO set at the chain state which is to be ported,
      store only the root of that Merkle tree, and require UTXO claimants prove that the UTXO they wish to claim is present in the tree.

*/

pragma solidity ^0.4.23;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/StandardToken.sol";
import "../node_modules/openzeppelin-solidity/contracts/MerkleProof.sol";


/**
* Based on https://github.com/ProjectWyvern/wyvern-ethereum
*/
contract UTXORedeemableToken is StandardToken {

    /* Origin Address */
    address public origin;

    /* Store time of launch for contract */
    uint256 public launchTime;

    /* Store last updated week */
    uint256 public lastUpdatedWeek = 0;

    /* Weekly update data */
    mapping(uint256 => uint256) public unclaimedCoinsByWeek;

    /* Root hash of the UTXO Merkle tree, must be initialized by token constructor. */
    bytes32 public rootUtxoMerkleTreeHash;

    /* Redeemed UTXOs. */
    mapping(bytes32 => bool) public redeemedUTXOs;

    /* Total tokens redeemed so far. */
    uint256 public totalRedeemed = 0;

    /* Maximum redeemable tokens, must be initialized by token constructor. */
    uint256 public maximumRedeemable;

    /* Claim, stake, and minting events need to happen atleast once every week for this function to
       run automatically, otherwise function can be manually called for that week */
    function storeWeekUnclaimed()
      public 
    {
        uint256 _weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);

        if (_weeksSinceLaunch <= 50 && _weeksSinceLaunch > lastUpdatedWeek) {
            uint256 unclaimedCoins = maximumRedeemable.sub(totalRedeemed);
            unclaimedCoinsByWeek[_weeksSinceLaunch] = unclaimedCoins;
            lastUpdatedWeek = _weeksSinceLaunch;
        }
    }

    /**
     * @dev Extract a bytes32 subarray from an arbitrary length bytes array.
     * @param _data Bytes array from which to extract the subarray
     * @param _pos Starting position from which to copy
     * @return Extracted length 32 byte array
     */
    function extract(
        bytes _data, 
        uint256 _pos
    ) 
        private
        pure 
        returns (bytes32 _result) 
    { 
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
    ) 
      public 
      pure 
      returns (bool) 
    {
        bytes32 _formattedHash;

        if (!_addPrefix) {
            _formattedHash = _hash;
        } else {
            // accomodate geth method of signing data with prefixed message
            bytes memory _prefix = "\x19Ethereum Signed Message:\n32";
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
    ) 
      public 
      pure 
      returns (bool)
    {
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
    )
        public 
        pure 
        returns (address) 
    {
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
    ) 
        public 
        pure 
        returns (bytes20) 
    {
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
    ) 
        public 
        view 
        returns (bool)
    {
        return MerkleProof.verifyProof(_proof, rootUtxoMerkleTreeHash, _merkleLeafHash);
    }

    /**
     * @dev Verify that a UTXO with the specified Merkle leaf hash can be redeemed
     * @param _merkleLeafHash Merkle tree hash of the UTXO to be checked
     * @param _proof Merkle tree proof
     * @return Whether or not the UTXO with the specified hash can be redeemed
     */
    function canRedeemUtxoHash(
        bytes32 _merkleLeafHash, 
        bytes32[] _proof
    ) 
        public view returns (bool) 
    {
        /* Check that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
        return(
          (redeemedUTXOs[_merkleLeafHash] == false) && 
          verifyProof(_proof, _merkleLeafHash)
        );
    }

    /**
     * @dev Convenience helper function to check if a UTXO can be redeemed
     * @param _originalAddress Raw Bitcoin address (no base58-check encoding)
     * @param _satoshis Amount of UTXO in satoshis
     * @param _proof Merkle tree proof
     * @return Whether or not the UTXO can be redeemed
     */
    function canRedeemUtxo(
        bytes20 _originalAddress,
        uint256 _satoshis,
        bytes32[] _proof
    ) 
        public 
        view 
        returns (bool)
    {
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

    function getRedeemAmount(
        uint256 _satoshis
    ) 
        public 
        view 
        returns (uint256) 
    {
        /* Convert from 8 decimals to 18 */
        uint256 _bhxWei = _satoshis.mul(1e10);

        /* Silly whale reduction
           If claim amount is above 1000 BHX with 18 decimals ( 1e3 * 1e18 = 1e21) */
        if (_bhxWei > 1e21) {
            /* If claim amount is below 100000 BHX with 18 decimals (1e5 * 1e18 = 1e23) */
            if (_bhxWei < 1e23) {
                /* If between 1000 and 10000, penalise by 50% to 75% linearly
                   The following is a range convert from 1000-10000 to 500-2500
                   _bhxWei = ((Input - InputLow) / (InputHigh - InputLow)) * (OutputHigh - OutputLow) + OutputLow
                   _bhxWei = ((x - 1000) / (10000 - 1000)) * (2500 - 500) + 500
                   _bhxWei = (2 (x - 1000))/9 + 500 */
                _bhxWei = _bhxWei
                    .sub(1e11)
                    .mul(2)
                    .div(9)
                    .add(5e10);
            } else {
                /* If greater than 10000 BHX penalise by 75% */
                _bhxWei = _bhxWei.div(4);
            }
        }

        /* If before launch return 0 weeks otherwise calculate */
        uint256 _weeksSinceLaunch = launchTime < block.timestamp 
            ? block.timestamp.sub(launchTime).div(7 days) 
            : 0;

        /* Calculate percent reduction */
        uint256 _reduction = uint256(100).sub(_weeksSinceLaunch.mul(2));

        /* 
          Calculate redeem amount in standard token decimals (1e18): 
          already has 8 decimals (1e8 * 1e10 = 1e18) 
        */
        uint256 _redeemAmount = _bhxWei.mul(_reduction).div(100);

        /* Apply speed bonus */
        if(_weeksSinceLaunch > 45) {
            return _redeemAmount;
        }

        if(_weeksSinceLaunch > 32) {
            return _redeemAmount.mul(101).div(100);
        }

        if(_weeksSinceLaunch > 24) {
            return _redeemAmount.mul(102).div(100);
        }

        if(_weeksSinceLaunch > 18) {
            return _redeemAmount.mul(103).div(100);
        }

        if(_weeksSinceLaunch > 14) {
            return _redeemAmount.mul(104).div(100);
        }

        if(_weeksSinceLaunch > 10) {
            return _redeemAmount.mul(105).div(100);
        }

        if(_weeksSinceLaunch > 7) {
            return _redeemAmount.mul(106).div(100);
        }

        if(_weeksSinceLaunch > 5) {
            return _redeemAmount.mul(107).div(100);
        }

        if(_weeksSinceLaunch > 3) {
            return _redeemAmount.mul(108).div(100);
        }

        if(_weeksSinceLaunch > 1) {
            return _redeemAmount.mul(109).div(100);
        }

        return _redeemAmount.mul(110).div(100);
    }

    /**
     * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
     * @param _satoshis Amount of UTXO in satoshis
     * @param _proof Merkle tree proof
     * @param _pubKey Uncompressed ECDSA public key to which the UTXO was sent
     * @param _isCompressed Whether the Bitcoin address was generated from a compressed public key
     * @param _v v parameter of ECDSA signature
     * @param _r r parameter of ECDSA signature
     * @param _s s parameter of ECDSA signature
     * @return The number of tokens redeemed, if successful
     */
     // TODO: make sure that this cannot be claimed after 50 weeks
    function redeemUtxo(
        uint256 _satoshis,
        bytes32[] _proof,
        bytes _pubKey,
        bool _isCompressed,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) 
        public 
        returns (uint256 _tokensRedeemed)
    {
        // ensure that redeeming after launch time
        require(block.timestamp >= launchTime);
        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        // /* Disable claims after 50 weeks */
        // require(block.timestamp.sub(launchTime).div(7 days) < 50);

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

        /* Mark the UTXO as redeemed. */
        redeemedUTXOs[_merkleLeafHash] = true;

        _tokensRedeemed = getRedeemAmount(_satoshis);

        /* Sanity check. */
        require(totalRedeemed.add(_tokensRedeemed) <= maximumRedeemable);

        /* Track total redeemed tokens. */
        totalRedeemed = totalRedeemed.add(_tokensRedeemed);

        /* Credit the redeemer. */ 
        balances[msg.sender] = balances[msg.sender].add(_tokensRedeemed);

        /* Increase supply */
        totalSupply_ = totalSupply_.add(_tokensRedeemed);

        /* Mark the transfer event. */
        emit Transfer(address(0), msg.sender, _tokensRedeemed);
        
        /* Return the number of tokens redeemed. */
        return _tokensRedeemed;

    }

    /**
     * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
     * @param _satoshis Amount of UTXO in satoshis
     * @param _proof Merkle tree proof
     * @param _pubKey Uncompressed ECDSA public key to which the UTXO was sent
     * @param _isCompressed Whether the Bitcoin address was generated from a compressed public key
     * @param _v v parameter of ECDSA signature
     * @param _r r parameter of ECDSA signature
     * @param _s s parameter of ECDSA signature
     * @param _referrer address of referring person
     * @return The number of tokens redeemed, if successful
     */
    function redeemReferredUtxo(
        uint256 _satoshis,
        bytes32[] _proof,
        bytes _pubKey,
        bool _isCompressed,
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        address _referrer
    ) 
        external 
        returns (uint256 _tokensRedeemed) 
    {
        /* Prevent Self-Referral */
        require(_referrer != msg.sender);
        require(_referrer != address(0));

        /* Credit claimer */
        _tokensRedeemed = redeemUtxo (
            _satoshis,
            _proof,
            _pubKey,
            _isCompressed,
            _v,
            _r,
            _s
        );

        /* Credit referrer */
        balances[_referrer] = balances[_referrer].add(_tokensRedeemed.div(20));

        /* Increase supply */
        totalSupply_ = totalSupply_.add(_tokensRedeemed.div(20));

        return _tokensRedeemed;
    }

}