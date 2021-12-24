pragma solidity = 0.5.16;

import './libraries/SafeMath.sol';

contract DemoDEXOrder {
    using SafeMath for uint;

    address creator;

    mapping(uint256 => bool) valid;
    mapping(uint256 => bool) isSold;
    mapping(uint256 => uint) creationTime;
    mapping(uint256 => uint) deadline;
    mapping(uint256 => address) fromToken;
    mapping(uint256 => uint) fromNum;
    mapping(uint256 => uint) toNum;
    mapping(uint256 => address) transfer;

    constructor() public {
        creator = msg.sender;
    }

    uint lastNow = 0;
    uint lastSalt = 0;

    function newOrder(bool _isSold, uint _deadline, address _fromToken, uint _fromNum, uint _toNum, address _transfer) public returns (uint256 id) {
        require(msg.sender == creator, 'Error: DemoDEXOrder only Creator can generate new order');
        if (block.timestamp != lastNow) {
            lastNow = block.timestamp;
            lastSalt = 0;
        }
        id = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, lastSalt)));
        lastSalt = lastSalt + 1;
        require(id != 0 && !valid[id], 'Error: DemoDEXOrder new id failed, please try again later');
        valid[id] = true;
        isSold[id] = _isSold;
        creationTime[id] = now;
        deadline[id] = _deadline;
        fromToken[id] = _fromToken;
        fromNum[id] = _fromNum;
        toNum[id] = _toNum;
        transfer[id] = _transfer;
    }

    function deleteOrder(uint256 id) public {
        require(msg.sender == creator, 'Error: DemoDEXOrder only Creator can delete order');
        require(valid[id], 'Error: DemoDEXOrder delete not existed order');
        valid[id] = false;
    }

    function isValid(uint256 id) public view returns (bool) {
        return valid[id];
    }

    function getIsSold(uint256 id) public view returns (bool) {
        require(valid[id], 'Error: DemoDEXOrder getIsSold invalid id');
        return isSold[id];
    }

    function getCreationTime(uint256 id) public view returns (uint) {
        require(valid[id], 'Error: DemoDEXOrder getCreationTime invalid id');
        return creationTime[id];
    }

    function getDeadline(uint256 id) public view returns (uint) {
        require(valid[id], 'Error: DemoDEXOrder getDeadline invalid id');
        return deadline[id];
    }

    function getFromToken(uint256 id) public view returns (address) {
        require(valid[id], 'Error: DemoDEXOrder getFromToken invalid id');
        return fromToken[id];
    }

    function getFromNum(uint256 id) public view returns (uint) {
        require(valid[id], 'Error: DemoDEXOrder getFromNum invalid id');
        return fromNum[id];
    }

    function getToNum(uint256 id) public view returns (uint) {
        require(valid[id], 'Error: DemoDEXOrder getToNum invalid id');
        return toNum[id];
    }

    function getTransfer(uint256 id) public view returns (address) {
        require(valid[id], 'Error: DemoDEXOrder getTransfer invalid id');
        return transfer[id];
    }

    function lower(uint256 left, uint256 right) public view returns (bool) {
        uint Left = getToNum(left).mul(getFromNum(right));
        uint Right = getToNum(right).mul(getFromNum(left)); 
        return (Left < Right || (Left == Right && getCreationTime(left) < getCreationTime(right)));
    }
}