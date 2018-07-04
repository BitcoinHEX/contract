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
  testRedeemReferredUtxo,
  testWeekIncrement
} = require('./helpers/urt')
const { getDefaultLaunchTime } = require('./helpers/bhx')
const {
  expectRevert,
  redeemer,
  referrer,
  otherAccount,
  oneBlockWeek,
  addressZero,
  incorrectBitcoinPrivateKey,
  incorrectProof
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

    it('should start with the correct values', async () => {
      await testInitialization(urt, launchTime)
    })
  })
})

describe('when using included utility functions', () => {
  contract('UTXORedeemableTokenStub', () => {
    let urt
    let launchTime

    before('setup contract stub', async () => {
      launchTime = await getDefaultLaunchTime()
      urt = await setupContract(launchTime)
    })
    it('should validateSignature using ethereum private key', async () => {
      await testValidateSignature(urt, redeemer, redeemer, 'testing', true)
    })

    it('should NOT validateSignature using incorrectAddress', async () => {
      await testValidateSignature(urt, redeemer, otherAccount, 'testing', false)
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

    it('should NOT redeem when referrer is address(0)', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          proof,
          satoshis,
          bitcoinPrivateKeys(0),
          addressZero,
          {
            from: referrer
          }
        )
      )
    })

    it('should NOT redeem UTXO with address(0) as referrer', async () => {
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

    it('should NOT redeem same UTXO twice', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)
      await testRedeemUtxo(urt, proof, satoshis, bitcoinPrivateKeys(0), {
        from: redeemer
      })

      await expectRevert(
        testRedeemUtxo(urt, proof, satoshis, bitcoinPrivateKeys(0), {
          from: redeemer
        })
      )
    })

    it('should NOT redeem referred UTXO twice', async () => {
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

    it('should NOT redeem with incorrect satoshis', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemUtxo(urt, proof, satoshis + 1, bitcoinPrivateKeys(0), {
          from: redeemer
        })
      )
    })

    it('should NOT redeem referred with incorrect satoshis', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          proof,
          satoshis + 1,
          bitcoinPrivateKeys(0),
          referrer,
          {
            from: redeemer
          }
        )
      )
    })

    it('should NOT redeem with incorrect pubKey', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemUtxo(urt, proof, satoshis, incorrectBitcoinPrivateKey, {
          from: redeemer
        })
      )
    })

    it('should NOT redeem referred with incorrect pubKey', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { proof, satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          proof,
          satoshis,
          incorrectBitcoinPrivateKey,
          referrer,
          {
            from: redeemer
          }
        )
      )
    })

    it('should NOT redeem with incorrect proof', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemUtxo(urt, incorrectProof, satoshis, bitcoinPrivateKeys(0), {
          from: redeemer
        })
      )
    })

    it('should NOT redeem referred with incorrect proof', async () => {
      await timeWarpRelativeToLaunchTime(urt, 60, true)
      const bitcoinTx = transactions[0]
      const { satoshis } = getProofAndComponents(bitcoinTx)

      await expectRevert(
        testRedeemReferredUtxo(
          urt,
          incorrectProof,
          satoshis,
          bitcoinPrivateKeys(0),
          referrer,
          {
            from: redeemer
          }
        )
      )
    })
  })
})

describe('when incrementing weeks', () => {
  contract('UtxoRedeemableToken', () => {
    let urt
    let testWeeks

    before('setup contract', async () => {
      const launchTime = await getDefaultLaunchTime()
      urt = await setupContract(launchTime)
    })

    it(`should increment first 3 weeks correctly`, async () => {
      testWeeks = [1, 2, 3]
      for (const week of testWeeks) {
        await timeWarpRelativeToLaunchTime(urt, oneBlockWeek * week + 1, true)
        await testWeekIncrement(urt, week, true)
      }
    })

    it('should increment last 3 weeks correctly', async () => {
      testWeeks = [48, 49, 50]
      for (const week of testWeeks) {
        await timeWarpRelativeToLaunchTime(urt, oneBlockWeek * week + 1, true)
        await testWeekIncrement(urt, week, true)
      }
    })

    it('should NOT increment weeks past 50', async () => {
      await timeWarpRelativeToLaunchTime(urt, oneBlockWeek * 52 + 1, true)
      await testWeekIncrement(urt, 51, false)
    })
  })
})
