pragma solidity ^0.5.7;

import "./GlobalsAndUtility.sol";
import "../node_modules/openzeppelin-solidity/contracts/cryptography/MerkleProof.sol";


contract UTXOClaimValidation is GlobalsAndUtility {
    /**
     * @dev PUBLIC FACING: Verify a BTC address and balance are unclaimed and part of the Merkle tree
     * @param btcAddress Bitcoin address (binary; no base58-check encoding)
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param proof Merkle tree proof
     * @return True if can be claimed
     */
    function canClaimBtcAddress(bytes20 btcAddress, uint256 rawSatoshis, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        require(_getCurrentDay() < CLAIM_PHASE_DAYS, "HEX: Claim phase has ended");

        /* Don't need to check Merkle proof if UTXO BTC address has already been claimed    */
        if (claimedBtcAddresses[btcAddress]) {
            return false;
        }

        /* Verify the Merkle tree proof */
        return _btcAddressIsValid(btcAddress, rawSatoshis, proof);
    }

    /**
     * @dev PUBLIC FACING: Verify a BTC address and balance are part of the Merkle tree
     * @param btcAddress Bitcoin address (binary; no base58-check encoding)
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param proof Merkle tree proof
     * @return True if valid
     */
    function btcAddressIsValid(bytes20 btcAddress, uint256 rawSatoshis, bytes32[] calldata proof)
        external
        pure
        returns (bool)
    {
        return _btcAddressIsValid(btcAddress, rawSatoshis, proof);
    }

    /**
     * @dev PUBLIC FACING: Verify a Merkle proof using the UTXO Merkle tree
     * @param merkleLeaf Leaf asserted to be present in the Merkle tree
     * @param proof Generated Merkle tree proof
     * @return True if valid
     */
    function merkleProofIsValid(bytes32 merkleLeaf, bytes32[] calldata proof)
        external
        pure
        returns (bool)
    {
        return _merkleProofIsValid(merkleLeaf, proof);
    }

    /**
     * @dev Verify that a Bitcoin signature matches the claim message containing
     * the Ethereum address
     * @param claimToAddr Eth address within the signed claim message
     * @param pubKeyX First  half of uncompressed ECDSA public key
     * @param pubKeyY Second half of uncompressed ECDSA public key
     * @param v v parameter of ECDSA signature
     * @param r r parameter of ECDSA signature
     * @param s s parameter of ECDSA signature
     * @return True if matching
     */
    function signatureMatchesClaim(
        address claimToAddr,
        bytes32 pubKeyX,
        bytes32 pubKeyY,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        public
        pure
        returns (bool)
    {
        require(v >= 27 && v <= 30, "HEX: v invalid");

        /*
            ecrecover() returns an Eth address rather than a public key, so
            we must do the same to compare.
        */
        address pubKeyEthAddr = pubKeyToEthAddress(pubKeyX, pubKeyY);

        /* Try matching the most likely type of claim message */
        bytes32 messageHash = _hash256(_createStandardClaimMessage(claimToAddr));

        if (ecrecover(messageHash, v, r, s) == pubKeyEthAddr) {
            return true;
        }

        /* Otherwise try the matching the legacy claim message as a fallback */
        messageHash = _hash256(_createLegacyClaimMessage(claimToAddr));

        return ecrecover(messageHash, v, r, s) == pubKeyEthAddr;
    }

    /**
     * @dev Derive an Ethereum address from an ECDSA public key
     * @param pubKeyX First  half of uncompressed ECDSA public key
     * @param pubKeyY Second half of uncompressed ECDSA public key
     * @return Derived Ethereum address
     */
    function pubKeyToEthAddress(bytes32 pubKeyX, bytes32 pubKeyY)
        public
        pure
        returns (address)
    {
        return address(uint160(uint256(keccak256(abi.encodePacked(pubKeyX, pubKeyY)))));
    }

    /**
     * @dev Derive a Bitcoin address from an ECDSA public key
     * @param pubKeyX First  half of uncompressed ECDSA public key
     * @param pubKeyY Second half of uncompressed ECDSA public key
     * @param addrType Type of BTC address to derive from the public key
     * @return Derived Bitcoin address (binary; no base58-check encoding)
     */
    function pubKeyToBtcAddress(bytes32 pubKeyX, bytes32 pubKeyY, uint8 addrType)
        public
        pure
        returns (bytes20)
    {
        require(addrType < BTC_ADDR_TYPE_COUNT, "HEX: addrType invalid");

        /*
            Helpful references:
             - https://en.bitcoin.it/wiki/Technical_background_of_version_1_Bitcoin_addresses
             - https://github.com/cryptocoinjs/ecurve/blob/master/lib/point.js
        */
        uint8 startingByte;
        bytes memory pubKey;

        if (addrType == BTC_ADDR_TYPE_P2PKH_UNCOMPRESSED) {
            /* Uncompressed public key format. */
            startingByte = 0x04;
            pubKey = abi.encodePacked(startingByte, pubKeyX, pubKeyY);
        } else {
            /* Compressed public key format. */
            startingByte = (pubKeyY[31] & 0x01) == 0 ? 0x02 : 0x03;
            pubKey = abi.encodePacked(startingByte, pubKeyX);
        }

        bytes20 pubKeyHash = _hash160(pubKey);
        if (addrType != BTC_ADDR_TYPE_P2WPKH_IN_P2SH) {
            return pubKeyHash;
        }
        return _hash160(abi.encodePacked(hex"0014", pubKeyHash));
    }

    /**
     * @dev Verify a BTC address and balance are part of the Merkle tree
     * @param btcAddress Bitcoin address (binary; no base58-check encoding)
     * @param rawSatoshis Raw BTC address balance in Satoshis
     * @param proof Merkle tree proof
     * @return True if valid
     */
    function _btcAddressIsValid(bytes20 btcAddress, uint256 rawSatoshis, bytes32[] memory proof)
        internal
        pure
        returns (bool)
    {
        /* Calculate the 32 byte Merkle leaf associated with this BTC address and balance */
        bytes32 merkleLeaf = bytes32(btcAddress) | bytes32(rawSatoshis);

        /* Verify the Merkle tree proof */
        return _merkleProofIsValid(merkleLeaf, proof);
    }

    /**
     * @dev Verify a Merkle proof using the UTXO Merkle tree
     * @param merkleLeaf Leaf asserted to be present in the Merkle tree
     * @param proof Generated Merkle tree proof
     * @return True if valid
     */
    function _merkleProofIsValid(bytes32 merkleLeaf, bytes32[] memory proof)
        private
        pure
        returns (bool)
    {
        return MerkleProof.verify(proof, MERKLE_TREE_ROOT, merkleLeaf);
    }

    /**
     * @dev Creates a HEX claim message from an Ethereum address
     * @param claimToAddr Destination Eth address to credit the claimed Hearts
     * @return Standard claim message
     */
    function _createStandardClaimMessage(address claimToAddr)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(24),
            bytes24("Bitcoin Signed Message:\n"),
            uint8(15 + ETH_ADDRESS_HEX_LEN),
            bytes15("Claim_HEX_to_0x"),
            _createHexStringFromEthAddress(claimToAddr)
        );
    }

    /**
     * @dev Creates a BitcoinHEX claim message from an Ethereum address
     * @param claimToAddr Destination Eth address to credit the claimed Hearts
     * @return Legacy claim message
     */
    function _createLegacyClaimMessage(address claimToAddr)
        private
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            uint8(24),
            bytes24("Bitcoin Signed Message:\n"),
            uint8(22 + ETH_ADDRESS_HEX_LEN),
            bytes22("Claim_BitcoinHEX_to_0x"),
            _createHexStringFromEthAddress(claimToAddr)
        );
    }

    /**
     * @dev Creates a lowercase hex string from an Ethereum address
     * @param ethAddr Eth address to convert
     * @return Hex string of Eth address
     */
    function _createHexStringFromEthAddress(address ethAddr)
        private
        pure
        returns (bytes memory hexStr)
    {
        hexStr = new bytes(ETH_ADDRESS_HEX_LEN);
        uint256 offset = 0;

        for (uint256 i = 0; i < ETH_ADDRESS_BYTE_LEN; i++) {
            uint8 b = uint8(bytes20(ethAddr)[i]);

            hexStr[offset++] = HEX_DIGITS[b >> 4];
            hexStr[offset++] = HEX_DIGITS[b & 0x0f];
        }
        return hexStr;
    }

    /**
     * @dev sha256(sha256(data))
     * @param data Data to be hashed
     * @return 32-byte hash
     */
    function _hash256(bytes memory data)
        private
        pure
        returns (bytes32)
    {
        return sha256(abi.encodePacked(sha256(data)));
    }

    /**
     * @dev ripemd160(sha256(data))
     * @param data Data to be hashed
     * @return 20-byte hash
     */
    function _hash160(bytes memory data)
        private
        pure
        returns (bytes20)
    {
        return ripemd160(abi.encodePacked(sha256(data)));
    }
}
