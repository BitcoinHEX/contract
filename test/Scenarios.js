const { setupStakeableToken } = require('./helpers/skt')
const {
  warpThroughBonusWeeks,
  timeWarpRelativeToLaunchTime
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')

const {
  accounts,
  oneInterestPeriod,
  getCurrentBlockTime,
  warpBufferTime
} = require('./helpers/general')
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
    let skt

    beforeEach('setup contract', async () => {
      const launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
    })

    it('should overflow after around 140 years due to compounding issues', async () => {
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

      while (!overflowed) {
        try {
          for (const staker of accounts) {
            const balance = await skt.balanceOf(staker)
            // eslint-disable-next-line no-console
            console.log(staker, 'balance', balance.toString())
            const stakeTime = await getCurrentBlockTime()
            const unlockTime = stakeTime + oneInterestPeriod * 365
            await skt.startStake(balance, unlockTime, {
              from: staker
            })
          }

          await warpThroughBonusWeeks(
            skt,
            elapsedTime + oneInterestPeriod * 365 + warpBufferTime
          )

          elapsedTime += oneInterestPeriod * 365 + warpBufferTime

          await Promise.all(
            accounts.map(staker => skt.claimAllStakingRewards(staker))
          )

          // eslint-disable-next-line no-console
          console.log(
            `elapsed time: ${elapsedTime / (60 * 60 * 24 * 365)} years`
          )
        } catch (err) {
          overflowed = true
        }

      }
    })
  })
})
