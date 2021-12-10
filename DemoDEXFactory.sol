pragma solidity =0.5.16;

import './DemoDEXPair.sol';

contract DemoDEXFactory  {
    mapping(address => mapping(address => address)) public pairsHashMap;
    address[] public pairsArrayInFactory;
    event PairCreatedSuccess(address indexed A, address indexed B, address pair, uint order);

    function PairsNumInFactory() external view returns (uint) {
        return pairsArrayInFactory.length;
    }

    // 用来创建ERC20交易对（以两个Token Address确定唯一性）
    function createPair(address A, address B) external returns (address pair) {
        require(A != B, 'Error : same token address');
        require(A != address(0) && B != address(0),'Error : contains zero address');
        require(pairsHashMap[A][B] == address(0), 'Error : pair already exist');
        
        bytes memory bytecode = type(DemoDEXPair).creationCode;
        // 由Pair创建过程保证Pair中 token0 < token1 (st --> token0, bt --> token1)
        (address st, address bt) = A < B ? (A, B) : (B, A);
        bytes32 salt = keccak256(abi.encodePacked(st, bt));
        // 使用Yul语言进行内联汇编
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        DemoDEXPair(pair).initialize(st, bt);
        pairsHashMap[A][B] = pair;
        pairsHashMap[B][A] = pair; // populate mapping in the reverse direction
        pairsArrayInFactory.push(pair);
        emit PairCreatedSuccess(st, bt, pair, pairsArrayInFactory.length);
        return pair;
    }

}