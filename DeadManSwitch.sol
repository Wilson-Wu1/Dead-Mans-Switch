//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract DeadManSwitch{

    event Create(address indexed from, address indexed to, uint256 value, uint256 deadline, uint256 amountOfTimeBeforeActivation);
    event CheckIn(address indexed from, uint256 newDeadline);
    event Activate(address indexed from, address indexed to, uint256 value, uint256 deadline);
    event DeadlineChange(address indexed from, uint256 newDeadline, uint256 newAmountOfTimeBeforeActivation);
    event WithdrawFundsEarly(address indexed from, uint256 value, uint256 deadline);

    struct Info{
        uint256 amount;
        uint256 deadline;
        uint256 amountOfTimeBeforeActivation;
        address destination;
    }

    mapping(address => Info) public userDepositInfo;


    //NOTE: User can send funds to 0 address if destination is set to 0 address.
    //Create a new dead man's switch. The amount deposited into this contract can be sent to the destination address once the deadline has been reached.
    function createDeadManSwitch(uint256 _amountOfTimeBeforeActivation, address _destination) payable external{
        require(msg.value > 0, "Cannot create switch with 0 ETH");
        require(_amountOfTimeBeforeActivation > 0, "Cannot create switch with 0 time");
        require(userDepositInfo[msg.sender].amount == 0, "Cannot create multiple switches for an address");
        require(msg.sender != _destination, "Cannot set destination as msg.sender");

        uint256 _deadline =  block.timestamp +_amountOfTimeBeforeActivation;
        userDepositInfo[msg.sender] = Info(msg.value, _deadline, _amountOfTimeBeforeActivation, _destination);
        
        emit Create(msg.sender, _destination, msg.value, _deadline, _amountOfTimeBeforeActivation);
    }

    //Check in on user's dead man's switch, delaying the activation
    function checkIn() external{
        Info storage userInfo = userDepositInfo[msg.sender];
        require(userInfo.amount > 0, "Address does not have a dead man's switch");
        require(block.timestamp <= userInfo.deadline, "Already past switch deadline");

        //Update the deadline
        uint256 updatedDeadline = block.timestamp + userInfo.amountOfTimeBeforeActivation;
        userInfo.deadline = updatedDeadline;

        emit CheckIn(msg.sender, updatedDeadline);
    }

    //Activate a user's dead man's switch and send its deposited amount to the destination address
    function activateDeadManSwitch(address deadUser) external{
        Info storage userInfo = userDepositInfo[deadUser];
        require(userInfo.amount > 0, "Address does not have a dead man's switch");
        require(block.timestamp > userInfo.deadline, "Not past switch deadline");

        //Store values in local var.
        uint256 amountToSend = userInfo.amount;
        address destinationAddress = userInfo.destination;

        emit Activate(msg.sender, destinationAddress, amountToSend, userInfo.deadline);

        delete userDepositInfo[deadUser];

        //Send deposited amount to destination address
        (bool success,) = payable(destinationAddress).call{value : amountToSend}("");
        require(success, "Transfer Failed");
    }


    //NOTE: Function changeDeadline() is optional since it defeats the purpose of a dead man switch.

    //Change the amount of days before switch activation
    //The new deadline is calculated by the current timestamp + newAmountOfDaysBeforeActivation
    function changeDeadline(uint256 newAmountOfTimeBeforeActivation) external{
        Info storage userInfo = userDepositInfo[msg.sender];
        require(userInfo.amount > 0, "Address does not have a dead man's switch");
        require(block.timestamp <= userInfo.deadline, "Already past switch deadline");
        require(newAmountOfTimeBeforeActivation > 0, "Cannot update switch with 0 time");

        uint256 updatedDeadline = block.timestamp + newAmountOfTimeBeforeActivation;
        
        userInfo.deadline = updatedDeadline;
        userInfo.amountOfTimeBeforeActivation = newAmountOfTimeBeforeActivation;

        emit DeadlineChange(msg.sender, updatedDeadline, newAmountOfTimeBeforeActivation);
    
    }
    

    //NOTE: Function withdrawFundsEarly() is optional since it defeats the purpose of a dead man switch.

    //Withdraw the amount deposited into this contract early. Only callable before a dead man's switch deadline.
    function withdrawFundsEarly() external{
        Info storage userInfo = userDepositInfo[msg.sender];
        require(userInfo.amount > 0, "Address does not have a dead man's switch");
        require(block.timestamp <= userInfo.deadline, "Already past switch deadline");

        uint256 amountToSend = userInfo.amount;

        emit WithdrawFundsEarly(msg.sender, amountToSend, userInfo.deadline);

        delete userDepositInfo[msg.sender];

        //Withdraw deposited amount back to switch creator
        (bool success,) = payable(msg.sender).call{value : amountToSend}("");
        require(success, "Transfer Failed");
    }


    //Deposit additional funds to the user's exisiting switch
    function addToExisitingSwitch() payable external{
        Info storage userInfo = userDepositInfo[msg.sender];
        require(userInfo.amount > 0, "Address does not have a dead man's switch");
        require(block.timestamp <= userInfo.deadline, "Already past switch deadline");
        require(msg.value > 0, "Must add non-zero amount to exisiting switch");
        
        userInfo.amount += msg.value;

        emit AddToExisitingSwitch(msg.sender, msg.value, userInfo.amount, userInfo.deadline);
    }

}
