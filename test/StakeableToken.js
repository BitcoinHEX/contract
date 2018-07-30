const {
  setupStakeableToken,
  testInitializeStakeableToken,
  testStartStake,
  testClaimStake,
  testCalculateStakingRewards,
  testCalculateSatoshiRewards,
  testCalculateViralRewards,
  testCalculateCritMassRewards,
  testCalculateAdditionalRewards
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
    let stakeAmount
    let stakeTime
    let unlockTime
    let stakeIndex
    let stakingRewards
    let satoshiRewards
    let viralRewards
    let critMassRewards
    let additionalRewards

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
      const staker = stakers[0]
      stakeAmount = await skt.balanceOf(staker)
      stakeTime = await getCurrentBlockTime()
      // set stake time to 20 days
      unlockTime = stakeTime + 60 * 60 * 24 * 21

      await testStartStake(skt, stakeAmount, unlockTime, { from: staker })
      stakeIndex = 0
    })

    it('should have correct staking rewards at time of maturation', async () => {
      await warpThroughBonusWeeks(skt, 60 * 60 * 24 * 22)
      stakingRewards = await testCalculateStakingRewards(
        skt,
        stakers[0],
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
        stakers[0],
        stakeIndex,
        satoshiRewards,
        viralRewards,
        critMassRewards
      )
    })

    it('should claim stake', async () => {
      await testClaimStake(
        skt,
        stakers[0],
        stakeIndex,
        stakingRewards,
        additionalRewards
      )
    })
  })
})
