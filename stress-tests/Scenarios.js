const {
  setupStakeableToken,
  testClaimAllStakes,
  testCompound
} = require('../test/helpers/skt')
const {
  warpThroughBonusWeeks,
  timeWarpRelativeToLaunchTime
} = require('../test/helpers/urt')
const { getDefaultLaunchTime } = require('../test/helpers/bhx')

const {
  accounts,
  stakers,
  oneInterestPeriod,
  getCurrentBlockTime,
  warpBufferTime,
  expectRevert,
  shuffleArray
} = require('../test/helpers/general')
const { tryStakeClaimRound } = require('./helpers/skt')
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
    let skt, stakeTime, unlockTime, launchTime

    beforeEach('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
    })

    it('should successfully claim all user stakes when less than 43', async () => {
      await skt.mintTokens(stakers[0], '50e18')
      const desiredStakes = 42
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        stakeTime = await getCurrentBlockTime()
        unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: stakers[0]
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)

      await testClaimAllStakes(skt, stakers[0], desiredStakes)
    })

    it('should run out of gas when trying to claim 43 or more stakes', async () => {
      await skt.mintTokens(stakers[0], '50e18')
      const desiredStakes = 43
      const stakeAmount = new BigNumber(1e18)

      for (let i = 0; i < desiredStakes; i++) {
        stakeTime = await getCurrentBlockTime()
        unlockTime = stakeTime + oneInterestPeriod * 365
        await skt.startStake(stakeAmount, unlockTime, {
          from: stakers[0]
        })
      }

      await warpThroughBonusWeeks(skt, oneInterestPeriod * 365 + warpBufferTime)
      await expectRevert(testClaimAllStakes(skt, stakers[0]))
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

    it.only('should overflow after x years due to compounding overflow when interest focused on one user', async () => {
      const maxCoins = new BigNumber('17.5e24') // 17.5 mil with 18 decimals
      const estimatedRedeemed = maxCoins.div(5) // 20% estimate
      const amountToMintPerUser = estimatedRedeemed.div(accounts.length)

      await Promise.all(
        accounts.map(staker => skt.mintTokens(staker, amountToMintPerUser))
      )

      const maxRedeemed = new BigNumber('100e18').mul(accounts.length)
      const totalRedeemed = maxRedeemed
      const redeemedCount = accounts.length

      await skt.setMaxRedeemable(maxRedeemed)
      await skt.setRedeemedCount(redeemedCount)
      await skt.setTotalRedeemed(totalRedeemed)

      let overflowed = false
      let elapsedTime = 0
      const attempts = 0
      const timeToStake = oneInterestPeriod * 365 + warpBufferTime

      while (!overflowed) {
        try {
          await tryStakeClaimRound(skt, accounts, timeToStake)

          elapsedTime += oneInterestPeriod * 365 + warpBufferTime

          // eslint-disable-next-line no-console
          console.log(
            `elapsed time: ${elapsedTime / (60 * 60 * 24 * 365)} years`
          )
        } catch (err) {
          if (attempts > 4) {
            // eslint-disable-next-line no-console
            console.log(err)
            overflowed = true
          } else {
            // ganache-cli times out sometimes... just retry to get through it
            await tryStakeClaimRound(skt, accounts, timeToStake)
          }
        }
      }
    })

    it.only(
      'should overflow after around x years due to totalSupply overflow when funds focused randomly',
      async () => {
        const maxCoins = new BigNumber('17.5e24') // 17.5 mil with 18 decimals
        const estimatedRedeemed = maxCoins.div(5) // 20% estimate
        const amountToMintPerUser = estimatedRedeemed.div(accounts.length)

        await Promise.all(
          accounts.map(staker => skt.mintTokens(staker, amountToMintPerUser))
        )

        const maxRedeemed = new BigNumber('100e18').mul(accounts.length)
        const totalRedeemed = maxRedeemed
        const redeemedCount = accounts.length

        await skt.setMaxRedeemable(maxRedeemed)
        await skt.setRedeemedCount(redeemedCount)
        await skt.setTotalRedeemed(totalRedeemed)

        let overflowed = false
        let elapsedTime = 0
        let shuffledStakers = accounts
        const attempts = 0
        const timeToStake = oneInterestPeriod * 365 + warpBufferTime

        while (!overflowed) {
          try {
            shuffledStakers = shuffleArray(shuffledStakers)

            await tryStakeClaimRound(skt, shuffledStakers, timeToStake)

            elapsedTime += oneInterestPeriod * 365 + warpBufferTime

            // eslint-disable-next-line no-console
            console.log(
              `elapsed time: ${elapsedTime / (60 * 60 * 24 * 365)} years`
            )
          } catch (err) {
            if (attempts > 4) {
              // eslint-disable-next-line no-console
              console.log(err)
              overflowed = true
            } else {
              // ganache-cli times out sometimes... just retry to get through it
              await tryStakeClaimRound(skt, shuffledStakers, timeToStake)
            }
          }
        }
      }
    ).timeout(60 * 60 * 1000) // set timeout to an hour to see how far this gets...
  })
})
