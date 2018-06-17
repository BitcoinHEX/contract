const MerkleProof = artifacts.require('MerkleProofStub')

const { sha3 } = require('ethereumjs-util')

const merkleTree = require('../data/merkleTree')
const utxos = require('../data/utxos')

const itemA = 'a'
const itemB = 'b'
const formattedHashA = '0x' + sha3(itemA).toString('hex')
const formattedHashB = '0x' + sha3(itemB).toString('hex')

const defaultProof = [formattedHashB]
const defaultRootHash =
  '0x' + sha3(Buffer.concat([sha3(itemA), sha3(itemB)])).toString('hex')
const defaultLeaf = formattedHashA

const invalidItem = 'x'
const invalidFormattedHash = '0x' + sha3(invalidItem).toString('hex')
const invalidProof = [invalidFormattedHash]
const invalidRootHash = '0x' + sha3('banana').toString('hex')
const invalidLeaf = invalidFormattedHash

const setupContract = async () => {
  const mkl = await MerkleProof.new()
  return mkl
}

const testVerifyProof = async (mkl, proof, rootHash, leaf, shouldVerify) => {
  const valid = await mkl.testVerifyProof(proof, rootHash, leaf)

  if (shouldVerify) {
      assert(
        valid,
        'MerkleProof should verify when given correct root, proof, and leaf'
      )
  } else {
      assert(
        !valid,
        'MerkleProof should NOT verify when given incrorrect root, proof, or leaf'
      )
  }
}

module.exports = {
  setupContract,
  testVerifyProof,
  defaultProof,
  defaultRootHash,
  defaultLeaf,
  invalidProof,
  invalidRootHash,
  invalidLeaf
}
