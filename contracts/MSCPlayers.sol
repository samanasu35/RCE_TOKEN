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
}

interface MSCCInterface {
    function isHasOffer(uint256 player, uint256 club, uint256 index) external view returns(bool);
    function acceptOffer(uint256 player, address owner, uint256 club, uint256 index) external returns(bool);
    function rejectOffer(uint256 player, uint256 club, uint256 index) external returns(bool);
    function isFull(uint256 club) external  view returns(bool);
}


contract MSCPlayers {

    RCETInterface iRCET;
    MSCLInterface iMSCL;
    MSCCInterface iMSCC;

    string private _name;
    string private _symbol;
    uint256 private trainingPrice;
    uint256 private abilityPrice;
    uint256 private mintPrice;
    mapping(uint256 => address) private _tokenOwner; //tokenID => address
    mapping(uint256 => uint256) private _playerTokenPrice; //tokenID => address
    mapping(uint256 => uint256) private _playerEthPrice; //tokenID => address
    mapping(address => uint256[]) private _ownerTokens; //address => tokenID
    mapping(address => uint256) private _balances; //address => player count
    mapping(uint256 => playerValues)  private _soccerPlayers; //tokenID => player values
    mapping(string => uint256) private _playerNames; //playerNames => tokenID
    mapping(uint256 => string) private positionTypes;
    mapping(uint256 => mapping(uint256 => string)) private abilities;
    mapping(uint256 => playerValues) private defaults;
    mapping(uint256 => playerValues) private maxs;
    mapping(uint8 => uint256[]) private countryPlayer;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    address public _owner;
    uint256 private _tokenIdCounter = 1;

    struct playerValues {
        uint8 country;
        address creator;
        uint256 year;
        uint256 trainingBeginDate;
        uint8 training;
        string playerName;
        uint8 positionType;
        uint8 SPD;
        uint8 DRI;
        uint8 PAS;
        uint8 SHO;
        uint8 STR;
        uint8 DEF;
        uint8 number;
        uint8[] abilities;

        uint256[] oldClubs;
        uint256 club;
        string clubName;
        uint256 transferValue;
        uint16 transferYear;
        uint256 currentValue;

        uint16 matchCounter;
        uint16 goalCounter;
    }


    constructor(string memory contractName, string memory contractSymbol) {
        _name = contractName;
        _symbol = contractSymbol;
        _owner = msg.sender;

        //priceses
        trainingPrice = 10**9;
        abilityPrice = 10**9;
        mintPrice = 10 * (10**9);


        // Pozisyon isimlerini dolduruyoruz
        positionTypes[0] ="Goalkeeper"; //kaleci (GK)
        positionTypes[1] ="Defense"; //defans (D L, D R, D C)
        positionTypes[2] ="Defensive Midfielder"; //defansif orta saha (DM L, DM R, DM C)
        positionTypes[3] ="Midfielder"; //ortasaha (M L, M R, M C)
        positionTypes[4] =" Attacking Midfielder"; //ofansif orta saha (AM L, AM R, AM C)
        positionTypes[5] =" Forward"; //forvet  (F L, F R, F C) 

        // yetenek isimleri
        abilities[0][0] = "Diving";                 // Kaleci: Atlama
        abilities[0][1] = "Handling";               // Kaleci: Top Tutma
        abilities[1][0] = "Tackling";               // Defans: Müdahale
        abilities[1][1] = "Marking";                // Defans: Adam Takip
        abilities[2][0] = "Interception";           // Orta Saha: Top Kapma
        abilities[2][1] = "Positioning";            // Orta Saha: Pozisyon Alma
        abilities[3][0] = "Passing Vision";         // Orta Saha: Pas Görüşü
        abilities[3][1] = "Ball Recovery";          // Orta Saha: Top Çalma
        abilities[4][0] = "Playmaking";             // Orta Saha: Oyun Kurma
        abilities[4][1] = "Creative Dribble";       // Orta Saha: Yaratıcı Dribbling
        abilities[5][0] = "Aerial Ability";         // Forvet: Havada Topa Hakimiyet
        abilities[5][1] = "Finishing";              // Forvet: Bitiricilik


        defaults[0].positionType = 0;                  defaults[1].positionType = 1;                  defaults[2].positionType = 2;
        defaults[3].positionType = 3;                  defaults[4].positionType = 4;                  defaults[5].positionType = 5;

        defaults[0].SPD = 40;   defaults[1].SPD = 60;   defaults[2].SPD = 70;   defaults[3].SPD = 70;   defaults[4].SPD = 75;   defaults[5].SPD = 80;
        defaults[0].DRI = 30;   defaults[1].DRI = 40;   defaults[2].DRI = 60;   defaults[3].DRI = 70;   defaults[4].DRI = 80;   defaults[5].DRI = 85;
        defaults[0].PAS = 50;   defaults[1].PAS = 50;   defaults[2].PAS = 70;   defaults[3].PAS = 75;   defaults[4].PAS = 80;   defaults[5].PAS = 70;
        defaults[0].SHO = 20;   defaults[1].SHO = 30;   defaults[2].SHO = 50;   defaults[3].SHO = 60;   defaults[4].SHO = 70;   defaults[5].SHO = 80;
        defaults[0].STR = 60;   defaults[1].STR = 70;   defaults[2].STR = 70;   defaults[3].STR = 60;   defaults[4].STR = 50;   defaults[5].STR = 40;
        defaults[0].DEF = 80;   defaults[1].DEF = 80;   defaults[2].DEF = 75;   defaults[3].DEF = 65;   defaults[4].DEF = 50;   defaults[5].DEF = 30;

        maxs[0].SPD = 80;       maxs[1].SPD = 90;       maxs[2].SPD = 90;       maxs[3].SPD = 95;       maxs[4].SPD = 95;       maxs[5].SPD = 95;
        maxs[0].DRI = 70;       maxs[1].DRI = 80;       maxs[2].DRI = 85;       maxs[3].DRI = 90;       maxs[4].DRI = 95;       maxs[5].DRI = 95;
        maxs[0].PAS = 90;       maxs[1].PAS = 80;       maxs[2].PAS = 90;       maxs[3].PAS = 95;       maxs[4].PAS = 90;       maxs[5].PAS = 85;
        maxs[0].SHO = 50;       maxs[1].SHO = 60;       maxs[2].SHO = 70;       maxs[3].SHO = 85;       maxs[4].SHO = 90;       maxs[5].SHO = 95;
        maxs[0].STR = 90;       maxs[1].STR = 95;       maxs[2].STR = 85;       maxs[3].STR = 80;       maxs[4].STR = 70;       maxs[5].STR = 60;
        maxs[0].DEF = 95;       maxs[1].DEF = 90;       maxs[2].DEF = 85;       maxs[3].DEF = 80;       maxs[4].DEF = 70;       maxs[5].DEF = 40;

    }

    function setInterfaces(address RCET, address MSCL) external onlyOwner
    {
        iRCET = RCETInterface(RCET);
        iMSCL = MSCLInterface(MSCL);
    }

    function sendTraining(uint256 tokenId, uint8 skill) external
    {
        require(_tokenOwner[tokenId] == msg.sender); //, "This player is not your!");
        require(skill > 0 && skill < 7); //, "skill must between 1-6");
        require(skill == 1 && _soccerPlayers[tokenId].SPD < maxs[_soccerPlayers[tokenId].positionType].SPD); //, "SPD skill cannot be developed further.");
        require(skill == 2 && _soccerPlayers[tokenId].DRI < maxs[_soccerPlayers[tokenId].positionType].DRI); //, "DRI skill cannot be developed further.");
        require(skill == 3 && _soccerPlayers[tokenId].PAS < maxs[_soccerPlayers[tokenId].positionType].PAS); //, "PAS skill cannot be developed further.");
        require(skill == 4 && _soccerPlayers[tokenId].SHO < maxs[_soccerPlayers[tokenId].positionType].SHO); //, "SHO skill cannot be developed further.");
        require(skill == 5 && _soccerPlayers[tokenId].STR < maxs[_soccerPlayers[tokenId].positionType].STR); //, "STR skill cannot be developed further.");
        require(skill == 6 && _soccerPlayers[tokenId].DEF < maxs[_soccerPlayers[tokenId].positionType].DEF); //, "DEF skill cannot be developed further.");
        require(_soccerPlayers[tokenId].training == 0); //,"your player already in training");
        SpendRCET(trainingPrice);
        _soccerPlayers[tokenId].trainingBeginDate = block.timestamp;
        _soccerPlayers[tokenId].training = skill;
    }

    function finishTraining(uint256 tokenId) external
    {
        require(_tokenOwner[tokenId] == msg.sender); //, "This player is not your!");
        require(block.timestamp >= _soccerPlayers[tokenId].trainingBeginDate + 1 days); //,"training end date has not passed yet!");
        if (_soccerPlayers[tokenId].training == 1) _soccerPlayers[tokenId].SPD +=1;
        if (_soccerPlayers[tokenId].training == 2) _soccerPlayers[tokenId].DRI +=1;
        if (_soccerPlayers[tokenId].training == 3) _soccerPlayers[tokenId].PAS +=1;
        if (_soccerPlayers[tokenId].training == 4) _soccerPlayers[tokenId].SHO +=1;
        if (_soccerPlayers[tokenId].training == 5) _soccerPlayers[tokenId].STR +=1;
        if (_soccerPlayers[tokenId].training == 6) _soccerPlayers[tokenId].DEF +=1;
        _soccerPlayers[tokenId].training = 0;
    }

    function sendSpecialTraining(uint256 tokenId, uint8 ability) external
    {
        require(ability < 2, "skill is between 0-2");
        require(_tokenOwner[tokenId] == msg.sender, "This player is not your!");
        require(block.timestamp >= _soccerPlayers[tokenId].trainingBeginDate + 1 days,"training end date has not passed yet!");
        require( _soccerPlayers[tokenId].abilities[ability] < 21,"This ability cannot be developed further.");
        SpendRCET(abilityPrice);
        _soccerPlayers[tokenId].trainingBeginDate = block.timestamp;
        _soccerPlayers[tokenId].training = ability + 7;
    }

    function finishSpecialTraining(uint256 tokenId) external
    {
        require(_tokenOwner[tokenId] == msg.sender, "This player is not your!");
        require(block.timestamp >= _soccerPlayers[tokenId].trainingBeginDate + 1 days, "training end date has not passed yet!");
        if (_soccerPlayers[tokenId].training == 7) _soccerPlayers[tokenId].abilities[0] +=1;
        if (_soccerPlayers[tokenId].training == 8) _soccerPlayers[tokenId].abilities[1] +=1;
        _soccerPlayers[tokenId].training = 0;
    }

    function getPlace(uint256 tokenId) external view returns( string memory)
    {   
        if (_soccerPlayers[tokenId].training == 0) return "waiting area";
        else if (_soccerPlayers[tokenId].training < 7) return "skill training";
        else if (_soccerPlayers[tokenId].training < 9) return "spacial training";
        else return "notFoundPlayerPlace";
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
                break;
            }
        }

        emit Transfer(from, to, tokenId);
    }
    

    function setClubTokenPrice(uint256 tokenId, uint256 price) external 
    {
        require(_tokenOwner[tokenId] == msg.sender, "this club is not yours");
        _playerTokenPrice[tokenId] = price;
    }

    function setClubEthPrice(uint256 tokenId, uint256 price) external 
    {
        require(_tokenOwner[tokenId] == msg.sender, "this club is not yours");
        _playerEthPrice[tokenId] = price;
    }

    function getPlayerTokenPrice(uint256 tokenId) public view returns(uint256) {return _playerTokenPrice[tokenId];}
    function getPlayerEthPrice(uint256 tokenId) public view returns(uint256) {return _playerEthPrice[tokenId];}

    function buyPlayer(address to, uint256 tokenId) external payable returns(bool)
    {
        require(getPlayerEthPrice(tokenId) > 0 || getPlayerTokenPrice(tokenId) > 0); //, "club is not open for sale");
        require(msg.value >= getPlayerEthPrice(tokenId)); //, "eth not enaught");
        iRCET.spend(msg.sender,getPlayerTokenPrice(tokenId));
        iRCET.earn(_tokenOwner[tokenId], getPlayerTokenPrice(tokenId) / 100 * 85);
        payable(_tokenOwner[tokenId]).transfer(msg.value / 100 * 80);
        playerValues storage player = _soccerPlayers[tokenId];
        iRCET.earn(player.creator, getPlayerTokenPrice(tokenId) / 100 * 10);
        payable(player.creator).transfer(getPlayerEthPrice(tokenId) / 100 * 10);
        _transfer(_tokenOwner[tokenId], to, tokenId);
        return true;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _tokenOwner[tokenId] != address(0);
    }

    // Sadece sahibinin çağırabileceği bir modifier
    modifier onlyOwner() {
        require(msg.sender == _owner); //, "ERC721: Only the contract owner can call this function");
        _;
    }

    function getCountryPlayers(uint8 cc) external view returns(uint256[] memory)
    {
        return countryPlayer[cc];
    } 

    // Yeni bir token yaratıp sahibini belirleyen mint fonksiyonu
    function mint(uint8 positionType, string memory playerName, uint8 number, uint8 countryCode) external  {
        require(msg.sender != address(0)); //, "ERC721: mint to the zero address");
        require(positionType >= 0 && positionType < 6); // , "Incorrect Position");
        require(countryCode < 48); //, "Incorrect country");
        require(_playerNames[playerName] == 0); //, "playerName is already used");
        require(countryPlayer[countryCode].length < 1600); //, "this country has 1600 soccer player");
        SpendRCET(100*(10**9));

        uint256 tokenId = _tokenIdCounter;
        // _soccerPlayers[tokenId].country = countryCode;
        // _soccerPlayers[tokenId].year = iMSCL.getYear();
        // _soccerPlayers[tokenId].number = number;
        // _soccerPlayers[tokenId].creator = msg.sender;
        // _soccerPlayers[tokenId].playerName = playerName;
        // _soccerPlayers[tokenId].positionType = positionType;
        // _soccerPlayers[tokenId].SPD = defaults[positionType].SPD;
        // _soccerPlayers[tokenId].DRI = defaults[positionType].DRI;
        // _soccerPlayers[tokenId].PAS = defaults[positionType].PAS;
        // _soccerPlayers[tokenId].SHO = defaults[positionType].SHO;
        // _soccerPlayers[tokenId].STR = defaults[positionType].STR;
        // _soccerPlayers[tokenId].DEF = defaults[positionType].DEF;
        // uint8[] storage pAbilities = _soccerPlayers[tokenId].abilities;
        // pAbilities.push(0);
        // pAbilities.push(0);
        _soccerPlayers[tokenId] = playerValues({
            trainingBeginDate: 0,
            training :0,
            country: countryCode,
            year: iMSCL.getYear(),
            number: number,
            creator: msg.sender,
            playerName: playerName,
            positionType: positionType,
            SPD: defaults[positionType].SPD,
            DRI: defaults[positionType].DRI,
            PAS: defaults[positionType].PAS,
            SHO: defaults[positionType].SHO,
            STR: defaults[positionType].STR,
            DEF: defaults[positionType].DEF,
            abilities: new uint8[](2),
            oldClubs: new uint256[](0), // Initialize empty dynamic array
            club: 0,
            clubName: "",
            transferValue: 0,
            transferYear: 0,
            currentValue: 0,
            matchCounter: 0,
            goalCounter: 0
        });
        countryPlayer[countryCode].push(tokenId);
        

        _balances[msg.sender] += 1;
        _tokenOwner[tokenId] = msg.sender;
        uint256[] storage userTokens = _ownerTokens[msg.sender]; 
        userTokens.push(tokenId);
        _playerNames[playerName] = tokenId;
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

    function getSender() public view returns(address)
    {
        return msg.sender;
    }

    function setTrainingPrice(uint256 newPrice) external onlyOwner {
        trainingPrice = newPrice;
    }

    function setAbilityPrice(uint256 newPrice) external onlyOwner {
        abilityPrice = newPrice;
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
    }

    function setPositionValues( uint8 positionType, uint8[] memory values, uint8[] memory valuesMax) external onlyOwner {
        defaults[positionType].SPD = values[0];
        defaults[positionType].DRI = values[1];
        defaults[positionType].PAS = values[2];
        defaults[positionType].SHO = values[3];
        defaults[positionType].STR = values[4];
        defaults[positionType].DEF = values[5];
        maxs[positionType].SPD = valuesMax[0];
        maxs[positionType].DRI = valuesMax[1];
        maxs[positionType].PAS = valuesMax[2];
        maxs[positionType].SHO = valuesMax[3];
        maxs[positionType].STR = valuesMax[4];
        maxs[positionType].DEF = valuesMax[5];
    }

    function getPlayer(uint256 tokenId) external view returns(uint16,uint16,uint8[3] memory)
    {
        playerValues memory p = _soccerPlayers[tokenId];
        uint8 ABI1 = p.abilities[0] * 10;
        uint8 ABI2 = p.abilities[1] * 10;
        uint8 pos = p.positionType;
        uint16 SHO = p.SHO * 100; //60
        uint16 STR = p.STR * 100; //60
        uint16 SPD = p.SPD * 100; //70
        uint16 PAS = p.PAS * 100; //75
        uint16 DRI = p.DRI * 100; //70
        uint16 DEF = p.DEF * 100; //65
        if (pos == 1) {DRI+= ABI2; SPD+=ABI1;}
        if (pos == 2) {DRI+= ABI1; PAS+=ABI2;}
        if (pos == 3) {PAS+= ABI1; DRI+=ABI2;}
        if (pos == 4) {DEF+= ABI1; DRI+=ABI2;}
        uint16 attack= SHO + STR + SPD + PAS; uint16 defance= DRI + DEF + DEF + STR;
        uint8[3] memory ar = [pos,ABI1,ABI2];
        return(attack , defance, ar);
    }

    //check allowance contract
    function isAllowanceContract() private view returns(bool)
    {
        return iRCET.isAllowanceContract(msg.sender) || address(iRCET) == msg.sender;
    }

    function addGoal(uint256 player, uint8 goalCounter) external returns(bool)
    {
        require(isAllowanceContract(),"Can not use this method");
        _soccerPlayers[player].goalCounter += goalCounter;
        _soccerPlayers[player].matchCounter += 1;
        return true;
    } 

    function isHasClub(uint256 player) external view returns(bool)
    {
        return _soccerPlayers[player].transferYear < iMSCL.getYear();
    }

    function acceptPlayerClub(uint256 player, uint256 club, uint256 index) external returns(bool)
    {
        require(isAllowanceContract(),"Can not use this method");
        require(_soccerPlayers[player].transferYear < iMSCL.getYear(),"player already has a club");
        require(iMSCC.isHasOffer(player, club, index),"offer can not found");
        require(iMSCL.getWeek() < 5 , "you can accept offer only first 4 week");
        require(!iMSCC.isFull(club), "club already has 16 players");
        
        iMSCC.acceptOffer(player, _tokenOwner[player], club, index);
        uint256[] storage oldClubs = _soccerPlayers[player].oldClubs;
        oldClubs.push(_soccerPlayers[player].club);
        _soccerPlayers[player].club = club;
        _soccerPlayers[player].transferYear = iMSCL.getYear();
        return true;
    }

    function rejectPlayerClub(uint256 player, uint256 club, uint256 index) external returns(bool)
    {
        require(isAllowanceContract(),"Can not use this method");
        require(iMSCC.isHasOffer(player, club, index),"offer can not found");
        iMSCC.rejectOffer(player, club, index);
        return true;
    }
}
