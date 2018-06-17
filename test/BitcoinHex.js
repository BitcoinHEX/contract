const { setupContract, testInitialization } = require('./helpers/bhx')

describe('when deploying BitcoinHex', () => {
  contract('BitcoinHex', () => {
    let bhx

    before('setup contracts', async () => {
      bhx = await setupContract()
    })

    it('should start with the correct values', async () => {
      await testInitialization(bhx)
    })
  })
})
