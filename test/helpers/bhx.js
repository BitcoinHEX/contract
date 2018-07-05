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
const defaultMaximumRedeemable = utxos.reduce(
  (total, tx) => total.add(new BigNumber(tx.satoshis).mul(1.1e10)),
  new BigNumber(0)
)
const defaultTotalBTCCirculationAtFork = defaultMaximumRedeemable

const setupContract = async () => {
  const bhx = await BitcoinHex.new(
    origin,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable,
    defaultTotalBTCCirculationAtFork
  )
  return bhx
}

const testInitialization = async bhx => {
  const name = await bhx.name()
  const symbol = await bhx.symbol()
  const decimals = await bhx.decimals()
  const ContractOrigin = await bhx.origin()
  const rootUtxoMerkleHash = await bhx.rootUTXOMerkleTreeHash()
  const maximumRedeemable = await bhx.maximumRedeemable()
  const totalBTCCirculationAtFork = await bhx.totalBTCCirculationAtFork()

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
    defaultTotalBTCCirculationAtFork.toString(),
    totalBTCCirculationAtFork.toString(),
    'totalBTCCirculationAtFork should match defaultTotalBTCCirculationAtFork'
  )
}

module.exports = {
  setupContract,
  testInitialization,
  defaultName,
  defaultSymbol,
  defaultDecimals,
  getDefaultLaunchTime,
  defaultMaximumRedeemable
}
