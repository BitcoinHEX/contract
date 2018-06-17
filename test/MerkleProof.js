const {
  setupContract,
  testVerifyProof,
  defaultProof,
  defaultRootHash,
  defaultLeaf,
  invalidProof,
  invalidRootHash,
  invalidLeaf
} = require('./helpers/mkl')

describe('when verifying a merkle proof', () => {
  contract('MerkleProof', async () => {
    let mkl

    before('setup contract', async () => {
      mkl = await setupContract()
    })

    it('should verify correct proof', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        defaultRootHash,
        defaultLeaf,
        true
      )
    })

    it('should NOT verify incorrect proof', async () => {
      await testVerifyProof(
        mkl,
        invalidProof,
        defaultRootHash,
        defaultLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        invalidRootHash,
        defaultLeaf,
        false
      )
    })

    it('should NOT verify incorrect rootHash', async () => {
      await testVerifyProof(
        mkl,
        defaultProof,
        defaultRootHash,
        invalidLeaf,
        false
      )
    })
  })
})
