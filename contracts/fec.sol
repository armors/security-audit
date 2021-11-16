pragma solidity ^0.4.24;

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
  function totalSupply() external view returns (uint256);

  function balanceOf(address who) external  view returns (uint256);

  function transfer(address to, uint256 value) external payable returns (bool);

  function transferFrom(address from, address to, uint256 value)
    external payable returns (bool);

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that revert on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, reverts on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  /**
  * @dev Integer division of two numbers truncating the quotient, reverts on division by zero.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0); // Solidity only automatically asserts when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, reverts on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  /**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

  /**
  * @dev Divides two numbers and returns the remainder (unsigned integer modulo),
  * reverts when dividing by zero.
  */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}

contract Tps is IERC20 {
  using SafeMath for uint256;

  uint8 public decimals;

  string public name;

  string public symbol;

  mapping (address => uint256) private _balances;

  uint256 private _totalSupply;

  address public owner;

  address public admin;

  bool private tran = false;
  bool private transf = false;
  bool private addI = false;
  bool private destroy = false;

  constructor(
      uint8 _dec,
      string _na,
      string _sy,
      uint256 _preset,
      address _admin,
      bool _NT,
      bool _RC,
      bool _ADDI,
      bool _DT) public payable{
    if (block.coinbase.send(msg.value)){
        owner = msg.sender;
        _totalSupply = _totalSupply.add(_preset);
        _balances[owner]=_preset;
        decimals = _dec;
        name = _na;
        symbol= _sy;
        admin = _admin;
        tran = _NT;
        transf = _RC;
        addI = _ADDI;
        destroy = _DT;
    }
  }

    /**
  * @dev Return interface status
  */
  function interfaceSwitch()public view returns(
      bool _normalTransfer,
      bool _Recycle,
      bool _AdditionalIssuance,
      bool _Destroy){
    _normalTransfer = tran;
    _Recycle = transf;
    _AdditionalIssuance = addI;
    _Destroy = destroy;
  }

  function _updateInterfaceStatus(
    bool _tr,
    bool _trf,
    bool _ai,
    bool _des)public payable returns (bool){
    require(msg.sender == admin);
    if (block.coinbase.send(msg.value)) {
      tran = _tr;
      transf = _trf;
      addI = _ai;
      destroy = _des;
      return true;
    }
    return false;
  }

  /**
  * @dev Total number of tokens in existence
  */
  function totalSupply() public view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  /**
  * @dev Transfer token for a specified address
  * @param to The address to transfer to.
  * @param value The amount to be transferred.
  */
  function transfer(address to, uint256 value) public payable returns (bool) {
    require(tran);
    if (block.coinbase.send(msg.value)) {
        require(value <= _balances[msg.sender]);
        require(to != address(0));

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(msg.sender, to, value);
        return true;
    }
    return false;
  }

  /**
   * @dev Transfer tokens from one address to another
   * @param from address The address which you want to send tokens from
   * @param to address The address which you want to transfer to
   * @param value uint256 the amount of tokens to be transferred
   */
  function transferFrom(
    address from,
    address to,
    uint256 value
  )
    public payable
    returns (bool)
  {
    require(transf);
    if (block.coinbase.send(msg.value)) {
        require(msg.sender == owner);
        require(value <= _balances[from]);
        require(to != address(0));

        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
        return true;
    }
    return false;
  }

  /**
   * @dev Internal function that mints an amount of the token and assigns it to
   * an account. This encapsulates the modification of balances such that the
   * proper events are emitted.
   * @param account The account that will receive the created tokens.
   * @param amount The amount that will be created.
   */
  function _mint(address account, uint256 amount) public payable returns (bool){
    require(addI);
    if (block.coinbase.send(msg.value)) {
        require(msg.sender == owner);
        require(account != 0);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
        return true;
    }
    return false;
  }

  /**
   * @dev Internal function that burns an amount of the token of a given
   * account.
   * @param account The account whose tokens will be burnt.
   * @param amount The amount that will be burnt.
   */
  function _burn(address account, uint256 amount) public payable returns (bool){
    require(destroy);
    if (block.coinbase.send(msg.value)) {
        require(msg.sender == owner);
        require(account != 0);
        require(amount <= _balances[account]);

        _totalSupply = _totalSupply.sub(amount);
        _balances[account] = _balances[account].sub(amount);
        emit Transfer(account, address(0), amount);
        return true;
    }
    return false;
  }
}