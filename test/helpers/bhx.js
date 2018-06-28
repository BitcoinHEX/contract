const { origin } = require('./general')
const merkleTree = require('../data/merkleTree')
const utxos = require('../data/utxos')
const BigNumber = require('bignumber.js')
const BitcoinHex = artifacts.require('BitcoinHex')

const defaultName = 'BitcoinHex'
const defaultSymbol = 'BHX'
const defaultDecimals = new BigNumber(18)
const defaultRootUtxoMerkleHash = '0x' + merkleTree.elements[0]
const defaultMaximumRedeemable = utxos.reduce(
  (total, tx) => total.add(tx.satoshis),
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
  testInitialization
}
