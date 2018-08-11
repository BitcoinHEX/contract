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
  totalStakedCoinsAtStart: struct[3],
  totalSupplyAtStart: struct[4]
})

const getWeeksSinceLaunch = async skt => {
  const launchTime = await skt.launchTime()
  const currentBlockTime = await getCurrentBlockTime()
  return new BigNumber(currentBlockTime)
    .sub(launchTime)
    .div(7)
    .floor(0)
}

// needed in order to keep array items in correct order during tests
const reorgStakesAfterRemoval = (stakeArray, removedIndex) => {
  stakeArray[removedIndex] = stakeArray[stakeArray.length - 1]
  stakeArray[removedIndex].stakeIndex = removedIndex
  return stakeArray.pop()
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

const testStartStake = async (
  skt,
  amount,
  unlockTime,
  expectedIndex,
  config
) => {
  const { from: staker } = config
  const preBalance = await skt.balanceOf(staker)
  const preStaked = await skt.getTotalUserStaked(staker)
  const preTotalStakedCoins = await skt.totalStakedCoins()

  await skt.startStake(amount, unlockTime, config)

  const postBalance = await skt.balanceOf(staker)
  const postStaked = await skt.getTotalUserStaked(staker)
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
  const overflowLimit = new BigNumber(2).toPower(256)
  const maxGroupPeriods = 10
  const remainingPeriods = periods % maxGroupPeriods
  const groupings = new BigNumber(periods).div(maxGroupPeriods).floor(0)
  let compounded = principle.div(1e10).floor(0)
  let raisedRateToPower
  let raisedByToPower
  let checkMul

  for (let i = 0; i < groupings; i++) {
    raisedRateToPower = raisedRate.toPower(maxGroupPeriods)
    raisedByToPower = new BigNumber(1e4).toPower(maxGroupPeriods)
    checkMul = compounded.mul(raisedRateToPower)
    compounded = compounded
      .mul(raisedRateToPower)
      .div(raisedByToPower)
      .floor(0)

    assert(
      raisedRateToPower.lessThan(overflowLimit),
      'raised rate raised to power of periods must be less than overflowLimit'
    )
    assert(
      raisedByToPower.lessThan(overflowLimit),
      'raised amount to power of periods must be less than overflowLimit'
    )
    assert(
      checkMul.lessThan(overflowLimit),
      'checkMul must be less than overflowLimit'
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
    raisedRateToPower.lessThan(overflowLimit),
    'raised rate raised to power of periods must be less than overflowLimit'
  )
  assert(
    raisedByToPower.lessThan(overflowLimit),
    'raised amount to power of periods must be less than overflowLimit'
  )
  assert(
    compounded.lessThan(overflowLimit),
    'compounded must be less than overflowLimit'
  )

  return compounded
}

const testCompound = async (skt, principle, periods, rate) => {
  const raisedRate = new BigNumber(rate).mul(100).add(10000)
  const expectedCompounded = calculateCompounded(principle, periods, raisedRate)
  const compounded = await skt.compound(principle, periods, raisedRate)

  assert.equal(
    compounded.toString(),
    expectedCompounded.toString(),
    'compounded should match expectedCompounded'
  )
}

const testCalculateStakingRewards = async (skt, staker, stakeIndex) => {
  const expectedRewards = await calculateStakingRewards(skt, staker, stakeIndex)

  const rewards = await skt.calculateStakingRewards(staker, stakeIndex)

  assert.equal(
    rewards.toString(),
    expectedRewards.toString(),
    'rewards should match expectedCompounded'
  )

  return rewards
}

const calculateStakingRewards = async (skt, staker, stakeIndex) => {
  const stakeStruct = await skt.staked(staker, stakeIndex)
  const stake = stakeStructToObj(stakeStruct)

  const periods = stake.unlockTime
    .sub(stake.stakeTime)
    .div(60 * 60 * 24 * 10)
    .floor(0)

  const interestRate = await skt.interestRatePercent()
  const raisedRate = interestRate.mul(100)

  let scaler = stake.totalStakedCoinsAtStart
    .mul(100)
    .div(stake.totalSupplyAtStart)
    .floor(0)
  scaler = scaler.equals(0) ? new BigNumber(1) : scaler
  const scaledRate = raisedRate.div(scaler).floor(0)
  const reRaisedRate = scaledRate.add(1e4)
  const expectedCompounded = calculateCompounded(
    stake.stakeAmount,
    periods,
    reRaisedRate
  )

  return expectedCompounded.sub(stake.stakeAmount)
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
  const redeemedCount = await skt.redeemedCount()
  const totalBtcCirculationAtFork = await skt.totalBtcCirculationAtFork()
  const expectedViralRewards = stakeAmount
    .mul(redeemedCount)
    .div(totalBtcCirculationAtFork)
    .floor(0)
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
    .floor(0)
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
  const preStaked = await skt.getTotalUserStaked(staker)
  const preTotalStakedCoins = await skt.totalStakedCoins()
  const preOriginBalance = await skt.balanceOf(origin)

  await skt.claimSingleStakingReward(staker, stakeIndex)

  const postStakerBalance = await skt.balanceOf(staker)
  const postStaked = await skt.getTotalUserStaked(staker)
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
    stake.stakeAmount.toString(),
    'staker staked amount should be decremented by stake amount'
  )
  assert.equal(
    preTotalStakedCoins.sub(postTotalStakedCoins).toString(),
    stake.stakeAmount.toString(),
    'totalStakedCoins should be decremented by stake amount'
  )
}

// TODO: update make these tests pass after updating the way calculateStakingRewards workds
// this needs to consider the different array positions of each array item...
// due to the way staking rewards works with total supply... perhaps use in stake struct?
const testClaimAllStakes = async (skt, staker, stakeCount) => {
  let totalStaked = new BigNumber(0)
  let expectedTotalSupply = await skt.totalSupply()
  let expectedTotalRewards = new BigNumber(0)

  for (let i = 0; i < stakeCount; i++) {
    const stakeStruct = await skt.staked(staker, i)
    const stake = stakeStructToObj(stakeStruct)
    const { stakeTime, unlockTime, stakeAmount } = stake

    const stakingRewards = await calculateStakingRewards(skt, staker, i)
    const satoshiRewards = await testCalculateSatoshiRewards(
      skt,
      stakeTime,
      unlockTime
    )
    const viralRewards = await testCalculateViralRewards(skt, stakeAmount)
    const critMassRewards = await testCalculateCritMassRewards(skt, stakeAmount)
    const additionalRewards = await testCalculateAdditionalRewards(
      skt,
      staker,
      i,
      satoshiRewards,
      viralRewards,
      critMassRewards
    )

    totalStaked = totalStaked.add(stakeAmount)
    expectedTotalSupply = expectedTotalSupply.add(additionalRewards.mul(2))
    expectedTotalRewards = expectedTotalRewards
      .add(stakingRewards)
      .add(additionalRewards)
  }

  const preStakerBalance = await skt.balanceOf(staker)
  const preStaked = await skt.getTotalUserStaked(staker)

  await skt.claimAllStakingRewards(staker)

  const postStakerBalance = await skt.balanceOf(staker)
  const postStaked = await skt.getTotalUserStaked(staker)

  assert.equal(
    postStakerBalance.sub(preStakerBalance).toString(),
    expectedTotalRewards.add(preStaked).toString(),
    'staker balance should be incremented by expectedTotalRewards + preStaked'
  )
  assert.equal(
    preStaked.sub(postStaked).toString(),
    totalStaked.toString(),
    'user staked should be decremented by totalStaked'
  )
}

module.exports = {
  defaultTotalBtcCirculationAtFork,
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake,
  testCompound,
  testCalculateStakingRewards,
  testCalculateSatoshiRewards,
  testCalculateViralRewards,
  testCalculateCritMassRewards,
  testCalculateAdditionalRewards,
  stakeStructToObj,
  getWeeksSinceLaunch,
  reorgStakesAfterRemoval,
  testClaimAllStakes
}
