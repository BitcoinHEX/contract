/* eslint-disable import/no-unassigned-import */
// Truffle requires babel-register for import in tests. https://github.com/trufflesuite/truffle/issues/664
require('babel-register')
require('babel-polyfill')

const secrets = require('./secrets')
const WalletProvider = require('truffle-wallet-provider')
const Wallet = require('ethereumjs-wallet')

const mainNetPrivateKey = new Buffer(secrets.mainnetPK, 'hex')
const mainNetWallet = Wallet.fromPrivateKey(mainNetPrivateKey)
const mainNetProvider = new WalletProvider(
  mainNetWallet,
  'https://mainnet.infura.io/'
)
const ropstenPrivateKey = new Buffer(secrets.ropstenPK, 'hex')
const ropstenWallet = Wallet.fromPrivateKey(ropstenPrivateKey)
const ropstenProvider = new WalletProvider(
  ropstenWallet,
  'https://ropsten.infura.io/'
)

module.exports = {
  networks: {
    ropsten: {
      provider: ropstenProvider,
      network_id: '3',
      gas: 4465030
    },
    live: {
      provider: mainNetProvider,
      network_id: '1',
      gas: 7500000
    }
  },
  mocha: {
    reporter: process.env.GAS_REPORTER ? 'eth-gas-reporter' : 'spec',
    reporterOptions: {
      currency: 'USD',
      gasPrice: 21
    }
  }
}
