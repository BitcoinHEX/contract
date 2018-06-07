## Standard Functions
BitcoinHEX conforms to the [ERC20](https://github.com/ethereum/EIPs/issues/20) spec, specifically using OpenZepplin's [Standard Token](https://openzeppelin.org/api/docs/token_ERC20_StandardToken.html) implementation. Those function docs will not be repeated here, see [OpenZepplin's docs](https://openzeppelin.org/api/docs/token_ERC20_StandardToken.html) for those.

## BitcoinHex Specific Functions
### canRedeemUTXO(bytes32 txid, bytes20 originalAddress, uint8 outputIndex, uint256 satoshis, bytes32[] proof)
TODO
### canRedeemUTXOHash(bytes32 merkleLeafHash, bytes32[] proof)
TODO
### redeemUTXO(bytes32 txid, uint8 outputIndex, uint256 satoshis, bytes32[] proof, bytes pubKey, bool isCompressed, uint8 v, bytes32 r, bytes32 s)
TODO
### redeemUTXO(bytes32 txid, uint8 outputIndex, uint256 satoshis, bytes32[] proof, bytes pubKey, bool isCompressed, uint8 v, bytes32 r, bytes32 s, address referrer)
TODO
### mapping(address => StakeStruct[]) public staked
TODO
### startStake(uint256 _value, uint256 _unlockTime)
TODO
### mint()
TODO