// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

 import "@openzeppelin/contracts/access/Ownable.sol";
 import "./Token.sol";
 
contract CarRental {
    string public name = "Car Rental";
    Token token; //Reference to deployed ERC20 Token contract
    address owner;
    address payable wallet; //Address of the owner of Car Rental Shop
    uint public carCount = 0;
    uint tokenConversionRate = 2; //conversion rate between Ether and Token, i.e. 1 Ether = 2 Token
    uint etherMinBalance = 1 ether; //minimum amount of ETH required to start Car rental
    uint tokenMinBalance = etherMinBalance * tokenConversionRate; //minimum amount of Tokens required to start Car rental   
    
    struct Car {
        //edited
        uint carId; // Id of the car
        string carBrand;  // characteristcs of the car
        string color;
        string carType;
        uint rentPerHour;
        uint securityDeposit;
        bool notAvailable;
        bool damage;
        address customer; 
    }

    struct Customer { 
        uint carId; // Id of rented Car       
        bool isRenting; // in order to start renting, `isRenting` should be false
        uint etherBalance; // customer internal ether account
        uint tokenBalance; // customer internal token account
        uint startTime; //starting time of the rental (in seconds)
        uint etherDebt; // amount in ether owed to Car Rental Shop
        
        //edited
        bool existence;
    }    

    mapping (address => Customer) customers ; // Record with customers data (i.e., balance, startTie, debt, rate, etc)
    mapping (uint => Car) Cars ; // Stock of Cars    

    modifier onlyCompany() {
        require(msg.sender == wallet, "Only company can access this");
        _;
    }
   
    modifier OnlyWhileNoPending(){
        require(customers[msg.sender].etherDebt == 0, "Not allowed to rent if debt is pending");
        _;
    }

    modifier OnlyWhileAvailable(uint carId){
        require(!Cars[carId].notAvailable, "Car not available");
        _;
    }

    modifier OnlyOneRental(){
        require(!customers[msg.sender].isRenting, "Another car rental in progress. Finish current rental first");
        _;
    }

    modifier EnoughRentFee(){
        require(customers[msg.sender].etherBalance >= etherMinBalance || customers[msg.sender].tokenBalance >= tokenMinBalance, "Not enough funds in your account");
        _;
    }
    
    modifier sameCustomer(uint carId) {
        require(msg.sender == Cars[carId].customer, "No previous agreement found with you & company");
        _;
    }
    
    modifier Notdamage(uint carId){
        require(!Cars[carId].damage, "Car damage");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Function accessible only by the owner");
        _;
    }

    modifier onlyCustomer() {
        require(msg.sender != owner, "Function accessible only by the customer");
        _;
    }

   // event RentalStart(address _customer, uint _startTime, uint _rate, uint carId, uint _blockId);
    event RentalStop(address _customer, uint _stopTime, uint _totalAmount, uint _totalDebt, uint _blockId);
    event FundsReceived(address _customer, uint _etherAmount, uint _tokenAmount);
    event FundsWithdrawned(address _customer);
    event FundsReturned(address _customer, uint _etherAmount, uint _tokenAmount);
    event BalanceUpdated(address _customer, uint _etherAmount, uint _tokenAmount);
    event TokensReceived(address _customer, uint _tokenAmount);    
    event DebtUpdated (address _customer, uint _origAmount, uint _pendingAmount, uint _debitedAmount, uint _tokenDebitedAmount);
    event TokensBought (address _customer,uint _etherAmount, uint _tokenAmount);

    constructor (Token _token) payable {
        token = _token;
        owner = msg.sender;
        wallet = payable(msg.sender);
    } 

    function addCar(uint _carId, string memory _carBrand, string memory _color, string memory _type, uint _rent) public onlyOwner {
        require(Cars[_carId].customer == address(0), "Car ID already occupied");
        uint _deposit = _rent * 3;
        Cars[_carId] = Car(_carId, _carBrand, _color, _type, _rent, _deposit, false, false, owner);
        carCount += 1;
    }

    function autoAddCar() public onlyOwner {
        addCar(1001, "Benz", "Silver", "AMG", 1 ether);
        addCar(1002, "Benz", "Black", "AMG", 1 ether);
        addCar(1003, "Audi", "White", "A6", 1 ether);
        addCar(1004, "Audi", "Black", "A6", 1 ether);
        addCar(1005, "McLaren", "Orange", "P1", 10 ether);
        addCar(1006, "Boeing", "White", "787", 100 ether);
    }

    function viewCar(uint _carId) public view returns (uint, string memory, string memory, string memory, uint, uint, string memory, bool, address) {
        Car memory temp = Cars[_carId];
        string memory status;
        if (temp.notAvailable){
            status = "Occupied";
        }
        else{
            status = "Available";
        }
        return (temp.carId, temp.carBrand, temp.color, temp.carType,
            temp.rentPerHour/1000000000000000000,
            temp.securityDeposit/1000000000000000000,
            status, temp.damage, temp.customer
        );
    }

    function buyTokens() payable public {
        require(msg.value > 0, "You need to send some Ether");
        uint tokensTobuy = msg.value * tokenConversionRate;
        uint rentalBalance = token.balanceOf(address(this));        
        require(tokensTobuy <= rentalBalance, "Not enough tokens in the reserve");
        token.transfer(msg.sender, tokensTobuy);
        wallet.transfer(msg.value);
        emit TokensBought(msg.sender, msg.value, tokensTobuy);
    }

    function testTokenBalance() public view returns(uint){
        return token.balanceOf(address(this));
    }

    function transferFunds() payable public {
        uint amount = token.allowance(msg.sender, address(this));
        _updateBalances(msg.sender , msg.value);
        if (customers[msg.sender].etherDebt > 0) {
            _updateStandingDebt(msg.sender,customers[msg.sender].etherDebt);
        }
        emit FundsReceived(msg.sender, msg.value, amount);
    }

    function _returnFunds(address payable _customer) private{
        uint tokenAmount = customers[_customer].tokenBalance;
        token.transfer(_customer, tokenAmount);
        customers[_customer].tokenBalance = 0;
        uint etherAmount = customers[_customer].etherBalance;
        _customer.transfer(etherAmount);
        customers[_customer].etherBalance= 0;
        emit FundsReturned(_customer, etherAmount, tokenAmount);
    }
    
    function withdrawFunds() public {
        require(!customers[msg.sender].isRenting, "Bike rental in progress. Finish current rental first");        
        if (customers[msg.sender].etherDebt > 0) {
            _updateStandingDebt(msg.sender,customers[msg.sender].etherDebt);
        }
        _returnFunds(payable(msg.sender));
        emit FundsWithdrawned(msg.sender);
    }

    function _updateBalances(address _customer, uint _ethers) private {        
        uint amount = 0;
        if (_ethers > 0) {             
            customers[_customer].etherBalance += _ethers;             
        }
        if (token.allowance(_customer, address(this)) > 0){
            amount = token.allowance(_customer, address(this));
            token.transferFrom(_customer, address(this), amount);
            customers[_customer].tokenBalance += amount;            
            emit TokensReceived(_customer, amount);
        }
        emit BalanceUpdated(_customer, _ethers, amount);
    }

    function _updateStandingDebt(address _customer, uint _amount) private returns (uint) {
        uint tokenPendingAmount = _amount * tokenConversionRate;
        uint tokensDebitedAmount=0;
        
        //First try to cancel pending debt with tokens available in customer's token account balance        
        if (customers[_customer].tokenBalance >= tokenPendingAmount){            
            customers[_customer].tokenBalance -= tokenPendingAmount;
            customers[_customer].etherDebt = 0;
            tokensDebitedAmount = tokenPendingAmount;
            emit DebtUpdated(_customer, _amount , 0, 0, tokensDebitedAmount);
            return 0;
        }
        else {
            tokenPendingAmount -= customers[_customer].tokenBalance;
            tokensDebitedAmount = customers[_customer].tokenBalance;
            customers[_customer].tokenBalance = 0;
            customers[_customer].etherDebt = tokenPendingAmount / tokenConversionRate;
        }
        //If debt pending amount > 0, try to cancel it with Ether available in customer's Ether account balance 
        uint etherPendingAmount = tokenPendingAmount / tokenConversionRate;
        if (customers[_customer].etherBalance >= etherPendingAmount){
            customers[_customer].etherBalance -= etherPendingAmount;
            wallet.transfer(etherPendingAmount);
            customers[_customer].etherDebt = 0;
            emit DebtUpdated(_customer, _amount , 0, etherPendingAmount, tokensDebitedAmount);
            return 0;
            
        }
        else {
            etherPendingAmount -= customers[_customer].etherBalance;
            uint debitedAmount = customers[_customer].etherBalance;
            wallet.transfer(debitedAmount);
            customers[_customer].etherDebt = etherPendingAmount;
            customers[_customer].etherBalance = 0;
            emit DebtUpdated(_customer, _amount , customers[_customer].etherDebt, debitedAmount, tokensDebitedAmount);
            return customers[_customer].etherDebt;
        }
    }

    function startRental(uint _carId) public payable onlyCustomer {
        // (modifiers:) onlyCompany OnlyWhileNoPending OnlyWhileAvailable(_carId) OnlyOneRental EnoughRentFee sameCustomer(_carId) Notdamage(_carId)
        //check the status of car
        require(Cars[_carId].customer != address(0), "Car not exist");
        require(!Cars[_carId].notAvailable, "Car not available"); // OnlyWhileAvailable
        require(!Cars[_carId].damage, "Car damage"); // Notdamage

        //check the status of customer
        require(customers[msg.sender].etherDebt == 0, "Not allowed to rent if debt is pending");
        _updateBalances(msg.sender, msg.value);        
        uint etherBalance = customers[msg.sender].etherBalance;
        uint tokenBalance = customers[msg.sender].tokenBalance;
        require(etherBalance >= etherMinBalance || tokenBalance >= tokenMinBalance, "Not enough funds in your account");
        require(etherBalance >= Cars[_carId].securityDeposit, "Not enough funds to fulfill security deposit");

        //customer status updated
        customers[msg.sender].existence = true;
        customers[msg.sender].isRenting = true;
        customers[msg.sender].startTime = block.timestamp;
        customers[msg.sender].carId = _carId;

        //car status updated
        Cars[_carId].notAvailable = true;
        Cars[_carId].customer = msg.sender;
    }

    function stopRental() external onlyCustomer returns(uint, uint) {
        require(customers[msg.sender].isRenting = true, "You are not renting a car");
        uint startTime = customers[msg.sender].startTime;
        uint stopTime = block.timestamp;
        uint totalTime = stopTime - startTime;

        uint _carId = customers[msg.sender].carId;

        //balance settlement
        uint amountToPay = Cars[_carId].rentPerHour * totalTime / 3600;
        uint etherPendingAmount = _updateStandingDebt(msg.sender, amountToPay);
        if (etherPendingAmount == 0){
            _returnFunds(payable(msg.sender));
        }

        //update car status
        Cars[_carId].notAvailable = false;
        Cars[_carId].customer = owner;
        
        //update customer status
        customers[msg.sender].carId = 0;
        customers[msg.sender].isRenting = false;
        
        return (totalTime, amountToPay);
    }

    //truffle testing functions     

    function getDebt(address customer) public view returns (uint) {
        return customers[customer].etherDebt;
    }
    
    function getEtherAccountBalance(address customer) public view returns (uint) {
        return customers[customer].etherBalance;
    }

    function getEtherAccountBalanceinEther() public view returns (uint) {
        return customers[msg.sender].etherBalance/1000000000000000000;
    }

    function getTokenAccountBalance(address customer) public view returns (uint) {
        return customers[customer].tokenBalance;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }

    function viewCurrentUser() public view returns (address) {
        return msg.sender;
    }

    function checkCustomerStatus() public view onlyCustomer returns(string memory, uint, uint){
        require(customers[msg.sender].existence, "Customer not exist");
        Customer memory temp = customers[msg.sender];
        string memory rent;
        uint cid;
        if (temp.isRenting){
            rent = "Is Renting";
            cid = temp.carId;
        }
        else{
            rent = "Not Renting";
        }
        return (rent, cid, temp.startTime);
    }
}