const BigNumber = require('bignumber.js')
const chalk = require('chalk')
const { warpThroughBonusWeeks } = require('../test/helpers/urt')
const { setupStakeableToken } = require('../stress-tests/skt')
const {
  oneBlockWeek,
  warpBufferTime,
  getCurrentBlockTime
} = require('../test/helpers/general')

/*
  default values:
    65 million utxos at fork block
    ~17.5 million Bitcoin at fork block
    20% redeem (high)
    10% redeem (mid)
    5% redeem (low)
*/
describe('when forecasting values based on different results', async () => {
  contract('StakeableToken', accounts => {
    const origin = accounts[0]
    const stakers = accounts.slice(1)
    // setup staker config for later use to know how much each user should stake
    const stakerConfig = {}
    // take each int and multiply by seconds in a month
    const stakingDurations = [3, 6, 9, 12, 24, 36, 120].map(option =>
      option.mul(60 * 60 * 24 * 30)
    )
    // give each staker a random staking amount from options
    stakers.map(staker => {
      stakerConfig[staker] =
        stakingDurations[Math.floor(Math.random() * stakingDurations.length)]
    })

    /*
    what do we want to do here?
    randomized stakes over 3 years for starters

    start with reclaiming... 
    need to reclaim full amount for each
    */
    it('should do stuff', async () => {
      const circulationAtFork = new BigNumber('17.5e6').mul(10).div(100)
      const maxRedeemable = new BigNumber('17.5e6').mul(20).div(100)
      const actualRedeemed = maxRedeemable.mul(20).div(100)
      const redeemAmountPerUser = actualRedeemed.div(stakers.length).floor()
      const bonusPeriodDuration = oneBlockWeek * 50

      // setup contract with desired values
      const skt = await setupStakeableToken(circulationAtFork, maxRedeemable)
      const startTime = await getCurrentBlockTime()

      const stakersPerPeriod = Math.floor(stakers.length / 49)
      const remainingStakers = stakers.length % 49

      // stake all remaining stakers at start
      for (let i = 0; i < remainingStakers; i++) {
        await skt.shortcutRedeem(redeemAmountPerUser, {
          from: stakers[i]
        })

        const stakeAmount = redeemAmountPerUser.mul(75).div(100)
        await skt.startStake(stakeAmount, startTime + bonusPeriodDuration, {
          from: stakers[i]
        })
        console.log(
          chalk.yellow(`redeemed and started stake for ${stakers[i]}`)
        )
      }

      // stake all non-remaining stakers at different times until bonus period end
      let stakerAccountsIndex = remainingStakers
      for (let i = 0; i < 49; i++) {
        for (let j = 0; j < stakersPerPeriod; j++) {
          await skt.shortcutRedeem(redeemAmountPerUser, {
            from: stakers[stakerAccountsIndex]
          })

          const stakeAmount = redeemAmountPerUser.mul(75).div(100)
          await skt.startStake(
            stakeAmount,
            startTime + bonusPeriodDuration - i * oneBlockWeek,
            {
              from: stakers[stakerAccountsIndex]
            }
          )
          console.log(
            chalk.yellow(
              `redeemed and started stake for: ${stakers[stakerAccountsIndex]}`
            )
          )
          await warpThroughBonusWeeks(skt, bonusPeriodDuration - warpBufferTime)
          stakerAccountsIndex++
        }
      }

      for (const staker of stakers) {
        await skt.claimAllStakingRewards(staker, {
          from: staker
        })
        console.log(chalk.yellow(`claimed staking rewards for: ${staker}`))
      }

      const originBalance = await skt.balanceOf(origin)
      const originStakeAmount = originBalance.mul(76).div(100)
      await skt.startStake(originStakeAmount)
      console.log(chalk.blue('started stake for'))

      for (const staker of stakers) {
        const balance = await skt.balanceOf(staker)
        const stakeAmount = balance.mul(75).div(100)

        await skt.startStake(stakeAmount, stakerConfig[staker], {
          from: staker
        })
        console.log(chalk.yellow('started post bonus stake'))
      }
    })
  })
})
