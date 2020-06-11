pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;
    

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    address[] airlines;
    mapping(address => bool) private RegisteredAirline;
    mapping(address => uint256) private airlineAttributes;
    mapping(address => uint256) private approved;
    mapping(address => uint256) private balance;
    mapping(bytes32 => address[]) private airlineinsurees;
    mapping(address => mapping(bytes32 => uint256)) amountOfInsurance;
    mapping(bytes32 => mapping(address => uint256)) payoutOfInsurance;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address firstAirline) public {
        contractOwner = msg.sender;
        RegisteredAirline[firstAirline] = true;
        airlines.push(firstAirline);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirlineRegistered(address caller) {
        require(RegisteredAirline[caller] == true, "Caller is not registered");
        _;
    }

    modifier requireNotRegistered(address airline) {
        require(
            RegisteredAirline[airline] == false,
            "Airline already registered"
        );
        _;
    }
    modifier requireIsAuthorized() {
        require(
            approved[msg.sender] == 1,
            "Caller is not contract owner"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */    

    function isAirline(address airline) public view returns (bool) {
        return RegisteredAirline[airline];
    }
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   

    function authorizedCaller(address contractAddress)
        external
        requireContractOwner
    {
        approved[contractAddress] = 1;
    }

    function unauthorizedCaller(address contractAddress)
        external
        requireContractOwner
    {
        delete approved[contractAddress];
    }
    function registerAirline(address airline)
        external
        requireIsOperational
        requireIsAuthorized
        requireNotRegistered(airline)
        returns (bool success)
    {
         require(airline != address(0));
        RegisteredAirline[airline] = true;
        airlines.push(airline);
        return RegisteredAirline[airline];
    }


   /**
    * @dev Buy insurance for a flight
    *
    */   
    function buy(
        address airline,
        string flight,
        uint256 _timestamp,
        address passenger,
        uint256 amount
    )external
        requireIsOperational
        requireIsAuthorized
        requireIsAirlineRegistered(airline)
    {
         
        bytes32 flightkey = getKeyOfFlight(airline, flight, _timestamp);

        airlineinsurees[flightkey].push(passenger);
        amountOfInsurance[passenger][flightkey] = amount;
        payoutOfInsurance[flightkey][passenger] = 0;
    

    }
         uint256 public total = 0;

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(
        address airline,
        string flight,
        uint256 timestamp,
        uint256 factor_numerator,
        uint256 factor_denominator
    )external requireIsOperational requireIsAuthorized {
        //get all the insurees
        bytes32 flightkey = getKeyOfFlight(airline, flight, timestamp);
        address[] storage insurees = airlineinsurees[flightkey];
    for (uint8 i = 0; i < insurees.length; i++) {
            address passenger = insurees[i];
            uint256 payout;
            uint256 amount = amountOfInsurance[passenger][flightkey];
            uint256 paid = payoutOfInsurance[flightkey][passenger];
            if (paid == 0) {
                payout = amount.mul(factor_numerator).div(factor_denominator);
                payoutOfInsurance[flightkey][passenger] = payout;
                balance[passenger] += payout;
            }
        }
    }
    

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(
        address airline,
        string flight,
        uint256 ts,
        address passenger,
        uint256 payout
    ) external requireIsOperational requireIsAuthorized {
        bytes32 flightkey = getKeyOfFlight(airline, flight, ts);
        payoutOfInsurance[flightkey][passenger] = payout;
        balance[passenger] += payout;
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
                            (   
                            )
                            public
                            payable
    {
    }

    function getKeyOfFlight
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function() 
                            external 
                            payable 
    {
        fund();
    }


}

