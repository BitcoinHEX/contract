const StakeableTokenStub = artifacts.require('StakeableTokenStub')

const BigNumber = require('bignumber.js')

const { origin } = require('./general')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')
const { defaultMaximumRedeemable } = require('./bhx')

const defaultTotalBtcCirculationAtFork = new BigNumber('1000e8')

const setupStakeableToken = launchTime =>
  StakeableTokenStub.new(
    origin,
    launchTime,
    defaultRootUtxoMerkleHash,
    defaultTotalBtcCirculationAtFork,
    defaultMaximumRedeemable
  )

const testInitializeStakeableToken = async (skt, expectedLaunchTime) => {
  const actualOrigin = await skt.origin()
  const launchTime = await skt.launchTime()
  const rootUtxoMerkleTreeHash = await skt.rootUtxoMerkleTreeHash()
  const totalBtcCirculationAtFork = await skt.totalBtcCirculationAtFork()
  const maximumRedeemable = await skt.maximumRedeemable()

  assert.equal(
    actualOrigin,
    origin,
    'contract origin should match origin address'
  )
  assert.equal(
    launchTime.toString(),
    expectedLaunchTime.toString(),
    'launchTime should match expectedLaunchTime'
  )
  assert.equal(
    rootUtxoMerkleTreeHash,
    defaultRootUtxoMerkleHash,
    'rootUtxoMerkleTreeHash should match defaultRootUtxoMerkleTreeHash'
  )
  assert.equal(
    totalBtcCirculationAtFork.toString(),
    defaultTotalBtcCirculationAtFork.toString(),
    'totalBtcCirculationAtFork should match defaultTotalBtcCirculationAtFork'
  )
  assert.equal(
    maximumRedeemable.toString(),
    defaultMaximumRedeemable.toString(),
    'maximumRedeemable should match defaultMaximumRedeemable'
  )
}

module.exports = {
  defaultTotalBtcCirculationAtFork,
  setupStakeableToken,
  testInitializeStakeableToken
}
