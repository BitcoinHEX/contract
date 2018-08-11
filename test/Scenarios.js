const { setupStakeableToken } = require('./helpers/skt')
const { stakers } = require('./helpers/general')
const BigNumber = require('bignumber.js')

describe.only('when running different scenarios', () => {
  contract('StakeableToken', () => {
    let skt,
      launchTime,
      stakeAmount,
      stakeTime,
      unlockTime,
      stakeIndex,
      stakingRewards,
      satoshiRewards,
      viralRewards,
      critMassRewards,
      additionalRewards,
      maxRedeemed,
      redeemedCount

    beforeEach('setup contract', async () => {
      skt = await setupStakeableToken()
      stakers.forEach(async staker => await skt.mint(staker, '100e18'))
      maxRedeemed = new BigNumber('100e18').mul(stakers.length)
      redeemedCount = maxRedeemed
      await skt.setMaxRedeemable(maxRedeemed)
      await skt.setRedeemedCount(redeemedCount)
    })
  })
})
