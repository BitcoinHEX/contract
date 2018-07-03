const {
  setupContract,
  testInitialization,
  testValidateSignature,
  testEcsdaVerify,
  testPubKeyToEthereumAddress,
  testPubKeyToBitcoinAddress,
  testCanRedeemUtxoHash,
  testCanRedeemUtxo
} = require('./helpers/urt')

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
        await testEcsdaVerify(urt, accounts[1], 0)
      })

      it('should convert ethereum public key to address', async () => {
        await testPubKeyToEthereumAddress(urt, 0)
      })

      it('should convert bitcoin public key to address', async () => {
        await testPubKeyToBitcoinAddress(urt, 0)
      })

      it('should allow redeeming valid UTXO hash', async () => {
        await testCanRedeemUtxoHash(urt)
      })

      it('should allow redeeming valid UTXO', async () => {
        await testCanRedeemUtxo(urt)
      })

      // it('should redeem UTXO', async () => {
      //   assert(false)
      // })

      // it('should redeem UTXO with referrer', async () => {
      //   assert(false)
      // })

      // it('should increment week correctly', async () => {
      //   assert(false)
      // })
    })
  })
})
