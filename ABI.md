## Standard Functions
BitcoinHEX conforms to the [ERC20](https://github.com/ethereum/EIPs/issues/20) spec, specifically using OpenZepplin's [Standard Token](https://openzeppelin.org/api/docs/token_ERC20_StandardToken.html) implementation. Those function docs will not be repeated here, see [OpenZepplin's docs](https://openzeppelin.org/api/docs/token_ERC20_StandardToken.html) for those.

## BitcoinHex Specific Functions

### canRedeemUTXOHash(bytes32 merkleLeafHash, bytes32[] proof)
* @dev Verify that a UTXO with the specified Merkle leaf hash can be redeemed
* @param merkleLeafHash Merkle tree hash of the UTXO to be checked
* @param proof Merkle tree proof
* @return Whether or not the UTXO with the specified hash can be redeemed

### redeemUTXO(bytes32 txid, uint8 outputIndex, uint256 satoshis, bytes32[] proof, bytes pubKey, bool isCompressed, uint8 v, bytes32 r, bytes32 s)
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

### redeemUTXO(bytes32 txid, uint8 outputIndex, uint256 satoshis, bytes32[] proof, bytes pubKey, bool isCompressed, uint8 v, bytes32 r, bytes32 s, address referrer)
* @dev Redeem a UTXO, crediting a proportional amount of tokens (if valid) to the sending address, and credit a bonus to a referrer
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

### mapping(address => StakeStruct[]) public staked
* @dev Lists all stakes for a given address

### startStake(uint256 _value, uint256 _unlockTime)
* @dev Locks up tokens for a pre-determined amount of time to earn rewards
* @param _value Amount of tokens to lock up (note token has 18 decimal places)
* @param _unlockTime Time to lock tokens till, tokens won't be accessible until this time has passed

### mint(address staker)
* @dev Redeems all stakes that have matured for a given address
* @param staker Address to redeem stakes for
