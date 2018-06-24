const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const Message = require('bitcore-message')
const { PrivateKey, PublicKey } = require('bitcore-lib')
const ethUtil = require('ethereumjs-util')
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

  const valid = await urt.validateSignature(messageHash, v, r, s, testedAddress)

  if (shouldBeValid) {
    assert(valid, 'signed message should validate')
  } else {
    assert(!valid, 'signed message should NOT validate')
  }
}

const parseSignature = sig => ({
  v: ((sig[0] - 27) & 1) + 27,
  r: sig.slice(1, 65),
  s: sig.slice(66)
})

const testEcsdaVerify = async urt => {
  const wif = privPubKeys[0].privateKey
  console.log('wif', wif)
  const privKey = PrivateKey.fromWIF(wif)
  console.log('privKey', privKey)
  const pubKey = PublicKey(privKey)
  console.log('pubKey', pubKey)
  const pubKeyBuffer = Buffer.from(pubKey.toString('hex'), 'hex')
  console.log('pubKeyBuffer', pubKeyBuffer)
  const ethAddressBuffer = ethUtil.publicToAddress(pubKeyBuffer, true)
  const ethAddress = ethAddressBuffer.toString('hex')
  console.log('ethAddress', ethAddress)
  const signature64 = Message(ethAddress).sign(privKey)
  console.log(Buffer.from(signature64, 'base64'))
  console.log(Buffer.from(signature64, 'base64').length)
  const signatureHex = Buffer.from(signature64, 'base64').toString('hex')
  console.log('sig', signatureHex)
  const { v, r, s } = parseSignature(signatureHex)
  console.log('v, r, s', v, r, s)

  const ecsdaArgs = ['0x' + ethAddress, '0x' + pubKey, v, '0x' + r, '0x' + s]
  console.log('ecsdaArgs', ecsdaArgs)
  const verified = await urt.ecdsaVerify(...ecsdaArgs)
  console.log(verified)
  assert(verified, 'ecsdaVerify should verify')
}

module.exports = {
  setupContract,
  testInitialization,
  testVerifySignature,
  testEcsdaVerify
}
