// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RCEToken {

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;
    address private _owner;
    mapping(address => bool) private _AllovanceContracts;
    mapping(address => uint256) private  balances;
    mapping(address => bool) private holders;
    address[] private holderArray;

    uint256 private _tokenPrice = 0;
    uint256 private _contratPrice = 0;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        _name = "Ruddygem Coin Ecosystem Token";
        _symbol = "RCE";
        _decimals = 9;
        _totalSupply = (10 ** _decimals) * (10**_decimals);
        _owner = msg.sender;
        _tokenPrice = 10**17;
        balances[address(this)] = _totalSupply;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // Sadece sahibinin çağırabileceği bir modifier
    modifier onlyOwner() {
        require(msg.sender == _owner, "ERC20: Only the contract owner can call this function");
        _;
    }

    function getOwner() public view returns(address){
        return _owner;
    }

    function transfer(address to, uint256 value) public returns(bool){
        transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) private returns(bool){
        require(to != from, "Can not transfer token to yourself");
        require(to != address(0), "Transfer to the zero address is not allowed");
        require(value <= balances[from], "Insufficient balance");

        balances[from] -= value;
        balances[to] += value;

        //eğer 1000 veya fazla token tutuyorsa holder olarak işaretle
        if (to != address(this)) holders[to] = balances[to] >= 1000 * (10**_decimals);
        holders[from] = balances[from] >= 1000 * (10**_decimals);

        emit Transfer(from, to, value);
        return true;
    }

    function isHolder(address addr) public view returns(bool)
    {
        return holders[addr];
    }

    function spend(address from, uint256 value) public returns(bool){
        require(_AllovanceContracts[msg.sender] || _owner == msg.sender, "Can not spend this token");
        require(from != address(0), "Transfer to the zero address is not allowed");
        require(value <= balances[from], "Insufficient balance");

        balances[from] -= value;
        balances[address(this)] += value;
        transferFrom(from, address(this), value);
        return true;
    }

    function earn(address to, uint256 value) public returns(bool){
        
        require(_AllovanceContracts[msg.sender] || _owner == msg.sender, "Can not use this method");
        require(to != address(0), "Transfer to the zero address is not allowed");
        require(value <= balances[address(this)], "Insufficient balance");

        transferFrom(address(this), to, value);
        return true;
    }

    //token fiyatını değiştirebilecek fonksiyon
    function changeTokenPrice(uint256 price) external onlyOwner
    {
        _tokenPrice = price;
    }

    //kontratın fiyatını değiştirebilecek fonksiyon
    function changeContratPrice(uint256 price) external onlyOwner
    {
        _contratPrice = price;
    }

    //add or remove allowance contract
    function addAllowanceContract(address contractAddress, bool allowance) external onlyOwner
    {
        _AllovanceContracts[contractAddress] = allowance;
    }

    //check allowance contract
    function isAllowanceContract(address contractAddress) external view returns(bool)
    {
        return _AllovanceContracts[contractAddress];
    }

    function buyToken(uint256 amount) external payable returns(bool)
    {
        uint256 totalPrice = _tokenPrice * amount;
        require(amount <= balances[address(this)], "Not enaught tokens in the contract");
        require(msg.value >= totalPrice,"Not enaught coin");
        transferFrom(address(this), msg.sender, amount);
        if (msg.value > totalPrice)
        {
            uint256 refund = msg.value - totalPrice;
            payable(msg.sender).transfer(refund);
        }
        return true;
    }

    function buyThisContrat() external payable returns(bool)
    {
        require(_contratPrice > 0, "This contrat is not open for sale");
        require(msg.value >= _contratPrice, "value not enaught for buy This Contrat");
        require(msg.sender != _owner, "You already owner");
        payable(_owner).transfer(address(this).balance);
        _owner = msg.sender;
        return true;
    }

    function getBalance() external onlyOwner
    {
        payable(_owner).transfer(address(this).balance);
    }

}
