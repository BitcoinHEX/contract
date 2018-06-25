const MerkleProof = artifacts.require('MerkleProofStub')

const { default: MerkleTree } = require('merkle-tree-solidity')
const { sha3 } = require('ethereumjs-util')

const merkleTree = require('../data/merkleTree')

const getFormattedHash = item => '0x' + item.toString('hex')

//
// data for simple merkle tree
//

const items = ['a', 'b', 'c', 'd', 'f', 'g']
const itemHashes = items.map(item => sha3(item))
const defaultMerkleTree = new MerkleTree(itemHashes, true)
const defaultRootHash = getFormattedHash(defaultMerkleTree.getRoot())
const defaultProof = defaultMerkleTree
  .getProofOrdered(itemHashes[0], 1)
  .map(getFormattedHash)
const defaultLeaf = getFormattedHash(itemHashes[0])

//
// invalid merkle items
//

const invalidItem = 'x'
const invalidFormattedHash = '0x' + sha3(invalidItem).toString('hex')
const invalidProof = [invalidFormattedHash]
const invalidRootHash = '0x' + sha3('banana').toString('hex')
const invalidLeaf = invalidFormattedHash

//
// bitcoin merkle tree items
//

const merkleLeafBufs = merkleTree.elements.map(item => Buffer.from(item, 'hex'))
const bitcoinMerkleTree = new MerkleTree(merkleLeafBufs)
const bitcoinRootHash = getFormattedHash(bitcoinMerkleTree.getRoot())
const bitcoinProof = bitcoinMerkleTree
  .getProofOrdered(merkleLeafBufs[0], 1)
  .map(getFormattedHash)
const bitcoinLeaf = getFormattedHash(merkleLeafBufs[0])

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
  defaultMerkleTree,
  testVerifyProof,
  defaultProof,
  defaultRootHash,
  defaultLeaf,
  invalidProof,
  invalidRootHash,
  invalidLeaf,
  bitcoinMerkleTree,
  bitcoinRootHash,
  bitcoinProof,
  bitcoinLeaf
}
