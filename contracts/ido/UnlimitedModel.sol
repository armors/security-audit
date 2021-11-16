// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./IERC20.sol";
import "./Ownable.sol";

contract UnlimitedModel is Ownable{

    IERC20 public token ;                   //项目方token
    IERC20 public USDT ;                     //USDT
    address public feeAddress;

    struct PairInfo{
        IERC20 pairToken;           //质押的token
        uint256 startTime;          //开始时间
        uint256 endTime;            //结束时间
        uint256 withdrawTime;       //项目方可以提现时间
        uint256 salesAmount;        //项目方出让token数
        uint256 totalAmount;        //用户购买总数
        uint256 claimAmount;        //用户兑换总数
        uint256 usdtAmount;         //USDT数量
        uint256 maxAmount;          //预订的募集上限
        uint256 price;              //单个token价格
        uint256 minAccount;         //IDO成功需要参与的最小钱包数量
        address[] accountList;        //参与的钱包列表
        mapping(address => uint) accountRs;    //参与的钱包记录
        mapping(uint256 => FeeInfo) feeRate;           //手续费率集合
    }

    struct UserInfo{
        uint256 buyAmount;          //质押数量
        uint256 balance;            //拥有额度
    }

    struct FeeInfo{
        uint256 multiple;           //倍率
        uint256 feeRate;            //费率分子
        uint256 feeRateDenominator; //费率分母
    }

    mapping(uint256 => PairInfo) public pairInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(uint256 => FeeInfo[]) public feeInfo;
    uint num = 0;
    uint[] public keys;
    event AddPair(address indexed user, address pairAddress, uint256 salesAmount,
        uint256 stratTime, uint256 endTime, uint256 prices);
    event WithdrawToken(address indexed user, uint256 amount);
    event WithdrawUSDT(address indexed user, uint256 amount);
    event BuyQuota(address indexed user, uint256 id, uint256 amount);
    event Claim(address indexed user, uint256 id, uint256 amount);
    event CashLimit(address indexed user, uint256 id, uint256 amount);


    constructor(address _token, address _usdt) {
        token = IERC20(_token);
        USDT = IERC20(_usdt);
        feeAddress = msg.sender;
    }

    function setFeeRate(uint256 _id, uint[] memory _multiple, 
        uint[] memory _rate, uint _denominator) public onlyOwner{
        require(_multiple.length == _rate.length,"Error Params");
        FeeInfo[] storage fees = feeInfo[_id];
        for(uint i = 0; i < _multiple.length; i++){
            FeeInfo memory fee = FeeInfo({
                multiple: _multiple[i],
                feeRate: _rate[i],
                feeRateDenominator: _denominator
            });
            fees.push(fee);
        }
    }

    function setFeeAddress(address _feeAddress) public onlyOwner{
        require(_feeAddress != address(0),"fee address cannot be 0");
        feeAddress = _feeAddress;
    }

//    管理员添加IDO交易对
//@@@@@@@@@
//    _pairAddress      质押token地址
//    _salesAmount        出让token的数量
//    _startTime        开始时间
//    _endTime          截止时间
//    _withdrawTime     可以提现时间（管理员）
//    _maxPerUser       每个钱包最大购买数量
//    _prices           每个token对应的usdt价格
//    _minAmount        最小募集额度
//@@@@@@@@@
    function addPair(
        address _pairAddress, uint256 _salesAmount, uint256 _startTime, 
        uint256 _endTime, uint256 _withdrawTime, uint256 _maxAmount,
        uint256 _prices, uint256 _minAccount, uint256 _feeID
    ) public onlyAdmin{
        for(uint256 i = 0; i < pairLength(); i++){
            require(pairInfo[keys[i]].pairToken != IERC20(_pairAddress), "Pair is existed");
        }

        IERC20 pToken = IERC20(_pairAddress);

        require(_startTime > block.timestamp,"Invalid Time");
        require(_endTime > _startTime, "Invalid strartTime");
        require(_withdrawTime > _endTime, "Invalid withdrawTime");
        require(token.balanceOf(msg.sender) >= _salesAmount, "Not enough token amount");

        token.transferFrom(msg.sender, address (this), _salesAmount);

        PairInfo storage p = pairInfo[num];
        p.pairToken = pToken;
        p.salesAmount = _salesAmount;
        p.totalAmount = 0;
        p.claimAmount = 0;
        p.usdtAmount = 0;
        p.startTime = _startTime;
        p.endTime = _endTime;
        p.withdrawTime = _withdrawTime;
        p.maxAmount = _maxAmount;
        p.price = _prices;
        p.minAccount = _minAccount;
        FeeInfo[] memory fees = feeInfo[_feeID];
        for(uint i = 0; i < fees.length; i++){
            p.feeRate[fees[i].multiple].multiple = fees[i].multiple;
            p.feeRate[fees[i].multiple].feeRate = fees[i].feeRate;
            p.feeRate[fees[i].multiple].feeRateDenominator = fees[i].feeRateDenominator;
        }
        keys.push(num);
        num++;
        emit AddPair(msg.sender, _pairAddress, _salesAmount, _startTime,_endTime, _prices);
    }

    //    取消交易对 取消操作只会将对应Pid的结构体的值初始化，无法删除元素
    //@@@@@@@@@
    //    _token       项目方token地址
    //    _usdt        usdt合约地址
    //@@@@@@@@@
    function cancelPair(uint256 _pid, address _recipient) public onlyAdmin{
        PairInfo storage pair = pairInfo[_pid];
        require(pair.startTime > block.timestamp,"Pair already start");
        token.transfer(_recipient, pair.salesAmount);
        delete pairInfo[_pid];
    }

//    管理员取走Token
    //@@@@@@@@@
    //    _pid          序号
    //    _recipient    接收者地址
    //@@@@@@@@@
    function withdrawToken(uint256 _pid, address _recipient) public onlyAdmin{
        PairInfo storage pair = pairInfo[_pid];
        require(pair.withdrawTime < block.timestamp,"The project is not withdraw");
        token.transfer(_recipient, pair.salesAmount - pair.claimAmount);
        emit WithdrawToken(msg.sender,pair.salesAmount - pair.claimAmount);
    }
//    管理员取走USDT 
    //@@@@@@@@@
    //    _pid          序号
    //    _recipient    接收者地址
    //@@@@@@@@@
    function withdrawUSDT(uint256 _pid, address _recipient) public onlyAdmin{
        PairInfo storage pair = pairInfo[_pid];
        require(pair.withdrawTime < block.timestamp,"The project is not withdraw");
        USDT.transfer(_recipient, pair.usdtAmount);
        emit WithdrawUSDT(msg.sender,pair.usdtAmount);
    }
//    用户购买额度
    //@@@@@@@@@
    //    _pid          序号
    //    _amount       购买数量
    //@@@@@@@@@
    function buyQuota(uint256 _pid, uint256 _amount) public {
        PairInfo storage pair = pairInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pair.startTime < block.timestamp, "Pair is not start");
        require(pair.endTime > block.timestamp, "Pair is over");
        pair.pairToken.transferFrom(msg.sender, address(this), _amount);
        user.buyAmount += _amount;
        pair.totalAmount += _amount;
        if (pair.accountRs[msg.sender] == 0) {
            pair.accountRs[msg.sender] = 1;
            pair.accountList.push(msg.sender);
        }
        emit BuyQuota(msg.sender, _pid, _amount);
    }
//    用户取回本金
    //@@@@@@@@@
    //    _pid          序号
    //@@@@@@@@@
    function claim(uint256 _pid) public virtual {
        PairInfo storage pair = pairInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pair.endTime < block.timestamp, "Pair is not over");
        require(user.buyAmount > 0,"Not enough amount");
        user.balance = getTokenAmount(_pid);
        pair.pairToken.transfer(msg.sender, user.buyAmount);
        emit Claim(msg.sender, _pid, user.buyAmount);
        user.buyAmount = 0;
    }

//    用户兑现额度
    //@@@@@@@@@
    //    _pid          序号
    //@@@@@@@@@
    function cashLimit(uint256 _pid) public {
        PairInfo storage pair = pairInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(pair.withdrawTime > block.timestamp,"The project can not cashLimit");
        require(pair.endTime < block.timestamp, "Pair is not over");
        require(pair.accountList.length >= pair.minAccount, "IDO Failed");
        if(user.balance == 0 ){
            user.balance = getTokenAmount(_pid);
        }
        require(user.balance > 0,"Not enough balance");
        USDT.transferFrom(msg.sender, address(this), user.balance * pair.price);
        FeeInfo storage fee = pair.feeRate[getPairFeeRateStep(_pid)];
        USDT.transferFrom(msg.sender, feeAddress, 
            user.balance * pair.price * fee.feeRate / fee.feeRateDenominator);
        token.transfer(msg.sender, user.balance);
        pair.claimAmount += user.balance;
        pair.usdtAmount += user.balance * pair.price;
        emit CashLimit(msg.sender, _pid, user.balance);
        pair.pairToken.transfer(msg.sender, user.buyAmount);
        emit Claim(msg.sender, _pid, user.buyAmount);
        user.balance = 0;
        user.buyAmount = 0;
    }

//    view functions

    function checkOrder(uint256 _pid) public view  returns (uint256){
        PairInfo storage pair = pairInfo[_pid];
        require(pair.withdrawTime > block.timestamp,"The project can not cashLimit");
        require(pair.endTime < block.timestamp, "Pair is not over");
        require(pair.accountList.length >= pair.minAccount, "IDO Failed");
        FeeInfo storage fee = pair.feeRate[getPairFeeRateStep(_pid)];
        uint256 amount = getTokenAmount(_pid);
        return (amount * pair.price) + 
            (amount * pair.price * fee.feeRate / fee.feeRateDenominator);
    }

    function pairLength() public view returns(uint256){
        return keys.length;
    }

    function pairAccountLength(uint _pid) public view returns(uint256){
        return pairInfo[_pid].accountList.length;
    }

    function getPairAccount(uint _pid, uint key) public view returns(address){
        return pairInfo[_pid].accountList[key];
    }

    //@@@@@@@@@
    //    _pid          序号
    //@@@@@@@@@
    function getTokenAmount(uint256 _pid) public view returns (uint256){
        PairInfo storage pair = pairInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if(user.balance > 0){
            return user.balance;
        }
        return user.buyAmount * pair.salesAmount / pair.totalAmount;
    }

    function getPairStatus(uint256 _pid) public view returns (bool){
        PairInfo storage pair = pairInfo[_pid];
        return pair.accountList.length >= pair.minAccount;
    }

    function getPairFeeRateStep(uint256 _pid) public view returns (uint256){
        PairInfo storage pair = pairInfo[_pid];
        uint256 step =  pair.totalAmount / pair.maxAmount;
        if (step > 500){
            return 500;
        }
        if (step > 250){
            return 250;
        }
        if (step > 100){
            return 100;
        }
        if (step > 50){
            return 50;
        }
        return 0;
    }
}
