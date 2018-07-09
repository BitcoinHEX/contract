const StakeableTokenStub = artifacts.require('StakeableTokenStub')

const BigNumber = require('bignumber.js')

const { origin } = require('./general')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')
const { defaultMaximumRedeemable } = require('./bhx')

const defaultTotalBtcCirculationAtFork = new BigNumber('1000e8')
const defaultInterestRatePercent = new BigNumber(1)

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
  const interestRatePercent = await skt.interestRatePercent()

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
  assert.equal(
    interestRatePercent.toString(),
    defaultInterestRatePercent.toString(),
    'interestRatePercent should match defaultInterestRatePercent'
  )
}

const testStartStake = async (skt, amount, time, config) => {
  const { from: staker } = config
  const preBalance = await skt.balanceOf(staker)
  const preStaked = await skt.getCurrentStaked(staker)
  const preTotalStakedCoins = await skt.totalStakedCoins()

  await skt.startStake(amount, time, config)

  const postBalance = await skt.balanceOf(staker)
  const postStaked = await skt.getCurrentStaked(staker)
  const postTotalStakedCoins = await skt.totalStakedCoins()

  assert.equal(
    preBalance.sub(postBalance).toString(),
    amount.toString(),
    'staker balance should be decremented by stake amount'
  )
  assert.equal(
    postStaked.sub(preStaked).toString(),
    amount.toString(),
    'staker staked amount should be incremented by stake amount'
  )
  assert.equal(
    postTotalStakedCoins.sub(preTotalStakedCoins).toString(),
    amount.toString(),
    'totalStakedCoins should be incremented by stake amount'
  )
}

module.exports = {
  defaultTotalBtcCirculationAtFork,
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake
}
