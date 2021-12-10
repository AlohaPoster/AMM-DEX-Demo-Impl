pragma solidity =0.5.16;

import './interface/IERC20.sol';
import './libraries/SafeMath.sol';

contract DemoDEXPair is IERC20 {
    using SafeMath  for uint;

    // ============================== ERC20 implementation (LP Token For This Pair) ====================================
    string public constant name = 'DemoDEXLPToken';
    string public constant symbol = 'DDLP';
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) public allowance;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function _transfer(address from, address to, uint value) internal {
        require(to != address(0));
        require(balanceOf[from] >= value);
        require(balanceOf[to] + value > balanceOf[to]);
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function transfer(address to, uint256 value) public returns (bool){
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint value) public returns (bool) { 
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool){
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // LP 为池子增加流动性，为其铸造LPToken, value为流动性值
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }
    
    // LP 向池子赎回流动性
    function _burn(address from, uint value) internal {
        require(balanceOf[from] >= value, 'Error : Account LiqudityToken not sufficient');
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }
   

    // ============================== Pair implenmentataion ====================================

    uint public constant MINIMUM_LIQUIDITY = 1000;
    uint public constant PREMIUM = 10; // 1% 的手续费

    // token0 < token1
    address public factory;
    address public token0;
    address public token1;
    uint112 private numToken0;          
    uint112 private numToken1; 
    IERC20 public IERC20Token0;
    IERC20 public IERC20Token1;          

    // 通过锁来防重入攻击
    uint private mutex = 0;
    function _lock() private {mutex = 1;}
    function _unlock() private {mutex = 0;}

    modifier ReentrantAttack() {
        require(mutex == 0, 'LOCKED, PLEASE WAIT');
        _lock();
        _;
        _unlock();
    }

    //当前区块创建时间不能晚于交易设定的最晚时间deadline
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'Fault : Swap Too Late ');
        _;
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(address indexed sender,uint amount0In, uint amount1In,uint amount0Out,uint amount1Out,address indexed to);

    constructor() public {
        factory = msg.sender;
    }

   function _transferERC20(address whichToken, address from, address to, uint value) private {
        uint which = _whichIsTokenA(whichToken);
        bool success;
        if(which == 0){
            success = IERC20Token0.transferFrom(from, to, value);
        }else {
            success = IERC20Token1.transferFrom(from, to, value);
        }
        require(success, 'Error : IERC20 TranserFrom Fault');
   }

    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, 'Error : Pair Creator must be factory'); 
        token0 = _token0;
        token1 = _token1;
        IERC20Token0 = IERC20(token0);
        IERC20Token1 = IERC20(token1);
    }

    function _updateWithBalance(uint balance0, uint balance1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'Error : OVERFLOW');
        numToken0 = uint112(balance0);
        numToken1 = uint112(balance1);
    }

    function _updateFromIERC20() private {
        numToken0 = uint112(IERC20Token0.balanceOf(address(this)));
        numToken1 = uint112(IERC20Token1.balanceOf(address(this)));
    }

    // 为LP提供流动性代币(已经讲Token转入自己账户)
    function computeLiquidityAndMint(address to) internal ReentrantAttack returns (uint liquidity) {
        uint balance0 = IERC20Token0.balanceOf(address(this));
        uint balance1 = IERC20Token1.balanceOf(address(this));
        uint amount0 = balance0.sub(numToken0);
        uint amount1 = balance1.sub(numToken1);
        require(amount0 > 0 && amount1 > 0,'Error : liquity should be positive number');
        uint _totalSupply = totalSupply; 
        if (_totalSupply == 0) {
            liquidity = sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); 
        } else {
            liquidity = min(amount0.mul(_totalSupply) / numToken0, amount1.mul(_totalSupply) / numToken1);
        }
        require(liquidity > 0, 'Error : liquidity should be positive number');
        _mint(to, liquidity);
        _updateWithBalance(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

   
    function comuteAmountsAndBurn(address to) internal ReentrantAttack returns (uint amount0, uint amount1) {
        uint balance0 = IERC20Token0.balanceOf(address(this));
        uint balance1 = IERC20Token1.balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];
        amount0 = liquidity.mul(balance0) / totalSupply; 
        amount1 = liquidity.mul(balance1) / totalSupply; 
        require(amount0 > 0 && amount1 > 0, 'Error : Liquidity not sufficient in pool');
        _burn(address(this), liquidity);
        IERC20Token0.transfer(to,amount0);
        IERC20Token1.transfer(to,amount1);
        balance0 = IERC20Token0.balanceOf(address(this));
        balance1 = IERC20Token1.balanceOf(address(this));
        _updateWithBalance(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

   
    function _transferTokensForSwap(uint amount0Out, uint amount1Out, address to) internal ReentrantAttack {
        require(amount0Out > 0 || amount1Out > 0, 'Error : Transfer amount should be positive either');
        require(amount0Out < numToken0 && amount1Out < numToken1, 'Error : Assert in Pool not sufficient');
        require(to != token0 && to != token1, 'Error : Transfer address invalid');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        if (amount0Out > 0) IERC20Token0.transfer(to, amount0Out); 
        if (amount1Out > 0) IERC20Token1.transfer(to, amount1Out); 
        balance0 = IERC20Token0.balanceOf(address(this));
        balance1 = IERC20Token1.balanceOf(address(this));
        }
        uint amount0In = balance0 >= numToken0 - amount0Out ? balance0 - (numToken0 - amount0Out) : 0;
        uint amount1In = balance1 >= numToken1 - amount1Out ? balance1 - (numToken1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Error : insufficient input amount');
        _updateWithBalance(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }


    // ============================== Liquidity Change implenmentataion ====================================

    event SwapToken(address from, address to, uint loseNum, uint getNum);

    // 为LP计算流动性提供量
    function _computeLiquidityAmount(address tokenA,address tokenB,uint desiredAmountA,uint desiredAmountB,uint minAmountA,uint minAmountB) internal view returns (uint amountA, uint amountB) {
        (uint numTokenA, uint numTokenB) = _sortedTokenNum(tokenA, tokenB);
        if (numToken0 == 0 && numToken1 == 0) {
            (amountA, amountB) = (desiredAmountA, desiredAmountB);
        } else {
            uint amountBOptimal = _getAssertNumForInsert(desiredAmountA, numTokenA, numTokenB);
            if (amountBOptimal <= desiredAmountB) {
                require(amountBOptimal >= minAmountB, 'Use desiredA, minAmoutB is to big');
                (amountA, amountB) = (desiredAmountA, amountBOptimal);
            } else {
                uint amountAOptimal = _getAssertNumForInsert(desiredAmountB, numTokenB, numTokenA);
                assert(amountAOptimal <= desiredAmountA);
                require(amountAOptimal >= minAmountA, 'Use desiredb, minAmoutA is to big');
                (amountA, amountB) = (amountAOptimal, desiredAmountB);
            }
        }
    }

    // LP 增加流动性，获取流动性代币
    function addLiquidity(address tokenA,address tokenB,uint amountADesired,uint amountBDesired,uint amountAMin,uint amountBMin,address to,uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _computeLiquidityAmount(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        _transferERC20(tokenA, msg.sender, address(this), amountA);
        _transferERC20(tokenB, msg.sender, address(this), amountB);
        liquidity = computeLiquidityAndMint(to);
    }

    function removeLiquidity(address tokenA,address tokenB,uint liquidity,uint amountAMin,uint amountBMin,address to,uint deadline
    ) public ensure(deadline) returns (uint amountA, uint amountB) {
        _transfer(msg.sender, address(this), liquidity); 
        (uint amount0, uint amount1) = comuteAmountsAndBurn(to); 
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'Error : a amount not sufficient in pool');
        require(amountB >= amountBMin, 'Error : b amount not sufficient in pool');
    }

    // A即numTokenA, B即numTokenB
    // 交易过程，假定用户要 Sold TokenA , A0个, Buy TokenB, B0个（即使用TokenA去交换TokenB）
    function _swap(uint numToSlod, uint numToBuy, address whichToSold, address whichToBuy, address _to) internal {
        (uint amount0Out, uint amount1Out) = (whichToSold < whichToBuy) ? (numToSlod, numToBuy) : (numToBuy, numToSlod);
        _transferTokensForSwap(amount0Out, amount1Out, _to);
    }

    // vSwap ，虚拟交换，可用于查看价格，不真正进行代币交换，调用交易无需附带TokenA 
    function vSwapWithFixedSold(uint A0, uint desiredB0Min, address tokenA) external view returns(uint realB0, bool ok){
        uint whichA = _whichIsTokenA(tokenA);
        if (whichA == 0) {
            realB0 = _getPriceWithFixedSold(A0, numToken0, numToken1);
        } else {
            realB0 = _getPriceWithFixedSold(A0, numToken1, numToken0); 
        }
        ok = (realB0 >= desiredB0Min) ? true : false;
    }

    function vSwapWithFixedBuy(uint B0, uint desiredA0Max, address tokenA) external view returns(uint realA0, bool ok) {
        uint whichA = _whichIsTokenA(tokenA);
        if (whichA == 0) {
            realA0 = _getPriceWithFixedBuy(B0, numToken0, numToken1);
        } else {
            realA0 = _getPriceWithFixedBuy(B0, numToken1, numToken0); 
        }
        ok = (realA0 <= desiredA0Max) ? true : false;
    }

    // 价格合适将直接进行Token swap
    function swapWithFixedSold(uint A0,uint desiredB0Min,address tokenA,uint deadline) external ensure(deadline) returns (bool) {
        uint whichA = _whichIsTokenA(tokenA);
        uint realB0;
        if (whichA == 0) {
            realB0 = _getPriceWithFixedSold(A0, numToken0, numToken1);
        } else {
            realB0 = _getPriceWithFixedSold(A0, numToken1, numToken0); 
        }
        address _tokenB = (whichA == 0) ? token1 : token0;
        if(realB0 >= desiredB0Min){
            _transferERC20(tokenA, msg.sender, address(this),A0);
            _swap(0, realB0, tokenA, _tokenB, msg.sender);
            return true;
        } 
        return false;
    }

   
    function swapWithFixedBuy(uint B0,uint desiredA0Max,address tokenA,uint deadline) external ensure(deadline) returns (bool) {
        uint whichA = _whichIsTokenA(tokenA);
        uint realA0;
        if (whichA == 0) {
            realA0 = _getPriceWithFixedBuy(B0, numToken0, numToken1);
        } else {
            realA0 = _getPriceWithFixedBuy(B0, numToken1, numToken0); 
        }
        address _tokenB = (whichA == 0) ? token1 : token0;
        if(realA0 <= desiredA0Max){
            _transferERC20(tokenA, msg.sender, address(this), realA0);
            _swap(0, B0, tokenA, _tokenB, msg.sender);
            return true;
        }
        return false;      
    }

    // ============================== Util Functions ====================================

    function min(uint x, uint y) internal pure returns (uint z) {z = x < y ? x : y;}

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _getAssertNumForInsert(uint newNumTokenA, uint numTokenA, uint numTokenB) internal pure returns(uint newNumTokenAnother){
        require(newNumTokenA > 0, 'Error : Added Assert Num should be positive number');
        require(numTokenA > 0 && numTokenA > 0, 'Error : Pool Liquidity not sufficient');
        newNumTokenAnother = newNumTokenA.mul(numTokenB) / numTokenA;
    }

    // [重要说明----！！！]
    // use CFMM (x*y == k) compute "Price"
    // 对于交易者 固定要买的数量 or 固定要卖的数量
    // A即numTokenA, B即numTokenB
    // 交易过程，假定用户要 Sold TokenA , A0个, Buy TokenB, B0个（即使用TokenA去交换TokenB）. 手续费0.5% => A' = A0*(1000 - PREMIUM)/1000 
    // 对池子(A+A')*(B-B0) == k

    // A0是固定的，计算B0的价格
    function _getPriceWithFixedSold(uint A0, uint A, uint B) internal pure returns(uint numTokenAnother){
        require(A0 > 0, 'Error : Swap Num should be positive number');
        require(A > 0 && B > 0, 'Error : Pool Liquidity not sufficient');
        uint Adot = A0.mul(1000-PREMIUM);
        numTokenAnother = (Adot.mul(B)) / (A.mul(1000).add(Adot));
    }

    // B0是固定的，计算A0的价格
    function _getPriceWithFixedBuy(uint B0, uint A, uint B) internal pure returns(uint numTokenAnother){
        require(B0 > 0, 'Error : Swap Num should be positive number');
        require(A > 0 && B> 0, 'Error : Pool Liquidity not sufficient');
        numTokenAnother = (A.mul(B0).mul(1000)) / (B.sub(B0).mul(1000-PREMIUM));
        numTokenAnother = numTokenAnother.add(1); // 保证提供的A0足够，解决整数除法精度消失
    }

    function _whichIsTokenA(address tokenA) internal view returns(uint num){
        require(tokenA != address(0), 'Error : Sold Token zero Address');
        require(tokenA == token0 || tokenA == token1, 'Error : Sold Token NOT in this Pair');
        num = (tokenA == token0) ? 0 : 1;
    }

    function _sortedTokenNum(address tokenA, address tokenB) internal view returns(uint numTokenA, uint numTokenB) {
        (numTokenA, numTokenB) = (tokenA < tokenB) ? (numToken0, numToken1) : (numToken1, numToken0);
    }

}
