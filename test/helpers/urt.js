const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const BigNumber = require('bignumber.js')
const { PrivateKey, PublicKey, Address, Networks } = require('bitcore-lib')

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

const getBitcoinPublicKey = (privatKey, address) => {
  const privateKey = PrivateKey(privPubKeys[0].privateKey, Networks.mainnet)
  console.log(privateKey)
  const pubKey = PublicKey(privateKey)
  console.log(pubKey)
  const derivedAddress = Address.fromPublicKey(pubKey)
  console.log(derivedAddress, Networks.mainnet)

  if (address) {
    assert.equal(
      derivedAddress,
      privPubKeys[0].address,
      'address should match given private key'
    )
  }
}

const testEcsdaVerify = async urt => {
  const pubKey = getBitcoinPublicKey(
    privPubKeys[0].privateKey,
    privPubKeys[0].address
  )
}

module.exports = {
  setupContract,
  testInitialization,
  testVerifySignature,
  testEcsdaVerify
}
