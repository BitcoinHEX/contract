const BigNumber = require('bignumber.js')

const accounts = web3.eth.accounts

const origin = accounts[0]
const redeemer = accounts[1]
const referrer = accounts[2]
const stakers = accounts.slice(3, 8)
const otherAccount = accounts[9]

const bigZero = new BigNumber(0)
const addressZero = '0x' + '0'.repeat(40)
const incorrectBitcoinPrivateKey =
  '5KahFE6gzBkHPdZ9YCuLan3XiKyJnBX94Jqb2T5qfy91ZmubNFP'
const incorrectProof = [
  '0x' + 'a'.repeat('64'),
  '0x' + 'b'.repeat('64'),
  '0x' + 'c'.repeat('64')
]

const oneBlockWeek = 60 * 60 * 24 * 7
const oneInterestPeriod = 60 * 60 * 24 * 10 // 10 days

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

    // const previousBlock = await web3.eth.getBlock(web3.eth.blockNumber - 1)
    // const currentBlock = await web3.eth.getBlock(web3.eth.blockNumber)
    // /* eslint-disable no-console */
    // console.log(`🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🏳️‍🌈🛸  Warped ${seconds} seconds at new block`)
    // console.log(`⏰  previous block timestamp: ${previousBlock.timestamp}`)
    // console.log(`⏱  current block timestamp: ${currentBlock.timestamp}`)
    /* eslint-enable no-console */
  } else {
    // eslint-disable-next-line
    console.log('❌ Did not warp... less than 0 seconds was given as an argument')
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

    return true
  }

  assert(false, "Expected throw wasn't received")
}

// test to see if numbers are within range range = allowable difference
const areInRange = (bigNum1, bigNum2, range) =>
  (bigNum1.greaterThanOrEqualTo(bigNum2) &&
    bigNum1.sub(range).lessThanOrEqualTo(bigNum2)) ||
  (bigNum1.lessThanOrEqualTo(bigNum2) &&
    bigNum1.add(range).greaterThanOrEqualTo(bigNum2))

module.exports = {
  accounts,
  origin,
  redeemer,
  referrer,
  stakers,
  otherAccount,
  incorrectBitcoinPrivateKey,
  incorrectProof,
  bigZero,
  addressZero,
  oneBlockWeek,
  expectRevert,
  send,
  timeWarp,
  getCurrentBlockTime,
  areInRange,
  oneInterestPeriod
}
