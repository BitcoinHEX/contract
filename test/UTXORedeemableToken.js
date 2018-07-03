const {
  setupContract,
  bitcoinPrivateKeys,
  getProofAndComponents,
  timeWarpRelativeToLaunchTime,
  testInitialization,
  testValidateSignature,
  testEcsdaVerify,
  testPubKeyToEthereumAddress,
  testPubKeyToBitcoinAddress,
  testCanRedeemUtxoHash,
  testCanRedeemUtxo,
  testRedeemUtxo
} = require('./helpers/urt')

const transactions = require('./data/transactions')

describe('when deploying UTXORedeemableToken', () => {
  contract('UTXORedeemableTokenStub', accounts => {
    let urt

    before('setup contract stub', async () => {
      urt = await setupContract()
    })

    describe('when initializing the contract', () => {
      it('should start with the correct values', async () => {
        await testInitialization(urt)
      })
    })

    describe('when using included utility functions', () => {
      it('should validateSignature using ethereum private key', async () => {
        await testValidateSignature(
          urt,
          accounts[1],
          accounts[1],
          'testing',
          true
        )
      })

      it('should NOT validateSignature using incorrectAddress', async () => {
        await testValidateSignature(
          urt,
          accounts[1],
          accounts[2],
          'testing',
          false
        )
      })

      it('should verify bitcoin signature using ecdsaVerify', async () => {
        await testEcsdaVerify(urt, bitcoinPrivateKeys(0), accounts[1])
      })

      it('should convert public key to ethereum address', async () => {
        await testPubKeyToEthereumAddress(urt, bitcoinPrivateKeys(0))
      })

      it('should convert public key to bitcoin address', async () => {
        await testPubKeyToBitcoinAddress(urt, bitcoinPrivateKeys(0))
      })

      it('should allow redeeming valid UTXO hash', async () => {
        const bitcoinTx = transactions[0]
        const { potentialMerkleLeaf, proof } = getProofAndComponents(bitcoinTx)
        await testCanRedeemUtxoHash(urt, potentialMerkleLeaf, proof)
      })

      it('should allow redeeming valid UTXO', async () => {
        const bitcoinTx = transactions[0]
        const { proof, formattedAddress, satoshis } = getProofAndComponents(
          bitcoinTx
        )
        await testCanRedeemUtxo(urt, proof, formattedAddress, satoshis)
      })

      it('should redeem UTXO', async () => {
        await timeWarpRelativeToLaunchTime(urt, 60, true)
        const bitcoinTx = transactions[0]
        const { proof, satoshis } = getProofAndComponents(bitcoinTx)
        await testRedeemUtxo(urt, proof, satoshis, bitcoinPrivateKeys(0), {
          from: accounts[1]
        })
      })

      // it('should redeem UTXO with referrer', async () => {
      //   assert(false)
      // })

      // it('should increment week correctly', async () => {
      //   assert(false)
      // })
    })
  })
})
