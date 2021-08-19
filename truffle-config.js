
/*const HDWalletProvider = require('truffle-hdwallet-provider');
const infuraKey = "6be0c3232652414b90c93edfa72846a4";//"c5ba986316384fe0bb2460b614ef05a0";
const mnemonic = "capital key cream tilt like ancient enough notice brand parade pair ask";
//const mnemonic = "feed phone inside today dragon damp chase capital smoke response demand upgrade";

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*" // Match any network id
    }, 
    rinkeby: {
      provider: () => new HDWalletProvider(mnemonic, `https://rinkeby.infura.io/v3/${infuraKey}`),
        network_id: 4,
        gas: 4500000,
        gasPrice: 10000000000
    }
  }
};*/
var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "capital key cream tilt like ancient enough notice brand parade pair ask";//"candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      // provider: function() {
      //   return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/",0,50);
      // },
      host: '127.0.0.1',
      port: 9545,
      network_id: '*',
      gas: 9999999
    },
    GanacheUI: {
      host: '127.0.0.1',
      port: 9545,
      network_id: '*',
      gas: 9999999
    }
  },
 /* networks: {
    development: {
      provider: function() {
        return new HDWalletProvider(mnemonic, "http://127.0.0.1:9545/", 0, 50);
      },
      network_id: '*',
      gas: 9999999,
      accounts:50
    }
  },*/
  compilers: {
    solc: {
      version: "^0.5.10"
    }
  }
};