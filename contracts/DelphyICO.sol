pragma solidity ^0.4.11;
/*

  Copyright 2017 Delphy Foundation.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

//   /$$$$$$$            /$$           /$$
//  | $$__  $$          | $$          | $$
//  | $$  \ $$  /$$$$$$ | $$  /$$$$$$ | $$$$$$$  /$$   /$$
//  | $$  | $$ /$$__  $$| $$ /$$__  $$| $$__  $$| $$  | $$
//  | $$  | $$| $$$$$$$$| $$| $$  \ $$| $$  \ $$| $$  | $$
//  | $$  | $$| $$_____/| $$| $$  | $$| $$  | $$| $$  | $$
//  | $$$$$$$/|  $$$$$$$| $$| $$$$$$$/| $$  | $$|  $$$$$$$
//  |_______/  \_______/|__/| $$____/ |__/  |__/ \____  $$
//                          | $$                 /$$  | $$
//                          | $$                |  $$$$$$/
//                          |__/                 \______/
//  Code style according to: https://github.com/DelphyProject/delphy_contracts/blob/master/style-guide.rst

import "./Math.sol";
import "./Owned.sol";
import "./DelphyToken.sol";

contract DelphyICO is Owned {
    using Math for uint;

    /*
     * EVENTS
     */
    event NewSale(address indexed destAddress, uint ethCost, uint gotTokens);
    event PartnerAddressQuota(address indexed partnerAddress, uint quota);

    /*
     *  Constants
     */
    /// ------------------------------------------------------------------------------------------------------------
    /// |                                                |                         |       |            |          |
    /// |        INTEREST (PRESALE IN 24 MONTHS)         |       PUBLIC SALE       |PRE-ICO| DEV TEAM   |FOUNDATION|
    /// |                       50%                      |        (18 + 8)%        |   5%  |    10%     |    9%    |
    /// ------------------------------------------------------------------------------------------------------------

    uint8 public constant decimals = 18;
    uint public constant TOTAL_TOKENS = 100000000 * 10**18; // 1e
    uint public constant MAX_ICO_DURATION = 5 days;

    /// interest 50%
    address public INTEREST_HOLDER = 0x000d0844f4d8be3c89c6e086fd00b35a6ae3312d8f;
    uint public constant INTEREST_Tokens = TOTAL_TOKENS * 50 / 100;

    /// first 18%
    address public constant PUBLIC_FIRST_HOLDER = 0xB1EFca62C555b49E67363B48aE5b8Af3C7E3e656;
    uint public constant PUBLIC_FIRST_Tokens = TOTAL_TOKENS * 18 / 100;

    /// second 8%
    address public constant PUBLIC_SECONDE_HOLDER = 0x00779e0e4c6083cfd26dE77B4dbc107A7EbB99d2;
    uint public constant PUBLIC_SECONDE_Tokens = TOTAL_TOKENS * 8 / 100;

    /// pre-ico 5%
    address public constant PRE_ICO_HOLDER = 0xDD91615Ea8De94bC48231c4ae9488891F1648dc5;
    uint public constant PRE_ICO_Tokens = TOTAL_TOKENS * 5 / 100;

    /// dev team 10%
    address public constant DEV_TEAM_HOLDER = 0xDD91615Ea8De94bC48231c4ae9488891F1648dc5;
    uint public constant DEV_TEAM_Tokens = TOTAL_TOKENS * 10 / 100;

    /// foundation 9%
    address public constant FOUNDATION_HOLDER = 0xDD91615Ea8De94bC48231c4ae9488891F1648dc5;
    uint public constant FOUNDATION_Tokens = TOTAL_TOKENS * 9 / 100;

    /// will sold
    uint public constant MAX_OPEN_SOLD = PUBLIC_SECONDE_Tokens;

    /*
     *  Storage
     */
    /// Fields that are only changed in constructor
    /// All deposited ETH will be instantly forwarded to this address.
    address public wallet;
    /// ICO start time
    uint public startTime;
    /// ICO end time
    uint public endTime;
    /// ERC20 compilant Delphy token contact instance
    DelphyToken public delphyToken;

    /// Fields that can be changed by functions
    /// Accumulator for open sold tokens
    uint public openSoldTokens;
    /// Due to an emergency, set this to true to halt the contribution
    bool public halted;

    /// Accumulator for partner sold
    mapping (address => uint256) public partnersBought;
    /// Buy
    mapping (address => uint) lockedBalances;

    /*
     * MODIFIERS
     */
    modifier onlyWallet {
        require(msg.sender == wallet);
        _;
    }

    modifier notHalted() {
        require(!halted);
        _;
    }

    modifier initialized() {
        require(address(wallet) != 0x0);
        _;
    }

    modifier notEarlierThan(uint x) {
        require(now >= x);
        _;
    }

    modifier earlierThan(uint x) {
        require(now < x);
        _;
    }

    modifier ceilingNotReached() {
        require(openSoldTokens < MAX_OPEN_SOLD);
        _;
    }

    modifier isLaterThan (uint x){
    	  assert(now > x);
    	  _;
    }

    modifier isNotContract(address _addr) {
        require(!isContract(_addr));
        _;
    }

    modifier isValidPayload() {
        require (msg.data.length == 4 || msg.data.length == 36);

        _;
    }

    /**
     * CONSTRUCTOR
     *
     * @dev Initialize the Delphy ICO contract
     * @param _wallet The escrow account address, all ethers will be sent to this address.
     * @param _startTime ICO start time
     */
     function DelphyICO(address _wallet, uint _startTime)
        public
    {
        require (_wallet != 0);

        halted = false;
        wallet = _wallet;
        startTime = _startTime;
    	endTime = startTime + MAX_ICO_DURATION;
        openSoldTokens = 0;

        address[] memory orgs = new address[](6);
        uint[] memory nums = new uint[](6);
        orgs[0] = INTEREST_HOLDER;
        nums[0] = INTEREST_Tokens;

        orgs[1] = PUBLIC_FIRST_HOLDER;
        nums[1] = PUBLIC_FIRST_Tokens;

        orgs[2] = PUBLIC_SECONDE_HOLDER;
        nums[2] = PUBLIC_SECONDE_Tokens;

        orgs[3] = PRE_ICO_HOLDER;
        nums[3] = PRE_ICO_Tokens;

        orgs[4] = DEV_TEAM_HOLDER;
        nums[4] = DEV_TEAM_Tokens;

        orgs[5] = FOUNDATION_HOLDER;
        nums[5] = FOUNDATION_Tokens;
        delphyToken = new DelphyToken(this, orgs, nums);
    }

    /**
     * Fallback function
     *
     * @dev If anybody sends Ether directly to this  contract, consider he is getting wan token
    */
    function () public payable notHalted ceilingNotReached{
    	buyDelphyToken(msg.sender);
    }

    /*
     * CONSTANT METHODS
     */

    /*
     * PUBLIC FUNCTIONS
     */
     /// @dev Exchange msg.value ether to Delphy for account recepient
     /// @param receipient Delphy tokens receiver
     function buyDelphyToken(address receipient)
         public
         payable
         notHalted
         initialized
         ceilingNotReached
         notEarlierThan(startTime)
         earlierThan(endTime)
         returns (bool)
     {
        require(receipient != 0x0);
        require(msg.value >= 0.1 ether);

        if (msg.sender != receipient)
            buyFromPartner(receipient);
        else
            buyNormal(receipient);

        return true;
     }

     /// @dev Locking period has passed - Locked tokens have turned into tradeable
     ///      All tokens owned by receipent will be tradeable
     function claimTokens(address receipent)
         isLaterThan(endTime)
         isValidPayload
     {
        uint tokenCount = lockedBalances[receipent] ;
        require(tokenCount != 0x0);

        lockedBalances[receipent] = 0;
        require(delphyToken.claimToken(PUBLIC_SECONDE_HOLDER, receipent, tokenCount));
     }

    /// @dev Emergency situation that requires contribution period to stop.
    /// Contributing not possible anymore.
    function halt() public onlyWallet{
        halted = true;
    }

    /// @dev Emergency situation resolved.
    /// Contributing becomes possible again withing the outlined restrictions.
    function unHalt() public onlyWallet{
        halted = false;
    }

    /*
     * INTERNAL FUNCTIONS
     */
     /// @dev Buy delphy tokens by partners
     function buyFromPartner(address receipient) internal {
        uint partnerAvailable = MAX_OPEN_SOLD.sub(openSoldTokens);

        require(partnerAvailable > 0);

        uint toFund;
        uint toCollect;
        (toFund,  toCollect)= costAndBuyTokens(partnerAvailable);

        partnersBought[receipient] = partnersBought[receipient].add(toCollect);
        buyCommon(receipient, toFund, toCollect);
     }
    /// @dev Buy Delphy token normally
    function buyNormal(address receipient) internal {
        // Do not allow contracts to game the system
        require(!isContract(msg.sender));

        uint tokenAvailable = MAX_OPEN_SOLD.sub(openSoldTokens);
        require(tokenAvailable != 0);

    	uint toFund;
    	uint toCollect;
    	(toFund, toCollect) = costAndBuyTokens(tokenAvailable);
        buyCommon(receipient, toFund, toCollect);
    }

    /// @dev Utility function for bug wanchain token
    function buyCommon(address receipient, uint toFund, uint wanTokenCollect) internal {
        require(msg.value >= toFund); // double check

        if(toFund > 0) {
            lockedBalances[receipient] += wanTokenCollect;
            wallet.transfer(toFund);
            openSoldTokens = openSoldTokens.add(wanTokenCollect);
            NewSale(receipient, toFund, wanTokenCollect);
        }

        uint toReturn = msg.value.sub(toFund);
        if(toReturn > 0) {
            msg.sender.transfer(toReturn);
        }
    }

    /// @dev Utility function for calculate available tokens and cost ethers
    function costAndBuyTokens(uint availableToken) constant internal returns (uint costValue, uint getTokens){
    	// all conditions has checked in the caller functions
    	uint exchangeRate = 250;
    	getTokens = exchangeRate * msg.value;

    	if(availableToken >= getTokens){
    		costValue = msg.value;
    	} else {
    		costValue = availableToken / exchangeRate;
    		getTokens = availableToken;
    	}
    }

    /// @dev Internal function to determine if an address is a contract
    /// @param _addr The address being queried
    /// @return True if `_addr` is a contract
    function isContract(address _addr) constant internal returns(bool) {
        uint size;
        if (_addr == 0) return false;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}