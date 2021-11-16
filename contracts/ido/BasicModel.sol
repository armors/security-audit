// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./IERC20.sol";
import "./Ownable.sol";

contract BasicModel is Ownable{

    IERC20 public token ;                   //项目方token
    IERC20 public USDT ;                     //USDT

    struct PairInfo{
        IERC20 pairToken;           //质押的token
        uint256 startTime;          //开始时间
        uint256 endTime;            //结束时间
        uint256 withdrawTime;       //项目方可以提现时间
        uint256 salesAmount;        //项目方出让token数
        uint256 totalAmount;        //用户购买总数
        uint256 claimAmount;        //用户兑换总数
        uint256 usdtAmount;         //USDT数量
        uint256 maxPerUser;         //单用户质押上限
        uint256 price;              //单个token价格
        uint256 minAmount;          //IDO成功需要募集的最小质押token数量
        uint256 maxAmount;          //IDO募集的最大质押token数量
    }

    struct UserInfo{
        uint256 buyAmount;          //质押数量
        uint256 balance;            //拥有额度
    }

    PairInfo[] public pairInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;


    event AddPair(address indexed user, address pairAddress, uint256 salesAmount,
        uint256 stratTime, uint256 endTime, uint256 maxPerUser, uint256 prices);
    event WithdrawToken(address indexed user, uint256 amount);
    event WithdrawUSDT(address indexed user, uint256 amount);
    event BuyQuota(address indexed user, uint256 id, uint256 amount);
    event Claim(address indexed user, uint256 id, uint256 amount);
    event CashLimit(address indexed user, uint256 id, uint256 amount);


    constructor(address _token, address _usdt) {
        token = IERC20(_token);
        USDT = IERC20(_usdt);
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
//    _maxAmount        最大募集额度
//@@@@@@@@@
    function addPair(
        address _pairAddress, uint256 _salesAmount, uint256 _startTime,
        uint256 _endTime, uint256 _withdrawTime, uint256 _maxPerUser, 
        uint256 _prices, uint256 _minAmount, uint256 _maxAmount
    ) public onlyAdmin{
        for(uint256 i = 0; i < pairLength(); i++){
            require(pairInfo[i].pairToken != IERC20(_pairAddress), "Pair is existed");
        }

        IERC20 pToken = IERC20(_pairAddress);

        require(_startTime > block.timestamp,"Invalid Time");
        require(_endTime > _startTime, "Invalid strartTime");
        require(_withdrawTime > _endTime, "Invalid withdrawTime");
        require(token.balanceOf(msg.sender) >= _salesAmount, "Not enough token amount");

        token.transferFrom(msg.sender, address (this), _salesAmount);

        pairInfo.push(PairInfo({
        pairToken: pToken,
        salesAmount: _salesAmount,
        totalAmount: 0,
        claimAmount: 0,
        usdtAmount: 0,
        startTime: _startTime,
        endTime: _endTime,
        withdrawTime: _withdrawTime,
        maxPerUser: _maxPerUser,
        price: _prices,
        minAmount: _minAmount,
        maxAmount: _maxAmount
        }));

        emit AddPair(msg.sender, _pairAddress, _salesAmount, _startTime,_endTime, _maxPerUser, _prices);
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
        require(pair.totalAmount + _amount <= pair.maxAmount,"More than MaxAmount");
        require(user.buyAmount + _amount <= pair.maxPerUser,"More than MaxPerUser");
        pair.pairToken.transferFrom(msg.sender, address(this), _amount);
        user.buyAmount += _amount;
        pair.totalAmount += _amount;
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
        require(pair.totalAmount >= pair.minAmount, "IDO Failed");
        if(user.balance == 0 ){
            user.balance = getTokenAmount(_pid);
        }
        require(user.balance > 0,"Not enough balance");
        USDT.transferFrom(msg.sender, address(this), user.balance * pair.price);
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

    function pairLength() public view returns(uint256){
        return pairInfo.length;
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
        return pair.totalAmount >= pair.minAmount;
    }

}
