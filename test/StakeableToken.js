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
  stakeStructToObj,
  reorgStakesAfterRemoval,
  testClaimAllStakes,
  testCompound
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
  oneInterestPeriod,
  oneBlockWeek,
  stakeBufferTime,
  warpBufferTime
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
      unlockTime = stakeTime + oneInterestPeriod
      await expectRevert(
        testStartStake(skt, stakeAmount, unlockTime, 0, {
          from: otherAccount
        })
      )
    })

    it('should NOT stake if user stakes for too little time', async () => {
      stakeTime = await getCurrentBlockTime()
      const invalidUnlockTime = stakeTime + oneInterestPeriod - 1
      await expectRevert(
        testStartStake(skt, stakeAmount, invalidUnlockTime, 0, {
          from: staker
        })
      )
    })

    it('should NOT stake if user stakes 1e10 or less', async () => {
      stakeTime = await getCurrentBlockTime()
      const invalidUnlockTime =
        stakeTime + oneInterestPeriod * 2 + stakeBufferTime
      await expectRevert(
        testStartStake(skt, 1e10, invalidUnlockTime, 0, {
          from: staker
        })
      )
    })

    it('should NOT stake if user stakes for too much time', async () => {
      stakeTime = await getCurrentBlockTime()
      const invalidUnlockTime =
        stakeTime + oneInterestPeriod * 365 + stakeBufferTime
      await expectRevert(
        testStartStake(skt, stakeAmount, invalidUnlockTime, 0, {
          from: staker
        })
      )
    })

    it('should stake', async () => {
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + oneInterestPeriod * 2 + stakeBufferTime

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
      await warpThroughBonusWeeks(skt, oneInterestPeriod * 2 + warpBufferTime)
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
      const unlockTime = stakeTime + oneInterestPeriod * 2 + stakeBufferTime
      for (const staker of activeStakers) {
        const stakeAmount = await skt.balanceOf(staker)

        stakingDataByUser[staker].stakeAmount = stakeAmount

        await testStartStake(skt, stakeAmount, unlockTime, stakeIndex, {
          from: staker
        })
      }
    })

    it('should have correct staking rewards for all accounts', async () => {
      await warpThroughBonusWeeks(skt, oneInterestPeriod * 2 + warpBufferTime)
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

describe('when handling multiple stakes', () => {
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
      let stakeTime, unlockTime

      // create 3 stakes for a single user
      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + oneInterestPeriod + stakeBufferTime
      await testStartStake(skt, stakeAmount, unlockTime, 0, {
        from: staker
      })
      userStakes.push({
        stakeIndex: 0,
        stakeAmount,
        stakeTime,
        unlockTime
      })

      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + oneInterestPeriod + stakeBufferTime
      await testStartStake(skt, stakeAmount, unlockTime, 1, {
        from: staker
      })
      userStakes.push({
        stakeIndex: 1,
        stakeAmount,
        stakeTime,
        unlockTime
      })

      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + oneInterestPeriod + stakeBufferTime
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
      await warpThroughBonusWeeks(skt, oneInterestPeriod * 3 + warpBufferTime)
      for (const stake of userStakes) {
        const { stakeIndex } = stake
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
      let stakingRewards, additionalRewards
      const stakeIndex = 0
      stakingRewards = userStakes[0].stakingRewards
      additionalRewards = userStakes[0].additionalRewards

      await testClaimStake(
        skt,
        staker,
        stakeIndex,
        stakingRewards,
        additionalRewards
      )
      reorgStakesAfterRemoval(userStakes, stakeIndex)

      stakingRewards = userStakes[0].stakingRewards
      additionalRewards = userStakes[0].additionalRewards

      await testClaimStake(
        skt,
        staker,
        stakeIndex,
        stakingRewards,
        additionalRewards
      )
      reorgStakesAfterRemoval(userStakes, stakeIndex)

      stakingRewards = userStakes[0].stakingRewards
      additionalRewards = userStakes[0].additionalRewards

      await testClaimStake(
        skt,
        staker,
        stakeIndex,
        stakingRewards,
        additionalRewards
      )
      reorgStakesAfterRemoval(userStakes, stakeIndex)
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
      await warpThroughBonusWeeks(skt, oneBlockWeek * 51 + warpBufferTime)
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      unlockTime = stakeTime + oneInterestPeriod * 2 + stakeBufferTime

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
      await timeWarp(oneInterestPeriod * 2 + warpBufferTime)
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

describe('when stress testing for overflows and gas limits', async () => {
  contract('StakeableToken', () => {
    let skt, stakeTime, unlockTime, launchTime
    const staker = stakers[0]

    beforeEach('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      await redeemAllUtxos(skt)
    })

    it('should successfully claim all user stakes when less than 43', async () => {
      await skt.mintTokens(staker, '50e18')
      const desiredStakes = 42
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        stakeTime = await getCurrentBlockTime()
        unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: staker
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)

      await testClaimAllStakes(skt, staker, desiredStakes)
    })

    it('should run out of gas when trying to claim 43 or more stakes', async () => {
      await skt.mintTokens(staker, '50e18')
      const desiredStakes = 43
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        stakeTime = await getCurrentBlockTime()
        unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: staker
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)
      await expectRevert(testClaimAllStakes(skt, staker))
    })

    it('should run into overflow issues when stakes are too high', async () => {
      let zeros = 18
      let limitReached = false
      while (!limitReached) {
        try {
          await testCompound(skt, new BigNumber(`1e${zeros}`), 365, 1)
          zeros++
        } catch (err) {
          assert(/checkMul must be less than overflowLimit/.test(err.message))
          // eslint-disable-next-line no-console
          console.log(
            `⚠️  approximate principle limit for compounding is 1e${zeros -
              1} ⚠️`
          )
          limitReached = true
        }
      }
    })
  })
})
