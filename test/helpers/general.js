const BigNumber = require('bignumber.js')

const accounts = web3.eth.accounts

const origin = accounts[0]
const redeemer = accounts[1]
const referrer = accounts[2]
const otherAccount = accounts[9]

const bigZero = new BigNumber(0)

const getCurrentBlockTime = async () => {
  const { timestamp } = await web3.eth.getBlock(web3.eth.blockNumber)
  return timestamp
}

const send = (method, params = []) =>
  web3.currentProvider.send({
    id: 0,
    jsonrpc: '2.0',
    method,
    params
  })

// increases time through evm command
const timeWarp = async seconds => {
  if (seconds > 0) {
    await send('evm_increaseTime', [seconds])
    await send('evm_mine')

    const previousBlock = await web3.eth.getBlock(web3.eth.blockNumber - 1)
    const currentBlock = await web3.eth.getBlock(web3.eth.blockNumber)
    /* eslint-disable no-console */
    console.log(`🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🛸  Warped ${seconds} seconds at new block`)
    console.log(`⏰  previous block timestamp: ${previousBlock.timestamp}`)
    console.log(`⏱  current block timestamp: ${currentBlock.timestamp}`)
    /* eslint-enable no-console */
  } else {
    // eslint-disable-next-line
    console.log('❌ Did not warp... 0 seconds was given as an argument')
  }
}

const expectRevert = async promise => {
  try {
    await promise
  } catch (error) {
    // TODO: Check jump destination to distinguish between a throw and an actual invalid jump.
    const invalidOpcode = error.message.search('invalid opcode') > -1

    // TODO: When we contract A calls contract B, and B throws, instead of an 'invalid jump', we get an 'out of gas'
    // error. How do we distinguish this from an actual out of gas event? The testrpc log actually show an "invalid
    // jump" event).
    const outOfGas = error.message.search('out of gas') > -1

    const revert = error.message.search('revert') > -1

    assert(
      invalidOpcode || outOfGas || revert,
      `Expected throw, got ${error} instead`
    )

    return
  }

  assert(false, "Expected throw wasn't received")
}

module.exports = {
  accounts,
  origin,
  redeemer,
  referrer,
  otherAccount,
  bigZero,
  expectRevert,
  timeWarp,
  getCurrentBlockTime
}
