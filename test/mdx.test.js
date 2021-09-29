const WHT = artifacts.require("WHT");
const MdexFactory = artifacts.require("MdexFactory");
const MdexRouter = artifacts.require("MdexRouter");
const MdxToken = artifacts.require("MdxToken");
const HecoPool = artifacts.require("HecoPool");

const ERC20TokenMock = artifacts.require("ERC20TokenMock");

const { expect } = require('chai');
const { ethers } = require('hardhat');

const {
    BN,           // Big Number support
    constants,    // Common constants, like the zero address and largest integers
    expectEvent,  // Assertions for emitted events
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

contract("mdx", ([owner, mdxFeeToSetter, lpUser, incomeAccount, investUser, reinvestManager, rebalanceManager]) => {

    beforeEach(async function () {
        // ERC20 mock
        this.depositToken = await ERC20TokenMock.new("depositToken", "DT", 10000000);
        this.rewardToken = await ERC20TokenMock.new("rewardToken", "RT", 10000000);

        let investUserAmountAll = new BN('10').pow(new BN('18')).mul(new BN('100000'));
        await this.depositToken.transfer(investUser, investUserAmountAll);

        // mdx 工厂 和 路由 以及 WHT
        this.mdexFactoryInstance = await MdexFactory.new(mdxFeeToSetter);
        let initCode = await this.mdexFactoryInstance.getInitCodeHash();
        await this.mdexFactoryInstance.setInitCodeHash(initCode, { from: mdxFeeToSetter });

        this.mdxWHTInstance = await WHT.new();

        this.mdexRouterInstance = await MdexRouter.new(
            this.mdexFactoryInstance.address,
            this.mdxWHTInstance.address
        );
        // 添加流动性 1 : 10
        let lp = {
            token0Amount: new BN('10').pow(new BN('18')).mul(new BN('100000')),
            token1Amount: new BN('10').pow(new BN('18')).mul(new BN('1000000')),
        };
        await this.depositToken.approve(this.mdexRouterInstance.address, constants.MAX_UINT256)
        await this.rewardToken.approve(this.mdexRouterInstance.address, constants.MAX_UINT256)
        await this.mdexRouterInstance.addLiquidity(
            this.depositToken.address,
            this.rewardToken.address,
            lp.token0Amount,
            lp.token1Amount,
            0,
            0,
            lpUser,
            constants.MAX_UINT256
        );

        // mdx token
        this.mdxTokenInstance = await MdxToken.new();
        // mdx pool
        let _mdxPerBlock = new BN('500000000000000000000');
        const mdxPool = {
            mdxPerBlock: _mdxPerBlock, // 500 mdx
            startBlock: 0,
        };
        this.hecoPoolInstance = await HecoPool.new(
            this.mdxTokenInstance.address,
            mdxPool.mdxPerBlock,
            mdxPool.startBlock,
        );
        await this.mdxTokenInstance.addMinter(this.hecoPoolInstance.address);

        // 创建矿池 // pid = 0
        await this.hecoPoolInstance.add(100, this.depositToken.address, true);
    });
});