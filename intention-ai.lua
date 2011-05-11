--This file implements the role strategy of AI. Since the implementation is very complicated you may want to read all the code, output some value and play around with them before you make any improvement.

--tables used in this file

--the royalty change to be made if someone plays the card specified.
--this table handles the cardEffect event.
sgs.ai_card_intention={}

--the royalty change to be made if someone plays the card specified.
--this table handles the cardUsed event.
sgs.ai_carduse_intention={}

--the number of remaining unknown roles.
sgs.ai_assumed={}
sgs.ai_assumed["rebel"]=0
sgs.ai_assumed["loyalist"]=0
sgs.ai_assumed["renegade"]=0

--the number of times when a player behaves against his displayed intention (like when someone who had been fighting against the rebels suddenly slashes a loyalist)
sgs.ai_renegade_suspect={}

--the number of times a player does something hostile to the lord
sgs.ai_anti_lord={}

--the number of times the hostile actions from a player can be "tolerated" (the lord doesn't treat him as a permanent rebel)
sgs.ai_lord_tolerance={}

--the role that a player "looks like"
--possible values are rebel, rebelish, nil, loyalish, loyalist
sgs.ai_explicit={}

--the degree of royalty of a player
sgs.ai_royalty={}

--returns a value that determines AI's hostility towards a player.
--basically >0 means enemy, <0 means friend, -2 means absolute friend(like lord for a loyalist), 3 means unknown potential enemy, 5 means most important targets, 4 means less important enemies 

function SmartAI:objectiveLevel(player)
    if isRolePredictable() then 
        if self:isFriend(player) then return -2
        elseif player:isLord() then return 5
        elseif player:getRole()=="renegade" then return 4.1
        else return 4.5 end
    end

    local modifier=0
    local rene=sgs.ai_renegade_suspect[player:objectName()] or 0
    if rene>1 then modifier=0.5 end
    
    local players=self.room:getOtherPlayers(self.player)
    players=sgs.QList2Table(players)
        
    if self.role=="lord" then
    
        local hasRebel=false
        for _,player in ipairs(players) do
            if player:getRole()=="rebel" then hasRebel=true break end
        end
        
        if not hasRebel then 
        
            local name=player:objectName()
        
            self:sort(players,"defense")
            if (players[#players]:objectName()==name) then modifier=-10
            elseif players[1]:objectName()==name and ((sgs.ai_anti_lord[name] or 0)-2)<=(sgs.ai_lord_tolerance[name] or 0) then modifier=10
            else modifier=2
            end
        end
        if sgs.ai_explicit[player:objectName()]=="rebel" then return 5-modifier
        elseif sgs.ai_explicit[player:objectName()]=="rebelish" then return 5-modifier
        elseif sgs.ai_explicit[player:objectName()]=="loyalist" then return -2
        elseif sgs.ai_explicit[player:objectName()]=="loyalish" then return -1
        elseif (self:singleRole())=="rebel" then return 4.6-modifier
        elseif (self:singleRole())=="loyalist" then return -1
        elseif (sgs.ai_royalty[player:objectName()]<=0) and 
            (sgs.ai_card_intention["general"](player,100)>0) 
            then return 3
        else return 0 end
    elseif self.role=="loyalist" then
        if sgs.ai_explicit[player:objectName()]=="rebel" then return 5-modifier
        elseif sgs.ai_explicit[player:objectName()]=="rebelish" then return 5-modifier
        elseif player:isLord() then return -2
        elseif sgs.ai_explicit[player:objectName()]=="loyalist" then return -1
        elseif sgs.ai_explicit[player:objectName()]=="loyalish" then return -1
        elseif (self:singleRole())=="rebel" then return 4-modifier
        elseif (self:singleRole())=="loyalist" then return -1
        elseif (sgs.ai_royalty[player:objectName()]<=0) and 
            (sgs.ai_card_intention["general"](player,100)>0) 
            then return 3.1
        else return 0 end
    elseif self.role=="rebel" then
        if sgs.ai_explicit[player:objectName()]=="loyalist" then return 5-modifier
        elseif sgs.ai_explicit[player:objectName()]=="loyalish" then return 5-modifier
        elseif sgs.ai_explicit[player:objectName()]=="rebel" then return -1
        elseif sgs.ai_explicit[player:objectName()]=="rebelish" then return -1
        elseif (self:singleRole())=="rebel" then return -1
        elseif (self:singleRole())=="loyalist" then return 4-modifier
        elseif (sgs.ai_royalty[player:objectName()]>0) and 
            (sgs.ai_card_intention["general"](player,100)<0) 
            then return 3
        else return 0 end
    elseif self.role=="renegade" then
        
        if #players==1 then return 5 end
        --if (#players==2) and player:isLord() then return 0 end
        if player:isLord() then return -2
        else

            local rnum=0
            local rval=0
            for _, aplayer in ipairs (players) do
                if aplayer:getRole()=="rebel" then 
                    rnum=rnum+getDefense(aplayer)
                    rval=rval+1
                elseif not aplayer:isLord() then rnum=rnum-getDefense(aplayer)
                else
                    rnum=rnum-getDefense(aplayer)*1.5
                end
            end
            
            local loyal_thresh=-2*#players
            
            if (rnum>loyal_thresh) or (self.room:getLord():getHp()<=rval) then
                self.role="loyalist"
                local level=self:objectiveLevel(player)
                self.role="renegade"
                return level
            else
                self.role="rebel"
                local level=self:objectiveLevel(player)
                self.role="renegade"
                return level
            end
        end
    end
    return 1
end

--this method is for debugging, skip this part if you want
function SmartAI:printStand()
    self.room:output(self.player:getRole())
    self.room:output("enemies:")
    for _, player in ipairs(self.enemies) do
        self.room:output(player:getGeneralName())
    end
    self.room:output("end of enemies")
    self.room:output("friends:")
    for _, player in ipairs(self.friends) do
        self.room:output(player:getGeneralName())
    end
    self.room:output("end of friends")
end

--this method checks system configuration and returns true if role strategy is not enabled.
function isRolePredictable()
    local mode=sgs.GetConfig("GameMode", "")
    if (mode=="06_3v3") or (not mode:find("0")) then return true end
    if (mode:find("02_1v1") or mode:find("03p")) then return true end
    
    return not sgs.GetConfig("RolePredictable", true)
end

-- this function create 2 tables contains the friends and enemies, respectively
function SmartAI:updatePlayers(inclusive)
        --self:log("updated")
        self.friends = sgs.QList2Table(self.lua_ai:getFriends())
        table.insert(self.friends, self.player)

        self.friends_noself = sgs.QList2Table(self.lua_ai:getFriends())

        sgs.rebel_target=self.room:getLord()
        
        self.enemies = sgs.QList2Table(self.lua_ai:getEnemies())
        
        
        if isRolePredictable() then
            sgs.ai_explicit[self.player:objectName()]=self.role
            self.retain=2
            self.harsh_retain=false
            return
        end
        
        inclusive=inclusive or true
        
        local flist={}
        local elist={}
        self.enemies=elist
        self.friends=flist


        local lord=self.room:getLord()
        local role=self.role
        self.retain=2
        self.harsh_retain=true

        local players=self.room:getOtherPlayers(self.player)
        players=sgs.QList2Table(players)


        for _,player in ipairs(players) do
            if #players==1 then break end
            if self:objectiveLevel(player)<0 then table.insert(flist,player) end
        end

        self.friends_noself={}

        for _, player in ipairs (flist) do
            table.insert(self.friends_noself,player)
        end
        table.insert(self.friends,self.player)

        if self.role=="rebel" then
            sgs.rebel_target=self.room:getLord()
            self.retain=2
        end
--
        if self.player:getHp()<2 then self.retain=0 end
        self:sortEnemies(players)
        for _,player in ipairs(players) do
            if self:objectiveLevel(player)>=4 then self.harsh_retain=false end
            if #elist==0 then
                table.insert(elist,player)
                if self:objectiveLevel(player)<4 then self.retain=0 end
            else
                if self:objectiveLevel(player)<=0 then break end
                table.insert(elist,player)
                self:updateLoyalTarget(player)
                
                if self:objectiveLevel(player)>=4 then self.harsh_retain=false end
                --local use=self:getTurnUse()
                    --if (#use)>=(self.player:getHandcardNum()-self.player:getHp()+self.retain) then
                        --self.room:output(#    use.."cards can be used")
                        --if not inclusive then return end
                    --end
            end
        end



end

--a generic function that deals the royalty change of some "level" when a card is played against "to"
--guessing the unknown roles is also implemented here
sgs.ai_card_intention["general"]=function(to,level)
    if to:isLord() then
        return -level*2
    elseif sgs.ai_explicit[to:objectName()]=="loyalist" then
        return -level
    elseif sgs.ai_explicit[to:objectName()]=="loyalish" then
        return -level
    elseif sgs.ai_explicit[to:objectName()]=="rebel" then
        return level
    elseif sgs.ai_explicit[to:objectName()]=="rebelish" then
        return level
    else
        local nonloyals=sgs.ai_assumed["rebel"]--+sgs.ai_assumed["renegade"]
        local loyals=sgs.ai_assumed["loyalist"]
        if loyals+nonloyals<=1 then return 0 end
        
        local ratio
        if loyals<=0 then ratio=1
        elseif nonloyals<=0 then ratio =-1 
        
        else
             local ratio1=(-loyals+nonloyals-1)/(loyals+nonloyals)
             local ratio2=(-loyals+nonloyals+1)/(loyals+nonloyals)
             ratio=1-math.sqrt((1-ratio1)*(1-ratio2))
             --if ratio1*ratio1>ratio2*ratio2 then ratio=ratio1
             --else ratio=ratio2 end
             --ratio=ratio
        end
        
        --if level==80 then to:getRoom():output(ratio) end
        return level*ratio
    end
end

-- here's the functions you want to add or modify
-- positive numbers means hostile, negative means friendly behavior against the "to" player

sgs.ai_carduse_intention["Indulgence"]=function(card,from,to,source)
    return sgs.ai_card_intention.general(to,120)
end

sgs.ai_carduse_intention["SupplyShortage"]=function(card,from,to,source)
    return sgs.ai_card_intention.general(to,120)
end

sgs.ai_card_intention["Slash"]=function(card,from,to,source)
    if sgs.ai_liuliEffect then
        sgs.ai_liuliEffect=false
        return 0
    end
    local modifier=0
    if sgs.ai_collateral then sgs.ai_collateral=false modifier=-40 end
    return sgs.ai_card_intention.general(to,80+modifier)
end

sgs.ai_card_intention["FireSlash"]=function(card,from,to,source)
    if sgs.ai_liuliEffect then
        sgs.ai_liuliEffect=false
        return 0
    end
    local modifier=0
    if sgs.ai_collateral then sgs.ai_collateral=false modifier=-40 end
    return sgs.ai_card_intention.general(to,80+modifier)
end

sgs.ai_card_intention["ThunderSlash"]=function(card,from,to,source)
    if sgs.ai_liuliEffect then
        sgs.ai_liuliEffect=false
        return 0
    end
    local modifier=0
    if sgs.ai_collateral then sgs.ai_collateral=false modifier=-40 end
    return sgs.ai_card_intention.general(to,80+modifier)
end

sgs.ai_card_intention["Peach"]=function(card,from,to,source)
        return sgs.ai_card_intention.general(to,-80)
end

sgs.ai_card_intention["Duel"]=function(card,from,to,source)
    if sgs.ai_lijian_effect then 
        sgs.ai_lijian_effect=false
        return 0 
    end
    return sgs.ai_card_intention.general(to,80)
end

sgs.ai_card_intention["Collateral"]=function(card,from,to,source)
    sgs.ai_collateral=true
    return sgs.ai_card_intention.general(to,80)
end

sgs.ai_card_intention["FireAttack"]=function(card,from,to,source)
    return sgs.ai_card_intention.general(to,80)
end

sgs.ai_card_intention["IronChain"]=function(card,from,to,source)
    --to:getRoom():output(to:isChained())
    if not to:isChained() then
        return sgs.ai_card_intention.general(to,80)
    else return sgs.ai_card_intention.general(to,-80)
    end
end

sgs.ai_card_intention["ArcheryAttack"]=function(card,from,to,source)
        --return sgs.ai_card_intention.general(to,40)
        return 0
end

sgs.ai_card_intention["SavageAssault"]=function(card,from,to,source)
        --return sgs.ai_card_intention.general(to,40)
        return 0
end

sgs.ai_card_intention["AmazingGrace"]=function(card,from,to,source)
        --return sgs.ai_card_intention.general(to,-20)
        return 0
end

sgs.ai_card_intention["Dismantlement"]=function(card,from,to,source)
        if to:containsTrick("indulgence") or to:containsTrick("supply_shortage") then 
            sgs.ai_snat_disma_effect=true
            sgs.ai_snat_dism_from=from
            return 0 
        end
        return sgs.ai_card_intention.general(to,70)
end

sgs.ai_card_intention["Snatch"]=function(card,from,to,source)
        if to:containsTrick("indulgence") or to:containsTrick("supply_shortage") then 
            sgs.ai_snat_disma_effect=true
            sgs.ai_snat_dism_from=from
            return 0 
        end
        return sgs.ai_card_intention.general(to,70)
end

sgs.ai_card_intention["TuxiCard"]=function(card,from,to,source)
--        from:getRoom():output("a TuxiCard")
        return sgs.ai_card_intention.general(to,80)
end

sgs.ai_carduse_intention["LeijiCard"]=function(card,from,to,source)
--        from:getRoom():output("a LeijiCard")
        return sgs.ai_card_intention.general(to,80)
end

sgs.ai_carduse_intention["RendeCard"]=function(card,from,to,source)
--        from:getRoom():output("a RendeCard")
        return sgs.ai_card_intention.general(to,-70)
end

sgs.ai_carduse_intention["QingnangCard"]=function(card,from,to,source)
--        from:getRoom():output("a QingnangCard")
        return sgs.ai_card_intention.general(to,-100)
end

sgs.ai_card_intention["ShensuCard"]=function(card,from,to,source)
--        from:getRoom():output("a ShensuCard")
        return sgs.ai_card_intention.general(to,80)
end

sgs.ai_card_intention["QiangxiCard"]=function(card,from,to,source)
--        from:getRoom():output("a ShensuCard")
        return sgs.ai_card_intention.general(to,80)
end

sgs.ai_carduse_intention["LijianCard"]=function(card,from,to,source)
--        from:getRoom():output("a LijianCard")
        if not sgs.ai_lijian_effect then
            sgs.ai_lijian_effect=true
            return sgs.ai_card_intention.general(to,70)
        else
            sgs.ai_lijian_effect=false
            return 0
        end
end

sgs.ai_carduse_intention["JieyinCard"]=function(card,from,to,source)
--        from:getRoom():output("a JieyinCard")
        return sgs.ai_card_intention.general(to,-80)
end

sgs.ai_carduse_intention["HuangtianCard"]=function(card,from,to,source)
        sgs.ai_lord_tolerance[from:objectName()]=(sgs.ai_lord_tolerance[from:objectName()] or 0)+1
--        from:getRoom():output("a JieyinCard")
        return sgs.ai_card_intention.general(to,-80)
end

sgs.ai_carduse_intention["JiemingCard"]=function(card,from,to,source)
--        from:getRoom():output("a JieyinCard")
        return sgs.ai_card_intention.general(to,-80)
end

sgs.ai_carduse_intention["HaoshiCard"]=function(card,from,to,source)
--        from:getRoom():output("a HaoCard")
        return sgs.ai_card_intention.general(to,-80)
end

sgs.ai_carduse_intention["FanjianCard"]=function(card,from,to,source)
--        from:getRoom():output("a FanjianCard")
        return sgs.ai_card_intention.general(to,70)
end

sgs.ai_carduse_intention["TianyiCard"]=function(card,from,to,source)
--        from:getRoom():output("a FanjianCard")
        return sgs.ai_card_intention.general(to,70)
end

sgs.ai_carduse_intention["QuhuCard"]=function(card,from,to,source)
--        from:getRoom():output("a FanjianCard")
        return sgs.ai_card_intention.general(to,70)
end

sgs.ai_carduse_intention["LiuliCard"]=function(card,from,to,source)
--        from:getRoom():output("a LiuliCard")
        sgs.ai_liuliEffect=true
        return sgs.ai_card_intention.general(to,70)
end

--these two tables are not used, they are a prototype I used before I have the functions above

sgs.ai_offensive_card=
{
    Slash=true,
    ThunderSlash=true,
    FireSlash=true,
    Duel=true,
    Collateral=true,
    Slash=true,
    FireAttack=true,
    Indulgence=true,
    SupplyShortage=true,
    IronChain=true,
}

sgs.ai_ambiguous_card=
{
   Dismantlement=true,
   Snatch=true,
   AmazingGrace=true,
   ArcheryAttack=true,
   SavageAssault=true,

}

--bullshit, skip it
function SmartAI:updateRoyalty(player)
end

--used for debug
function SmartAI:printRoyalty()
        player=self.player
        self.room:output(player:getGeneralName().." "..sgs.ai_royalty[player:objectName()].." "..(sgs.ai_explicit[player:objectName()] or " "))
end

--update a player's royalty by the specified amount and also update the explicit table.
function SmartAI:refreshRoyalty(player,intention)
    if player:isLord() then return end
    local name=player:objectName()

        if (intention>=70) or (intention<=-70) then
            if sgs.ai_royalty[name]*intention<0 then
            sgs.ai_royalty[name]=sgs.ai_royalty[name]/2
            self:refreshRoyalty(player,0)
            sgs.ai_renegade_suspect[name]=(sgs.ai_renegade_suspect[name] or 0)+1
            end
        end
        
        if ((sgs.ai_anti_lord[name] or 0)-2)>(sgs.ai_lord_tolerance[name] or 0) then 
            if intention>0 then intention=intention/5 end
        end
        sgs.ai_royalty[name]=sgs.ai_royalty[name]+intention
        
        if sgs.ai_explicit[name]=="loyalish" then
            sgs.ai_assumed["loyalist"]=sgs.ai_assumed["loyalist"]+1
        elseif sgs.ai_explicit[name]=="loyalist" then
            sgs.ai_assumed["loyalist"]=sgs.ai_assumed["loyalist"]+1
        elseif sgs.ai_explicit[name]=="rebelish" then
            sgs.ai_assumed["rebel"]=sgs.ai_assumed["rebel"]+1
        elseif sgs.ai_explicit[name]=="rebel" then
            sgs.ai_assumed["rebel"]=sgs.ai_assumed["rebel"]+1
        end
        sgs.ai_explicit[name]=nil
        
    if sgs.ai_royalty[name]<=-160 then
        if not sgs.ai_explicit[name] then sgs.ai_assumed["rebel"]=sgs.ai_assumed["rebel"]-1 end
        sgs.ai_explicit[name]="rebel"
        sgs.ai_royalty[name]=-160
    elseif sgs.ai_royalty[name]<=-70 then
        if not sgs.ai_explicit[name] then sgs.ai_assumed["rebel"]=sgs.ai_assumed["rebel"]-1 end
        sgs.ai_explicit[name]="rebelish"
    elseif sgs.ai_royalty[name]>=160 then
        if not sgs.ai_explicit[name] then sgs.ai_assumed["loyalist"]=sgs.ai_assumed["loyalist"]-1 end
        sgs.ai_explicit[name]="loyalist"
        sgs.ai_royalty[name]=160
    elseif sgs.ai_royalty[name]>=70 then
        if not sgs.ai_explicit[name] then sgs.ai_assumed["loyalist"]=sgs.ai_assumed["loyalist"]-1 end
        sgs.ai_explicit[name]="loyalish"
    elseif sgs.ai_explicit[name] then
    end
end

--used for debug
function SmartAI:printAssume()
	self.room:output(sgs.ai_assumed["rebel"])
	self.room:output(sgs.ai_assumed["loyalist"])
	self.room:output("----")
end

function SmartAI:printObjective()
        local players=self.room:getOtherPlayers(self.player)
        self:log("")
        self:log(self.player:getGeneralName())
        
        for _,player in sgs.qlist(players) do 
            self:log(player:getGeneralName().." : "..self:objectiveLevel(player))
        end
end

function SmartAI:getPreferedActions()
end

--return nil if there are more than one possible roles for the remainning unknown characters
--return loyalist or rebel if that is the only possible role for the remainning unknow characters
--doesn't consider renegades.seems that this method doesn;t work well when there are two renegades in play.
function SmartAI:singleRole()
    local roles=0
    local theRole
    local selfexp=sgs.ai_explicit[self.player:objectName()]
    if selfexp=="loyalish" then selfexp="loyalist"
    elseif selfexp=="rebelish" then selfexp="rebel"
    end
    local selftru=self.role
    
    if (self.role~="lord") and (self.role~="renegade") then sgs.ai_assumed[self.role]=sgs.ai_assumed[self.role]-1 end
    if selfexp then sgs.ai_assumed[selfexp]=(sgs.ai_assumed[selfexp] or 0)+1 end
    	
    
    if sgs.ai_assumed["rebel"]>0 then
        roles=roles+1
        theRole="rebel"
    end
    if sgs.ai_assumed["loyalist"]>-1 then
        roles=roles+1
        theRole="loyalist"
    end
    
    if (self.role~="lord") and (self.role~="renegade") then sgs.ai_assumed[self.role]=sgs.ai_assumed[self.role]+1 end
    if selfexp then sgs.ai_assumed[selfexp]=sgs.ai_assumed[selfexp]-1 end
    
    
    if roles==1 then
        if sgs.ai_assumed["loyalist"]==sgs.ai_assumed["rebel"] then return nil end
        return theRole
    end
    return nil
end

--bullshit that I have planned to code but not yet done.

function SmartAI:getInflictTargets()
    
end

function SmartAI:getProtectTarget()
    
end

function SmartAI:getSupportTarget()
    
end

function SmartAI:getWeakenTarget()
    
end

