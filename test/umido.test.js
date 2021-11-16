const BasicModel = artifacts.require("UnlimitedModel")
const ERC20TokenMock = artifacts.require("ERC20TokenMock")

const { expect } = require('chai')
const { ethers } = require('hardhat')
const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers')

contract("IDO", ([owner, admin, user1, user2, user3, user4, user5, user6,fee]) => {

    beforeEach(async function () {
        // ERC20 mock
        this.token = await ERC20TokenMock.new("demoToken", "Demo", 10000000,{from:admin})
        this.depToken1 = await ERC20TokenMock.new("depToken1", "DT1", 10000000)
        this.depToken2 = await ERC20TokenMock.new("depToken2", "DT2", 10000000)
        this.usdt = await ERC20TokenMock.new("USDT", "USDT", 10000000)
        this.basic = await BasicModel.new(this.token.address,this.usdt.address)
        await this.basic.setAdmin(admin)
        await this.token.approve(this.basic.address, 100000,{from:admin})
        await initAccount(this.depToken1, this.basic,owner)
        await initAccount(this.depToken2, this.basic,owner)
        await initAccount(this.usdt, this.basic,owner)
        let multiple = [0,50,100,250,500]
        let rate = [100,50,30,25,20]
        let rate1 = [100,40,20,10,5]
        await this.basic.setFeeRate(0,multiple,rate,10000)
        await this.basic.setFeeRate(0,multiple,rate1,10000)
        await this.basic.setFeeAddress(fee)
    })

    it("Test setFee", async function(){
        let multiple = [0,50,100,250,500]
        let rate = [100,50,30,25]
        // await this.basic.setFeeRate(0,multiple,rate,10000)
        // await this.basic.setFeeRate(0,multiple,rate1,10000)
        // await this.basic.setFeeAddress(fee)
        await expectRevert(this.basic.setFeeRate(0,multiple,rate,10000),"Error Params")
        await expectRevert(this.basic.setFeeAddress(ZERO_ADDRESS),"fee address cannot be 0")
    })

    it("Test successful",async function(){
        let dt = await getDT()
        await testAddPair(this.basic,this.depToken1,dt + 100,
            dt + 500,dt + 1000,
            100,1,2)
        assert.equal(await this.token.balanceOf(this.basic.address),10000)
        await miner(100)
        await buy(this.basic,0,10)
        await miner(500)
        let balance = await this.depToken1.balanceOf(this.basic.address)
        assert.equal(balance,50)
        // let feeBalance = await this.usdt.balanceOf(fee)
        // console.log(feeBalance.toString())
        await this.basic.pairAccountLength(0,{from:user1})
        await this.basic.getPairAccount(0,0,{from:user1})
        await this.basic.checkOrder(0,{from:user1})
        await claim(this.basic,0)
        await this.basic.getTokenAmount(0,{from:user1})
        await cashLimit(this.basic,0)
        await miner(1000)
        let tokenBalance = await this.token.balanceOf(this.basic.address)
        let usdtBalance = await this.usdt.balanceOf(this.basic.address)
        let rs = await this.basic.getPairStatus(0)
        assert.equal(rs,true)
        await this.basic.withdrawToken(0,user6,{from:admin})
        await this.basic.withdrawUSDT(0,user6,{from:admin})
        balance = await this.token.balanceOf(user6)
        assert.equal(tokenBalance,balance.toString())
        balance = await this.usdt.balanceOf(user6)
        assert.equal(usdtBalance,balance.toString())
        // feeBalance = await this.usdt.balanceOf(fee)
        // console.log(feeBalance.toString())
    })

    describe("Test addPair",function(){
        it("Test addPair simple.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,
                dt + 100,dt + 500,dt + 1000,
                100,10,60,10000)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await testAddPair(this.basic,this.depToken2,dt + 100,
                dt+500,dt+1000,
                100,10,60,10000)
            assert.equal(await this.token.balanceOf(this.basic.address),20000)
        })

        it("Test addPair _startTime > block.timestamp.", async function () {
            let dt = await getDT()
            await expectRevert(
                testAddPair(this.basic,this.depToken1,dt,
                    dt + 500,dt + 1000,
                    100,10,60),
                "Invalid Time");
        })
    
        it("Test addPair endTime > stratTime.", async function () {
            let dt = await getDT()
            await expectRevert(
                testAddPair(this.basic,this.depToken1,dt+ 100,
                    dt - 500,dt + 1000,
                    100,10,60),
                "Invalid strartTime");
        })
    
        it("Test addPair _withdrawTime > _endTime.", async function () {
            let dt = await getDT()
            await expectRevert(
                testAddPair(this.basic,this.depToken1,dt + 100,
                    dt + 500,dt + 400,
                    100,10,60),
                "Invalid withdrawTime");
        })
    
        it("Test addPair Not enough token amount.", async function () {
            let dt = await getDT()
            let balance = await this.token.balanceOf(admin)
            await this.token.transfer(user1,balance, {from:admin})
            await expectRevert(
                testAddPair(this.basic,this.depToken1,dt + 100,
                    dt + 500,dt + 1000,
                    100000000,10,60),
                "Not enough token amount");
        })
    
        it("Test addPair Pair is existed", async function(){
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt + 100,
                dt + 500,dt+1000,
                100,10,60)
            await expectRevert(testAddPair(this.basic,this.depToken1,dt + 100,
                dt + 500,dt+1000,
                100,10,60),
                "Pair is existed")
        })
    })

    describe("Test cancelPair",function(){
        it("Test cancelPair simple.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt + 100,
                dt+500,dt+1000,
                100,10,60)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await testAddPair(this.basic,this.depToken2,dt+400,
                dt+500,dt+1000,
                100,10,60)
            assert.equal(await this.token.balanceOf(this.basic.address),20000)
            await this.basic.cancelPair(1,admin,{from:admin})
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
        })
        it("Test cancelPair Pair already start.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt + 100,
                dt+500,dt+1000,
                100,10,60)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await testAddPair(this.basic,this.depToken2,dt + 100,
                dt+500,dt+1000,
                100,10,60)
            assert.equal(await this.token.balanceOf(this.basic.address),20000)
            await miner(100)
            await expectRevert(this.basic.cancelPair(1,admin,{from:admin}), "Pair already start")
        })
    })

    describe("Test buyQuota",function(){
        it("Test buyQuota simple.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+50,
                dt+75,dt+1000,
                100,10,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            await buy(this.basic,0,10)
        })
    
        it("Test buyQuota pair.startTime < block.timestamp",async function(){
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+100,
                dt+200,dt+1000,
                100,10,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await expectRevert(this.basic.buyQuota(0,10,{from: user1}),"Pair is not start")
        })
    
        it("Test buyQuota pair.endTime > block.timestamp",async function(){
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+100,
                dt+200,dt+300,
                100,10,40)
            await ethers.provider.send('evm_increaseTime', [400])
            await ethers.provider.send('evm_mine')
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await expectRevert(this.basic.buyQuota(0,10,{from: user1}),"Pair is over")
        })
    })

    describe("Test only claim",function(){
        it("Test claim simple.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,10,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            let balance = await this.depToken1.balanceOf(user1)
            await buy(this.basic,0,10)
            assert.equal(await this.depToken1.balanceOf(user1), balance - 10)
            miner(800)
            await claim(this.basic, 0)
            assert.equal(await this.depToken1.balanceOf(user1), balance.toString())
        })

        it("Test claim pair.endTime < block.timestamp.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,10,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            miner(400)
            await expectRevert(claim(this.basic, 0),"Pair is not over")
        })

        it("Test claim user.buyAmount > 0.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,10,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            miner(800)
            await expectRevert(this.basic.claim(0, {from:user6}),"Not enough amount")
        })
    })

    describe("Test only cashLimit",function(){
        it("Test cashLimit simple.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,2)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            let balance = await this.depToken1.balanceOf(user1)
            await buy(this.basic,0,10)
            assert.equal(await this.depToken1.balanceOf(user1), balance - 10)
            miner(800)
            await cashLimit(this.basic, 0)
            assert.equal(await this.depToken1.balanceOf(user1), balance.toString())
        })

        it("Test clacashLimitim pair.endTime < block.timestamp.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            miner(400)
            await expectRevert(cashLimit(this.basic, 0),"Pair is not over")
        })

        it("Test cashLimit pair.withdrawTime > block.timestamp.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,40)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            miner(1500)
            await expectRevert(cashLimit(this.basic, 0),"The project can not cashLimit")
        })

        it("Test cashLimit pair.totalAmount >= pair.minAmount.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                120,1,110)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            await buy(this.basic,0,10)
            miner(800)
            await expectRevert(cashLimit(this.basic, 0),"IDO Failed")
        })

        it("Test cashLimit user.balance > 0.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,2)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            let balance = await this.depToken1.balanceOf(user1)
            await buy(this.basic,0,10)
            assert.equal(await this.depToken1.balanceOf(user1), balance - 10)
            miner(800)
            await cashLimit(this.basic, 0)
            assert.equal(await this.depToken1.balanceOf(user1), balance.toString())
            await expectRevert(cashLimit(this.basic, 0),"Not enough balance")
        })
    })

    describe("Test withdraw",function(){
        it("Test withdraw token & USDT.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,2)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            let balance = await this.depToken1.balanceOf(user1)
            await buy(this.basic,0,10)
            assert.equal(await this.depToken1.balanceOf(user1), balance - 10)
            miner(800)
            await claim(this.basic,0)
            await cashLimit(this.basic, 0)
            assert.equal(await this.depToken1.balanceOf(user1), balance.toString())
            miner(500)
            await this.basic.withdrawToken(0,user6,{from:admin})
            balance = await this.token.balanceOf(user6)
            assert.equal(balance,2000)
            await this.basic.withdrawUSDT(0,user6,{from:admin})
            balance = await this.usdt.balanceOf(user6)
            assert.equal(balance,8000)
            balance = await this.token.balanceOf(this.basic.address)
            assert.equal(balance, 0)
            balance = await this.usdt.balanceOf(this.basic.address)
            assert.equal(balance, 0)
            balance = await this.depToken1.balanceOf(this.basic.address)
            assert.equal(balance, 0)
        })

        it("Test withdraw pair.withdrawTime < block.timestamp.", async function () {
            let dt = await getDT()
            await testAddPair(this.basic,this.depToken1,dt+15,
                dt+500,dt+1000,
                100,1,2)
            assert.equal(await this.token.balanceOf(this.basic.address),10000)
            await miner(50)
            let balance = await this.depToken1.balanceOf(user1)
            await buy(this.basic,0,10)
            assert.equal(await this.depToken1.balanceOf(user1), balance - 10)
            miner(800)
            await cashLimit(this.basic, 0)
            assert.equal(await this.depToken1.balanceOf(user1), balance.toString())
            await expectRevert(this.basic.withdrawToken(0,user6,{from:admin}),"The project is not withdraw")
            await expectRevert(this.basic.withdrawUSDT(0,user6,{from:admin}),"The project is not withdraw")
        })
    })
    
    async function getDT(){
        const blockNumBefore = await ethers.provider.getBlockNumber()
        const blockBefore = await ethers.provider.getBlock(blockNumBefore)
        return blockBefore.timestamp
    }

    async function miner(t){
        await ethers.provider.send('evm_increaseTime', [t])
        await ethers.provider.send('evm_mine')
    }

    async function claim(basic,pid){
        await basic.claim(pid, {from:user1})
        await basic.claim(pid, {from:user2})
        await basic.claim(pid, {from:user3})
        await basic.claim(pid, {from:user4})
        await basic.claim(pid, {from:user5})
        // await basic.claim(pid, {from:user6})
    }

    async function cashLimit(basic,pid){
        await basic.cashLimit(pid, {from:user1})
        await basic.cashLimit(pid, {from:user2})
        await basic.cashLimit(pid, {from:user3})
        await basic.cashLimit(pid, {from:user4})
        // await basic.cashLimit(pid, {from:user5})
        // await basic.cashLimit(pid, {from:user6})
    }

    async function buy(basic,pid,amount){
        await basic.buyQuota(pid,amount,{from: user1})
        await basic.buyQuota(pid,amount,{from: user2})
        await basic.buyQuota(pid,amount,{from: user3})
        await basic.buyQuota(pid,amount,{from: user4})
        await basic.buyQuota(pid,amount,{from: user5})
        // await basic.buyQuota(pid,amount,{from: user6})
    }

    async function testAddPair(basic,token,startTime,endtime,withdrawtime,max,price,minAmount,salesAmount=10000,maxAmount=10000){
        await basic.addPair(token.address,salesAmount,startTime,endtime,withdrawtime,maxAmount,price,minAmount,0,{from:admin})

    }


    async function initAccount(token,model,opt){
        await token.approve(model.address, 10000)
        await token.approve(model.address, 10000,{from:opt})
        assert.equal(await token.allowance(owner,model.address),10000)
        await token.transfer(user1,10000,{from:opt})
        assert.equal(await token.balanceOf(user1),10000)
        await token.approve(model.address, 10000,{from:user1})
        assert.equal(await token.allowance(user1,model.address),10000)
        await token.transfer(user2,10000,{from:opt})
        await token.approve(model.address, 10000,{from:user2})
        await token.transfer(user3,10000,{from:opt})
        await token.approve(model.address, 10000,{from:user3})
        await token.transfer(user4,10000,{from:opt})
        await token.approve(model.address, 10000,{from:user4})
        await token.transfer(user5,10000,{from:opt})
        await token.approve(model.address, 10000,{from:user5})
        // await token.transfer(user6,10000,{from:opt})
        // await token.approve(model.address, 10000,{from:user6})
    }
})

