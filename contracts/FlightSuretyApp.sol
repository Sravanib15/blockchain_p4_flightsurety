pragma solidity ^0.5.10;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    
    uint256 AIRLINE_REGISTRATION_FEE = 10 ether;
    uint256 MAX_INSURANCE_PLAN = 1 ether;
    uint256 INSURANCE_PAYOUT = 150; //(div by 100 to get to 1.5%)
    uint256 AIRLINE_VOTING_THRESHOLD = 4;
    uint256 AIRLINE_VOTES_REQUIRED = 2;

    address private contractOwner;          // Account used to deploy contract
    bool private operational = true;

    struct AirlineVotes {    
        bool isRegistered;
        bool isFunded;
    }

    mapping(address => address[]) public airlineVotes;
    FlightSuretyDate fsd;

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
         // Modify to call data contract's status
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

    modifier isAirlineNotRegistered() {
        require(
            fsd.isRegistered(msg.sender), "Airline must be registered"
        );
        _;
    }

    modifier onlyNotRegisteredAirline(address airline) {
        require(!fsd.isAirlineRegistered(airline), "Airline already registered");
        _;
    }

    modifier onlyNotFundedAirline(address airline) {
        require(!fsd.isAirlineFunded(airline), "Airline already funded");
        _;
    }

    modifier onlyRegisteredAirline(address airline) {
        require(fsd.isAirlineRegistered(airline), "Airline already registered");
        _;
    }

    modifier onlyFundedAirline(address airline) {
        require(fsd.isAirlineFunded(airline), "Airline already funded");
        _;
    }

    modifier onlyRegisteredFlight(bytes32 flight) {
        require(fsd.isFlightRegistered(flight), "Flight is not registered");
        _;
    }

    modifier onlyNotRegisteredFlight(bytes32 flight) {
        require(!fsd.isFlightRegistered(flight), "Flight is already registered");
        _;
    }

    modifier onlyNotLandedFlight(bytes32 flight) {
        require(!fsd.hasFlightLanded(flight), "Flight is already landed");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address payable fsData
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        fsd = fsData;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            pure 
                            returns(bool) 
    {
        return operational;  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  
   /**
    * @dev Add an airline to the registration queue
    *
    */   
    function registerAirline
                            (   
                                address airline
                            )
                            external
                            requiresIsOperational
                            onlyNotRegisteredAirline(airline)
                            onlyFundedAirline(msg.sender)
                            returns(bool success, uint256 votes)
    {
        if (fsd.getRegisteredAirlineCount() <= AIRLINE_VOTING_THRESHOLD) {
            fsd.registerAirline(airlin, msg.sender);
            return(true, 0);
        } else {
            bool duplicate = false;
            
            for(uint i=0; i < airlineVotes[airline].length; i++) {
                if (airlineVotes[airline][i] == msg.sender) {
                    duplicate = true;
                    break;
                }
            }
            if(!duplicate) 
                airlineVotes[airline].push(msg.sender);
            
            if(airlineVotes[airline].length >= fsd.getRegisteredAirlineCount.div(AIRLINE_VOTES_REQUIRED)) {
                fsd.registerAirline(airline, msg.sender);
                return(true, airlineVotes[airline].length);
            }
            return (false, airlineVotes[airline].length);
        }
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
                                (
                                    bytes32 flight,
                                    uint256 timestamp,
                                    string calldata from,
                                    string calldata to,
                                    string landing
                                )
                                external
                                requiresIsOperational
                                onlyFundedAirline(msg.sender)
    {
        fsd.registerFlight(
            getFlightKey(msg.sender, flight, timestamp),
            msg.sender,
            from,
            to,
            landing
        );
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
                                (
                                    address airline,
                                    string memory flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                requireIsOperational
    {
        fsd.processFlightStatus(airline, flight, timestamp, statusCode);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp,
                            bytes32 flight                       
                        )
                        external
                        onlyRegisteredFlight(flight)
                        onlyNotLandedFlight(flight)

    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    function fundAirline ()
                         external 
                         payable 
                         requiresIsOperational
                         onlyRegisteredAirline(msg.sender)
                         onlyNotFundedAirline(msg.sender)
                         require(msg.value >= AIRLINE_REGISTRATION_FEE, "Minimum funding needed to register") 
    {
        fsd.transfer(AIRLINE_REGISTRATION_FEE);
        return fsd.fundAirline(msg.sender, AIRLINE_REGISTRATION_FEE);
    }

    function buy (bytes32 flight)
                             public 
                             payable 
                             requiresIsOperational 
                             onlyRegisteredFlight(flight) 
                             onlyNotLandedFlight(flight) 
                             require(msg.value <= MAX_INSURANCE_PLAN, "Value exceeds max insurance plan.") {
        fsd.transfer(msg.value);                        
        fsd.buy(flight, msg.sender, msg.value, INSURANCE_PAYOUT)

    }
// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

contract FlightSuretyData {
    function getRegisteredAirlineCount() public view returns(uint256);
    function getRegisteredFlightCount() public view returns(uint256);
    function isAirlineRegistered (address airline) public view returns(bool);
    function isAirlineFunded (address airline) public view returns(bool);
    function isFlightRegistered (address flight) public view returns(bool);
    function hasFlightLanded (bytes32 flight) public view returns(bool);
    function processFlightStatus(address airline, string calldata flight, uint256 timestamp, uint status) external;
    function isOperational() 
                            public 
                            view 
                            returns(bool);
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external;
    function registerAirline
                            (   
                                address airline,
                                address originalAirline
                            )
                            external;
    function registerFlight
                            (   
                                bytes32 flight,
                                address airline,
                                string memory from,
                                string memory to,
                                uint256 landing
                            )
                            external;
    function buy
                            (  
                                bytes32 flight,
                                address passenger,
                                uint256 amt,
                                uint payout                           
                            )
                            external
                            payable;
    function creditInsurees
                                (
                                    bytes32 flight
                                )
                                internal;                                               
    function pay
                            (
                                address payable passenger
                            )
                            external
                            payable;
    function fund
                            (   
                            )
                            public
                            payable;
    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    function fundAirline
                            (   
                                address airline,
                                address originalAirline
                            )
                            external

}