pragma solidity ^0.4.24;

contract Migrations {
  address public _originAddress;
  uint public lastCompletedMigration;

  constructor() public {
    _originAddress = msg.sender;
  }

  modifier restricted() {
    require(msg.sender == _originAddress);

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
