pragma solidity >= 0.4.24;

contract TaxiBusiness{
    
    struct Participant {
        address addr;
        uint participantBalance;
    }
    Participant public participant;
    Participant[] public participants;
    mapping (address=>bool) public joinedParticipantMap;
    //joinedParticipantMap
    address public manager;     //that is decided offline who creates the contract initially.
    
    struct TaxiDriver{
        address payable addr;
        uint taxiDriverSalary;
        uint256 lastSalaryTimestamp;
        uint approvalState;
    }
    
    TaxiDriver public proposedDriver;
    TaxiDriver public taxiDriver;
    address payable public carDealer;
    uint public contractBalance;
    uint32 public ownedCarID;
    
    struct ProposedCar{
        uint32 carID;
        uint price;
        uint256 offerValidTime;
        uint approvalState; 
    }
    ProposedCar public  proposedCar;
    ProposedCar public proposedRepurchaseCar; //current car
    
    uint public fixExpensesForMaintenanceAndTax; //Every 6 months car needs to go to Car Dealer for maintenance and taxes needs to be paid, total amount for maintenance and tax is fixed
    uint public participationFee;  //An amount that participants needs to pay for entering the taxi business
    
    uint public aMonth;
    uint public sixMonths;
    
    uint32 public timeStampForFixedExpenses;
    uint32 public timeStampForDividend;
    
    function Time_call() public returns (uint256){ //https://www.unixtimestamp.com/
        return now;
    }
    
    modifier onlyManager {
        require(msg.sender == manager, "only manager, check address");
        _;
    }
    
    modifier onlyCarDealer{
        require(msg.sender == carDealer, "only carDealer, check address");
        _;
    }
    
    modifier onlyParticipant{
        require(joinedParticipantMap[msg.sender],"Only participants, check address");
        _;
    }
    
    modifier onlyTaxiDriver{
        require(msg.sender == taxiDriver.addr, "only taxiDriver, check address");
        _;
    }
    
    constructor() public payable{
		manager = msg.sender;
		
		fixExpensesForMaintenanceAndTax = 10 ether;
		participationFee = 100 ether;
		
		aMonth =720;
		sixMonths = aMonth *6;
    }
    
    function join() public payable{
        require(!joinedParticipantMap[msg.sender],"Can only join once.");
        require(participants.length <= 9, "Maximum 9 participants.");
        require(msg.value >= participationFee , "Participants have to pay 100 ether or more.");

        Participant memory newParticipant = Participant(msg.sender, 0);

        joinedParticipantMap[msg.sender] = true;
        participants.push(newParticipant);
    }
    
    function setCarDealer(address payable dealerAddress) public onlyManager{
        carDealer = dealerAddress;
	}
	
	function CarProposeToBusiness(uint32 carId, uint price, uint256 offerValidTime) public payable onlyCarDealer{
	    ProposedCar memory carProposed = ProposedCar(carId, price, offerValidTime, 0);
	    proposedCar = carProposed;
	    
	}
	
	function proposeDriver(address payable driverAddress, uint taxiDriverSalary) public onlyManager {
	    TaxiDriver memory driverProposed = TaxiDriver(driverAddress, taxiDriverSalary, 0, 0);
	    proposedDriver = driverProposed;
	}
	
	function approveDriver() public onlyParticipant{
	    proposedDriver.approvalState +=1;
	}
	
	function setDriver() public onlyManager{
	    require(proposedDriver.approvalState > 5 , " approval state isn't approved by more than half of the participants. ");
	    taxiDriver = proposedDriver;
	}
	
	function fireDriver() public payable onlyManager{
	    taxiDriver.addr.transfer(taxiDriver.taxiDriverSalary);
	    TaxiDriver memory firedDriver = TaxiDriver(address(0),0,0,0); 
        taxiDriver = firedDriver;
	}
	
	function getSalary() public payable onlyTaxiDriver{
        require(taxiDriver.taxiDriverSalary > 0, "Don't have any money to take.");
        
        taxiDriver.addr.transfer(taxiDriver.taxiDriverSalary);
        taxiDriver.taxiDriverSalary = 0;
	}
	
	function releaseSalary(uint a_taxiDriverSalary) public payable onlyManager{
	    require(now - taxiDriver.lastSalaryTimestamp > aMonth, "once in a month,try again later");
	    
	    taxiDriver.taxiDriverSalary += a_taxiDriverSalary;
	    taxiDriver.lastSalaryTimestamp = uint32(now);
	}
	
	function carExpenses() public onlyManager{
	    require(now - sixMonths > timeStampForFixedExpenses, "You already paid 6 months after the last one.");
	    
        carDealer.transfer(fixExpensesForMaintenanceAndTax);
        timeStampForFixedExpenses = uint32(now);
	}
	
	function approvePurchaseCar() public onlyParticipant{
	    
	    require(proposedCar.carID != 0, "pproposal car didn't set. Please propose a car.");
	    proposedCar.approvalState += 1;
	}
	
	function purchaseCar() public payable onlyManager{
	    require(now < proposedCar.offerValidTime, "time-out");
	    require(proposedCar.approvalState < 5 ,"Should approved more than half of participants.");
	    
	    carDealer.transfer(proposedCar.price);
	    ownedCarID =proposedCar.carID;
	    proposedCar.offerValidTime = 0;
	}
	
	function repurchaseCarPropose(uint32 carId, uint price, uint256 offerValidTime) public onlyCarDealer{
        require(ownedCarID != 0, "you have to have a car for repurchase.");
        
        ProposedCar memory m_repurchaseCar = ProposedCar(carId, price, offerValidTime, 0);
        proposedRepurchaseCar = m_repurchaseCar;
	}
	
	function repurchaseCar() public onlyCarDealer{
	    require(now < proposedRepurchaseCar.offerValidTime, "offer valid time - out");
        require(carDealer.balance >= proposedRepurchaseCar.price," dont have money to buy");
        
        if(proposedRepurchaseCar.approvalState > 5){
            
            ownedCarID = proposedRepurchaseCar.carID;
            proposedRepurchaseCar.offerValidTime = 0;
        } else{
            
            ProposedCar memory repurchaseDoesntHappen = ProposedCar(0, 0, 0, 0);
            proposedRepurchaseCar = repurchaseDoesntHappen;
        }
	}
	
	function approveSellPropose() public onlyParticipant {
	    require(ownedCarID != 0, "you have to have a car for repurchase.");
	    proposedRepurchaseCar.approvalState += 1;
	}
	
	function payDividend() public onlyManager{
	    require(now - sixMonths > timeStampForDividend, "already paid.");
	    
	    uint numberOfParticipant = participants.length;
	    uint totalMoneyInAddress = address(this).balance;
	    
	    if(now - timeStampForFixedExpenses > sixMonths){
            totalMoneyInAddress = (totalMoneyInAddress - fixExpensesForMaintenanceAndTax ) ;
        }
        
	    if(now - taxiDriver.lastSalaryTimestamp > aMonth){
            totalMoneyInAddress = (totalMoneyInAddress - taxiDriver.taxiDriverSalary ) ;
        }
	    
	    uint forEachParticipant = totalMoneyInAddress / numberOfParticipant;
	    
	    for(uint i=0; i<participants.length; i++){        
            participants[i].participantBalance += forEachParticipant;
        }
	    
	}
	
	function getDividend() public onlyParticipant{
	    
        for(uint8 i=0; i<participants.length; i++){
            if(participants[i].addr == msg.sender){
                assert(address(this).balance >= participants[i].participantBalance);
                participants[i].participantBalance = 0;
                msg.sender.transfer(participants[i].participantBalance);
                break;
            }
        }
	}
	
	function () external{
	    //fallback function
	}
	
	function getCharge() public payable{
	    //address(this).transfer(msg.value) ;
	    
	}
	
	
}
