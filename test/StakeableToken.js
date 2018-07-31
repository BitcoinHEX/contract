const {
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake,
  testCalculateStakingRewards,
  testCalculateSatoshiRewards,
  testCalculateViralRewards,
  testCalculateCritMassRewards,
  testCalculateAdditionalRewards,
  stakeStructToObj
} = require('./helpers/skt')
const {
  timeWarpRelativeToLaunchTime,
  warpThroughBonusWeeks,
  redeemAllUtxos
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')
const {
  stakers,
  otherAccount,
  getCurrentBlockTime,
  timeWarp,
  bigZero,
  expectRevert,
  oneInterestPeriod
} = require('./helpers/general')
const BigNumber = require('bignumber.js')

describe('when using core StakeableToken functionality', () => {
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

    it('should NOT stake if user has no tokens', async () => {
      stakeAmount = 1e18
      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + 60 * 60 * 24 * 7
      await expectRevert(
        testStartStake(skt, stakeAmount, unlockTime, 0, {
          from: otherAccount
        })
      )
    })

    it('should NOT stake if user stakes for too little time', async () => {
      stakeTime = await getCurrentBlockTime()
      const invalidUnlockTime = stakeTime + 60 * 60 * 24 * 9 // 9 days
      await expectRevert(
        testStartStake(skt, stakeAmount, invalidUnlockTime, 0, {
          from: staker
        })
      )
    })

    it('should NOT stake if user stakes for too much time', async () => {
      stakeTime = await getCurrentBlockTime()
      const invalidUnlockTime = stakeTime + 60 * 60 * 24 * 3651 // 10 years and 1 day
      await expectRevert(
        testStartStake(skt, stakeAmount, invalidUnlockTime, 0, {
          from: staker
        })
      )
    })

    it('should stake', async () => {
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      unlockTime = stakeTime + 60 * 60 * 24 * 21

      await testStartStake(skt, stakeAmount, unlockTime, 0, { from: staker })
      stakeIndex = 0
    })

    it('should NOT claim a stake if before maturation date', async () => {
      const stakingRewardsStub = new BigNumber(0)
      const additionalRewardsStub = new BigNumber(0)
      await expectRevert(
        testClaimStake(
          skt,
          staker,
          stakeIndex,
          stakingRewardsStub,
          additionalRewardsStub
        )
      )
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

    it('should NOT claim a stake for a user who has NO stake', async () => {
      const stakingRewardsStub = new BigNumber(0)
      const additionalRewardsStub = new BigNumber(0)
      await expectRevert(
        testClaimStake(
          skt,
          otherAccount,
          stakeIndex,
          stakingRewardsStub,
          additionalRewardsStub
        )
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

describe('when handling multiple users', () => {
  contract('StakeableToken', () => {
    let skt, launchTime
    const stakeIndex = 0
    const activeStakers = stakers.filter(staker => staker != stakers[1])
    const stakingDataByUser = {}
    activeStakers.map(staker => (stakingDataByUser[staker] = {}))
    before('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should stake all account balances', async () => {
      const stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      const unlockTime = stakeTime + 60 * 60 * 24 * 21 // 3 weeks
      for (const staker of activeStakers) {
        const stakeAmount = await skt.balanceOf(staker)

        stakingDataByUser[staker].stakeAmount = stakeAmount

        await testStartStake(skt, stakeAmount, unlockTime, stakeIndex, {
          from: staker
        })
      }
    })

    it('should have correct staking rewards for all accounts', async () => {
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 21 + 60)
      for (const staker of activeStakers) {
        const stakingRewards = await testCalculateStakingRewards(
          skt,
          staker,
          stakeIndex
        )
        stakingDataByUser[staker].stakingRewards = stakingRewards
      }
    })

    it('should have correct satoshi rewards for all stakers', async () => {
      for (const staker of activeStakers) {
        const stakeStruct = await skt.staked(staker, stakeIndex)
        const { stakeTime, unlockTime } = stakeStructToObj(stakeStruct)
        const satoshiRewards = await testCalculateSatoshiRewards(
          skt,
          stakeTime,
          unlockTime
        )
        stakingDataByUser[staker].satoshiRewards = satoshiRewards
      }
    })

    it('should have correct viral rewards for all stakers', async () => {
      for (const staker of activeStakers) {
        const stakeStruct = await skt.staked(staker, stakeIndex)
        const { stakeAmount } = stakeStructToObj(stakeStruct)
        const viralRewards = await testCalculateViralRewards(skt, stakeAmount)
        stakingDataByUser[staker].viralRewards = viralRewards
      }
    })

    it('should have correct crit mass rewards for all stakers', async () => {
      for (const staker of activeStakers) {
        const stakeStruct = await skt.staked(staker, stakeIndex)
        const { stakeAmount } = stakeStructToObj(stakeStruct)
        const critMassRewards = await testCalculateCritMassRewards(
          skt,
          stakeAmount
        )
        stakingDataByUser[staker].critMassRewards = critMassRewards
      }
    })

    it('should have correct additional rewards for all users', async () => {
      for (const staker of activeStakers) {
        const {
          satoshiRewards,
          viralRewards,
          critMassRewards
        } = stakingDataByUser[staker]
        const additionalRewards = await testCalculateAdditionalRewards(
          skt,
          staker,
          stakeIndex,
          satoshiRewards,
          viralRewards,
          critMassRewards
        )

        stakingDataByUser[staker].additionalRewards = additionalRewards
      }
    })

    it('should claim matured stakes for all users', async () => {
      for (const staker of activeStakers) {
        const { stakingRewards, additionalRewards } = stakingDataByUser[staker]
        await testClaimStake(
          skt,
          staker,
          stakeIndex,
          stakingRewards,
          additionalRewards
        )
      }
    })
  })
})

describe.only('when handling multiple stakes', () => {
  contract('StakeableToken', () => {
    let skt
    const staker = stakers[0]
    const userStakes = []

    before('setup contract', async () => {
      const launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should make several stakes', async () => {
      let stakeAmount = await skt.balanceOf(staker)
      stakeAmount = stakeAmount.div(3).floor(0)
      const stakeTime = await getCurrentBlockTime()
      let unlockTime

      // create 3 stakes for a single user
      unlockTime = stakeTime + oneInterestPeriod
      await testStartStake(skt, stakeAmount, unlockTime, 0, {
        from: staker
      })
      userStakes.push({
        stakeIndex: 0,
        stakeAmount,
        stakeTime,
        unlockTime
      })

      unlockTime = stakeTime + oneInterestPeriod * 2
      await testStartStake(skt, stakeAmount, unlockTime, 1, {
        from: staker
      })
      userStakes.push({
        stakeIndex: 1,
        stakeAmount,
        stakeTime,
        unlockTime
      })

      unlockTime = stakeTime + oneInterestPeriod * 3
      await testStartStake(skt, stakeAmount, unlockTime, 2, {
        from: staker
      })
      userStakes.push({
        stakeIndex: 2,
        stakeAmount,
        stakeTime,
        unlockTime
      })
    })

    it('should have correct staking rewards for each stake', async () => {
      for (const stake of userStakes) {
        const { stakeIndex } = stake
        await warpThroughBonusWeeks(skt, oneInterestPeriod * stakeIndex)
        const stakingRewards = await testCalculateStakingRewards(
          skt,
          staker,
          stakeIndex
        )

        userStakes[stakeIndex].stakingRewards = stakingRewards
      }
    })

    it('should have correct satoshi rewards for each stake', async () => {
      for (const stake of userStakes) {
        const { stakeTime, unlockTime, stakeIndex } = stake
        const satoshiRewards = await testCalculateSatoshiRewards(
          skt,
          stakeTime,
          unlockTime
        )

        userStakes[stakeIndex].satoshiRewards = satoshiRewards
      }
    })

    it('should have correct viral rewards for each stake', async () => {
      for (const stake of userStakes) {
        const { stakeAmount, stakeIndex } = stake
        const viralRewards = await testCalculateViralRewards(skt, stakeAmount)

        userStakes[stakeIndex].viralRewards = viralRewards
      }
    })

    it('should have correct crit mass rewards for each stake', async () => {
      for (const stake of userStakes) {
        const { stakeAmount, stakeIndex } = stake
        const critMassRewards = await testCalculateCritMassRewards(
          skt,
          stakeAmount
        )

        userStakes[stakeIndex].critMassRewards = critMassRewards
      }
    })

    it('should have correct additional rewards for each stake', async () => {
      for (const stake of userStakes) {
        const {
          stakeIndex,
          satoshiRewards,
          viralRewards,
          critMassRewards
        } = stake
        const additionalRewards = await testCalculateAdditionalRewards(
          skt,
          staker,
          stakeIndex,
          satoshiRewards,
          viralRewards,
          critMassRewards
        )

        userStakes[stakeIndex].additionalRewards = additionalRewards
      }
    })

    it('should claim each stake', async () => {
      for (const stake of userStakes) {
        const { stakeIndex, stakingRewards, additionalRewards } = stake
        await testClaimStake(
          skt,
          staker,
          stakeIndex,
          stakingRewards,
          additionalRewards
        )
      }
    })
  })
})

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

      await testStartStake(skt, stakeAmount, unlockTime, stakeIndex, {
        from: staker
      })
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

/*
  what do we want to do here???

  NEED TO:
    check on behavior for different weeks...
    fuzzy test different values
    test multiple stakes
      test incredibly high stakes until running out of gas
        getting rewards
        claiming stakes
    test compound interest until overflows...
      take steps to prevent this

*/
