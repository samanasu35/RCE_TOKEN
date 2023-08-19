// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface MSCCInterface {
    function getFirst11(uint256 tokenId) external view returns(uint256[11] memory);
}

interface MSCPInterface {
    function getPlayer(uint256 tokenId) external view returns(uint16,uint16,uint8[3] memory);
}



contract MSCMatch {

    MSCPInterface iMSCP;
    MSCCInterface iMSCC;
    address _owner;

    struct clubValues {
        uint8 country;
        uint8 league;
        address creator;
        uint16 year;
        string clubName;
        uint8[] orders;
        uint256[] players;
    }

    // Sadece sahibinin çağırabileceği bir modifier
    modifier onlyOwner() {
        require(msg.sender == _owner, "ERC721: Only the contract owner can call this function");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function setInterfaces(address MSCC, address MSCP) external onlyOwner
    {
        iMSCC = MSCCInterface(MSCC);
        iMSCP = MSCPInterface(MSCP);
    }

    function doMatch(uint256 team1, uint256 team2) external returns(uint8, uint8, uint256[11] memory,uint256[11] memory )
    {
        uint256[11] memory t1Players = iMSCC.getFirst11(team1);
        uint256[11] memory t2Players = iMSCC.getFirst11(team2);
        uint16[2] memory def; 
        uint16[2] memory attack;
        uint8[2][2] memory keeparAbis;
        uint8[3][2] memory attackerAbis;
        for(uint8 i= 0; i<11;i++)
        {
            (uint16 d1, uint16 a1, uint8[3] memory abis1) = iMSCP.getPlayer(t1Players[i]);
            (uint16 d2, uint16 a2, uint8[3] memory abis2) = iMSCP.getPlayer(t2Players[i]);
            def[0]+=d1; attack[0]+=a1;
            def[1]+=d2; attack[1]+=a2;
            if(abis1[0] == 0) {keeparAbis[0][0] = abis1[1]; keeparAbis[0][1] = abis1[2];} 
            if(abis1[0] == 1) {attackerAbis[0][0] += abis1[1]; attackerAbis[0][1] += abis1[2]; attackerAbis[0][2]++;} 
            if(abis2[0] == 0) {keeparAbis[1][0] = abis2[1]; keeparAbis[1][1] = abis2[2];} 
            if(abis2[0] == 1) {attackerAbis[1][0] += abis2[1]; attackerAbis[1][1] += abis2[2]; attackerAbis[1][2]++;} 
        }
        attackerAbis[0][0] /= attackerAbis[0][2];
        attackerAbis[0][1] /= attackerAbis[0][2];
        attackerAbis[1][0] /= attackerAbis[1][2];
        attackerAbis[1][1] /= attackerAbis[1][2];
        (uint8 g1, uint8 g2) = rnd100(def,attack,keeparAbis,attackerAbis);
        return (g1,g2,t1Players,t2Players);
    }

    uint256 private nonce = 0;
    
    function rnd100(uint16[2] memory def,uint16[2] memory attack,uint8[2][2] memory keeperAbis,uint8[3][2] memory attackerAbis) internal returns (uint8, uint8) {
        uint256 shoot = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;
        uint256 goal = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;
        uint256 keep = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;
        uint256 useSkill = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;
        uint256 useAttackSkill = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;
        uint256 useKeepSkill = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 100 + 1;
        nonce++;

        if (nonce == type(uint128).max) nonce=0;

        // uint16 t1sum = def[0] + attack[0];
        // uint16 t2sum = def[1] + attack[1];
        // uint16 t1 = t1sum * 100 / (t1sum+t2sum);
        uint16 change1 = attack[0] * 100  / (attack[0]+def[1]);
        uint16 change2 = attack[1] * 100  / (attack[1]+def[0]);
        uint8 goal1; uint8 goal2;
        
        for(uint8 i=0; i<9;i++)
        {
            if (i%2==0) //home team attack
            {
                if (shoot < change1) //shoot
                {
                    if(useSkill<51) //use first abis //air ball
                    {
                        if (goal < 10 + (useAttackSkill < attackerAbis[0][0] ? attackerAbis[0][0] : 0)) //
                        {
                            if (keep >= 5 +  (useKeepSkill < keeperAbis[0][0] ? keeperAbis[0][0] : 0)) goal1++;
                        }
                    }
                    else 
                    {
                        if (goal < 10 + (useAttackSkill < attackerAbis[1][0] ? attackerAbis[1][0] : 0)) //
                        {
                            if (keep >= 5 +  (useKeepSkill < keeperAbis[0][0] ? keeperAbis[0][0] : 0)) goal1++;
                        }
                    }
                }
            }
            else 
            {
                if (shoot < change2) //shoot
                {
                    if(useSkill<51) //use first abis //air ball
                    {
                        if (goal < 10 + (useAttackSkill < attackerAbis[0][1] ? attackerAbis[0][1] : 0)) //
                        {
                            if (keep >= 5 +  (useKeepSkill < keeperAbis[0][1] ? keeperAbis[0][1] : 0)) goal2++;
                        }
                    }
                    else 
                    {
                        if (goal < 10 + (useAttackSkill < attackerAbis[1][1] ? attackerAbis[1][1] : 0)) //
                        {
                            if (keep >= 5 +  (useKeepSkill < keeperAbis[0][1] ? keeperAbis[0][1] : 0)) goal2++;
                        }
                    }
                }
            }
        }
        return(goal1,goal2);
    }
}