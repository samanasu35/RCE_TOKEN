// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface RCETInterface {
    function balanceOf(address account) external view returns (uint256);
    function spend(address from, uint256 value) external returns (bool);
    function earn(address to, uint256 value) external returns (bool);
    function isAllowanceContract(address contractAddress) external view returns(bool);
}

interface MSCCInterface {
    function isHasOffer(uint256 player, uint256 club, uint256 index) external view returns(bool);
    function acceptOffer(uint256 player, address owner, uint256 club, uint256 index) external returns(bool);
    function rejectOffer(uint256 player, uint256 club, uint256 index) external returns(bool);
    function getFirst11(uint256 tokenId) external view returns(uint256[11] memory);
}

interface MSCPInterface {
    function isHasClub(uint256 player) external view returns(bool);
}

interface MSCMInterface {
    function doMatch(uint256 team1, uint256 team2) external returns(uint8, uint8, uint256[11] memory, uint256[11] memory);
}

contract MSCLeague {
    RCETInterface iRCET;
    MSCCInterface iMSCC;
    MSCPInterface iMSCP;
    MSCMInterface iMSCM;

    uint16 private year;
    uint8 private week;
    uint8 private day;
    uint256 private lastExecutedDay;
    bool firstYear = true;

    struct clubValues {
        uint8 country;
        uint256 club;
        uint8 league;
        uint256 order;
        uint16 goal;
        uint8 play;
        uint8 win;
        uint8 lose;
    }

    struct matchValue {
        uint256 club1;
        uint256 club2;
        uint256[] playersClub1;
        uint256[] playersClub2;
        uint8[2] goal;
        uint256 winner;
        bool isComplated;
    }

    address private _owner;
    string[48] private _countries = [
        "Turkey", "United States", "China", "Russia", "Germany", "United Kingdom",
        "Japan", "India", "France", "Brazil", "Italy", "Canada", "Australia",
        "South Korea", "Spain", "Mexico", "Indonesia", "Netherlands", "Saudi Arabia",
        "Switzerland", "Sweden", "Belgium", "Argentina", "Norway", "Austria",
        "United Arab Emirates", "Poland", "Thailand", "Iran", "Israel", "Greece",
        "Singapore", "Ukraine", "Egypt", "South Africa", "Denmark", "Malaysia",
        "Colombia", "Philippines", "Finland", "Chile", "Czech Republic",
        "Romania", "Portugal", "Vietnam", "Peru", "Qatar", "Kazakhstan"
    ];

    //leagues = A,B,C,D,E
    mapping(uint256 => clubValues) clubCurrentValues;
    mapping(uint16 => mapping(uint8 => mapping(uint8 => uint256[]))) private leagues; //year -> country -> league -> clubs

    //year -> country -> league -> week -> match -> matchvalue
    mapping(uint16 => mapping(uint8 => mapping(uint8 => mapping(uint8 => mapping(uint8 => matchValue))))) private archive; 
    mapping(uint16 => uint8[2][10][38]) private weeksMatch;


    // Sadece sahibinin çağırabileceği bir modifier
    modifier onlyOwner() {
        require(msg.sender == _owner, "Only the contract owner can call this function");
        _;
    }

    function addClubtoLeague(uint256 club, uint8 countryCode) external
    {
        require(isAllowanceContract(), "");
        uint8 leagueIndex;
        if (leagues[year][countryCode][0].length < 20) leagueIndex = 0;
        else if (leagues[year][countryCode][1].length < 20) leagueIndex = 1;
        else if (leagues[year][countryCode][2].length < 20) leagueIndex = 2;
        else if (leagues[year][countryCode][3].length < 20) leagueIndex = 3;
        else leagueIndex = 4;
        leagues[year][countryCode][leagueIndex].push(club);
        clubValues storage cValues = clubCurrentValues[club];
        cValues.club = club;
        cValues.country = countryCode;
        cValues.league = leagueIndex;
        cValues.order = leagues[year][countryCode][leagueIndex].length;
    }

    function getClubCurrent(uint256 club) external view returns(clubValues memory)
    {
        return clubCurrentValues[club];
    }

    function getWeeksMatches(uint16 y, uint8 w) public view returns(uint8[2][10] memory)
    {
        require(w > 0 && w < 39, "w(week) must between 1-38");
        require(y == 0 || y >= 2023, "y(year) must 2023 or bigger");
        if(y==0) y = year;
        w--;
        uint8[2][10][38] storage yearMatch = weeksMatch[y];
        return yearMatch[w];
    }

    function doMatch(uint256 club) public returns(uint8, uint8)
    {
        clubValues storage homeValue = clubCurrentValues[club];
        clubValues storage awayValue;
        uint8[2][10] memory weeksM = getWeeksMatches(year, week);
        require(day > 2, "your match is not today");
        uint8[2] memory match1 = weeksM[(day-3)*2];
        uint8[2] memory match2 = weeksM[(day-3)*2+1];
        require(homeValue.order == match1[0] || homeValue.order == match1[1] || homeValue.order == match2[0] || homeValue.order == match2[1],"your match is not today");
        uint8 matchOrder = homeValue.order == match1[0] || homeValue.order == match1[1] ? (day-3)*2 : (day-3)*2 + 1;
        uint256 team1;
        uint256 team2;
        if (homeValue.order == match1[0]) {
            team1 = club;
            team2 = leagues[year][homeValue.country][homeValue.league][match1[1]];
            awayValue = clubCurrentValues[team2];
        }
        else if (homeValue.order == match1[1]) {
            team2 = club;
            team1 = leagues[year][homeValue.country][homeValue.league][match1[1]];
            awayValue = clubCurrentValues[team1];
        }
        else if (homeValue.order == match2[0]) {
            team1 = club;
            team2 = leagues[year][homeValue.country][homeValue.league][match2[1]];
            awayValue = clubCurrentValues[team2];
        }
        else {
            team2 = club;
            team1 = leagues[year][homeValue.country][homeValue.league][match2[1]];
            awayValue = clubCurrentValues[team1];
        }
        
        //maç verilerini gir
        matchValue storage mValue = archive[year][homeValue.country][homeValue.league][week][matchOrder];
        (uint8 goal1, uint8 goal2, uint256[11] memory t1p, uint256[11] memory t2p) = iMSCM.doMatch(team1, team2);
        mValue.club1 = team1;
        mValue.club2 = team2;
        mValue.goal = [goal1,goal2];
        mValue.isComplated = true;
        mValue.playersClub1 = t1p;
        mValue.playersClub2 = t2p;
        mValue.winner = goal1 > goal2 ? team1 : (goal2 > goal1 ? team2 : 0);

        //takım verilerini düzenle
        homeValue.goal+=goal1;
        homeValue.play++;
        homeValue.lose += goal2 > goal1 ? 1 : 0;
        homeValue.win += goal1 > goal2 ? 1 : 0;

        awayValue.goal += goal2;
        awayValue.play++;
        awayValue.win += goal2 > goal1 ? 1 : 0;
        awayValue.lose += goal1 > goal2 ? 1 : 0;

        return (goal1,goal2);
    }

    function getAllMatches() public view returns(uint8[2][10][38] memory)
    {
        return weeksMatch[year];
    }

    function setWeeks(uint8[2][10][38] memory mathes) external onlyOwner returns(bool)
    {
        weeksMatch[year] = mathes;
        return true;
    } 

    constructor() {
        _owner = msg.sender;
        year = 2023;
        week = 1;
        day = 1;
        lastExecutedDay = block.timestamp / 1 days;
    }

    function setInterfaces(address RCET, address MSCP, address MSCC, address MSCM) external onlyOwner
    {
        iRCET = RCETInterface(RCET);
        iMSCC = MSCCInterface(MSCC);
        iMSCP = MSCPInterface(MSCP);
        iMSCM = MSCMInterface(MSCM);
    }

    function getYear() public view returns(uint16) { return year;} 
    function getWeek() public view returns(uint8) { return week;} 
    function getDay() public view returns(uint8) { return day;} 
    function getCountries() external view returns(string[48] memory) { return _countries;} 
    function getCountry(uint8 index) external view returns(string memory) { return _countries[index];} 
    function incDay() external onlyOwner {
        uint256 currentDay = block.timestamp / 1 days;
        require(currentDay > lastExecutedDay, "Function can only be called once per day");
        lastExecutedDay = currentDay;
        day++;
        if (day == 8) {day = 1; incWeek();}
    }
    function incWeek() internal onlyOwner {
        week++;
    }
    function incYear() external onlyOwner { 
        year++; week = 0;
    }

    //check allowance contract
    function isAllowanceContract() private view returns(bool)
    {
        return iRCET.isAllowanceContract(msg.sender) || address(iRCET) == msg.sender;
    }
}