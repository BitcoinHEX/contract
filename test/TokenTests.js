const expectRevert = require('./helpers/expectRevert')

const BitcoinHexStub = artifacts.require('./stubs/BitcoinHexStub.sol')

describe('when deploying BitcoinHex', () => {
  contract('BitcoinHex', accounts => {
    let bhx
    const originContract = accounts[0]

    before('setup BitcoinHex', async () => {
      bhx = await BitcoinHexStub.new(originContract)
    })

    it('should have correct name and symbol', async () => {
      assert.equal(
        await bhx.name.call(),
        'BitcoinHex',
        'BitcoinHexStub name incorrect'
      )
      assert.equal(
        await bhx.symbol.call(),
        'BHX',
        'BitcoinHexStub symbol incorrect'
      )
    })

    it("should fail to transfer bhxs to address(0) or the bhx's address", async () => {
      await expectRevert(bhx.transfer(0, 1))
      await expectRevert(bhx.transfer(bhx.address, 1))
    })
  })
})
