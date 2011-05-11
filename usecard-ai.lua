--This filed is used for the strategies of playing single cards (as what they are).
--This file is the most important file for the AI strategy.

--Generally, the common parameters for all the useCard methods are a "use" struct and a card struct. 
--After a useCard method is called, AI will examiine whether use.card is defined or not. If it is, that card is played. Otherwise it is not.
--There are two ways these methods can be called: the use struct is a dummy, invalid use struct or the use struct is an effective use struct returned by the system. 
--When the AI is trying to figure out whether a card is playable or not, it will call its useCard method with a dummy use struct. this can be checked by calling use.isDummy
--When the AI is actually playing a card, use.isDummy doesn't exist and you have to make sure that the use.to:append() line is properly executed so that the card is played with your desired targets.

--handle the cases where slashing an enemy is unprefered.
--returns true if you dont want the AI to slash the emeny with the slash card given.
function SmartAI:slashProhibit(card,enemy)
    if enemy:hasSkill("liuli") then 
        if enemy:getHandcardNum()<1 then return false end
        for _, friend in ipairs(self.friends_noself) do
            if enemy:canSlash(friend,true) and self:slashIsEffective(card, friend) then return true end
        end
    end
    
    if enemy:hasSkill("leiji") then 
        if self.player:hasSkill("tieji") then return false end
        
        if enemy:getHandcardNum()>=3 then return true end
        if enemy:getArmor() and (enemy:getArmor():objectName()=="eight_diagram") then 
            local equips=enemy:getEquips()
            for _,equip in sgs.qlist(equips) do
                if equip:getSuitString()=="spade" then return true end
            end
        end
    end
    
    if enemy:hasSkill("tiandu") then 
        if enemy:getArmor() and (enemy:getArmor():objectName()=="eight_diagram") then return true end
    end
    
    if enemy:hasSkill("ganglie") then
        if self.player:getHandcardNum()+self.player:getHp()<5 then return true end
    end
    
    return false
end

--handles the use of slash and peach.
--the analeptic card is only played when you are about to slash an enemy.
--if you played an analeptic card, the getUseValue method will check the case and give the slash card a very high useValue, so a slash is always used after you played an analeptic.

function SmartAI:useBasicCard(card, use,no_distance)
        if card:getSkillName()=="wushen" then no_distance=true end
        if card:inherits("Slash") and self:slashIsAvailable() then
		    self:sort(self.enemies, "defense")
		    local target_count=0
            for _, enemy in ipairs(self.enemies) do
                        local slash_prohibit=false
                        slash_prohibit=self:slashProhibit(card,enemy)
                        if not slash_prohibit then
                            if ((self.player:canSlash(enemy, not no_distance)) or 
                            (use.isDummy and (self.player:distanceTo(enemy)<=self.predictedRange))) and 
                            self:objectiveLevel(enemy)>3 and
                            self:slashIsEffective(card, enemy) then
                                -- fill the card use struct
                                local anal=self:searchForAnaleptic(use,enemy,card)
                                if anal then 
                                    use.card = anal
                                    return 
                                end
                                use.card=card
                                if use.to then use.to:append(enemy) end
                                target_count=target_count+1
                                if self.slash_targets<=target_count then return end
                            end
                        end
		    end
	    elseif card:inherits("Peach") and self.player:isWounded() then
				local peaches=0
				local cards = self.player:getHandcards()
    			cards=sgs.QList2Table(cards)
				for _,card in ipairs(cards) do
					if card:inherits("Peach") then peaches=peaches+1 end
				end
				if peaches<=1 then
                	for _, friend in ipairs(self.friends_noself) do
                    	if (friend:getHp()<self.player:getHp()) and (friend:getHp()<2) and not friend:hasSkill("buqu") then return end
                	end	
                end
		        use.card = card
        
	    end
end


--handles the use of dismantlement card.
--the decision between handcards, equips or judgingArea is not made here. 
--after nullification is processed, you choose the target card of dismantlement in the askForCardChosen method.

function SmartAI:useCardDismantlement(dismantlement, use)
	if (not self.has_wizard) and self:hasWizard(self.enemies) then
		-- find lightning
		local players = self.room:getOtherPlayers(self.player)
		players = self:exclude(players, dismantlement)
		for _, player in ipairs(players) do
			if player:containsTrick("lightning") then
				use.card = dismantlement
                                if use.to then use.to:append(player) end
				return			
			end
		end
	end

	self:sort(self.friends_noself,"defense")
	local friends = self:exclude(self.friends_noself, dismantlement)
	for _, friend in ipairs(friends) do
		if friend:containsTrick("indulgence") or friend:containsTrick("supply_shortage") then
			use.card = dismantlement
                        if use.to then use.to:append(friend) end

			return
		end			
	end		
	
	self:sort(self.enemies,"defense")
	for _, enemy in ipairs(self.enemies) do
		if getDefense(enemy)<8 then break
		else self:sort(self.enemies,"threat")
		break
		end
	end	
	local enemies = self:exclude(self.enemies, dismantlement)
	for _, enemy in ipairs(enemies) do
		local equips = enemy:getEquips()
		
		if equips or not (enemy:hasSkill("kongcheng") or enemy:hasSkill("lianying")) then
		
		    if  not enemy:isNude() then
				use.card = dismantlement
                if use.to then use.to:append(enemy) end
				return 
		    end
		end
	end
end

-- very similar with SmartAI:useCardDismantlement
--handles the use of snatch card.
--the decision between handcards, equips or judgingArea is not made here. 
--after nullification is processed, you choose the target card of snatch in the askForCardChosen method.

function SmartAI:useCardSnatch(snatch, use)
        if (not self.has_wizard) and self:hasWizard(self.enemies)  then
		-- find lightning
		local players = self.room:getOtherPlayers(self.player)
		players = self:exclude(players, snatch)
		for _, player in ipairs(players) do
			if player:containsTrick("lightning") then
				use.card = snatch
                                if use.to then use.to:append(player) end
				
				return			
			end			
		end
	end

	self:sort(self.friends_noself,"defense")
	local friends = self:exclude(self.friends_noself, snatch)
	for _, friend in ipairs(friends) do
		if friend:containsTrick("indulgence") or friend:containsTrick("supply_shortage") then
			use.card = snatch
                        if use.to then use.to:append(friend) end

			return
		end			
	end		
	
	self:sort(self.enemies,"defense")
	for _, enemy in ipairs(self.enemies) do
		if getDefense(enemy)<8 then break
		else self:sort(self.enemies,"threat")
		break
		end
	end	
	local enemies = self:exclude(self.enemies, snatch)
	for _, enemy in ipairs(enemies) do
		if  not enemy:isNude() then
			if equips or not (enemy:hasSkill("kongcheng") or enemy:hasSkill("lianying")) then
				use.card = snatch
                if use.to then use.to:append(enemy) end
				return
			end
		end
	end
end

function SmartAI:useCardFireAttack(fire_attack, use)
	local lack = {
		spade = true,
		club = true,
		heart = true,
		diamond = true,
	}

	local cards = self.player:getHandcards()
	for _, card in sgs.qlist(cards) do
		if card:getEffectiveId() ~= fire_attack:getEffectiveId() then
			lack[card:getSuitString()] = nil
		end
	end	

	self:sort(self.enemies,"defense")
	for _, enemy in ipairs(self.enemies) do
		if (self:objectiveLevel(enemy)>3) and not enemy:isKongcheng() then
			local cards = enemy:getHandcards()
			local success = true
			for _, card in sgs.qlist(cards) do
				if lack[card:getSuitString()] then
					success = false
					break
				end
			end

			if success then
				use.card = fire_attack
                                if use.to then use.to:append(enemy) end
				return
			end
		end
	end
end




function SmartAI:useCardDuel(duel, use)
	self:sort(self.enemies,"defense")
	local enemies = self:exclude(self.enemies, duel)
	for _, enemy in ipairs(enemies) do
		if self:objectiveLevel(enemy)>3 then
		local n1 = self:getSlashNumber(self.player)
		local n2 = self:getSlashNumber(enemy)

		if n1 >= n2 then
			use.card = duel
                        if use.to then use.to:append(enemy) end

			return
		end
		end
	end
end

--this is just a local function use in the useCardSupplyShortage card following.
local function handcard_subtract_hp(a, b)
	local diff1 = a:getHandcardNum() - a:getHp()
	local diff2 = b:getHandcardNum() - b:getHp()

	return diff1 < diff2
end

function SmartAI:useCardSupplyShortage(card, use)
	table.sort(self.enemies, handcard_subtract_hp)

	local enemies = self:exclude(self.enemies, card)
	for _, enemy in ipairs(enemies) do
		if ((#enemies==1) or not enemy:hasSkill("tiandu")) and not enemy:containsTrick("supply_shortage") then
			use.card = card
             if use.to then use.to:append(enemy) end

			return
		end
	end
end

--similar to supplyshortage
local function hp_subtract_handcard(a,b)
	local diff1 = a:getHp() - a:getHandcardNum()
	local diff2 = b:getHp() - b:getHandcardNum()

	return diff1 < diff2
end

function SmartAI:useCardIndulgence(card, use)
	table.sort(self.enemies, hp_subtract_handcard)

	local enemies = self:exclude(self.enemies, card)
	for _, enemy in ipairs(enemies) do
		if not enemy:containsTrick("indulgence") and not enemy:hasSkill("keji") then			
			use.card = card
                        if use.to then use.to:append(enemy) end

			return
		end
	end
end

function SmartAI:useCardCollateral(card, use)
	self:sort(self.enemies,"threat")

	for _, enemy in ipairs(self.enemies) do
		if not (self.room:isProhibited(self.player, enemy, card) or enemy:hasSkill("weimu"))
			and enemy:getWeapon() then

			for _, enemy2 in ipairs(self.enemies) do
				if enemy:canSlash(enemy2) then
					use.card = card
                                        if use.to then use.to:append(enemy) end
                                        if use.to then use.to:append(enemy2) end

					return
				end
			end
		end
	end
end

function SmartAI:useCardIronChain(card, use)
	local targets = {}
	self:sort(self.friends,"defense")
	for _, friend in ipairs(self.friends) do
		if friend:isChained() then
			table.insert(targets, friend)
		end
	end

	self:sort(self.enemies,"defense")
	for _, enemy in ipairs(self.enemies) do
		if not enemy:isChained() and not self.room:isProhibited(self.player, enemy, card) 
			and not enemy:hasSkill("danlao") and not (self:objectiveLevel(enemy)<=3) then
			table.insert(targets, enemy)
		end
	end

        use.card = card

	if targets[2] then
                if use.to then use.to:append(targets[1]) end
                if use.to then use.to:append(targets[2]) end
	end
end

-- the ExNihilo is always used
function SmartAI:useCardExNihilo(card, use)
        use.card = card
end


function SmartAI:useCardLightning(card, use)
        if not self:hasWizard(self.enemies) then
            if self:hasWizard(self.friends) then
                use.card = card
                return
            end
            local players=self.room:getAllPlayers()
            players=sgs.QList2Table(players)
            
            local friends=0
            local enemies=0
            
            for _,player in ipairs(players) do
                if self:objectiveLevel(player)>=4 then
                    enemies=enemies+1
                elseif self:isFriend(player) then
                    friends=friends+1
                end
            end
            
            local ratio
            
            if friends==0 then ratio=999
            else ratio=enemies/friends
            end
            
            if ratio>1.5 then
		        use.card = card
		        return
		    end
	    end
end

function SmartAI:useCardGodSalvation(card, use)
	local good, bad = 0, 0
	for _, friend in ipairs(self.friends) do if friend:isWounded() then
		
                        good = good + 10/(friend:getHp())
                        if friend:isLord() then good = good + 10/(friend:getHp()) end
		end
	end

	for _, enemy in ipairs(self.enemies) do if enemy:isWounded() then
                bad = bad + 10/(enemy:getHp())
                if enemy:isLord() then bad = bad + 10/(enemy:getHp()) end
		end
	end

	if good > bad then
		use.card = card
	end
end

function SmartAI:useCardAmazingGrace(card, use)
	if #self.friends >= #self.enemies then
		use.card = card
	end
end

function SmartAI:useTrickCard(card, use)
	if card:inherits("AOE") then
		local good, bad = 0, 0
		for _, friend in ipairs(self.friends_noself) do
			if self:aoeIsEffective(card, friend) then
                                bad = bad + 20/(friend:getHp())+10
                                if friend:isLord() 
                                and (friend:getHp()<3) then return end
                                if (friend:getHp()<2)
                                and (self.player:isLord())
                                then return end
			end
		end

		for _, enemy in ipairs(self.enemies) do
			if self:aoeIsEffective(card, enemy) then
                                good = good + 20/(enemy:getHp())+10
                                if enemy:isLord() then good = good + 20/(enemy:getHp()) end
			end
		end

		if good > bad then
			use.card = card
		end
	else
		self:useCardByClassName(card, use)
	end
end


sgs.weapon_range =
{	
	Crossbow = 1,
	Blade = 3,
	Spear = 3,
	DoubleSword =2,
	QinggangSword=2,
	Axe=3,
	KylinBow=5,
	Halberd=4,
	IceSword=2,
	Fan=4,
	GudingBlade=2,
	
}

--return an evaluation of an equip card.
--This method is very pooly written and you may want to modify the criteria and formulas I used 
function SmartAI:evaluateEquip(card)

		local deltaSelfThreat = 0
		local currentRange 
                if not card then return -1
                else
                currentRange = sgs.weapon_range[card:className()] or 0
		end
		for _,enemy in ipairs(self.enemies) do
			if self.player:distanceTo(enemy) <= currentRange then
					deltaSelfThreat=deltaSelfThreat+6/getDefense(enemy)
			end
		end
		
		if card:inherits("Crossbow") and deltaSelfThreat~=0 then 
		    if self.player:hasSkill("kurou") then deltaSelfThreat=deltaSelfThreat*3+10 end
			deltaSelfThreat = deltaSelfThreat + self:getSlashNumber(self.player)*3-2
		elseif card:inherits("Blade") then 
			deltaSelfThreat = deltaSelfThreat + self:getSlashNumber(self.player)
		elseif card:inherits("Spear") then--and 
			--self.player:getHandcardNum()/2 - self:getSlashNumber(self.player)>0 then 
				--deltaSelfThreat = deltaSelfThreat + self.player:getHandcardNum()/2 - self:getSlashNumber(self.player)
		else
			for _,enemy in ipairs(self.enemies) do
				if self.player:distanceTo(enemy) <= currentRange then
					if card:inherits("DoubleSword") and 
						enemy:getGeneral():isMale() ~= self.player:getGeneral():isMale() then
							deltaSelfThreat=deltaSelfThreat+3
					elseif card:inherits("QinggangSword") and enemy:getArmor() then
						deltaSelfThreat=deltaSelfThreat+3
					elseif card:inherits("Axe") and enemy:getHp()<3 then
						deltaSelfThreat=deltaSelfThreat+3-enemy:getHp()
					elseif card:inherits("KylinBow") and (enemy:getDefensiveHorse() or enemy:getDefensiveHorse())then
						deltaSelfThreat=deltaSelfThreat+1
						break
					elseif card:inherits("GudingBlade") and enemy:getHandcardNum()<3 then
						deltaSelfThreat=deltaSelfThreat+2
						if enemy:getHandcardNum()<1 then deltaSelfThreat=deltaSelfThreat+4 end
					end
				end
			end
		end
		return deltaSelfThreat
end

function SmartAI:useEquipCard(card, use)
	
	if card:inherits("Weapon") then
		if self:evaluateEquip(card) > (self:evaluateEquip(self.player:getWeapon())) then
		if use.isDummy and self.weaponUsed then return end
		if self.player:getHandcardNum()<=self.player:getHp() then return end
		use.card = card		
		end
	elseif card:inherits("Armor") then
	    if self.player:hasSkill("bazhen") then return end
	 	if not self.player:getArmor() then use.card=card
	 	elseif (self.player:getArmor():objectName())=="silver_lion" then use.card=card
	 	elseif self.player:isChained()  and (self.player:getArmor():inherits("vine")) and not (card:objectName()=="silver_lion") then use.card=card
	 	elseif (card:objectName()=="eight_diagram") and (self.player:hasSkill("leiji") or self.player:hasSkill("tiandu")) then use.card=card
	 	end
	elseif self.lua_ai:useCard(card) then
		use.card = card
	end
end