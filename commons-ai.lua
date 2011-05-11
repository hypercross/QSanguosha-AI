--This file implements common functions that are universally useful. They are basically functional utilities and don't actually involve any AI strategy.
--You don't really have to read the code , I recommend you just to read the comments to see the usage of these methods.
--
--
--
--
-- compare functions
sgs.ai_compare_funcs = {
	hp = function(a, b)
		return a:getHp() < b:getHp()
	end,

	handcard = function(a, b)
		return a:getHandcardNum() < b:getHandcardNum()
	end,

	value = function(a, b)
		local value1 = a:getHp() * 2 + a:getHandcardNum()
		local value2 = b:getHp() * 2 + b:getHandcardNum()

		return value1 < value2
	end,

	chaofeng = function(a, b)
		local c1 = sgs.ai_chaofeng[a:getGeneralName()]	or 0
		local c2 = sgs.ai_chaofeng[b:getGeneralName()] or 0

		if c1 == c2 then
			return sgs.ai_compare_funcs.value(a, b)
		else
			return c1 > c2
		end
	end,

	defense = function(a,b)
		local d1=a:getHp() * 2 + a:getHandcardNum()
		if(d1>a:getHp()*3) then d1=a:getHp()*3 end
		if a:getArmor() then d1=d1+2 end
		local d2=b:getHp() * 2 + b:getHandcardNum()
		if(d2>b:getHp()*3) then d2=b:getHp()*3 end
		if b:getArmor() then d2=d2+2 end
		
		local c1 = sgs.ai_chaofeng[a:getGeneralName()]	or 0
		local c2 = sgs.ai_chaofeng[b:getGeneralName()] or 0
		
		if (a:getHandcardNum()<2) and (b:getHandcardNum()>=2) then return true end
		if (b:getHandcardNum()<2) and (a:getHandcardNum()>=2) then return false end
		
                if sgs.rebel_target:objectName()==a:objectName() then return true end
                if sgs.rebel_target:objectName()==b:objectName() then return false end
                
                if sgs.loyal_target then
                    if sgs.loyal_target:objectName()==a:objectName() then return true end
                    if sgs.loyal_target:objectName()==b:objectName() then return false end
                end

		return d1<d2
	end,

	threat = function ( a, b)
		local players=sgs.QList2Table(a:getRoom():getOtherPlayers(a))
		local d1=a:getHandcardNum()
		for _, player in ipairs(players) do
			if a:canSlash(player,true) then
				d1=d1+10/(getDefense(player))
			end
		end
		players=sgs.QList2Table(b:getRoom():getOtherPlayers(b))
		local d2=b:getHandcardNum()
		for _, player in ipairs(players) do
			if b:canSlash(player,true) then
				d2=d2+10/(getDefense(player))
			end
		end


		local c1 = sgs.ai_chaofeng[a:getGeneralName()]	or 0
		local c2 = sgs.ai_chaofeng[b:getGeneralName()] or 0


		 return d1+c1/2>d2+c2/2
        end,
}
--return the player object by its objectName(a string). 
--when comparing two players (to check if they are referencing a same player object) , you should always compare their objectName.
function SmartAI:getPlayer(objectName)
    local players=self.room:getAllPlayers()
    players=sgs.QList2Table(players)
    for _,player in ipairs(players) do
        if player:objectName()==objectName then return player end
    end
    return nil
end

--return the player object by its generalName(a string).
--when comparing two players (to check if they are referencing a same player object) , you should always compare their objectName.
function SmartAI:getPlayerByGeneral(general)
    local players=self.room:getAllPlayers()
    players=sgs.QList2Table(players)
    for _,player in ipairs(players) do
        if player:getGeneralName()==general then return player end
    end
    return nil
end    

--a shorter way to output a string to the serverlog.
function SmartAI:log(outString)
    self.room:output(outString)
end

--used for retrial card strategy. 
--this method is used to construct a cardSet to match the judge result conditions. 
--what i did was "true" when the suit,number pair is a good result and "false" when it is bad.
function fillCardSet(cardSet,suit,suit_val,number,number_val)
    if suit then
        cardSet[suit]={}
        for i=1,13 do
            cardSet[suit][i]=suit_val
        end
    end
    if number then
        cardSet.club[number]=number_val
        cardSet.spade[number]=number_val
        cardSet.heart[number]=number_val
        cardSet.diamond[number]=number_val
    end
end

--used for retrial card strategy. 
--this method is used to match a cardSet to the current judge card to check whether the result is good.
--the cardSet is created as an empty table from nowhere, and is filled by fillCardSet.
function goodMatch(cardSet,card)
    local result=card:getSuitString()
    local number=card:getNumber()
    if cardSet[result][number] then return true
    else return false
    end
end

--return an empty cards from places specified by flags.
function SmartAI:getCardRandomly(who, flags)
	local cards = who:getCards(flags)
	local r = math.random(0, cards:length()-1)
	local card = cards:at(r)
	return card:getEffectiveId()
end

--return true if the current player has that skill.
--skill is a lua table defined in packagename-skill-ai.lua files.
function SmartAI:hasSkill(skill)
    if (skill.name=="huangtianv") then
        return (self.player:getKingdom()=="qun") and (self.room:getLord():hasLordSkill("huangtian") and not self.player:isLord())
    elseif (skill.name=="jijiang") then
        return (self.player:isLord() and self.player:hasLordSkill(skill.name))
    else
        return self.player:hasSkill(skill.name)
    end
end

--return true if the current player has the parameter card object as an equipment.
function SmartAI:hasEquip(card)
    local equips=self.player:getEquips()
    if not equips then return false end
    for _,equip in sgs.qlist(equips) do
        if equip:getId()==card:getId() then return true end
    end
    return false
end

--return true if there is a player in the player object table who has the skill guidao guicai or tiandu.
function SmartAI:hasWizard(players)
	for _, player in ipairs(players) do
		if player:hasSkill("guicai") or player:hasSkill("guidao") or player:hasSkill("tiandu") then
			return true
		end
	end
        return false
end



--sort the players by the key.
-- the keys are specified at the top of this file
function SmartAI:sort(players, key)
	key = key or "chaofeng" -- the default compare key is "chaofeng"

	local func= sgs.ai_compare_funcs[key]

	assert(func)

	table.sort(players, func)
end

--a generic card use method that determines which useCard method to call.
function SmartAI:useCardByClassName(card, use)
	local class_name = card:className()
	local use_func = self["useCard" .. class_name]
	
	if use_func then
		use_func(self, card, use)
	end
end

--return true if other(a player object) is a friend
function SmartAI:isFriend(other)
    if isRolePredictable() then return self.lua_ai:isFriend(other) end
    if (self.player:objectName())==(other:objectName()) then return true end 
	if self:objectiveLevel(other)<0 then return true end
    return false
end

--return true if other(a player object) is an enemy
function SmartAI:isEnemy(other)
    if isRolePredictable() then return self.lua_ai:isEnemy(other) end
	if self:objectiveLevel(other)>0 then return true end
	return false
    --local players=self.enemies
    --for _,player in ipairs(players) do
    --    if (player:objectName())==(other:objectName()) then return true end
    --end
        --return self.lua_ai:isEnemy(other)
    --    return false
end

function SmartAI:isNeutrality(other)
	return self.lua_ai:relationTo(other) == sgs.AI_Neutrality
end


-- get the card with the maximal card point
function SmartAI:getMaxCard(player)
	player = player or self.player

	if player:isKongcheng() then
		return nil
	end

	local cards = player:getHandcards()
	local max_card, max_point = nil, 0
	for _, card in sgs.qlist(cards) do
		local point = card:getNumber()
		if point > max_point then
			max_point = point
			max_card = card
		end
	end

	return max_card
end

function SmartAI:slashIsEffective(slash, to)
	if self.player:hasWeapon("qinggang_sword") then
		return true
	end

	local armor = to:getArmor()
	if armor then
		if armor:objectName() == "renwang_shield" then
		    if not slash then return true end
			return not slash:isBlack()
		elseif armor:inherits("Vine") then
		    if not slash then return false end
			return slash:inherits("NatureSlash") or self.player:hasWeapon("fan")
		end
	end

	return true
end

--well i didn't write this. believe or not my AI doesn't cheat :p
function SmartAI:slashHit(slash, to)
	return self:getJinkNumber(to) == 0
end

--whether AI can play another slash this turn.
function SmartAI:slashIsAvailable()
	if self.player:hasWeapon("crossbow") or self.player:hasSkill("paoxiao") then
		return true
	end

	if self.player:hasFlag("tianyi_success") then
		return self.player:getMark("SlashCount") <= 2
	else
		return self.player:getMark("SlashCount") < 1
	end
end

--return the number of avaliable slashes of the player object
function SmartAI:getSlashNumber(player)
	local n = 0
	if player:hasSkill("wusheng") then
		local cards = player:getCards("he")
		for _, card in sgs.qlist(cards) do
			if card:isRed() or card:inherits("Slash") then
				n = n + 1
			end
		end
	elseif player:hasSkill("wushen") then
		local cards = player:getHandcards()
		for _, card in sgs.qlist(cards) do
			if card:getSuit() == sgs.Card_Heart or card:inherits("Slash") then
				n = n + 1
			end
		end
	else
		local cards = player:getHandcards()
		for _, card in sgs.qlist(cards) do
			if card:inherits("Slash") then
				n = n + 1
			end
		end

		local left = cards:length() - n
		if player:hasWeapon("spear") then
			n = n + math.floor(left/2)
		end
	end

	if player:isLord() and player:hasSkill("jijiang") then
		local lieges = self.room:getLieges("shu", player)
		for _, liege in sgs.qlist(lieges) do
			if liege == "loyalist" then
				n = n + self:getSlashNumber(liege)
			end
		end
	end

	if player:hasSkill("wushuang") then
		n = n * 2
	end

	return n
end

--return the number of avaliable jinks of the player object
function SmartAI:getJinkNumber(player)
	local n = 0

	local cards = player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if card:inherits("Jink") then
			n = n + 1
		end
	end

    if player:hasSkill("wushen") then
        for _, card in sgs.qlist(cards) do
			if card:inherits("Jink") and (card:getSuitString()=="heart") then
				n = n - 1
			end
		end
    end

	if player:hasSkill("longdan") then
		for _, card in sgs.qlist(cards) do
			if card:inherits("Slash") then
				n = n + 1
			end
		end
	elseif player:hasSkill("qingguo") then
		for _, card in sgs.qlist(cards) do
			if card:isBlack() then
				n = n + 1
			end
		end
	end

	local armor = player:getArmor()
	if armor and armor:objectName() == "eight_diagram" then
		local judge_card = self.room:peek()
		if judge_card:isRed() then
			n = n + 1
		end
	end

	if player:isLord() and player:hasSkill("hujia") then
		local lieges = self.room:getLieges("wei",player)
		for _, liege in sgs.qlist(lieges) do
			if liege:getRole() == "loyalist" then
				n = n + self:getJinkNumber(liege)
			end
		end
	end

	return n
end

--return true if the aoe card is effective to the "to" player object
function SmartAI:aoeIsEffective(card, to)
	-- the AOE starter is not effected by AOE
	if self.player == to then
		return false
	end

	-- the vine
	local armor = to:getArmor()
	if armor and armor:inherits("Vine") then
		return false
	end

	-- Jiaxu's weimu
	if self.room:isProhibited(self.player, to, card) then
		return false
	end

	-- Yangxiu's Danlao
	if to:hasSkill("danlao") then
		return false
	end

	-- Menghuo and Zhurong
	if card:inherits("SavageAssault") then
		if to:hasSkill("huoshou") or to:hasSkill("juxiang") then
			return false
		end
	end

	return true
end


--return the distance limit of the card
function SmartAI:getDistanceLimit(card)
	if self.player:hasSkill "qicai" then
		return nil
	end

	if card:inherits "Snatch" then
		return 1
	elseif card:inherits "SupplyShortage" then
		if self.player:hasSkill "duanliang" then
			return 2
		else
			return 1
		end
	end
end

--return a table of players that are reachable by this card.
function SmartAI:exclude(players, card)
	local excluded = {}
	local limit = self:getDistanceLimit(card)
	for _, player in sgs.list(players) do
		if not self.room:isProhibited(self.player, player, card) then
			local should_insert = true
			if limit then
				should_insert = self.player:distanceTo(player) <= limit
			end

			if should_insert then
				table.insert(excluded, player)
			end
		end
	end

	return excluded
end

--return a slash card
function SmartAI:getSlash()
    local cards = self.player:getHandcards()
    cards=sgs.QList2Table(cards)
    
    self:sortByUsePriority(cards)
    
    for _, slash in ipairs(cards) do
        if slash:inherits("Slash") then return slash end
    end
    return nil
end

--bullshit, nothing here
function SmartAI:cardMatch(condition)

end

--fast way to print classNames of the cards in the cards table.
function SmartAI:printCards(cards)
    local string=""
    for _,card in ipairs(cards) do
        string=string.." "..card:className()
    end
    self.room:output(string)
end