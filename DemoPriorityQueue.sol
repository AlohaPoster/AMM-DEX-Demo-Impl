pragma solidity = 0.5.16;

import './DemoDEXOrder.sol';

contract DemoPriorityQueue {
    uint[] minDeadline;
    uint[] minDeadlineId;
    uint256[] heap;
    uint size = 0;
    uint capacity = 0;
    mapping(uint256 => bool) valid;
    mapping(uint256 => uint) location;

    address creator;
    address orderlist;

    constructor(address _orderlist) public {
        creator = msg.sender;
        orderlist = _orderlist;
    }
 
    function _swap(uint loc0, uint loc1) private {
        require(loc0 < size, 'Error: PriorityQueue swap with invalid loc0');
        require(loc1 < size, 'Error: PriorityQueue swap with invalid loc1');
        uint256 temp = heap[loc0];
        heap[loc0] = heap[loc1];
        heap[loc1] = temp;
        location[heap[loc0]] = loc0;
        location[heap[loc1]] = loc1;
    }

    function _father(uint loc) private pure returns (uint) { return (loc - 1) >> 1; }
    function _leftson(uint loc) private pure returns (uint) { return (loc << 1) + 1; }
    function _rightson(uint loc) private pure returns (uint) { return (loc << 1) + 2; }

    function _update(uint loc) private {
        minDeadline[loc] = DemoDEXOrder(orderlist).getDeadline(heap[loc]);
        minDeadlineId[loc] = heap[loc];
        for (uint child = _leftson(loc); child < size && child <= _rightson(loc); child ++) {
            if (minDeadline[loc] < minDeadline[child]) {
                minDeadline[loc] = minDeadline[child];
                minDeadlineId[loc] = minDeadlineId[child];
            }
        }
    }

    function _updateChain(uint loc) private {
        _update(loc);
        while (loc > 0) {
            loc = _father(loc);
            _update(loc);
        }
    }

    function _adjustUp(uint loc) private returns (uint) {
        while (loc > 0) {
            if (DemoDEXOrder(orderlist).lower(heap[loc], heap[_father(loc)])) {
                _swap(loc, _father(loc));
                loc = _father(loc);
            } else {
                break;
            }
        }
        return loc;
    }

    function _adjustDown(uint loc) private returns (uint) {
        while (_leftson(loc) < size) {
            uint child = (_rightson(loc) < size && DemoDEXOrder(orderlist).lower(heap[_rightson(loc)], heap[_leftson(loc)])) ? (_rightson(loc)) : (_leftson(loc));
            if (DemoDEXOrder(orderlist).lower(heap[child], heap[loc])) {
                _swap(child, loc);
                loc = child;
            } else {
                break;
            }
        }
        return loc;
    }

    function addOrder(uint256 id) public {
        require(msg.sender == creator, 'Error: PriorityQueue on Creator can add order');
        require(!valid[id], 'Error: PriorityQueue add existed order');
        valid[id] = true;
        if (size < capacity) {
            heap[size] = minDeadlineId[size] = id;
            minDeadline[size] = DemoDEXOrder(orderlist).getDeadline(id);
        } else {
            heap.push(id);
            minDeadline.push(DemoDEXOrder(orderlist).getDeadline(id));
            minDeadlineId.push(id);
            capacity ++;
        }
        location[id] = size;
        size++;
        _adjustUp(size - 1);
        _updateChain(size - 1);
    }

    function getSize() public view returns (uint) {
        return size;
    }

    function getFrontOrderId() public view returns (uint256) {
        require(size > 0, 'Error: PriorityQueue is empty');
        return heap[0];
    }

    function popFrontOrderId() public returns (uint256 id) {
        require(msg.sender == creator, 'Error: PriorityQueue on Creator can delete order');
        require(size > 0, 'Error: PriorityQueue is empty');
        id = heap[0];
        valid[id] = false;
        if (size > 1) {
            _swap(0, size - 1);
            size --;
            _updateChain(_father(size));
            _updateChain(_adjustDown(0));
        } else {
            size --;
        }
    }
 
    function removeOrderWithId(uint id) public {
        require(msg.sender == creator, 'Error: PriorityQueue on Creator can delete order');
        require(valid[id], 'Error: PriorityQueue remove not existed order');
        uint loc = location[id];
        valid[id] = false;
        if (size > 1) {
            if (loc != size - 1) {                                                             // delete element at loc
                _swap(loc, size - 1);                                                          // swap heap[loc] and heap[last]
                size --;                                                                       // remove heap[last]
                _updateChain(_father(size));                                                   // update deadline info from father(last) to root
                if (loc > 0 && DemoDEXOrder(orderlist).lower(heap[loc], heap[_father(loc)])) { // adjustup(loc) or adjustdown(loc)
                    _adjustUp(loc);                                                            // up(loc)
                    _updateChain(loc);                                                         // update from loc to root
                } else {
                    _updateChain(_adjustDown(loc));                                            // down(loc) and update from result to root
                }
            } else {                                                                           // delete last element
                size --;
                _updateChain(_father(size));
            }
        } else {                                                                               // delete the only element
            size --;
        }
    }

    function popMinDeadlineOrderId() public returns (uint256 id) {
        require(msg.sender == creator, 'Error: PriorityQueue on Creator can delete order');
        require(size > 0, 'Error: PriorityQueue is empty');
        id = minDeadlineId[0];
        removeOrderWithId(id);
    }
    
    function getMinDeadlineOrderId() public view returns (uint256) {
        require(size > 0, 'Error: PriorityQueue is empty');
        return minDeadlineId[0];
    }

    function getNext(uint256 id) public view returns (uint256 left, uint256 right) {
        left = right = 0;
        require(valid[id], 'Error: PriorityQueue getNext from not existed order');
        uint loc = location[id];
        if (_leftson(loc) < size) left = heap[_leftson(loc)];
        if (_rightson(loc) < size) right = heap[_rightson(loc)];
    }
}