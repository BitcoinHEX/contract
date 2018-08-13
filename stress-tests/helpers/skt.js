const {
  getCurrentBlockTime,
  oneInterestPeriod,
  accounts,
  warpBufferTime,
  shuffleArray
} = require('../../test/helpers/general')
const { warpThroughBonusWeeks } = require('../../test/helpers/urt')
const chalk = require('chalk')
const BN = require('bignumber.js')
const BigNumber = require('bignumber.js')

const tryStakeClaimRound = async (skt, stakers, timeToStake) => {
  let stakeTime
  for (const staker of stakers) {
    const balance = await skt.balanceOf(staker)
    stakeTime = await getCurrentBlockTime()
    const unlockTime = stakeTime + oneInterestPeriod * 365

    // eslint-disable-next-line no-console
    console.log(chalk.magenta(`staking ${balance.toString()} for ${staker}`))

    await skt.startStake(balance, unlockTime, {
      from: staker
    })
  }

  await warpThroughBonusWeeks(skt, stakeTime + timeToStake)

  await Promise.all(stakers.map(staker => skt.claimAllStakingRewards(staker)))
}

const stressTestStakes = async (
  skt,
  totalCoins,
  timeToStake,
  randomizeStakes
) => {
  const amountToMintPerUser = totalCoins.div(accounts.length)

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
  let attempts = 0
  let stakingAccounts

  while (!overflowed) {
    try {
      if (randomizeStakes) {
        stakingAccounts = shuffleArray(accounts)
      } else {
        stakingAccounts = accounts
      }

      await tryStakeClaimRound(skt, stakingAccounts, timeToStake)

      elapsedTime += oneInterestPeriod * 365 + warpBufferTime

      // eslint-disable-next-line no-console
      console.log(
        chalk.yellow(
          `elapsed time: ${elapsedTime / (60 * 60 * 24 * 365)} years`
        )
      )
    } catch (err) {
      if (attempts > 4) {
        const totalSupply = await skt.totalSupply()
        const balances = await Promise.all(
          stakingAccounts.map(account => skt.balanceOf(account))
        )
        // need to use bn.js rather than bignumber.js in order to avoid hitting 15 sig dig limit
        const maxBalance = balances.reduce((prevValue, currValue) => {
          return new BN(prevValue.toString()).lt(new BN(currValue.toString()))
            ? currValue
            : prevValue
        }, new BN(0))

        /* eslint-disable no-console */
        console.log(
          chalk.cyan(
            `overflow point reached! Max account balance: ${maxBalance}`
          )
        )
        console.log(chalk.cyan(`totalSupply: ${totalSupply.toString()}`))
        console.log(
          chalk.cyan(`elapsed time: ${elapsedTime / (60 * 60 * 24 * 365)}`)
        )
        /* eslint-enable no-console */
        overflowed = true
      } else {
        attempts++
        // eslint-disable-next-line no-console
        console.log(
          chalk.red(
            `error occurred: ${err.message}. Trying attempt: ${attempts}...`
          )
        )
      }
    }
  }
}

module.exports = {
  tryStakeClaimRound,
  stressTestStakes
}
