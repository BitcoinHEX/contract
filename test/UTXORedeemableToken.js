const { setupContract, testInitialization } = require('./helpers/urt')

describe('when using UTXORedeemableToken functions', () => {
  contract('UTXORedeemableTokenStub', () => {
    let urt

    before('setup contract stub', async () => {
      urt = await setupContract()
    })

    it('should start with the correct values', async () => {
      await testInitialization(urt)
    })
  })
})
