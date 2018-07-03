const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const { ECPair, crypto } = require('bitcoinjs-lib')
const { ecsign, publicToAddress } = require('ethereumjs-util')
const { soliditySha3 } = require('web3-utils')
const { decode: decode58 } = require('bs58')
const BigNumber = require('bignumber.js')

const privateKeys = require('../data/privateKeys')
const transactions = require('../data/transactions')
const dataMerkleTree = require('../data/merkleTree.json')
const { origin, bigZero, accounts } = require('./general')
const { defaultLaunchTime, defaultMaximumRedeemable } = require('./bhx')
const {
  bitcoinRootHash: defaultRootUtxoMerkleHash,
  bitcoinMerkleTree: defaultMerkleTree
} = require('./mkl')

const setupContract = async () => {
  const urt = await UtxoRedeemableToken.new(
    origin,
    defaultLaunchTime,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable
  )

  return urt
}

const getProofAndComonents = txIndex => {
  const { address: originalAddress, satoshis } = transactions[txIndex]
  const formattedAddress = stripHexifyBase58Address(originalAddress)

  const potentialMerkleLeaf = soliditySha3(
    {
      t: 'bytes20',
      v: formattedAddress
    },
    {
      t: 'uint256',
      v: satoshis
    }
  )
  const merkleLeafBufs = defaultMerkleTree.elements.map(item =>
    Buffer.from(item, 'hex')
  )
  const hashMerkleLeafIndex = defaultMerkleTree.elements
    .map(element => element.toString('hex'))
    .indexOf(potentialMerkleLeaf.replace('0x', ''))
  const proof = defaultMerkleTree
    .getProofOrdered(
      merkleLeafBufs[hashMerkleLeafIndex],
      hashMerkleLeafIndex + 1
    )
    .map(getFormattedLeaf)

  assert(
    dataMerkleTree.elements.includes(
      potentialMerkleLeaf.replace('0x', ''),
      'resulting potentialMerkleLeaf should be included in dataMerkleTree elements'
    )
  )

  return {
    potentialMerkleLeaf,
    proof,
    formattedAddress,
    satoshis
  }
}

// get pub key by concatenating x and y coordinates
const retrievePubKey = wif => {
  const ecPair = ECPair.fromWIF(wif)

  return (
    '0x' +
    ecPair.Q.affineX.toBuffer(32).toString('hex') +
    ecPair.Q.affineY.toBuffer(32).toString('hex')
  )
}

// remove 1st byte mainnet designation & 4 byte checksum at end & convert to hex
const stripHexifyBase58Address = address =>
  '0x' +
  decode58(address)
    .slice(1, 21)
    .toString('hex')

const getFormattedLeaf = leafBuffer => '0x' + leafBuffer.toString('hex')

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

const testValidateSignature = async (
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

const testEcsdaVerify = async (urt, ethAddress, privKeyIndex) => {
  const { privateKey: wif } = privateKeys[privKeyIndex]
  const ecPair = ECPair.fromWIF(wif)
  ethAddress = ethAddress.replace('0x', '')
  const ethHashBuf = crypto.sha256(Buffer.from(ethAddress, 'hex'))

  // sign and format resulting signature components
  let { v, r, s } = ecsign(ethHashBuf, ecPair.d.toBuffer())
  v = parseInt(v, 10)
  r = '0x' + r.toString('hex')
  s = '0x' + s.toString('hex')

  const pubKey = retrievePubKey(wif)
  const verified = await urt.ecdsaVerify('0x' + ethAddress, pubKey, v, r, s)

  assert(verified, 'ecsdaVerify should verify properly formatted signature')
}

const testPubKeyToEthereumAddress = async (urt, privKeyIndex) => {
  const { privateKey: wif } = privateKeys[privKeyIndex]
  const actualAddress = '0x' + publicToAddress(pubKey).toString('hex')

  const pubKey = retrievePubKey(wif)
  const address = await urt.pubKeyToEthereumAddress(pubKey)

  assert.equal(
    address,
    actualAddress,
    'pubKeyToEthereumAddress should match actualAddress'
  )
}

const testPubKeyToBitcoinAddress = async (urt, privKeyIndex) => {
  const { privateKey: wif, address: actualAddress } = privateKeys[privKeyIndex]
  const rawHexAddress = stripHexifyBase58Address(actualAddress)

  const pubKey = retrievePubKey(wif)
  const resultAddress = await urt.pubKeyToBitcoinAddress(pubKey, true)

  assert.equal(
    resultAddress,
    rawHexAddress,
    'resultAddress should match rawHexAddress'
  )
}

const testCanRedeemUtxoHash = async (urt, txIndex) => {
  const { potentialMerkleLeaf, proof } = getProofAndComonents(txIndex)

  const canRedeem = await urt.canRedeemUtxoHash(potentialMerkleLeaf, proof)

  assert(
    canRedeem,
    'should be able to redeem with merkleLeaf and correct proof'
  )
}

const testCanRedeemUtxo = async (urt, txIndex) => {
  const { proof, formattedAddress, satoshis } = getProofAndComonents(txIndex)

  const canRedeem = await urt.canRedeemUtxo(formattedAddress, satoshis, proof)

  assert(
    canRedeem,
    'should be able to redeem using correct merkleLeaf components'
  )
}

const testRedeemUtxo = async (urt, txIndex) => {
  const { proof, satoshis } = getProofAndComonents(txIndex)
}

module.exports = {
  setupContract,
  testInitialization,
  testValidateSignature,
  testEcsdaVerify,
  testPubKeyToEthereumAddress,
  testPubKeyToBitcoinAddress,
  testCanRedeemUtxoHash,
  testCanRedeemUtxo,
  testRedeemUtxo
}
