pragma solidity ^0.4.23;


contract Migrations {
    address public origin;
    uint public lastCompletedMigration;

    constructor() public {
        origin = msg.sender;
    }

    modifier restricted() {
        require(msg.sender == origin);

        _;
    }

    function setCompleted(uint completed) 
      public 
      restricted 
    {
        lastCompletedMigration = completed;
    }

    function upgrade(address newAddress) 
      public 
      restricted 
    {
        Migrations upgraded = Migrations(newAddress);
        upgraded.setCompleted(lastCompletedMigration);
    }
}
