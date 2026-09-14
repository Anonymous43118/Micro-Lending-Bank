// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank {
    address public owner;
    mapping(address => uint256) public balances;
    
    constructor(){
        owner = msg.sender;
    }

    modifier isOwner(){
        require(msg.sender == owner, "Not owner");
        _;
    }

    event TransferLogged(address indexed from, address indexed to, uint256 amount);
    event WithdrawLogged(address indexed to, uint256 amount); 

    // 存款功能
    function deposit() public payable {
        balances[msg.sender] += msg.value;
    } 

    // 提款功能
    function withdraw(uint256 _amount) public {
        require(balances[msg.sender] >= _amount, "The balance is not enough!");
        balances[msg.sender] -= _amount;
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Transfer of ETH failed");

        emit WithdrawLogged(msg.sender, _amount);
    } 
    
    // 轉帳功能
    function transfer(address _to, uint256 _amount) external {
        require(_to != address(0), "Can't transfer to address 0");
        require(_to != msg.sender, "Cannot transfer to yourself");
        require(balances[msg.sender] >= _amount, "The balance is not enough!");
        
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        emit TransferLogged(msg.sender, _to, _amount); //
    }
}
