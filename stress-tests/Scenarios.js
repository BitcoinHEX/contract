const { testClaimAllStakes, testCompound } = require('../test/helpers/skt')
const { warpThroughBonusWeeks } = require('../test/helpers/urt')
const {
  stakers,
  oneInterestPeriod,
  getCurrentBlockTime,
  warpBufferTime,
  expectRevert
} = require('../test/helpers/general')
const { stressTestStakes, setupStakeableToken } = require('./helpers/skt')
const BigNumber = require('bignumber.js')

/*
  default values:
    65 million utxos at fork block
    ~17.5 million Bitcoin at fork block
    20% redeem (high)
    10% redeem (mid)
    5% redeem (low)
*/

describe('when running different scenarios', () => {
  contract('StakeableToken', () => {
    const defaultCirculationAtFork = new BigNumber('17.5e6').mul(10).div(100)
    const defaultMaximumRedeemable = new BigNumber('17.5e6').mul(20).div(100)

    it('should successfully claim all user stakes when less than 35', async () => {
      const mintPerUser = new BigNumber('50e18')
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )
      await skt.mintTokens(stakers[0], mintPerUser)
      const desiredStakes = 34
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        const stakeTime = await getCurrentBlockTime()
        const unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: stakers[0]
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)
      await testClaimAllStakes(skt, stakers[0], desiredStakes)
    })

    it('should run out of gas when trying to claim 35 or more stakes', async () => {
      const mintPerUser = new BigNumber('50e18')
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )
      await skt.mintTokens(stakers[0], mintPerUser)
      const desiredStakes = 35
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        const stakeTime = await getCurrentBlockTime()
        const unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: stakers[0]
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)
      await expectRevert(testClaimAllStakes(skt, stakers[0]))
    })

    it('should run into overflow issues when stakes are too high', async () => {
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )

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
describe('when running different long term scenarios', () => {
  contract('StakeableToken', () => {
    const defaultCirculationAtFork = new BigNumber('17.5e24').mul(10).div(100)
    const defaultMaximumRedeemable = new BigNumber('17.5e24').mul(20).div(100)

    it('should overflow after 150 years due to compounding overflow when interest focused on one user in max interest period increments', async () => {
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )

      // max interest time
      const timeToStake = oneInterestPeriod * 365

      await stressTestStakes(skt, defaultMaximumRedeemable, timeToStake, false)
    }).timeout(60 * 60 * 1000) // set timeout to an hour... this test will take a looong time

    it('should overflow after 150 years due to compounding overflow when interest focused on one user in ~1 year increments', async () => {
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )

      // little less than 1 year
      const timeToStake = oneInterestPeriod * 36

      await stressTestStakes(skt, defaultMaximumRedeemable, timeToStake, false)
    }).timeout(60 * 60 * 2000) // set timeout to an hour... this test will take a looong time

    it('should overflow after around 200+ years due to totalSupply overflow when funds focused randomly in max interest period increments', async () => {
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )

      // max interest time
      const timeToStake = oneInterestPeriod * 365

      await stressTestStakes(skt, defaultMaximumRedeemable, timeToStake, true)
    }).timeout(60 * 60 * 1000) // set timeout to an hour... this test will take a looong time

    it('should overflow after around 200+ years due to totalSupply overflow when funds focused randomly in ~1 year increments', async () => {
      const skt = await setupStakeableToken(
        defaultCirculationAtFork,
        defaultMaximumRedeemable
      )

      // little less than 1 year
      const timeToStake = oneInterestPeriod * 36

      await stressTestStakes(skt, defaultMaximumRedeemable, timeToStake, true)
    }).timeout(60 * 60 * 2000) // set timeout to an hour... this test will take a looong time
  })
})
