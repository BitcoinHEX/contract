const {
  getCurrentBlockTime,
  oneInterestPeriod
} = require('../../test/helpers/general')
const { warpThroughBonusWeeks } = require('../../test/helpers/urt')

const tryStakeClaimRound = async (skt, stakers, timeToStake) => {
  let stakeTime
  for (const staker of stakers) {
    const balance = await skt.balanceOf(staker)
    stakeTime = await getCurrentBlockTime()
    const unlockTime = stakeTime + oneInterestPeriod * 365

    // eslint-disable-next-line no-console
    console.log(`staking ${balance.toString()} for ${staker}`)

    await skt.startStake(balance, unlockTime, {
      from: staker
    })
  }

  await warpThroughBonusWeeks(skt, stakeTime + timeToStake)

  await Promise.all(stakers.map(staker => skt.claimAllStakingRewards(staker)))
}

module.exports = {
  tryStakeClaimRound
}
