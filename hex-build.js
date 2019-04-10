#!/usr/bin/env node

'use strict';
const fs = require('fs');
const solc = require('solc');
const solpp = require('solpp');

const buildDir = './build';
const contractDir = './contracts';

const contractName = 'HEX';
const contractFile = 'HEX.sol';

const flattenedPath = `${buildDir}/${contractFile}`;
const contractPath = `${contractDir}/${contractFile}`;

function formatJson(obj) {
  return JSON.stringify(obj, null, 2) + '\n';
}

function saveTextFile(textPath, text) {
  if (!fs.existsSync(textPath) || text !== fs.readFileSync(textPath, 'utf-8')) {
    fs.writeFileSync(textPath, text);
    console.log('Saved:', textPath);
    return true;
  }
  return false;
}

function saveJsonFile(ext, obj) {
  const jsonPath = `${buildDir}/${contractName}.${ext}.json`;

  return saveTextFile(jsonPath, formatJson(obj));
}

async function flatten() {
  const ppOpts = {
    noPreprocessor: true,
  };

  let src = await solpp.processFile(contractPath, ppOpts);

  if (!src.endsWith('\n')) {
    src += '\n';
  }
  return src;
}

function compile(src) {
  const input = {
    language: 'Solidity',
    sources: {
      [contractFile]: {
        content: src,
      },
    },
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      outputSelection: {
        [contractFile]: {
          [contractName]: [
            'evm.bytecode.object',
            'evm.bytecode.sourceMap',
            'evm.deployedBytecode.object',
            'evm.deployedBytecode.sourceMap',
            'metadata',
          ],
        },
      },
    },
  }

  const output = JSON.parse(solc.compileStandard(JSON.stringify(input)));
  if (output.errors) {
    console.error(formatJson(output.errors));
    process.exit(1);
  }
  return output;
}

async function build() {
  console.log('Flattening:', contractPath);
  const src = await flatten();

  console.log('Compiling: ', contractPath);
  const output = compile(src);

  const contract = output.contracts[contractFile][contractName];
  const metadata = JSON.parse(contract.metadata);
  
  const abi = metadata.output.abi;
  delete metadata.output.abi;

  saveJsonFile('abi', abi);
  saveJsonFile('evm', contract.evm);
  saveJsonFile('metadata', metadata);

  saveTextFile(flattenedPath, src);
}

build();
