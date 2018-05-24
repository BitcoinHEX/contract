
// Truffle requires babel-register for import in tests. https://github.com/trufflesuite/truffle/issues/664
require('babel-register');
require('babel-polyfill');

let secrets = require('./secrets');
const WalletProvider = require("truffle-wallet-provider");
const Wallet = require('ethereumjs-wallet');

let mainNetPrivateKey = new Buffer(secrets.mainnetPK, "hex");
let mainNetWallet = Wallet.fromPrivateKey(mainNetPrivateKey);
let mainNetProvider = new WalletProvider(mainNetWallet, "https://mainnet.infura.io/");
let ropstenPrivateKey = new Buffer(secrets.ropstenPK, "hex");
let ropstenWallet = Wallet.fromPrivateKey(ropstenPrivateKey);
let ropstenProvider = new WalletProvider(ropstenWallet,  "https://ropsten.infura.io/");

module.exports = {
  networks: {
    development: { host: "localhost", port: 8545, 
                   network_id: "*", gas: 4465030 },    
    ropsten: { provider: ropstenProvider, 
                   network_id: "3", gas: 4465030 },
    live: { provider: mainNetProvider, 
                   network_id: "1", gas: 7500000 }
  }
};