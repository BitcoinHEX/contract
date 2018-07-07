const {
  setupStakeableToken,
  testInitializeStakeableToken
} = require('./helpers/skt')
const { getDefaultLaunchTime } = require('./helpers/bhx')

describe.only('when deploying StakeableToken', () => {
  contract('StakeableToken', () => {
    let skt
    let launchTime

    before('setup contracts', async () => {
      launchTime = await getDefaultLaunchTime()
      skt = await setupStakeableToken(launchTime)
    })

    it('should initialize with correct values', async () => {
      await testInitializeStakeableToken(skt, launchTime)
    })
  })
})
