const { origin, getCurrentBlockTime, send } = require('./general')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')
const utxos = require('../data/transactions')
const BigNumber = require('bignumber.js')
const BitcoinHex = artifacts.require('BitcoinHex')

const defaultName = 'BitcoinHex'
const defaultSymbol = 'BHX'
const defaultDecimals = new BigNumber(18)
// 1 day from now as unix timestamp in local blockchain time
const getDefaultLaunchTime = async () => {
  // block time seems to get out of sync between describe blocks...
  await send('evm_increaseTime', [1])
  await send('evm_mine')
  const blockTime = await getCurrentBlockTime()
  return blockTime + 60 * 60 * 24
}
// multiply each by 1e10 and add 10 percent in order to get wei units redeemable
// 10 percent accounts for speed bonus when claiming
const defaultMaximumRedeemable = utxos.reduce(
  (total, tx) => total.add(new BigNumber(tx.satoshis).mul(1.1e10)),
  new BigNumber(0)
)
const defaultTotalBtcCirculationAtFork = defaultMaximumRedeemable.mul(1e18)

const setupContract = async () => {
  const bhx = await BitcoinHex.new(
    origin,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable,
    defaultTotalBtcCirculationAtFork
  )
  return bhx
}

const testInitialization = async bhx => {
  const name = await bhx.name()
  const symbol = await bhx.symbol()
  const decimals = await bhx.decimals()
  const ContractOrigin = await bhx.origin()
  const rootUtxoMerkleHash = await bhx.rootUtxoMerkleTreeHash()
  const maximumRedeemable = await bhx.maximumRedeemable()
  const totalBtcCirculationAtFork = await bhx.totalBtcCirculationAtFork()

  assert.equal(name, defaultName, 'name should match defaultName')
  assert.equal(symbol, defaultSymbol, 'symbol should match defaultSymbol')
  assert.equal(
    decimals.toString(),
    defaultDecimals.toString(),
    'decimals should match defaultDecimals'
  )
  assert.equal(ContractOrigin, origin, 'ContractOrigin should match origin')
  assert.equal(
    rootUtxoMerkleHash,
    defaultRootUtxoMerkleHash,
    'rootUtxoMerkleHash should match defaultRootUtxoMerkleHash'
  )
  assert.equal(
    maximumRedeemable.toString(),
    defaultMaximumRedeemable.toString(),
    'maximumRedeemable should match defaultMaximumRedeemable'
  )
  assert.equal(
    defaultTotalBtcCirculationAtFork.toString(),
    totalBtcCirculationAtFork.toString(),
    'totalBtcCirculationAtFork should match defaultTotalBtcCirculationAtFork'
  )
}

module.exports = {
  setupContract,
  testInitialization,
  defaultName,
  defaultSymbol,
  defaultDecimals,
  getDefaultLaunchTime,
  defaultMaximumRedeemable,
  defaultTotalBtcCirculationAtFork
}
