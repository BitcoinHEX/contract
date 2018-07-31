const StakeableTokenStub = artifacts.require('StakeableTokenStub')

const BigNumber = require('bignumber.js')

const { origin, getCurrentBlockTime } = require('./general')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')
const {
  defaultMaximumRedeemable,
  defaultTotalBtcCirculationAtFork
} = require('./bhx')

const defaultInterestRatePercent = new BigNumber(1)

const stakeStructToObj = struct => ({
  stakeAmount: struct[0],
  stakeTime: struct[1],
  unlockTime: struct[2],
  totalStakedCoinsAtStart: struct[3]
})

const getWeeksSinceLaunch = async skt => {
  const launchTime = await skt.launchTime()
  const currentBlockTime = await getCurrentBlockTime()
  return new BigNumber(currentBlockTime)
    .sub(launchTime)
    .div(7)
    .floor(0)
}

const setupStakeableToken = launchTime =>
  StakeableTokenStub.new(
    origin,
    launchTime,
    defaultRootUtxoMerkleHash,
    defaultTotalBtcCirculationAtFork,
    defaultMaximumRedeemable // 2.558493073E19
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

const testStartStake = async (skt, amount, unlockTime, config) => {
  const { from: staker } = config
  const preBalance = await skt.balanceOf(staker)
  const preStaked = await skt.getCurrentStaked(staker)
  const preTotalStakedCoins = await skt.totalStakedCoins()

  await skt.startStake(amount, unlockTime, config)

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

// mimic smart contract function and check for integer overflows which can happen in solidity
const calculateCompounded = (principle, periods, raisedRate) => {
  const maxGroupPeriods = 30
  const remainingPeriods = periods % maxGroupPeriods
  const groupings = new BigNumber(periods).div(maxGroupPeriods).floor(0)
  let compounded = principle.div(1e10).floor(0)
  let raisedRateToPower
  let raisedByToPower

  for (let i = 0; i < groupings; i++) {
    raisedRateToPower = raisedRate.toPower(maxGroupPeriods)
    raisedByToPower = new BigNumber(1e4).toPower(maxGroupPeriods)
    compounded = compounded.mul(raisedRateToPower).div(raisedByToPower)

    assert(
      raisedRateToPower.lessThan('2e256'),
      'raised rate raised to power of periods must be less than 2^256'
    )
    assert(
      raisedByToPower.lessThan('2e256'),
      'raised amount to power of periods must be less than 2^256'
    )
  }

  raisedRateToPower = raisedRate.toPower(remainingPeriods)
  raisedByToPower = new BigNumber(1e4).toPower(remainingPeriods)
  compounded = compounded
    .mul(raisedRateToPower)
    .div(raisedByToPower)
    .floor(0)
    .mul(1e10)

  assert(
    raisedRateToPower.lessThan('2e256'),
    'raised rate raised to power of periods must be less than 2^256'
  )
  assert(
    raisedByToPower.lessThan('2e256'),
    'raised amount to power of periods must be less than 2^256'
  )

  return compounded
}

// TODO: double check that areInRange is satisfactorily accurate
const testCalculateStakingRewards = async (skt, staker, stakeIndex) => {
  const stakeStruct = await skt.staked(staker, stakeIndex)
  const stake = stakeStructToObj(stakeStruct)

  const periods = stake.unlockTime
    .sub(stake.stakeTime)
    .div(60 * 60 * 24 * 10)
    .floor(0)

  const interestRate = await skt.interestRatePercent()
  const raisedRate = interestRate.mul(100)
  const totalSupply = await skt.totalSupply()
  let scaler = stake.totalStakedCoinsAtStart
    .mul(100)
    .div(totalSupply)
    .floor(0)
  scaler = scaler.equals(0) ? new BigNumber(1) : scaler
  const scaledRate = raisedRate.div(scaler).floor(0)
  const reRaisedRate = scaledRate.add(1e4)
  const expectedCompounded = calculateCompounded(
    stake.stakeAmount,
    periods,
    reRaisedRate
  )

  const rewards = await skt.calculateStakingRewards(staker, stakeIndex)

  assert.equal(
    rewards.toString(),
    expectedCompounded.sub(stake.stakeAmount).toString(),
    'rewards should match expectedCompounded'
  )

  return rewards
}

const calculateSatoshiRewards = async (skt, stakeTime, unlockTime) => {
  const launchTime = await skt.launchTime()
  const startWeek = new BigNumber(stakeTime)
    .sub(launchTime)
    .div(60 * 60 * 24 * 7)
    .floor(0)
  const endWeek = new BigNumber(unlockTime)
    .sub(launchTime)
    .div(60 * 60 * 24 * 7)
    .floor(0)

  const rewardableEndWeek = endWeek > 50 ? 50 : endWeek
  let expectedRewards = new BigNumber(0)
  for (let i = startWeek; i < rewardableEndWeek; i++) {
    const unclaimedCoins = await skt.unclaimedCoinsByWeek(i)
    const weeklyReward = unclaimedCoins
      .mul(2)
      .div(100)
      .floor(0)
    expectedRewards = expectedRewards.add(weeklyReward)
  }

  return expectedRewards
}

const testCalculateSatoshiRewards = async (skt, stakeTime, unlockTime) => {
  const expectedRewards = await calculateSatoshiRewards(
    skt,
    stakeTime,
    unlockTime
  )

  const rewards = await skt.calculateWeAreAllSatoshiRewards(
    stakeTime,
    unlockTime
  )

  assert.equal(
    rewards.toString(),
    expectedRewards.toString(),
    'satoshi rewards should match expected rewards'
  )

  return rewards
}

const testCalculateViralRewards = async (skt, stakeAmount) => {
  const totalRedeemed = await skt.totalRedeemed()
  const totalBtcCirculationAtFork = await skt.totalBtcCirculationAtFork()
  const expectedViralRewards = stakeAmount
    .mul(totalRedeemed)
    .div(totalBtcCirculationAtFork)
    .mul(10)
    .div(100)
    .floor(0)

  const rewards = await skt.calculateViralRewards(stakeAmount)

  assert.equal(
    rewards.toString(),
    expectedViralRewards.toString(),
    'viral rewards should match expectedViralRewards'
  )

  return rewards
}

const testCalculateCritMassRewards = async (skt, stakeAmount) => {
  const totalRedeemed = await skt.totalRedeemed()
  const maximumRedeemable = await skt.maximumRedeemable()
  const expectedCritMassRewards = stakeAmount
    .mul(totalRedeemed)
    .div(maximumRedeemable)
    .mul(10)
    .div(100)
    .floor(0)

  const rewards = await skt.calculateCritMassRewards(stakeAmount)

  assert.equal(
    rewards.toString(),
    expectedCritMassRewards.toString(),
    'crit mass rewards should match expectedCritMassRewards'
  )

  return rewards
}

const testCalculateAdditionalRewards = async (
  skt,
  staker,
  stakeIndex,
  expectedSatoshiRewards,
  expectedViralRewards,
  expectedCritMassRewards
) => {
  const expectedRewards = expectedSatoshiRewards
    .add(expectedViralRewards)
    .add(expectedCritMassRewards)

  const rewards = await skt.calculateAdditionalRewards(staker, stakeIndex)

  assert.equal(
    rewards.toString(),
    expectedRewards.toString(),
    'rewards should match expected rewards'
  )

  return rewards
}

const testClaimStake = async (
  skt,
  staker,
  stakeIndex,
  stakingRewards,
  additionalRewards
) => {
  const stakeStruct = await skt.staked(staker, stakeIndex)
  const stake = stakeStructToObj(stakeStruct)
  const expectedTotalRewards = stake.stakeAmount
    .add(stakingRewards)
    .add(additionalRewards)

  const preStakerBalance = await skt.balanceOf(staker)
  const preStaked = await skt.getTotalStaked(staker)
  const preTotalStakedCoins = await skt.totalStakedCoins()
  const preOriginBalance = await skt.balanceOf(origin)

  await skt.claimSingleStakingReward(staker, stakeIndex)

  const postStakerBalance = await skt.balanceOf(staker)
  const postStaked = await skt.getTotalStaked(staker)
  const postTotalStakedCoins = await skt.totalStakedCoins()
  const postOriginBalance = await skt.balanceOf(origin)

  assert.equal(
    postOriginBalance.sub(preOriginBalance).toString(),
    additionalRewards.toString(),
    'origin balance should be incremented by additional rewards amount'
  )

  assert.equal(
    postStakerBalance.sub(preStakerBalance).toString(),
    expectedTotalRewards.toString(),
    'staker balance should be incremented by stake amount + rewards'
  )
  assert.equal(
    preStaked.sub(postStaked).toString(),
    preStaked.toString(),
    'staker staked amount should be decremented by stake amount'
  )
  assert.equal(
    preTotalStakedCoins.sub(postTotalStakedCoins).toString(),
    preStaked.toString(),
    'totalStakedCoins should be decremented by stake amount'
  )
}

module.exports = {
  defaultTotalBtcCirculationAtFork,
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake,
  testCalculateStakingRewards,
  testCalculateSatoshiRewards,
  testCalculateViralRewards,
  testCalculateCritMassRewards,
  testCalculateAdditionalRewards,
  stakeStructToObj,
  getWeeksSinceLaunch
}
