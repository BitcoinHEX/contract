const UtxoRedeemableToken = artifacts.require('UTXORedeemableTokenStub')

const { ECPair, crypto } = require('bitcoinjs-lib')
const { ecsign, publicToAddress } = require('ethereumjs-util')
const { soliditySha3 } = require('web3-utils')
const { decode: decode58 } = require('bs58')
const BigNumber = require('bignumber.js')
const privateKeys = require('../data/privateKeys')
const dataMerkleTree = require('../data/merkleTree.json')
const transactions = require('../data/transactions')

const {
  origin,
  bigZero,
  accounts,
  stakers,
  timeWarp,
  getCurrentBlockTime,
  oneBlockWeek
} = require('./general')

const { defaultMaximumRedeemable } = require('./bhx')
const {
  bitcoinRootHash: defaultRootUtxoMerkleHash,
  bitcoinMerkleTree: defaultMerkleTree
} = require('./mkl')

const satoshiStructToObj = struct => ({
  unclaimedCoins: struct[0],
  totalStaked: struct[1]
})

const redeemAllUtxos = async contract => {
  let index = 0
  for (const bitcoinTx of transactions) {
    // problem with data given at the moment it seems when using account[1]... skip for now
    // TODO: make sure correct data is used for testing!!!
    if (index !== 1) {
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await testRedeemUtxo(
        contract,
        proof,
        satoshis,
        bitcoinPrivateKeys(index),
        {
          from: stakers[index]
        }
      )
    }

    index++
  }
}

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
  const weekInSeconds = new BigNumber(60 * 60 * 24 * 7)
  const launchTime = await urt.launchTime()
  const endOfBonus = launchTime.add(weekInSeconds.mul(50))
  const currentBlockTime = await getCurrentBlockTime()
  let bonusWeeksToWarp
  if (launchTime.add(seconds).gt(endOfBonus)) {
    if (endOfBonus.gt(currentBlockTime)) {
      bonusWeeksToWarp = endOfBonus
        .sub(currentBlockTime)
        .div(weekInSeconds)
        .floor(0)
    } else {
      bonusWeeksToWarp = 0
    }
  } else {
    bonusWeeksToWarp = new BigNumber(seconds).div(weekInSeconds).floor(0)
  }

  /* eslint-disable no-console */
  await urt.storeSatoshiWeekData()

  for (let i = 1; i <= bonusWeeksToWarp; i++) {
    await timeWarpRelativeToLaunchTime(urt, weekInSeconds * i, true)
    await urt.storeSatoshiWeekData()
    console.log(
      `warped to week ${i} of ${bonusWeeksToWarp} and stored week unclaimed`
    )
  }

  await timeWarpRelativeToLaunchTime(urt, seconds, true)
  await urt.storeSatoshiWeekData()
  console.log(
    `warped remaining ${seconds -
      bonusWeeksToWarp * weekInSeconds} seconds and stored week unclaimed`
  )
  /* eslint-enable no-console */
}

const timeWarpRelativeToLaunchTime = async (urt, seconds, moveAhead) => {
  const launchTime = await urt.launchTime()
  const { timestamp: now } = await web3.eth.getBlock(web3.eth.blockNumber)
  let targetSeconds

  if (moveAhead) {
    // eslint-disable-next-line no-console
    console.log(`warping to ${seconds} seconds ahead of launchTime...`)
    targetSeconds = launchTime
      .sub(now)
      .add(seconds)
      .toNumber()
  } else {
    // eslint-disable-next-line no-console
    console.log(`warping to ${seconds} seconds before launchTime...`)
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
  const preOriginBalance = await urt.balanceOf(origin)
  const preRedeemedCount = await urt.redeemedCount()

  await urt.redeemUtxo(satoshis, proof, pubKey, true, v, r, s, config)

  const postRedeemerBalance = await urt.balanceOf(config.from)
  const postOriginBalance = await urt.balanceOf(origin)
  const [redeemAmount, speedBonus] = await urt.getRedeemAmount(satoshis)
  const expectedRedeemAmount = redeemAmount.add(speedBonus)
  const postRedeemedCount = await urt.redeemedCount()
  assert.equal(
    postRedeemerBalance.sub(preRedeemerBalance).toString(),
    expectedRedeemAmount.toString(),
    'redeemer token balance should be incremented by expectedRedeemAmount'
  )
  assert.equal(
    postOriginBalance.sub(preOriginBalance).toString(),
    speedBonus.toString(),
    'origin balance should be incremented by speedBonus'
  )
  assert.equal(
    preRedeemedCount.add(1).toString(),
    postRedeemedCount.toString(),
    'redeemCount should be incremented by 1'
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
  const preOriginBalance = await urt.balanceOf(origin)
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
  const postOriginBalance = await urt.balanceOf(origin)
  const postReferrerBalance = await urt.balanceOf(referrer)
  const [redeemAmount, speedBonus] = await urt.getRedeemAmount(satoshis)
  const expectedRedeemAmount = redeemAmount.add(speedBonus)
  const expectedReferralAmount = expectedRedeemAmount.div(20).floor(0)

  assert.equal(
    postRedeemerBalance.sub(preRedeemerBalance).toString(),
    expectedRedeemAmount.toString(),
    'redeemer token balance should be incremented by expectedRedeemAmount'
  )
  assert.equal(
    postOriginBalance.sub(preOriginBalance).toString(),
    speedBonus.toString(),
    'origin balance should be incremented by speedBonus'
  )
  assert.equal(
    postReferrerBalance.sub(preReferrerBalance).toString(),
    expectedReferralAmount.toString(),
    'referrer token balance should be incremented by expectedReferralAmount'
  )
}

const testWeekIncrement = async (urt, expectedWeek, shouldIncrement) => {
  const preLastUpdatedWeek = await urt.lastUpdatedWeek()
  const preSatoshiStruct = await urt.satoshiRewardDataByWeek(expectedWeek)
  const { unclaimedCoins: preUnclaimedCoins } = satoshiStructToObj(
    preSatoshiStruct
  )

  await urt.storeSatoshiWeekData()

  const postLastUpdatedWeek = await urt.lastUpdatedWeek()
  const postSatoshiStruct = await urt.satoshiRewardDataByWeek(expectedWeek)
  const { unclaimedCoins: postUnclaimedCoins } = satoshiStructToObj(
    postSatoshiStruct
  )

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
  await urt.storeSatoshiWeekData()
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

  const reduction = new BigNumber(100).sub(weeksSinceLaunch.mul(2))
  bigAmount = bigAmount
    .mul(reduction)
    .div(100)
    .floor(0)

  let speedBonus
  switch (true) {
    case weeksSinceLaunch.greaterThan(45):
      speedBonus = bigZero
      break
    case weeksSinceLaunch.greaterThan(32):
      speedBonus = bigAmount
        .mul(101)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(24):
      speedBonus = bigAmount
        .mul(102)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(18):
      speedBonus = bigAmount
        .mul(103)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(14):
      speedBonus = bigAmount
        .mul(104)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(10):
      speedBonus = bigAmount
        .mul(105)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(7):
      speedBonus = bigAmount
        .mul(106)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(5):
      speedBonus = bigAmount
        .mul(107)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(3):
      speedBonus = bigAmount
        .mul(108)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    case weeksSinceLaunch.greaterThan(1):
      speedBonus = bigAmount
        .mul(109)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
    default:
      speedBonus = bigAmount
        .mul(110)
        .div(100)
        .floor(0)
        .sub(bigAmount)
      break
  }

  return bigAmount.add(speedBonus)
}

const testGetRedeemAmount = async (urt, amount) => {
  const [redeemAmount, speedBonus] = await urt.getRedeemAmount(amount)
  const expectedAmount = await calculateExpectedRedeemAmount(urt, amount)

  assert.equal(
    redeemAmount.add(speedBonus).toString(),
    expectedAmount.toString(),
    'redeemAmount should match expectedAmount'
  )
}

const getModelingVariables = async urt => {
  return {
    totalRedeemed: (await urt.totalRedeemed()).toString(),
    totalStakedCoins: (await urt.totalStakedCoins()).toString(),
    redeemedCount: (await urt.redeemedCount()).toString()
  }
}

module.exports = {
  satoshiStructToObj,
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
  warpThroughBonusWeeks,
  redeemAllUtxos,
  getModelingVariables
}
