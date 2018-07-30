const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const { ECPair, crypto } = require('bitcoinjs-lib')
const { ecsign, publicToAddress } = require('ethereumjs-util')
const { soliditySha3 } = require('web3-utils')
const { decode: decode58 } = require('bs58')
const BigNumber = require('bignumber.js')

const privateKeys = require('../data/privateKeys')
const dataMerkleTree = require('../data/merkleTree.json')
const {
  origin,
  bigZero,
  accounts,
  timeWarp,
  getCurrentBlockTime,
  oneBlockWeek
} = require('./general')
const { defaultMaximumRedeemable } = require('./bhx')
const {
  bitcoinRootHash: defaultRootUtxoMerkleHash,
  bitcoinMerkleTree: defaultMerkleTree
} = require('./mkl')

const setupContract = async launchTime => {
  const urt = await UtxoRedeemableToken.new(
    origin,
    launchTime,
    defaultRootUtxoMerkleHash,
    defaultMaximumRedeemable
  )

  return urt
}

const bitcoinPrivateKeys = privateKeyIndex =>
  privateKeys[privateKeyIndex].privateKey

const getProofAndComponents = bitcoinTx => {
  const { address: originalAddress, satoshis } = bitcoinTx
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
    .getProof(merkleLeafBufs[hashMerkleLeafIndex])
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

const retrieveBitcoinAddress = wif => ECPair.fromWIF(wif).getAddress()

// sign and format resulting signature components
const signEthAddress = (wif, ethAddress) => {
  const ecPair = ECPair.fromWIF(wif)
  let { v, r, s } = ecsign(
    crypto.sha256(Buffer.from(ethAddress.replace('0x', ''), 'hex')),
    ecPair.d.toBuffer()
  )

  v = parseInt(v, 10)
  r = '0x' + r.toString('hex')
  s = '0x' + s.toString('hex')

  return { v, r, s }
}

// remove 1st byte mainnet designation & 4 byte checksum at end & convert to hex
const stripHexifyBase58Address = address =>
  '0x' +
  decode58(address)
    .slice(1, 21)
    .toString('hex')

const getFormattedLeaf = leafBuffer => '0x' + leafBuffer.toString('hex')

const warpThroughBonusWeeks = async (urt, seconds) => {
  /* eslint-disable no-console */
  const weekInSeconds = 60 * 60 * 24 * 7
  const weeksToWarp = Math.floor(seconds / weekInSeconds)
  await urt.storeWeekUnclaimed()

  for (let i = 1; i <= weeksToWarp; i++) {
    await timeWarpRelativeToLaunchTime(urt, weekInSeconds * i, true)
    await urt.storeWeekUnclaimed()
    console.log(
      `warped to week ${i} of ${weeksToWarp} and stored week unclaimd`
    )
  }

  await timeWarpRelativeToLaunchTime(urt, seconds, true)
  await urt.storeWeekUnclaimed()
  console.log('warped remaining seconds and stored week unclaimed')
  /* eslint-enable no-console */
}

const timeWarpRelativeToLaunchTime = async (urt, seconds, moveAhead) => {
  const launchTime = await urt.launchTime()
  const { timestamp: now } = await web3.eth.getBlock(web3.eth.blockNumber)
  let targetSeconds

  if (moveAhead) {
    // eslint-disable-next-line no-console
    console.log(`warping to ${seconds} seconds ahead of bet launchTime...`)
    targetSeconds = launchTime
      .sub(now)
      .add(seconds)
      .toNumber()
  } else {
    // eslint-disable-next-line no-console
    console.log(`warping to ${seconds} seconds before bet launchTime...`)
    targetSeconds = launchTime
      .sub(now)
      .sub(seconds)
      .toNumber()
  }

  await timeWarp(targetSeconds)
}

const testInitialization = async (urt, expectedLaunchTime) => {
  const contractOrigin = await urt.origin()
  const launchTime = await urt.launchTime()
  const lastUpdatedWeek = await urt.lastUpdatedWeek()
  const rootUtxoMerkleTreeHash = await urt.rootUtxoMerkleTreeHash()
  const totalRedeemed = await urt.totalRedeemed()
  const maximumRedeemable = await urt.maximumRedeemable()

  assert.equal(contractOrigin, origin, 'contractOrigin should match origin')
  assert.equal(
    launchTime.toString(),
    expectedLaunchTime.toString(),
    'launchTime should match expectedLaunchTime'
  )
  assert.equal(
    lastUpdatedWeek.toString(),
    bigZero.toString(),
    'lastUpdatedWeek should start as 0'
  )
  assert.equal(
    rootUtxoMerkleTreeHash,
    defaultRootUtxoMerkleHash,
    'rootUtxoMerkleTreeHash should match defaultRootUtxoMerkleHash'
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

const testEcsdaVerify = async (urt, bitcoinPrivateKey, ethAddress) => {
  const { v, r, s } = signEthAddress(bitcoinPrivateKey, ethAddress)
  const pubKey = retrievePubKey(bitcoinPrivateKey)

  const verified = await urt.ecdsaVerify(ethAddress, pubKey, v, r, s)

  assert(verified, 'ecsdaVerify should verify properly formatted signature')
}

const testPubKeyToEthereumAddress = async (urt, bitcoinPrivateKey) => {
  const pubKey = retrievePubKey(bitcoinPrivateKey)
  const actualAddress = '0x' + publicToAddress(pubKey).toString('hex')

  const address = await urt.pubKeyToEthereumAddress(pubKey)

  assert.equal(
    address,
    actualAddress,
    'pubKeyToEthereumAddress should match actualAddress'
  )
}

const testPubKeyToBitcoinAddress = async (urt, bitcoinPrivateKey) => {
  const rawHexAddress = stripHexifyBase58Address(
    retrieveBitcoinAddress(bitcoinPrivateKey)
  )

  const pubKey = retrievePubKey(bitcoinPrivateKey)
  const resultAddress = await urt.pubKeyToBitcoinAddress(pubKey, true)

  assert.equal(
    resultAddress,
    rawHexAddress,
    'resultAddress should match rawHexAddress'
  )
}

const testCanRedeemUtxoHash = async (urt, potentialMerkleLeaf, proof) => {
  const canRedeem = await urt.canRedeemUtxoHash(potentialMerkleLeaf, proof)

  assert(
    canRedeem,
    'should be able to redeem with merkleLeaf and correct proof'
  )
}

const testCanRedeemUtxo = async (urt, proof, formattedAddress, satoshis) => {
  const canRedeem = await urt.canRedeemUtxo(formattedAddress, satoshis, proof)

  assert(
    canRedeem,
    'should be able to redeem using correct merkleLeaf components'
  )
}

const testRedeemUtxo = async (
  urt,
  proof,
  satoshis,
  bitcoinPrivateKey,
  config
) => {
  const pubKey = retrievePubKey(bitcoinPrivateKey)
  const { v, r, s } = signEthAddress(bitcoinPrivateKey, config.from)
  const preRedeemerBalance = await urt.balanceOf(config.from)

  await urt.redeemUtxo(satoshis, proof, pubKey, true, v, r, s, config)

  const postRedeemerBalance = await urt.balanceOf(config.from)
  const expectedRedeemAmount = await urt.getRedeemAmount(satoshis)

  assert.equal(
    postRedeemerBalance.sub(preRedeemerBalance).toString(),
    expectedRedeemAmount.toString(),
    'redeemer token balance should be incremented by expectedRedeemAmount'
  )
}

const testRedeemReferredUtxo = async (
  urt,
  proof,
  satoshis,
  bitcoinPrivateKey,
  referrer,
  config
) => {
  const pubKey = retrievePubKey(bitcoinPrivateKey)
  const { v, r, s } = signEthAddress(bitcoinPrivateKey, config.from)
  const preRedeemerBalance = await urt.balanceOf(config.from)
  const preReferrerBalance = await urt.balanceOf(referrer)
  await urt.redeemReferredUtxo(
    satoshis,
    proof,
    pubKey,
    true,
    v,
    r,
    s,
    referrer,
    config
  )
  const postRedeemerBalance = await urt.balanceOf(config.from)
  const postReferrerBalance = await urt.balanceOf(referrer)
  const expectedRedeemAmount = await urt.getRedeemAmount(satoshis)
  const expectedReferralAmount = expectedRedeemAmount.div(20).floor(0)

  assert.equal(
    postRedeemerBalance.sub(preRedeemerBalance).toString(),
    expectedRedeemAmount.toString(),
    'redeemer token balance should be incremented by expectedRedeemAmount'
  )
  assert.equal(
    postReferrerBalance.sub(preReferrerBalance).toString(),
    expectedReferralAmount.toString(),
    'referrer token balance should be incremented by expectedReferralAmount'
  )
}

const testWeekIncrement = async (urt, expectedWeek, shouldIncrement) => {
  const preLastUpdatedWeek = await urt.lastUpdatedWeek()
  const preUnclaimedCoins = await urt.unclaimedCoinsByWeek(expectedWeek)

  await urt.storeWeekUnclaimed()

  const postLastUpdatedWeek = await urt.lastUpdatedWeek()
  const postUnclaimedCoins = await urt.unclaimedCoinsByWeek(expectedWeek)

  const maximumRedeemable = await urt.maximumRedeemable()
  const totalRedeemed = await urt.totalRedeemed()
  const expectedUnclaimedCoins = maximumRedeemable.sub(totalRedeemed)

  if (shouldIncrement) {
    assert(
      preLastUpdatedWeek.lessThan(postLastUpdatedWeek),
      'postLastWeekUpdated should be greater than preLastWeekUpdated'
    )
    assert.equal(
      postLastUpdatedWeek.toString(),
      new BigNumber(expectedWeek).toString(),
      'postLastUpdatedWeek should match expectedWeek'
    )
    assert(
      preUnclaimedCoins.equals(0),
      'preUnclaimedCoins should be 0 before incremeneting a week'
    )
    assert.equal(
      postUnclaimedCoins.toString(),
      expectedUnclaimedCoins.toString(),
      'postUnclaimedCoins should match expectedUnclaimedCoins'
    )
  } else {
    if (expectedWeek <= 50) {
      assert.equal(
        new BigNumber(expectedWeek).toString(),
        postLastUpdatedWeek.toString(),
        'postLastUpdatedWeek should match expectedWeek'
      )
    }

    assert.equal(
      preLastUpdatedWeek.toString(),
      postLastUpdatedWeek.toString(),
      'pre and post lastUpdatedWeek should match'
    )
    assert.equal(
      postUnclaimedCoins.toString(),
      preUnclaimedCoins.toString(),
      'postUnclaimedCoins should match expectedUnclaimedCoins'
    )
  }
}

const calculateExpectedRedeemAmount = async (urt, amount) => {
  // convert to wei units
  let bigAmount = new BigNumber(amount).mul(1e10)
  await urt.storeWeekUnclaimed()
  const blockTime = await getCurrentBlockTime()
  const launchTime = await urt.launchTime()
  const timeDiff = new BigNumber(blockTime).sub(launchTime)
  const weeksSinceLaunch = timeDiff.greaterThan(0)
    ? timeDiff.div(oneBlockWeek).floor(0)
    : bigZero

  if (bigAmount.greaterThan('1e21')) {
    bigAmount = bigAmount.lessThan('1e23')
      ? bigAmount
          .sub('1e11')
          .mul(2)
          .div(9)
          .floor(0)
          .add('5e10')
      : bigAmount.div(4).floor(0)
  }

  // TODO: talk with other dev on if this is really intended....
  // reduction plus bonus? seems redundant
  const reduction = new BigNumber(100).sub(weeksSinceLaunch.mul(2))
  bigAmount = bigAmount
    .mul(reduction)
    .div(100)
    .floor(0)

  switch (true) {
    case weeksSinceLaunch.greaterThan(45):
      return bigAmount
    case weeksSinceLaunch.greaterThan(32):
      return bigAmount.mul(1.01)
    case weeksSinceLaunch.greaterThan(24):
      return bigAmount.mul(1.02)
    case weeksSinceLaunch.greaterThan(18):
      return bigAmount.mul(1.03)
    case weeksSinceLaunch.greaterThan(14):
      return bigAmount.mul(1.04)
    case weeksSinceLaunch.greaterThan(10):
      return bigAmount.mul(1.05)
    case weeksSinceLaunch.greaterThan(7):
      return bigAmount.mul(1.06)
    case weeksSinceLaunch.greaterThan(5):
      return bigAmount.mul(1.07)
    case weeksSinceLaunch.greaterThan(3):
      return bigAmount.mul(1.08)
    case weeksSinceLaunch.greaterThan(1):
      return bigAmount.mul(1.09)
    default:
      return bigAmount.mul(1.1)
  }
}

const testGetRedeemAmount = async (urt, amount) => {
  const redeemAmount = await urt.getRedeemAmount(amount)
  const expectedAmount = await calculateExpectedRedeemAmount(urt, amount)

  assert.equal(
    redeemAmount.toString(),
    expectedAmount.toString(),
    'redeemAmount should match expectedAmount'
  )
}

module.exports = {
  setupContract,
  bitcoinPrivateKeys,
  getProofAndComponents,
  timeWarpRelativeToLaunchTime,
  testInitialization,
  testValidateSignature,
  testEcsdaVerify,
  testPubKeyToEthereumAddress,
  testPubKeyToBitcoinAddress,
  testCanRedeemUtxoHash,
  testCanRedeemUtxo,
  testRedeemUtxo,
  testRedeemReferredUtxo,
  testWeekIncrement,
  testGetRedeemAmount,
  warpThroughBonusWeeks
}
