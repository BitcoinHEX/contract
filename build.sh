#!/bin/bash

./clean.sh
solc --optimize --gas --pretty-json --abi --bin --output-dir build/Token src/BitcoinHex.sol