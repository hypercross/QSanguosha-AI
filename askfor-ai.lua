--
-- AI strategies for all the passive "asked for" game play is implemented in this file. 
-- This includes skill invoke, slash-jink, weapon skills, etc.
--
--
--

--global tables

--invocation of weapon skills and general skills(which are defined in the files named after the general's package name)
sgs.ai_skill_invoke = {
	eight_diagram = true,
	double_sword = true,
	fan = true,
	
	kylin_bow = function(self, data)	
		local effect = data:toSlashEffect()
		
		if effect.to:hasSkill("xiaoji") then
			return false
		end
		
		return self:isEnemy(effect.to)
	end,
}

-- used for SmartAI:askForUseCard
sgs.ai_skill_use = {}

-- used for SmartAI:askForChoice
sgs.ai_skill_choice = {}


--methods

--invocation of skills not as skillcards
function SmartAI:askForSkillInvoke(skill_name, data)
	local invoke = sgs.ai_skill_invoke[skill_name]
	if type(invoke) == "boolean" then
		return invoke
	elseif type(invoke) == "function" then
		return invoke(self, data)
	else
		local skill = sgs.Sanguosha:getSkill(skill_name)
		return skill and skill:getFrequency() == sgs.Skill_Frequent
	end
end

--invocation of skills as skillcards
function SmartAI:askForUseCard(pattern, prompt)
	local use_func = sgs.ai_skill_use[pattern]
	if string.find(pattern,"@@liuli") then use_func = sgs.ai_skill_use["@@liuli"] end
	if use_func then
		return use_func(self, prompt) or "."
	else
		return "."
	end
end

function SmartAI:askForDiscard(reason, discard_num, optional, include_equip)
    
    if reason=="ganglie" then
        if self.player:getHp()>self.player:getHandcardNum() then return {} end
        if self.player:getHandcardNum()<2 then return {} end 
	elseif optional then
		return {}
	end
	
		local flags = "h"
		if include_equip then
			flags = flags .. "e"
		end

		local cards = self.player:getCards(flags)
		cards = sgs.QList2Table(cards)
		self:sortByKeepValue(cards)
		local to_discard = {}
		for i=1, discard_num do
			table.insert(to_discard, cards[i]:getEffectiveId())
		end

		return to_discard
	
end

--return a card that matches the cardSet with lowest useValue.
--used exclusively for guidao and guicai

function SmartAI:getRetrialCard(flags,cardSet,reversed)
    local cards=self.player:getCards(flags)
    cards=sgs.QList2Table(cards)
    self:sortByUseValue(cards,true)
    self.room:output("looking for card")

    for _, card in ipairs(cards) do
    
        local result=card:getSuitString()
        local number=card:getNumber()
        
        if (cardSet[result][number]) and not reversed then
            return card:getEffectiveId()
        end
        
        if (not cardSet[result][number]) and reversed then
            return card:getEffectiveId()
        end
    end
    self.room:output("unfound.")
    return "."
end


function SmartAI:askForPlayerChosen(targets, reason)
	local r = math.random(0, targets:length() - 1)
	return targets:at(r)
end


--for answering hujia or dongzhuo's benghuai, etc
function SmartAI:askForChoice(skill_name, choices)
	local choice = sgs.ai_skill_choice[skill_name]
	if type(choice) == "string" then
		return choice
	elseif type(choice) == "function" then
		return choice(self, choices)
	else
		local skill = sgs.Sanguosha:getSkill(skill_name)
		return skill:getDefaultChoice()
	end		
end

--used for choosing a card when casting Dismantlement or Snatch.
--also works for simayi's fankui,etc

function SmartAI:askForCardChosen(who, flags, reason)

    if self:isFriend(who) then
		if flags:match("j") then
			local tricks = who:getCards("j")

			local lightning, indulgence, supply_shortage
			for _, trick in sgs.qlist(tricks) do
				if trick:inherits "Lightning" then
					lightning = trick:getId()
				elseif trick:inherits "Indulgence" or trick:getSuit() == sgs.Card_Diamond then
					indulgence = trick:getId()
				else
					supply_shortage = trick:getId()
				end
			end

			if self:hasWizard(self.enemies) and lightning then
				return lightning
			end

			if indulgence and supply_shortage then
				if who:getHp() < who:getHandcardNum() then
					return indulgence
				else
					return supply_shortage
				end
			end

			if indulgence or supply_shortage then
				return indulgence or supply_shortage
			end
		elseif flags:match("e") and who:hasSkill("xiaoji") then
			local equips = who:getEquips()
			if not equips:isEmpty() then
				return equips:at(0):getId()
			end
		end
	else
        if (who:getHandcardNum()<2) and (not who:isKongcheng()) and
         not (who:hasSkill("lianying") or who:hasSkill("kongcheng")) then return -1 
		
		elseif flags:match("e") then
		    
			if who:getDefensiveHorse() then
				for _,friend in ipairs(self.friends) do
					if friend:distanceTo(who)==friend:getAttackRange()+1 then 
					 	return who:getDefensiveHorse():getId()
					end
				end
			end
			
		
			if who:getOffensiveHorse() then
			    if who:hasSkill("xiaoji") and who:getHandcardNum()>=who:getHp() then
			    else
				    for _,friend in ipairs(self.friends) do
					    if who:distanceTo(friend)==who:getAttackRange() and
					    who:getAttackRange()>1 then 
					 	    return who:getOffensiveHorse():getId() 
					    end
				    end
				end
			end
			
			if who:getArmor() then 
			    local canFire=false
			        
			        if self.player:getWeapon() then 
			            if self.player:getWeapon():inherits("Fan") then canFire=true end
			        end
			    if self.toUse then
			        for _,card in ipairs(self.toUse) do 
			            if card:inherits("FireSlash") then canFire=true end
			            if card:inherits("FireAttack") then canFire=true end
			        end
			    end
			    if canFire and (who:getArmor():objectName()=="vine") then 
				elseif (who:getArmor():objectName()=="silver_lion") and who:isWounded() then 
                else return who:getArmor():getId() 
                end
			end
			
			if who:getWeapon() then 
			    if not (who:hasSkill("xiaoji") and (who:getHandcardNum()>=who:getHp())) then
				for _,friend in ipairs(self.friends) do
					if (who:distanceTo(friend) <= who:getAttackRange()) and (who:distanceTo(friend)>1) then 
					 	return who:getWeapon():getId()
					end
				end
				end
			end
		end
        
        if not who:isKongcheng() then
			return -1
		end
	end
    self:log("??????")
	local new_flag=""
    if flags:match("h") then new_flag="h" end
    if flags:match("e") then new_flag=new_flag.."e" end
    return self:getCardRandomly(who, new_flag)
end

--used for answering card, like Jink when you are slashed and slash when someone duels you
--if nil is returned, the defalut askForCard in TrustAI is called and the AI will give the card asked for as lone as it has that card.

function SmartAI:askForCard(pattern,prompt)
        self.room:output(prompt)
        if sgs.ai_skill_invoke[pattern] then return sgs.ai_skill_invoke[pattern](self,prompt) end

        if not prompt then return end
        local parsedPrompt=prompt:split(":")

        if parsedPrompt[1]=="collateral-slash" then return "."
        elseif (parsedPrompt[1]=="@jijiang-slash") then
            if self:isFriend(self.room:getLord()) then return self:getSlash()
            else return "." end
        elseif parsedPrompt[1]=="double-sword-card" then return "."
        elseif parsedPrompt[1]=="@wushuang-slash-1" and (self:getSlashNumber(self.player)<2)then
            return "."
        elseif (parsedPrompt[1]=="@wushuang-jink-1") and (self:getJinkNumber(self.player)<2) then return "." 
        elseif (parsedPrompt[1]=="@roulin1-jink-1") and (self:getJinkNumber(self.player)<2) then return "." 
        elseif (parsedPrompt[1]=="@roulin2-jink-1") and (self:getJinkNumber(self.player)<2) then return "." end
        --self.room:output("eee")

	return nil
end

function SmartAI:askForAG(card_ids,refusable)
    local ids=card_ids
    local cards={}
    for _,id in ipairs(ids) do
        table.insert(cards,sgs.Sanguosha:getCard(id))
    end
    self:sortByCardNeed(cards)
    return cards[#cards]:getEffectiveId()
end

--this method is not yet implemented.
function SmartAI:askForNullification(trick_name, from, to)
	return nil
end