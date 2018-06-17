const {
  setupContract,
  testVerifyProof,
  defaultProof,
  defaultRootHash,
  defaultLeaf,
  invalidProof,
  invalidRootHash,
  invalidLeaf,
  bitcoinProof,
  bitcoinRootHash,
  bitcoinLeaf
} = require('./helpers/mkl')

describe('when verifying a merkle proof', () => {
  contract('MerkleProof', async () => {
    let mkl

    before('setup contract', async () => {
      mkl = await setupContract()
    })

    it('should verify correct proof using simple merkle tree', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        defaultRootHash,
        defaultLeaf,
        true
      )
    })

    it('should NOT verify incorrect proof using simple merkle tree', async () => {
      await testVerifyProof(
        mkl,
        invalidProof,
        defaultRootHash,
        defaultLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash using simple merkle tree', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        invalidRootHash,
        defaultLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash using simple merkle tree', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        defaultRootHash,
        invalidLeaf,
        false
      )
    })

    it('should verify correct proof using bitcoin merkle tree', async () => {
      await testVerifyProof(
        mkl,
        bitcoinProof,
        bitcoinRootHash,
        bitcoinLeaf,
        true
      )
    })

    it('should NOT verify incorrect proof using bitcoin merkle tree', async () => {
      await testVerifyProof(
        mkl,
        invalidProof,
        bitcoinRootHash,
        bitcoinLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash using bitcoin merkle tree', async () => {
      await testVerifyProof(
        mkl,
        bitcoinProof,
        invalidRootHash,
        bitcoinLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash using bitcoin merkle tree', async () => {
      await testVerifyProof(
        mkl,
        bitcoinProof,
        bitcoinRootHash,
        invalidLeaf,
        false
      )
    })
  })
})
