pragma solidity ^0.5;
import "./Oraclize.sol";

contract Lottery is usingOraclize {

  uint number_participants;
  address payable[] participants;
  address creator;

  modifier minAmount() {
    require(msg.value > 1 ether);
    _;
  }

    modifier onlyCreator() {
    require(msg.sender == creator);
    _;
  }

  modifier nonZeroBalance(){
    require(address(this).balance > 0);
    _;
  }

  event drew(
    address indexed winner,
    uint amount
  );

  event LogNewOraclizeQuery(string description);

  constructor() public {
    creator = msg.sender;
    OAR = OraclizeAddrResolverI(0x6f485C8BF6fc43eA212E93BBF8ce046C7f1cb475);
  }

  function bet() public payable minAmount {
    participants.push(msg.sender);
    number_participants++;
  }

  function draw() public payable onlyCreator nonZeroBalance {
    if (oraclize_getPrice("URL") > address(this).balance) {
      emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
      emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");

      // I have to provide the URL to Mathias' web-app implementation of the beacon. (The URL is an API that returns the random value)
      oraclize_query("URL", "");
    }
  }

  function __callback(bytes32 myid, string memory res) public {
      require(msg.sender == oraclize_cbAddress());
      address payable winner = participants[parseInt(res) % number_participants];
      uint amount = address(this).balance;

      winner.transfer(address(this).balance);
      emit drew(winner, amount);
      number_participants = 0;
      delete participants;
  }
}
