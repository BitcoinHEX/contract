#!/bin/bash

if [ -z "$1" ]
then
      echo "Usage: node.sh CHAIN"
      echo "Valid values for CHAIN are: olympic, frontier, homestead, mainnet, morden, ropsten, classic, expanse, testnet, kovan and dev"
else
      parity ui --chain $1 --jsonrpc-apis all 
fi