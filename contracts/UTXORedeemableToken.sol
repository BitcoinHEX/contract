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

/* solium-disable security/no-block-members */


/**
* Based on https://github.com/ProjectWyvern/wyvern-ethereum
*/
contract UTXORedeemableToken is StandardToken {
<<<<<<< HEAD

    /* Origin Address */
    address origin;
=======
>>>>>>> a05ef61a9beed0d06f024aee24381035e512df9e

    /* Store time of launch for contract */
    uint256 launchTime;

    /* Store last updated week */
    uint256 lastUpdatedWeek = 0;

    struct WeekDataStruct {
        uint256 unclaimedCoins;
    }

    /* Weekly update data */
    mapping(uint256 => WeekDataStruct) weekData;

    /* Root hash of the UTXO Merkle tree, must be initialized by token constructor. */
    bytes32 public rootUTXOMerkleTreeHash;

    /* Redeemed UTXOs. */
    mapping(bytes32 => bool) redeemedUTXOs;

    /* Total tokens redeemed so far. */
    uint256 public totalRedeemed;

    /* Maximum redeemable tokens, must be initialized by token constructor. */
    uint256 public maximumRedeemable;

    /* Redemption event, containing all relevant data for later analysis if desired. */
    event UTXORedeemed(
        bytes32 txid,
        uint8 outputIndex,
        uint256 satoshis,
        bytes32[] proof,
        bytes pubKey,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address indexed redeemer,
        uint256 numberOfTokens
    );

    /* Claim, stake, and minting events need to happen atleast once every week for this function to
       run automatically, otherwise function can be manually called for that week */
    function storeWeekUnclaimed() public {
        uint256 weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);
        if (weeksSinceLaunch < 51 && weeksSinceLaunch > lastUpdatedWeek) {
            uint256 unclaimedCoins = maximumRedeemable.sub(totalRedeemed);
            weekData[weeksSinceLaunch] = WeekDataStruct(unclaimedCoins);
            lastUpdatedWeek = weeksSinceLaunch;
        }
    }

    /**
     * @dev Extract a bytes32 subarray from an arbitrary length bytes array.
     * @param data Bytes array from which to extract the subarray
     * @param pos Starting position from which to copy
     * @return Extracted length 32 byte array
     */
    function extract(bytes data, uint256 pos) private pure returns (bytes32 result) { 
        for (uint256 i = 0; i < 32; i++) {
            result ^= (bytes32(0xff00000000000000000000000000000000000000000000000000000000000000) & data[i + pos]) >> (i * 8);
        }
        return result;
    }
    
    /**
     * @dev Validate that a provided ECSDA signature was signed by the specified address
     * @param hash Hash of signed data
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @param expected Address claiming to have created this signature
     * @return Whether or not the signature was valid
     */
    function validateSignature (
        bytes32 hash, 
        uint8 v, 
        bytes32 r, 
        bytes32 s, 
        address expected
    ) 
      public 
      pure 
      returns (bool) 
    {
        return ecrecover(
            hash, 
            v, 
            r, 
            s
        ) == expected;
    }

    /**
     * @dev Validate that the hash of a provided address was signed by the ECDSA public key associated with the specified Ethereum address
     * @param addr Address signed
     * @param pubKey Uncompressed ECDSA public key claiming to have created this signature
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @return Whether or not the signature was valid
     */
    function ecdsaVerify (
        address addr, 
        bytes pubKey, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) 
      public 
      pure 
      returns (bool)
    {
        return validateSignature(
            sha256(abi.encodePacked(addr)), 
            v, 
            r, 
            s, 
            pubKeyToEthereumAddress(pubKey)
        );
    }

    /**
     * @dev Convert an uncompressed ECDSA public key into an Ethereum address
     * @param pubKey Uncompressed ECDSA public key to convert
     * @return Ethereum address generated from the ECDSA public key
     */
    function pubKeyToEthereumAddress (bytes pubKey) public pure returns (address) {
        return address(uint(keccak256(pubKey)) & 0x000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }

    /**
     * @dev Calculate the Bitcoin-style address associated with an ECDSA public key
     * @param pubKey ECDSA public key to convert
     * @param isCompressed Whether or not the Bitcoin address was generated from a compressed key
     * @return Raw Bitcoin address (no base58-check encoding)
     */
    function pubKeyToBitcoinAddress(bytes pubKey, bool isCompressed) public pure returns (bytes20) {
        /* Helpful references:
           - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses 
           - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
        */

        /* x coordinate - first 32 bytes of public key */
        uint256 x = uint(extract(pubKey, 0));
        /* y coordinate - second 32 bytes of public key */
        uint256 y = uint(extract(pubKey, 32)); 
        uint8 startingByte;
        if (isCompressed) {
            /* Hash the compressed public key format. */
            startingByte = y % 2 == 0 ? 0x02 : 0x03;
            return ripemd160(abi.encodePacked(sha256(abi.encodePacked(startingByte, x))));
        } else {
            /* Hash the uncompressed public key format. */
            startingByte = 0x04;
            return ripemd160(abi.encodePacked(sha256(abi.encodePacked(startingByte, x, y))));
        }
    }

    /**
     * @dev Verify a Merkle proof using the UTXO Merkle tree
     * @param proof Generated Merkle tree proof
     * @param merkleLeafHash Hash asserted to be present in the Merkle tree
     * @return Whether or not the proof is valid
     */
    function verifyProof(bytes32[] proof, bytes32 merkleLeafHash) public view returns (bool) {
        return MerkleProof.verifyProof(proof, rootUTXOMerkleTreeHash, merkleLeafHash);
    }

    /**
     * @dev Convenience helper function to check if a UTXO can be redeemed
     * @param txid Transaction hash
     * @param originalAddress Raw Bitcoin address (no base58-check encoding)
     * @param outputIndex Output index of UTXO
     * @param satoshis Amount of UTXO in satoshis
     * @param proof Merkle tree proof
     * @return Whether or not the UTXO can be redeemed
     */
    function canRedeemUTXO(
        bytes32 txid,
        bytes20 originalAddress,
        uint8 outputIndex,
        uint256 satoshis,
        bytes32[] proof
    ) 
        public 
        view 
        returns (bool)
    {
        /* Calculate the hash of the Merkle leaf associated with this UTXO. */
        bytes32 merkleLeafHash = keccak256(
            abi.encodePacked(
                txid, 
                originalAddress, 
                outputIndex, 
                satoshis
            )
        );
    
        /* Verify the proof. */
        return canRedeemUTXOHash(merkleLeafHash, proof);
    }
      
    /**
     * @dev Verify that a UTXO with the specified Merkle leaf hash can be redeemed
     * @param merkleLeafHash Merkle tree hash of the UTXO to be checked
     * @param proof Merkle tree proof
     * @return Whether or not the UTXO with the specified hash can be redeemed
     */
    function canRedeemUTXOHash(bytes32 merkleLeafHash, bytes32[] proof) public view returns (bool) {
        /* Check that the UTXO has not yet been redeemed and that it exists in the Merkle tree. */
        return((redeemedUTXOs[merkleLeafHash] == false) && verifyProof(proof, merkleLeafHash));
    }

    function getRedeemAmount(uint256 amount) internal view returns (uint256 redeemed) {
        uint256 satoshis = amount;

        /* Weeks since launch */
        uint256 weeksSinceLaunch = block.timestamp.sub(launchTime).div(7 days);

        /* Calculate percent reduction */
        uint256 reduction = uint256(100).sub(weeksSinceLaunch.mul(2));

        /* Silly whale reduction
           If claim amount is above 1000 BHX with 18 decimals ( 1e3 * 1e18 = 1e20) */
        if (satoshis > 1e21) {
            /* If claim amount is below 100000 BHX with 18 decimals (1e5 * 1e18 = 1e23) */
            if (satoshis < 1e23) {
                /* If between 1000 and 10000, penalise by 50% to 75% linearly
                   The following is a range convert from 1000-10000 to 500-2500
                   satoshis = ((Input - InputLow) / (InputHigh - InputLow)) * (OutputHigh - OutputLow) + OutputLow
                   satoshis = ((x - 1000) / (10000 - 1000)) * (2500 - 500) + 500
                   satoshis = (2 (x - 1000))/9 + 500 */
                satoshis = satoshis
                    .sub(1e11)
                    .mul(2)
                    .div(9)
                    .add(5e10);
            } else {
                /* If greater than 10000 BHX penalise by 75% */
                satoshis = satoshis.div(4);
            }
        }

        /* 
          Calculate redeem amount in standard token decimals (1e18): 
          already has 8 decimals (1e8 * 1e10 = 1e18) 
        */
        uint256 redeemAmount = satoshis.mul(reduction).mul(1e10).div(100);

        /* Apply speed bonus */
        if(weeksSinceLaunch > 45){
            return redeemAmount;
        }

        if(weeksSinceLaunch > 32){
            return redeemAmount.mul(101).div(100);
        }

        if(weeksSinceLaunch > 24){
            return redeemAmount.mul(102).div(100);
        }

        if(weeksSinceLaunch > 18){
            return redeemAmount.mul(103).div(100);
        }

        if(weeksSinceLaunch > 14){
            return redeemAmount.mul(104).div(100);
        }

        if(weeksSinceLaunch > 10){
            return redeemAmount.mul(105).div(100);
        }

        if(weeksSinceLaunch > 7){
            return redeemAmount.mul(106).div(100);
        }

        if(weeksSinceLaunch > 5){
            return redeemAmount.mul(107).div(100);
        }

        if(weeksSinceLaunch > 3){
            return redeemAmount.mul(108).div(100);
        }

        if(weeksSinceLaunch > 1){
            return redeemAmount.mul(109).div(100);
        }

        return redeemAmount.mul(110).div(100);
    }

    /**
     * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
     * @param txid Transaction hash
     * @param outputIndex Output index of the UTXO
     * @param satoshis Amount of UTXO in satoshis
     * @param proof Merkle tree proof
     * @param pubKey Uncompressed ECDSA public key to which the UTXO was sent
     * @param isCompressed Whether the Bitcoin address was generated from a compressed public key
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @return The number of tokens redeemed, if successful
     */
    function redeemUTXO (
        bytes32 txid,
        uint8 outputIndex,
        uint256 satoshis,
        bytes32[] proof,
        bytes pubKey,
        bool isCompressed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) 
        public 
        returns (uint256 tokensRedeemed)
    {
        /* Check if weekly data needs to be updated */
        storeWeekUnclaimed();

        /* Disable claims after 50 weeks */
        require(block.timestamp.sub(launchTime).div(7 days) < 50);

        /* Calculate original Bitcoin-style address associated with the provided public key. */
        bytes20 originalAddress = pubKeyToBitcoinAddress(pubKey, isCompressed);

        /* Calculate the UTXO Merkle leaf hash. */
        bytes32 merkleLeafHash = keccak256(
            abi.encodePacked(
                txid, 
                originalAddress, 
                outputIndex, 
                satoshis
            )
        );

        /* Verify that the UTXO can be redeemed. */
        require(canRedeemUTXOHash(merkleLeafHash, proof));

        /* Claimant must sign the Ethereum address to which they wish to remit the redeemed tokens. */
        require(
            ecdsaVerify(
                msg.sender, 
                pubKey, 
                v, 
                r, 
                s
            )
        );

        /* Mark the UTXO as redeemed. */
        redeemedUTXOs[merkleLeafHash] = true;

        tokensRedeemed = getRedeemAmount(satoshis);

        /* Sanity check. */
        require(totalRedeemed.add(tokensRedeemed) <= maximumRedeemable);

        /* Track total redeemed tokens. */
        totalRedeemed = totalRedeemed.add(tokensRedeemed);

        /* Credit the redeemer. */ 
        balances[msg.sender] = balances[msg.sender].add(tokensRedeemed);

        /* Increase supply */
        totalSupply_ = totalSupply_.add(tokensRedeemed);

        /* Mark the transfer event. */
        emit Transfer(address(0), msg.sender, tokensRedeemed);

        /* Mark the UTXO redemption event. */
        emit UTXORedeemed(
            txid, 
            outputIndex, 
            satoshis, 
            proof, 
            pubKey, 
            v, 
            r,
            s, 
            msg.sender, 
            tokensRedeemed
        );
        
        /* Return the number of tokens redeemed. */
        return tokensRedeemed;

    }

    /**
     * @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address
     * @param txid Transaction hash
     * @param outputIndex Output index of the UTXO
     * @param satoshis Amount of UTXO in satoshis
     * @param proof Merkle tree proof
     * @param pubKey Uncompressed ECDSA public key to which the UTXO was sent
     * @param isCompressed Whether the Bitcoin address was generated from a compressed public key
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @param referrer address of referring person
     * @return The number of tokens redeemed, if successful
     */
    function redeemUTXO (
        bytes32 txid,
        uint8 outputIndex,
        uint256 satoshis,
        bytes32[] proof,
        bytes pubKey,
        bool isCompressed,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address referrer
    ) 
        public 
        returns (uint256 tokensRedeemed) 
    {
        /* Credit claimer */
        tokensRedeemed = redeemUTXO (
            txid,
            outputIndex,
            satoshis,
            proof,
            pubKey,
            isCompressed,
            v,
            r,
            s
        );

        /* Credit referrer */
        balances[referrer] = balances[referrer].add(tokensRedeemed.div(20));

        /* Increase supply */
        totalSupply_ = totalSupply_.add(tokensRedeemed.div(20));

        return tokensRedeemed;
    }

}