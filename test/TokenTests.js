import expectRevert from "./helpers/expectRevert";
import {verifyEvent} from './helpers/extras';

const Token = artifacts.require("./helpers/MockToken.sol");

// Note from @Emmonspired - we will add token transferrence tests here
contract('Token Tests', accounts => {
    
    const eventSigApproval = web3.sha3('Approval(address,address,uint256)');
    const eventSigTransfer = web3.sha3('Transfer(address,address,uint256)');

    const owner = accounts[0];
    const account_two = accounts[1];
    const account_three = accounts[2];

    let token;
    let owner_starting_balance,
        account_two_starting_balance,
        account_three_starting_balance;

    
    before(async () => {
        token = await Token.new({from: owner});
    });

    beforeEach(async () => {
        owner_starting_balance = await token.balanceOf.call(owner);
        account_two_starting_balance = await token.balanceOf.call(account_two);
        account_three_starting_balance = await token.balanceOf.call(account_three);
    });

    it("should have the owner account set correctly", async () => {
        assert.equal(owner, await token.owner.call(), "owner is not set correctly");
    });

    it("should have correct name and symbol", async () => {
        assert.equal(await token.name.call(), 'BitcoinHex', "Token name incorrect");
        assert.equal(await token.symbol.call(), 'BHX', "Token symbol incorrect");
    });
    
    it("should fail to transfer tokens to 0x0 or the token's address", async () => {
        await expectRevert(token.transfer(0, 1, {from: owner}));
        await expectRevert(token.transfer(token.address, 1, {from: owner}));
    });
    
});
