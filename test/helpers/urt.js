const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const { origin, bigZero } = require('./general')
const { defaultLaunchTime, defaultMaximumRedeemable } = require('./bhx')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')

const setupContract = async () => {
  const urt = await UtxoRedeemableToken.new(
    origin,
    defaultLaunchTime,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable
  )

  return urt
}

const testInitialization = async urt => {
  const contractOrigin = await urt.origin()
  const launchTime = await urt.launchTime()
  const lastUpdatedWeek = await urt.lastUpdatedWeek()
  const rootUTXOMerkleTreeHash = await urt.rootUTXOMerkleTreeHash()
  const totalRedeemed = await urt.totalRedeemed()
  const maximumRedeemable = await urt.maximumRedeemable()

  assert.equal(contractOrigin, origin, 'contractOrigin should match origin')
  assert.equal(
    launchTime.toString(),
    defaultLaunchTime.toString(),
    'launchTime should match defaultLaunchTime'
  )
  assert.equal(
    lastUpdatedWeek.toString(),
    bigZero.toString(),
    'lastUpdatedWeek should start as 0'
  )
  assert.equal(
    rootUTXOMerkleTreeHash,
    defaultRootUtxoMerkleHash,
    'rootUTXOMerkleTreeHash should match defaultRootUtxoMerkleHash'
  )
  assert.equal(
    totalRedeemed.toString(),
    bigZero.toString(),
    'totalRedeemed should start as 0'
  )
  assert.equal(
    maximumRedeemable.toString(),
    defaultMaximumRedeemable.toString(),
    'maximumRedeemable should match defaultMaximumRedeemable'
  )
}

module.exports = {
  setupContract,
  testInitialization
}
