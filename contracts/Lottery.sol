pragma solidity ^0.5.0;
import "./Oraclize.sol";
import "./JsmnSolLib.sol";
import "./BytesLib.sol";

contract Precompile {
  function bigModExp (uint, uint, uint, bytes memory, bytes memory, bytes memory) public returns (bytes memory);
}

contract Lottery is usingOraclize {

  uint number_participants;
  address payable[] participants;
  address creator;
  bytes random;
  string result;

  // Set minimum betting amount = 1 ether
  modifier minAmount() {
    require(msg.value > 1 ether);
    _;
  }

  // Ensure only the lottery owner can call certain methods
  modifier onlyCreator() {
    require(msg.sender == creator);
    _;
  }

  // Ensure that contract has a non-zero balance before performing a draw
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

      random = bytes(result);
      uint randm = parseInt(result);
      address payable winner = participants[randm % number_participants];
      uint amount = address(this).balance;

      winner.transfer(address(this).balance);
      emit drew(winner, amount);
      number_participants = 0;
      delete participants;
    }
  }

  function verify() public payable returns (bool) {
    if (oraclize_getPrice("URL") > address(this).balance) {
      emit LogNewOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
    } else {
      emit LogNewOraclizeQuery("Oraclize query was sent, standing by for the answer..");

      // Endpoint to obtain proof
      oraclize_query("URL", "");

      /*
          result = 
          {
            "proof" : " ",
            "exponent" : " ", =  2 * #iterations
            "mod" : " "
          }
      */

      /*****************************Parsing the proof sent by the beacon*****************************/
      uint returnValue;
      JsmnSolLib.Token[] memory tokens;
      uint actualNum;
      (returnValue, tokens, actualNum) = JsmnSolLib.parse(result, 6);
      
      JsmnSolLib.Token memory t;

      t = tokens[2];
      string memory proof = JsmnSolLib.getBytes(result, t.start, t.end);
      bytes memory proofBytes = bytes(proof);

      t = tokens[4];
      string memory exponent = JsmnSolLib.getBytes(result, t.start, t.end);
      bytes memory exponentBytes = bytes(exponent);

      t = tokens[6];
      string memory modulus = JsmnSolLib.getBytes(result, t.start, t.end);
      bytes memory modulusBytes = bytes(modulus);
      /**********************************************************************************************/

      /************************Modular squaring verification using precompile************************/
      Precompile modExp = Precompile(0x0000000000000000000000000000000000000005);

      bytes memory verf = modExp.bigModExp(random.length, exponentBytes.length, modulusBytes.length, 
                                          random, exponentBytes, modulusBytes);

      if (BytesLib.equal(proofBytes, verf))
        return true;
      else
        return false;
      /**********************************************************************************************/

    }
  }

  function __callback(bytes32 myid, string memory res) public {
      require(msg.sender == oraclize_cbAddress());
      result = res;
  }
}
