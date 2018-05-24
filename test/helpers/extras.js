// Special non-standard methods implemented by testrpc that
// aren’t included within the original RPC specification.
// See https://github.com/ethereumjs/testrpc#implemented-methods

const increaseTime = (time) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [time], // Time increase param.
            id: new Date().getTime()
        }, (err) => {
            if (err) {
                return reject(err);
            }

            resolve();
        });
    });
};

const takeSnapshot = () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_snapshot',
            params: [],
            id: new Date().getTime()
        }, (err, result) => {
            if (err) {
                return reject(err);
            }

            resolve(result.result);
        });
    });
};

const revertToSnapshot = (snapShotId) => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_revert',
            params: [snapShotId],
            id: new Date().getTime()
        }, (err) => {
            if (err) {
                return reject(err);
            }

            resolve();
        });
    });
};

const evm_mine = () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_mine',
            params: [],
            id: new Date().getTime()
        }, (err) => {
            if (err) {
                return reject(err);
            }

            resolve();
        });
    });
};

const verifyEvent = (txHash, eventSig) => {      
    let txr = web3.eth.getTransactionReceipt(txHash);    
    for (let n in txr.logs) {     
        //console.log(txr.logs[n].topics);   
        if (txr.logs[n].topics && txr.logs[n].topics[0] === eventSig ){            
            return true;
        }
    }
    return false;
};

export { increaseTime, takeSnapshot, revertToSnapshot, evm_mine, verifyEvent };
