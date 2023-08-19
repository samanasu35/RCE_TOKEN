// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface RCETInterface {
    function balanceOf(address account) external view returns (uint256);
    function spend(address from, uint256 value) external returns (bool);
    function earn(address to, uint256 value) external returns (bool);
    function isAllowanceContract(address contractAddress) external view returns(bool);
}

interface MSCLInterface {
    function getYear() external view returns (uint16);
    function getWeek() external view returns (uint8);
    function addClubtoLeague(uint256 club, uint8 countryCode) external;
}

interface MSCPInterface {
    function isHasClub(uint256 player) external view returns(bool);
}

contract MSCClub {

    RCETInterface iRCET;
    MSCLInterface iMSCL;
    MSCPInterface iMSCP;

    string private _name;
    string private _symbol;
    uint256 private mintPrice;
    mapping(uint256 => address) private _tokenOwner; //tokenID => address
    mapping(uint256 => uint256) private _clubTokenPrice; //tokenID => address
    mapping(uint256 => uint256) private _clubEthPrice; //tokenID => address
    mapping(address => uint256[]) private _ownerTokens; //address => tokenID
    mapping(address => uint256) private _balances; //address => club count
    mapping(uint256 => clubValues)  private _soccerClubs; //tokenID => club values
    mapping(string => uint256) private _clubNames; //clubNames => tokenID
    mapping(uint8 => uint256[]) private countryClub;

    //mapping(uint16 => mapping(uint256 => uint256[])) private _clubPlayers; //year -> clubId -> players
    mapping(uint16 => mapping(uint256 => offerValues[])) private _clubOffers; //year -> clubId -> offers
    mapping(uint16 => mapping(uint256 => offerValues[])) private _playerOffers; //year -> playerId -> offers

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    address public _owner;
    uint256 private _tokenIdCounter = 1;

    struct clubValues {
        uint8 country;
        uint8 league;
        address creator;
        uint16 year;
        string clubName;
        uint8[] orders;
        uint256[] players;
    }

    struct offerValues {
        uint256 indexP;
        uint256 indexC;
        uint256 player;
        uint256 club;
        uint256 price;
    }


    constructor(string memory contractName, string memory contractSymbol) {
        _name = contractName;
        _symbol = contractSymbol;
        _owner = msg.sender;

        //priceses
        mintPrice = 100 * (10**9);
    }

    function setInterfaces(address RCET, address MSCL, address MSCP) external onlyOwner
    {
        iRCET = RCETInterface(RCET);
        iMSCL = MSCLInterface(MSCL);
        iMSCP = MSCPInterface(MSCP);
    }

    //check allowance contract
    function isAllowanceContract() private view returns(bool)
    {
        return iRCET.isAllowanceContract(msg.sender) || address(iRCET) == msg.sender;
    }

    function isHasOffer(uint256 player, uint256 club, uint256 index) external view returns(bool)
    {
        return _playerOffers[iMSCL.getYear()][player][index].club == club;
    }

    function isFull(uint256 club) public view returns(bool)
    {
        return _soccerClubs[club].players.length == 16;
    }

    function sendOffer(uint256 player, uint256 club, uint256 value) external returns(bool)
    {
        require(_tokenOwner[club] == msg.sender, "this club is not yours");
        require(iMSCP.isHasClub(player), "Player already has a club");
        require(!isFull(club), "your club already has 16 players");
        require(iMSCL.getWeek() < 5 , "you can offer only first 4 week");
        iRCET.spend(msg.sender, value);
        offerValues memory newOffer;
        newOffer.club = club;
        newOffer.player = player;
        newOffer.price = value;
        offerValues[] storage clubOffers = _clubOffers[iMSCL.getYear()][club];
        offerValues[] storage playerOffers = _playerOffers[iMSCL.getYear()][player];
        newOffer.indexC = clubOffers.length;
        newOffer.indexP = playerOffers.length;
        clubOffers.push(newOffer);
        playerOffers.push(newOffer);
        return true;
    }

    function rejectOffer(uint256 player, uint256 club, uint256 index) public returns(bool)
    {
        require(isAllowanceContract(), "Can not use this method");
        offerValues[] storage offersPlayer = _playerOffers[iMSCL.getYear()][player];
        offerValues storage offerPlayer = offersPlayer[index];
        offerValues[] storage offersClub = _clubOffers[iMSCL.getYear()][club];
        offerValues storage offerClub = offersClub[offerPlayer.indexC];
        iRCET.earn(_tokenOwner[club], offerClub.price);

        if (offersClub.length -1 > offerClub.indexC) offerClub = offersClub[offersClub.length -1];
        offersClub.pop();

        if (offersPlayer.length -1 > offerPlayer.indexP) offerPlayer = offersPlayer[offersPlayer.length -1];
        offersPlayer.pop();
        return true;
    }

    function acceptOffer(uint256 player, address owner, uint256 club, uint256 index) external returns(bool)
    {
        require(isAllowanceContract(), "Can not use this method");
        offerValues[] storage offersPlayer = _playerOffers[iMSCL.getYear()][player];
        offerValues storage offerPlayer = offersPlayer[index];
        offerValues[] storage offersClub = _clubOffers[iMSCL.getYear()][club];
        offerValues storage offerClub = offersClub[offerPlayer.indexC];
        iRCET.earn(owner, offerClub.price / 100 * 90);
        _soccerClubs[club].players.push(player);

        if (offersClub.length -1 > offerClub.indexC) offerClub = offersClub[offersClub.length -1];
        offersClub.pop();

        if (offersPlayer.length -1 > offerPlayer.indexP) offerPlayer = offersPlayer[offersPlayer.length -1];
        offersPlayer.pop();
        
        for (uint256 i = offersPlayer.length - 1; i >= 0; i--) rejectOffer(player, offersPlayer[i].club, i);
        if (isFull(club))
        {
            offersClub = _clubOffers[iMSCL.getYear()][club];
            for(uint256 i = offersClub.length - 1; i >= 0; i--) deleteOffer(offersClub[i].player, club, offersClub[i].indexP);
        }
        return true;
    }

    function deleteOffer(uint256 player, uint256 club, uint256 index) public returns(bool)
    {
        require(_tokenOwner[club] == msg.sender || isAllowanceContract(), "this club is not yours");
        offerValues[] storage offersClub = _clubOffers[iMSCL.getYear()][club];
        offerValues storage offerClub = offersClub[index];
        offerValues[] storage offersPlayer = _playerOffers[iMSCL.getYear()][player];
        offerValues storage offerPlayer = offersPlayer[offerClub.indexP];

        iRCET.earn(_tokenOwner[club], offerClub.price / 100 * 90);

        if (offersClub.length -1 > offerClub.indexC) offerClub = offersClub[offersClub.length -1];
        offersClub.pop();

        if (offersPlayer.length -1 > offerPlayer.indexP) offerPlayer = offersPlayer[offersPlayer.length -1];
        offersPlayer.pop();

        return true;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address owner) external view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter - 1;
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _tokenOwner[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        _balances[from] -= 1;
        _balances[to] += 1;
        _tokenOwner[tokenId] = to;
        uint256[] storage toTokens = _ownerTokens[to];
        toTokens.push(tokenId);
        uint256[] storage fromTokens = _ownerTokens[from];
        if (fromTokens.length == 1) fromTokens.pop();
        else if (fromTokens[fromTokens.length -1] == tokenId) fromTokens.pop();
        else for (uint8 i = 0; i < fromTokens.length; i++) 
        {
            if (fromTokens[i] == tokenId)
            {
                fromTokens[i] = fromTokens[fromTokens.length - 1];
                fromTokens.pop();
            }
        }

        emit Transfer(from, to, tokenId);
    }

    function setClubTokenPrice(uint256 tokenId, uint256 price) external 
    {
        require(_tokenOwner[tokenId] == msg.sender, "this club is not yours");
        _clubTokenPrice[tokenId] = price;
    }

    function setClubEthPrice(uint256 tokenId, uint256 price) external 
    {
        require(_tokenOwner[tokenId] == msg.sender, "this club is not yours");
        _clubEthPrice[tokenId] = price;
    }

    function getClubTokenPrice(uint256 tokenId) public view returns(uint256) {return _clubTokenPrice[tokenId];}
    function getClubEthPrice(uint256 tokenId) public view returns(uint256) {return _clubEthPrice[tokenId];}

    function buyClub(address to, uint256 tokenId) external payable returns(bool)
    {
        require(getClubEthPrice(tokenId) > 0 || getClubTokenPrice(tokenId) > 0, "club is not open for sale");
        require(msg.value >= getClubEthPrice(tokenId), "eth not enaught");
        iRCET.spend(msg.sender,getClubTokenPrice(tokenId));
        iRCET.earn(_tokenOwner[tokenId], getClubTokenPrice(tokenId) / 100 * 85);
        payable(_tokenOwner[tokenId]).transfer(msg.value / 100 * 80);
        clubValues storage club = _soccerClubs[tokenId];
        iRCET.earn(club.creator, getClubTokenPrice(tokenId) / 100 * 10);
        payable(club.creator).transfer(getClubEthPrice(tokenId) / 100 * 10);
        _transfer(_tokenOwner[tokenId], to, tokenId);
        return true;
    }


    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwner[tokenId] != address(0);
    }

    // Sadece sahibinin çağırabileceği bir modifier
    modifier onlyOwner() {
        require(msg.sender == _owner, "ERC721: Only the contract owner can call this function");
        _;
    }

    function getCountryClub(uint8 cc) external view returns(uint256[] memory)
    {
        return countryClub[cc];
    }

    // Yeni bir token yaratıp sahibini belirleyen mint fonksiyonu
    function mint(uint8 positionType, string memory clubName,  uint8 countryCode) external  {
        require(msg.sender != address(0), "ERC721: mint to the zero address");
        require(positionType >= 0 && positionType < 6 , "Incorrect Position");
        require(countryCode < 48, "Incorrect country");
        require(_clubNames[clubName] == 0, "clubName is already used");
        require(countryClub[countryCode].length < 100, "this country has 100 club");
        SpendRCET(100*(10**9));

        uint256 tokenId = _tokenIdCounter;
        _soccerClubs[tokenId].country = countryCode;
        _soccerClubs[tokenId].year = iMSCL.getYear();
        _soccerClubs[tokenId].creator = msg.sender;
        _soccerClubs[tokenId].clubName = clubName;  
        _soccerClubs[tokenId].orders = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16];  
        countryClub[countryCode].push(tokenId);
        iMSCL.addClubtoLeague(tokenId, countryCode);    

        _balances[msg.sender] += 1;
        _tokenOwner[tokenId] = msg.sender;
        uint256[] storage userTokens = _ownerTokens[msg.sender]; 
        userTokens.push(tokenId);
        _clubNames[clubName] = tokenId;
        _tokenIdCounter += 1;
        emit Transfer(address(0), msg.sender, tokenId);
    }

    // ERC-20 kontratına erişen ve msg.sender'a ait bakiyeyi kontrol eden fonksiyon
    function checkRCETBalance() internal view returns (uint256) {
        return iRCET.balanceOf(msg.sender);
    }

    // ERC-20 kontratına erişen ve ERC-20 tokenlarını transfer eden fonksiyon
    function SpendRCET(uint256 value) internal returns(bool) {
        require(checkRCETBalance() >= value, "Not eanught RCET balance");
        bool success = iRCET.spend(msg.sender, value);
        require(success, "RCET spend failed");
        return success;
    }

    // ERC-20 kontratına erişen ve ERC-20 tokenlarını transfer eden fonksiyon
    function earnRCET(uint256 value) internal returns(bool) {
        bool success = iRCET.earn(msg.sender, value);
        require(success, "RCET earn failed");
        return success;
    }

    function getSender() public view returns(address)
    {
        return msg.sender;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function getClub(uint256 tokenId) external view returns(clubValues memory)
    {
        return _soccerClubs[tokenId];
    }

    function getFirst11(uint256 tokenId) external view returns(uint256[11] memory)
    {
        uint256[] storage allPlayers = _soccerClubs[tokenId].players;
        uint256[11] memory players = [allPlayers[0],allPlayers[1],allPlayers[2],allPlayers[3],allPlayers[4],
        allPlayers[5],allPlayers[6],allPlayers[7],allPlayers[8],allPlayers[9],allPlayers[10]];
        return players;
    }

    function orderPlayer(uint256 club, uint8[] memory orders) external
    {
        require(isFull(club), "not enaught players for this method");
        require(_tokenOwner[club] == msg.sender, "this club is not yours");
        _soccerClubs[club].orders = orders;
    }
}
