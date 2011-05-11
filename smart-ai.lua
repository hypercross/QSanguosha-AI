 -- This is the Smart AI, and it should be loaded and run at the server side

-- "middleclass" is the Lua OOP library written by kikito
-- more information see: https://github.com/kikito/middleclass
require "middleclass"

-- initialize the random seed for later use
math.randomseed(os.time())

-- this table stores all specialized AI classes
sgs.ai_classes = {}



sgs.ai_skill_use_func={}
sgs.ai_skills={}

-- this function is only function that exposed to the host program
-- and it clones an AI instance by general name
function CloneAI(player)
	local ai_class = sgs.ai_classes[player:getGeneralName()]
	if ai_class then
		return ai_class(player).lua_ai
	else
		return SmartAI(player).lua_ai
	end
end

function getCount(name)
	if sgs.ai_round[name] then 
                sgs.ai_round[name]=sgs.ai_round[name]+1
	else 
		sgs.ai_round[name]=1 
	end
        return sgs.ai_round[name]
end

--defense is defined as hp*2 + hand + (2)(if armor present)
function getDefense(player)
	local d=player:getHp() * 2 + player:getHandcardNum()
	if(d>player:getHp()*3) then d=player:getHp()*3 end
	if player:getArmor() then d=d+2 end
	return d
end

-- SmartAI is the base class for all other specialized AI classes
SmartAI = class "SmartAI"


-- the "initialize" function is just the "constructor"
function SmartAI:initialize(player)
	
	self.player = player
	self.room = player:getRoom()
	
        self.role =player:getRole()

        if sgs.ai_assumed[self.role] then sgs.ai_assumed[self.role] = sgs.ai_assumed[self.role] +1
        elseif self.role~="lord" then sgs.ai_assumed[self.role] =1
        end
	
	
	self.lua_ai = sgs.LuaAI(player)
	self.lua_ai.callback = function(method_name, ...)
		local method = self[method_name]
		if method then
			return method(self, ...)
		end
	end

        
        self.retain=2
        --self.harsh_retain=true
        if not sgs.ai_royalty[self.player:objectName()] then
            --self.room:output("initialized"..self.player:objectName()..self.role)
            sgs.ai_royalty[self.player:objectName()]=0
        end
        if self.player:isLord() then
            sgs.ai_royalty[self.player:objectName()]=160
            sgs.ai_explicit[self.player:objectName()]="loyalist"
            if (sgs.ai_chaofeng[self.player:getGeneralName()] or 0) < 3 then
                sgs.ai_chaofeng[self.player:getGeneralName()]=3
            end
        end
        



        --self:updatePlayers()
end

function SmartAI:updateLoyalTarget(player)
if self.role=="rebel" then return end
    if (self:objectiveLevel(player)>4) then
        if not sgs.loyal_target then sgs.loyal_target=player 
        elseif (sgs.loyal_target:getHp()>1) and (getDefense(player)<=3) then sgs.loyal_target=player 
        elseif (sgs.loyal_target:getHandcardNum()>0) and (player:getHandcardNum()==0) then sgs.loyal_target=player 
        elseif (sgs.ai_chaofeng[player:getGeneralName()] or 0)>(sgs.ai_chaofeng[sgs.loyal_target:getGeneralName()] or 0) then sgs.loyal_target=player 
        elseif (sgs.loyal_target:getArmor()) and (not player:getArmor()) then sgs.loyal_target=player 
        end
    end
end

function SmartAI:printFEList()
    self.room:output("-----------")
    self.room:output(self.player:getGeneralName().." list:")
    for _, player in ipairs (self.enemies) do
        self.room:output("enemy "..player:getGeneralName()..(sgs.ai_explicit[player:objectName()] or ""))
    end

    for _, player in ipairs (self.friends_noself) do
        self.room:output("friend "..player:getGeneralName()..(sgs.ai_explicit[player:objectName()] or ""))
    end
    self.room:output(self.player:getGeneralName().." list end")
end

function SmartAI:sortEnemies(players)
    local comp_func=function(a,b)
        local alevel=self:objectiveLevel(a)
        local blevel=self:objectiveLevel(b)

        if alevel~=blevel then return alevel>blevel end
        if alevel==3 then return getDefense(a)>getDefense(b) end

        alevel=sgs.ai_chaofeng[a:getGeneralName()] or 0
        blevel=sgs.ai_chaofeng[b:getGeneralName()] or 0
        if alevel~=blevel then
            return alevel>blevel
        end

        alevel=getDefense(a)
        blevel=getDefense(b)
        if alevel~=blevel then
            return alevel<blevel
        end
    end
    table.sort(players,comp_func)
end



function SmartAI:filterEvent(event, player, data)


        if event == sgs.CardUsed then
            self:updatePlayers()
        elseif event == sgs.CardEffect then
            self:updatePlayers()
        elseif event == sgs.Death then
                self:updatePlayers()
                if self==sgs.recorder then
                	local selfexp=sgs.ai_explicit[player:objectName()]
                	if selfexp then
                	    if selfexp=="loyalish" then selfexp="loyalist"
                	    elseif selfexp=="rebelish" then selfexp="rebel"
                	    end
                    	sgs.ai_explicit[player:objectName()]=nil
                    	sgs.ai_assumed[selfexp]=sgs.ai_assumed[selfexp]+1
                    end
                    sgs.ai_assumed[player:getRole()]=sgs.ai_assumed[player:getRole()]-1 
                end
        end
        if (event == sgs.TurnStart) or (event == sgs.GameStart) then
                self:updatePlayers()
                --if (self.room:nextPlayer():objectName()==self.player:objectName()) then
                for _,skill in ipairs(sgs.ai_skills) do
                    if self:hasSkill(skill) then
                    self[skill.name.."_used"]=false
                    end
                end
                

                --end
                --self:updatePlayers()
                 --self:printRoyalty()
        end

        if not sgs.recorder then
            sgs.recorder=self
        end

        if self~=sgs.recorder then return end


        if event == sgs.TurnStart then
            self:updateRoyalty(self.room:getCurrent())
        end

        if event == sgs.CardEffect then

                local struct= data:toCardEffect()
                local card  = struct.card
                local to    = struct.to
                local from  = struct.from
                local source= self.room:getCurrent()
--                self.room:output(
  --                  card:className().." "..
    --                from:getGeneralName().." "..
      --              to:getGeneralName().." ".."effected")
                if sgs.ai_card_intention[card:className()] then
                    local intention=sgs.ai_card_intention[card:className()](card,from,to,source)
                    --self.room:output(intention..">")
                    if to:isLord() and intention<0 then 
                    sgs.ai_anti_lord[from:objectName()]=(sgs.ai_anti_lord[from:objectName()] or 0)+1
                    end
                    self:refreshRoyalty(from,intention)
                end
        elseif event == sgs.CardUsed then
                local struct= data:toCardUse()
                --self.room:output("struct")
                local card  = struct.card

--                self.room:output("Card")
                local to    = struct.to
                      to    = sgs.QList2Table(to)
--                self.room:output("to")
                local from  = struct.from
--                self.room:output("from")
                local source= self.room:getCurrent()

 --               self.room:output(
   --                 card:className().." "..
     --               from:getGeneralName().." ".."used"
       --             )
                   

                for _, eachTo in ipairs(to) do
                    if sgs.ai_carduse_intention[card:className()] then
                        local intention=sgs.ai_carduse_intention[card:className()](card,from,eachTo,source)
                        self:refreshRoyalty(from,intention)
                        
                        if eachTo:isLord() and intention<0 then 
                        sgs.ai_anti_lord[from:objectName()]=(sgs.ai_anti_lord[from:objectName()] or 0)+1
                        end
                        
                    end
                    self.room:output(eachTo:objectName())
                end
        elseif event == sgs.DrawNCards then
            --self.room:output(player:getGeneralName().." draws "..data:toInt())

        elseif event == sgs.CardDiscarded then
            local card = data:toCard()
            local cards= card:getSubcards()
            if type(cards)=="QList" then
                cards=sgs.QList2Table(cards)
                self.room:output(player:getGeneralName().." discards "..table.concat(cards,"+"))
            end

        elseif event == sgs.CardResponsed then
            local card = data:toCard()
            --self.room:output(player:getGeneralName().." responded with "..card:className())

        elseif event == sgs.CardLost then
            local move=data:toCardMove()
            local from=move.from
            local to=  move.to
            local place=move.from_place
            if sgs.ai_snat_disma_effect then 
                self.room:output(
                    "cardlostevent "..
                    from:getGeneralName().." "..
                    place
                    )
                sgs.ai_snat_disma_effect=false
                local intention=sgs.ai_card_intention.general(from,70)
                if place==2 then intention=-intention end
                
                if from:isLord() and intention<0 then 
                sgs.ai_anti_lord[sgs.ai_snat_dism_from:objectName()]=(sgs.ai_anti_lord[sgs.ai_snat_dism_from:objectName()] or 0)+1
                end
                
                self:refreshRoyalty(sgs.ai_snat_dism_from,intention)
            end
        end

end


-- the table that stores whether the skill should be invoked
-- used for SmartAI:askForSkillInvoke


function SmartAI:searchForAnaleptic(use,enemy,slash)

    
    
    if not self.toUse then return nil end
    --if #self.toUse<=1 then return nil end
    if not use.to then return nil end
    if self.anal_used then return nil end
    
    local cards = self.player:getHandcards()
    cards=sgs.QList2Table(cards)
    self:fillSkillCards(cards)
    
    
   if (getDefense(self.player)<getDefense(enemy))and
   (self.player:getHandcardNum()<1+self.player:getHp()) or
     self.player:hasFlag("drank") then return end

    if enemy:getArmor() then 
        if ((enemy:getArmor():objectName())=="eight_diagram")
            or ((enemy:getArmor():objectName())=="silver_lion") then return nil end end
    for _, anal in ipairs(cards) do
        if (anal:className()=="Analeptic") and not (anal:getEffectiveId()==slash:getEffectiveId()) then
            self.anal_used=true
            
            return anal
        end
    end
return nil
end



function SmartAI:getTurnUse()
    local cards = self.player:getHandcards()
    cards=sgs.QList2Table(cards)
    
    
    
    local turnUse={}
    local slashAvail=1
    self.predictedRange=self.player:getAttackRange()
    self.predictNewHorse=false
    self.retain_thresh=5
    self.slash_targets=1
    self.slash_distance_limit=false
    
    self.weaponUsed=false
    
    if self.player:isLord() then self.retain_thresh=6 end
    if self.player:hasFlag("tianyi_success") then 
        slashAvail=2 
        self.slash_targets=2
        self.slash_distance_limit=true
    end
    
    self:fillSkillCards(cards)
    
    self:sortByUseValue(cards)
    
    if self.player:hasSkill("paoxiao") or 
        (
            self.player:getWeapon() and 
            (self.player:getWeapon():objectName()=="crossbow")
        ) then
        slashAvail=100
    end
    
            
    local i=0
    --self.room:output(#cards)
    for _,card in ipairs(cards) do
        local dummy_use={}
        dummy_use.isDummy=true
        if (not self.player:hasSkill("kongcheng")) and (not self.player:hasSkill("lianying")) then
            if (i >= (self.player:getHandcardNum()-self.player:getHp()+self.retain)) and (self:getUseValue(card)<self.retain_thresh) then
                --if self.room:getCurrent():objectName()==self.player:objectName() then self:log(card:className()..self:getUseValue(card)) end
                return turnUse
            end
        
            if (i >= (self.player:getHandcardNum()-self.player:getHp())) and (self:getUseValue(card)<8.5) and self.harsh_retain then
                --if self.room:getCurrent():objectName()==self.player:objectName() then self:log(card:className()..self:getUseValue(card)) end
                return turnUse
            end
        end
        
        local type = card:getTypeId()
        if type == sgs.Card_Basic then
            self:useBasicCard(card, dummy_use, self.slash_distance_limit)
        elseif type == sgs.Card_Trick then
            self:useTrickCard(card, dummy_use)
        elseif type == sgs.Card_Equip then
            self:useEquipCard(card, dummy_use)
        elseif type == sgs.Card_Skill then
            self:useSkillCard(card, dummy_use)
        end


        if dummy_use.card then
            if (card:inherits("Slash")) then 
                if slashAvail>0 then
                    slashAvail=slashAvail-1
                    table.insert(turnUse,card)
                    
                end
            else
                if card:inherits("Weapon") then 
                    self.predictedRange=sgs.weapon_range[card:className()] 
                    self.weaponUsed=true
                end
                if card:inherits("OffensiveHorse") then self.predictNewHorse=true end
                if card:objectName()=="crossbow" then slashAvail=100 end
                if card:inherits("Snatch") then i=i-1 end
                if card:inherits("Peach") then i=i+2 end
                if card:inherits("Collateral") then i=i-1 end
                if card:inherits("AmazingGrace") then i=i-1 end
                if card:inherits("ExNihilo") then i=i-2 end
                table.insert(turnUse,card)
            end
            i=i+1
        else
--            self.room:output(card:className().." unused")
        end
    end
--    self.room:output(self.player:getGeneralName()..i)
    return turnUse
end

function SmartAI:activate(use)
		--self.room:output(self:singleRole())
		--self:printAssume()
		self:printObjective()
        --local moves=self:getMoves()
        --self:printMoves(moves)
        --if self.player:getHandcardNum()<self.player:getHp() then return end
        --self.room:output(getCount(self.player:objectName()))
        self:updatePlayers()
        self.toUse =self:getTurnUse()
        --self:printCards(self.toUse)
        if self.harsh_retain then self:log("harsh_retaining") end
        --self:printFEList()
        --local cards = self.player:getHandcards()
        --cards=sgs.QList2Table(cards)
        --self:sortByUsePriority(cards)
        --self.room:output("usesize"..#self.toUse)

        self:sortByUsePriority(self.toUse)
        for _, card in ipairs(self.toUse) do

			local type = card:getTypeId()

			if type == sgs.Card_Basic then
				self:useBasicCard(card, use, self.slash_distance_limit)
			elseif type == sgs.Card_Trick then
				self:useTrickCard(card, use)
		    elseif type == sgs.Card_Skill then
                self:useSkillCard(card, use)
			else
				self:useEquipCard(card, use)
			end
                        if use:isValid() then
--                        self.room:output("card Used")
                self.toUse=nil
				return
                        else
                            self.room:output("invalidUseCard")
                        end
                end
        self.toUse=nil
end

function SmartAI:getOneFriend()
	for _, friend in ipairs(self.friends) do
		if friend ~= self.player then
			return friend
		end
	end
end

function SmartAI.newSubclass(theClass, name)
	local class_name = name:sub(1, 1):upper() .. name:sub(2) .. "AI"
	local new_class = class(class_name, theClass)

	function new_class:initialize(player)
		super.initialize(self, player)
	end

	sgs.ai_classes[name] = new_class

	return new_class
end

function SmartAI:setOnceSkill(name)
	function self:filterEvent(event, player, data)
		super.filterEvent(self, event, player, data)
		if not player then return end
		if event == sgs.PhaseChange and player:objectName() == self.player:objectName()
			and player:getPhase() == sgs.Player_Play then
			self[name .. "_used"] = false
                        self.toUse=nil
		end
	end
end



function SmartAI:fillSkillCards(cards)
    for _,skill in ipairs(sgs.ai_skills) do
        
        if self:hasSkill(skill) then
            --self:log(skill.name)
            
            if skill.name=="wushen" then 
            
                
                for i=#cards,1,-1 do 
                    
                    if cards[i]:getSuitString()=="heart" then
                        self:log("cant use "..cards[i]:className()..i)
                        table.remove(cards,i)
                    end
                end
            end
            
            local card=skill.getTurnUseCard(self)
            if #cards==0 then card=skill.getTurnUseCard(self,true) end
            if card then table.insert(cards,card) end
            --self:printCards(cards)
            
        end
    end
end

function SmartAI:useSkillCard(card,use)
    --self:log(card:className())
    sgs.ai_skill_use_func[card:className()](card,use,self)
end





-- load other ai scripts
dofile "lua/ai/commons-ai.lua"
dofile "lua/ai/usecard-ai.lua"
dofile "lua/ai/askfor-ai.lua"

dofile "lua/ai/standard-ai.lua"
dofile "lua/ai/wind-ai.lua"
dofile "lua/ai/fire-ai.lua"
dofile "lua/ai/thicket-ai.lua"
dofile "lua/ai/god-ai.lua"
dofile "lua/ai/yitian-ai.lua"
dofile "lua/ai/nostalgia-ai.lua"

dofile "lua/ai/general_config.lua"
dofile "lua/ai/intention-ai.lua"
dofile "lua/ai/state-ai.lua"
dofile "lua/ai/playrule-ai.lua"

dofile "lua/ai/standard-skill-ai.lua"
dofile "lua/ai/thicket-skill-ai.lua"
dofile "lua/ai/fire-skill-ai.lua"