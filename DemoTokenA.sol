
pragma solidity =0.5.16;
import './interface/IERC20.sol';

contract TokenDemo is IERC20 {

    uint256 public totalSupply = 10000*10**18;
    string public constant name = "DemoDEXTestToken0";                  
    uint8 public constant decimals = 18;               
    string public constant symbol = "DTA";  
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;             

    // 测试用， 无限制领取代币
    function getToken(uint256 value) external {
        uint256 addNum = value * 10 ** 18;
        balances[msg.sender] += addNum;
        totalSupply += addNum;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        require(balances[msg.sender] >= _value && balances[_to] + _value > balances[_to]);
        require(_to != address(0));
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }


    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        require(balances[_from] >= _value && allowed[_from][msg.sender] >= _value);
        balances[_to] += _value;
        balances[_from] -= _value; 
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function balanceOf(address _owner) external view returns (uint256 balance) {
        return balances[_owner];
    }


    function approve(address _spender, uint256 _value) external returns (bool)   
    { 
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) external view returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
    
}