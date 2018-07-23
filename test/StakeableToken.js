const {
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake
} = require('./helpers/skt')
const {
  timeWarpRelativeToLaunchTime,
  warpThroughBonusWeeks,
  getProofAndComponents,
  bitcoinPrivateKeys,
  testRedeemUtxo
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')
const { stakers, getCurrentBlockTime } = require('./helpers/general')

const transactions = require('./data/transactions')

describe.only('when deploying StakeableToken', () => {
  contract('StakeableToken', () => {
    let skt
    let launchTime

    before('setup contracts', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
      await timeWarpRelativeToLaunchTime(skt, 60, true)
      let index = 0
      for (const bitcoinTx of transactions) {
        // problem with data given at the moment it seems when using account[1]... skip for now
        // TODO: make sure correct data is used for testing!!!
        if (index !== 1) {
          const { proof, satoshis } = getProofAndComponents(bitcoinTx)

          await testRedeemUtxo(
            skt,
            proof,
            satoshis,
            bitcoinPrivateKeys(index),
            {
              from: stakers[index]
            }
          )
        }

        index++
      }
    })

    it('should initialize with correct values', async () => {
      await testInitializeStakeableToken(skt, launchTime)
    })

    it('should stake', async () => {
      const staker = stakers[2]
      const stakeAmount = await skt.balanceOf(staker)
      const currentTime = await getCurrentBlockTime()
      // set stake time to 20 days
      const stakeTime = currentTime + 60 * 60 * 24 * 21

      await testStartStake(skt, stakeAmount, stakeTime, { from: staker })
    })

    it('should claim stake', async () => {
      const staker = stakers[2]
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 22)
      await testClaimStake(skt, staker)
    })
  })
})
