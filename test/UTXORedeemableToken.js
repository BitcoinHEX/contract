const {
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
  testRedeemReferredUtxo
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')
const {
  expectRevert,
  redeemer,
  referrer,
  otherAccount
} = require('./helpers/general')

const transactions = require('./data/transactions')

describe('when deploying UTXORedeemableToken', () => {
  contract('UTXORedeemableTokenStub', () => {
    let urt
    let launchTime

    before('setup contract stub', async () => {
      launchTime = await getDefaultLaunchTime()
      urt = await setupContract(launchTime)
    })

    describe('when initializing the contract', () => {
      it('should start with the correct values', async () => {
        await testInitialization(urt, launchTime)
      })
    })

    describe('when using included utility functions', () => {
      it('should validateSignature using ethereum private key', async () => {
        await testValidateSignature(urt, redeemer, redeemer, 'testing', true)
      })

      it('should NOT validateSignature using incorrectAddress', async () => {
        await testValidateSignature(
          urt,
          redeemer,
          otherAccount,
          'testing',
          false
        )
      })

      it('should verify bitcoin signature using ecdsaVerify', async () => {
        await testEcsdaVerify(urt, bitcoinPrivateKeys(0), redeemer)
      })

      it('should convert public key to ethereum address', async () => {
        await testPubKeyToEthereumAddress(urt, bitcoinPrivateKeys(0))
      })

      it('should convert public key to bitcoin address', async () => {
        await testPubKeyToBitcoinAddress(urt, bitcoinPrivateKeys(0))
      })

      it('should allow redeeming valid UTXO hash', async () => {
        const bitcoinTx = transactions[0]
        const { potentialMerkleLeaf, proof } = getProofAndComponents(bitcoinTx)
        await testCanRedeemUtxoHash(urt, potentialMerkleLeaf, proof)
      })

      it('should allow redeeming valid UTXO', async () => {
        const bitcoinTx = transactions[0]
        const { proof, formattedAddress, satoshis } = getProofAndComponents(
          bitcoinTx
        )
        await testCanRedeemUtxo(urt, proof, formattedAddress, satoshis)
      })
    })
  })
})

describe('when redeeming utxos', () => {
  contract('UtxoRedeemableToken', () => {
    let urt
    let launchTime

    beforeEach('setup contract', async () => {
      launchTime = await getDefaultLaunchTime()
      urt = await setupContract(launchTime)
    })

    it('should NOT redeem UTXO before launch time', async () => {
      // warp to 60 seconds BEFORE launch time
      await timeWarpRelativeToLaunchTime(urt, 60, false)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await expectRevert(
        testRedeemUtxo(urt, proof, satoshis, bitcoinPrivateKeys(0), {
          from: redeemer
        })
      )
    })

    it('should NOT redeem referred UTXO before launch time', async () => {
      // warp to 60 seconds BEFORE launch time
      await timeWarpRelativeToLaunchTime(urt, 60, false)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          proof,
          satoshis,
          bitcoinPrivateKeys(0),
          referrer,
          {
            from: redeemer
          }
        )
      )
    })

    it('should NOT redeem self-referred UTXO', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          proof,
          satoshis,
          bitcoinPrivateKeys(0),
          referrer,
          {
            from: referrer
          }
        )
      )
    })

    it('should redeem UTXO', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await testRedeemUtxo(urt, proof, satoshis, bitcoinPrivateKeys(0), {
        from: redeemer
      })
    })

    it('should redeem UTXO with referrer', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await testRedeemReferredUtxo(
        urt,
        proof,
        satoshis,
        bitcoinPrivateKeys(0),
        referrer,
        {
          from: redeemer
        }
      )
    })

    // it('should increment week correctly', async () => {
    //   assert(false)
    // })
  })
})
