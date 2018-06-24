const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const { ECPair, crypto } = require('bitcoinjs-lib')
const { ecsign, publicToAddress } = require('ethereumjs-util')
const BigNumber = require('bignumber.js')

const privPubKeys = require('../data/privPubKeys')
const { origin, bigZero, accounts } = require('./general')
const { defaultLaunchTime, defaultMaximumRedeemable } = require('./bhx')
const { bitcoinRootHash: defaultRootUtxoMerkleHash } = require('./mkl')

const setupContract = async () => {
  const urt = await UtxoRedeemableToken.new(
    origin,
    defaultLaunchTime,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable
  )

  return urt
}

const testInitialization = async urt => {
  const contractOrigin = await urt.origin()
  const launchTime = await urt.launchTime()
  const lastUpdatedWeek = await urt.lastUpdatedWeek()
  const rootUTXOMerkleTreeHash = await urt.rootUTXOMerkleTreeHash()
  const totalRedeemed = await urt.totalRedeemed()
  const maximumRedeemable = await urt.maximumRedeemable()

  assert.equal(contractOrigin, origin, 'contractOrigin should match origin')
  assert.equal(
    launchTime.toString(),
    defaultLaunchTime.toString(),
    'launchTime should match defaultLaunchTime'
  )
  assert.equal(
    lastUpdatedWeek.toString(),
    bigZero.toString(),
    'lastUpdatedWeek should start as 0'
  )
  assert.equal(
    rootUTXOMerkleTreeHash,
    defaultRootUtxoMerkleHash,
    'rootUTXOMerkleTreeHash should match defaultRootUtxoMerkleHash'
  )
  assert.equal(
    totalRedeemed.toString(),
    bigZero.toString(),
    'totalRedeemed should start as 0'
  )
  assert.equal(
    maximumRedeemable.toString(),
    defaultMaximumRedeemable.toString(),
    'maximumRedeemable should match defaultMaximumRedeemable'
  )
}

const testVerifySignature = async (
  urt,
  address,
  testedAddress,
  message,
  shouldBeValid
) => {
  assert(
    accounts.includes(address),
    'address used for signing must be included in testing accounts'
  )
  const messageHash = web3.sha3(message)
  const signature = web3.eth.sign(address, messageHash).replace('0x', '')
  const r = '0x' + signature.slice(0, 64)
  const s = '0x' + signature.slice(64, 128)
  // see: https://github.com/trufflesuite/ganache-cli/issues/243
  const v = new BigNumber('0x' + signature.slice(128, 130)).add(27).toNumber()

  const valid = await urt.validateSignature(
    messageHash,
    v,
    r,
    s,
    testedAddress,
    true
  )

  if (shouldBeValid) {
    assert(valid, 'signed message should validate')
  } else {
    assert(!valid, 'signed message should NOT validate')
  }
}

const testEcsdaVerify = async urt => {
  // set bitcoin stuff from private key
  const wif = privPubKeys[0].privateKey
  const ecPair = ECPair.fromWIF(wif)

  const ethAddress = accounts[1].slice(2)
  const ethHashBuf = crypto.sha256(Buffer.from(ethAddress, 'hex'))
  let { v, r, s } = ecsign(ethHashBuf, ecPair.d.toBuffer())
  v = parseInt(v, 10)
  r = '0x' + r.toString('hex')
  s = '0x' + s.toString('hex')
  const pubKey =
    '0x' +
    ecPair.Q.affineX.toBuffer(32).toString('hex') +
    ecPair.Q.affineY.toBuffer(32).toString('hex')

  const verified = await urt.ecdsaVerify('0x' + ethAddress, pubKey, v, r, s)
  assert(verified, 'ecsdaVerify should verify')
}

module.exports = {
  setupContract,
  testInitialization,
  testVerifySignature,
  testEcsdaVerify
}
