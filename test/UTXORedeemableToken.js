const {
  setupContract,
  testInitialization,
  testVerifySignature,
  testEcsdaVerify
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
        await testVerifySignature(
          urt,
          accounts[1],
          accounts[1],
          'testing',
          true
        )
      })

      it('should NOT validateSignature using incorrectAddress', async () => {
        await testVerifySignature(
          urt,
          accounts[1],
          accounts[2],
          'testing',
          false
        )
      })

      it('should verify bitcoin signature using ecdsaVerify', async () => {
        await testEcsdaVerify(urt)
      })

      // it('should convert ethereum public key to address', async () => {
      //   assert(false)
      // })

      // it('should convert bitcoin public key to address', async () => {
      //   assert(false)
      // })

      // it('should verify merkle proof', async () => {
      //   assert(false)
      // })

      // it('should allow redeeming valid UTXO', async () => {
      //   assert(false)
      // })

      // it('should allow redeeming valid UTXO hash', async () => {
      //   assert(false)
      // })

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
