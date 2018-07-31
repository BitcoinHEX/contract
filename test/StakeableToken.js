const {
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake,
  testCalculateStakingRewards,
  testCalculateSatoshiRewards,
  testCalculateViralRewards,
  testCalculateCritMassRewards,
  testCalculateAdditionalRewards
} = require('./helpers/skt')
const {
  timeWarpRelativeToLaunchTime,
  warpThroughBonusWeeks,
  redeemAllUtxos
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')
const {
  stakers,
  getCurrentBlockTime,
  timeWarp,
  bigZero
} = require('./helpers/general')

describe('when deploying StakeableToken', () => {
  contract('StakeableToken', () => {
    let skt
    let launchTime
    let stakeAmount
    let stakeTime
    let unlockTime
    let stakeIndex
    let stakingRewards
    let satoshiRewards
    let viralRewards
    let critMassRewards
    let additionalRewards
    const staker = stakers[0]

    before('setup contracts', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should initialize with correct values', async () => {
      await testInitializeStakeableToken(skt, launchTime)
    })

    it('should stake', async () => {
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      unlockTime = stakeTime + 60 * 60 * 24 * 21

      await testStartStake(skt, stakeAmount, unlockTime, { from: staker })
      stakeIndex = 0
    })

    it('should have correct staking rewards at time of maturation', async () => {
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 22)
      stakingRewards = await testCalculateStakingRewards(
        skt,
        staker,
        stakeIndex
      )
    })

    it('should have correct satoshi rewards at time of maturation', async () => {
      satoshiRewards = await testCalculateSatoshiRewards(
        skt,
        stakeTime,
        unlockTime
      )
    })

    it('should have correct viral rewards at time of maturation', async () => {
      viralRewards = await testCalculateViralRewards(skt, stakeAmount)
    })

    it('should have correct crit mass rewards at time of maturation', async () => {
      critMassRewards = await testCalculateCritMassRewards(skt, stakeAmount)
    })

    it('should calculate correct additionalRewards', async () => {
      additionalRewards = await testCalculateAdditionalRewards(
        skt,
        staker,
        stakeIndex,
        satoshiRewards,
        viralRewards,
        critMassRewards
      )
    })

    it('should claim stake', async () => {
      await testClaimStake(
        skt,
        staker,
        stakeIndex,
        stakingRewards,
        additionalRewards
      )
    })
  })
})

describe('when handling multiple stakes', () => {
  contract('StakeableToken', () => {
    let skt, launchTime, stakeTime, unlockTime
    const stakeIndex = 0
    const activeStakers = stakers.filter(staker => staker != stakers[1])
    before('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should stake all account balances', async () => {
      stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      unlockTime = stakeTime + 60 * 60 * 24 * 21 // 3 weeks
      for (const staker of activeStakers) {
        const stakeAmount = await skt.balanceOf(staker)
        await testStartStake(skt, stakeAmount, unlockTime, {
          from: staker
        })
      }
    })

    it('should have correct staking rewards for all accounts', async () => {
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 21 + 60)
      for (const staker of activeStakers) {
        await testCalculateStakingRewards(skt, staker, stakeIndex)
      }
    })
  })
})
/*
  what do we want to do here???

  NEED TO:
    check on behavior for different weeks...

  NEED TO:
  handle multiple:
    redeems
    stakes
    claims
    RANDOMIZE ALL THE THINGS!
*/

describe('when staking outside of the bonus weeks', () => {
  contract('StakeableToken', () => {
    let skt
    let launchTime
    let stakeAmount
    let stakeTime
    let unlockTime
    let stakeIndex
    let stakingRewards
    const additionalRewards = bigZero
    const staker = stakers[0]

    before('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should stake after bonus period', async () => {
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 7 * 51)
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      unlockTime = stakeTime + 60 * 60 * 24 * 20

      await testStartStake(skt, stakeAmount, unlockTime, { from: staker })
      stakeIndex = 0
    })

    it('should have correct staking rewards after maturation during post bonus period', async () => {
      stakingRewards = await testCalculateStakingRewards(
        skt,
        staker,
        stakeIndex
      )
    })

    it('should NOT give any satoshi rewards during post bonus period', async () => {
      await testCalculateSatoshiRewards(skt, stakeTime, unlockTime)
    })

    it('should still show viral rewards during post bonus period', async () => {
      await testCalculateViralRewards(skt, stakeAmount)
    })

    it('should still show crit mass rewards after bonus period', async () => {
      await testCalculateCritMassRewards(skt, stakeAmount)
    })

    it('should return 0 for additional rewards', async () => {
      const expectedSatoshiRewards = bigZero
      // actual rewards given should be 0 even though view function returns non zero value
      const expectedViralRewards = bigZero
      // actual rewards given should be 0 even though view function returns non zero value
      const expectedCritMassRewards = bigZero
      await testCalculateAdditionalRewards(
        skt,
        staker,
        stakeIndex,
        expectedSatoshiRewards,
        expectedViralRewards,
        expectedCritMassRewards
      )
    })

    it('should claim staking rewards during post bonus period with NO additional rewards', async () => {
      await timeWarp(60 * 60 * 24 * 20)
      await testClaimStake(
        skt,
        staker,
        stakeIndex,
        stakingRewards,
        additionalRewards // this is set to 0 at top of test block
      )
    })
  })
})
