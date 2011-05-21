-- pojun
sgs.ai_skill_invoke.pojun = function(self, data)
	local damage = data:toDamage()
	local good = damage.to:getHp() > 2
	
	
	if self:isFriend(damage.to) then
		return good
	elseif self:isEnemy(damage.to) then
		return not good
	end
end

--jiejiu
local jiejiu_skill={}
jiejiu_skill.name="jiejiu"
table.insert(sgs.ai_skills,jiejiu_skill)
jiejiu_skill.getTurnUseCard=function(self)
    local cards = self.player:getCards("h")	
    cards=sgs.QList2Table(cards)
	
	local anal_card
	
	self:sortByUseValue(cards,true)
	
	for _,card in ipairs(cards)  do
		if card:inherits("Analeptic") then 
			anal_card = card
			break
		end
	end

	if anal_card then		
		local suit = anal_card:getSuitString()
    	local number = anal_card:getNumberString()
		local card_id = anal_card:getEffectiveId()
		local card_str = ("slash:jiejiu[%s:%s]=%d"):format(suit, number, card_id)
		local slash = sgs.Card_Parse(card_str)
		
	--	assert(slash)
        
        return slash
	end
end
local gaoshun_ai = SmartAI:newSubclass "gaoshun"

function gaoshun_ai:askForCard(pattern,prompt)
	local card = super.askForCard(self, pattern, prompt)
	if card then return card end
	if pattern == "slash" then
		local cards = self.player:getCards("h")
		cards=sgs.QList2Table(cards)
		self:fillSkillCards(cards)
        self:sortByUseValue(cards,true)
		for _, card in ipairs(cards) do
			if card:inherits("Analeptic") then
				local suit = card:getSuitString()
				local number = card:getNumberString()
				local card_id = card:getEffectiveId()
				return ("slash:jiejiu[%s:%s]=%d"):format(suit, number, card_id)
			end
		end
	end
end





-- buyi
sgs.ai_skill_invoke.buyi = function(self, data)
	local dying = data:toDying()
	return self:isFriend(dying.who)
end



--xuanfeng
sgs.ai_skill_invoke.lingtong = function(self, data)
	return true
end

--xuanhuo
local fazheng_ai = SmartAI:newSubclass "fazheng"
fazheng_ai:setOnceSkill("xuanhuo")
function fazheng_ai:activate(use)
	super.activate(self, use)
	if use:isValid() then
		return
	end
	
	local cards = self.player:getHandcards()
	if not self.xuanhuo_used then
		cards=sgs.QList2Table(cards)
		self:sortByUseValue(cards)
		
		for _, enemy in ipairs(self.enemies) do
			if not enemy:isKongcheng() then
				for _, card in ipairs(cards)do
					if card:getSuit() == sgs.Card_Heart and not card:inherits("Peach")  and self.player:getHandcardNum() > 1 then
						use.card = sgs.Card_Parse("@XuanhuoCard=" .. card:getEffectiveId())
						use.to:append(enemy)
						self.xuanhuo_used = true
						return
					end	
				end		
			end
		end
		
	end
end
function fazheng_ai:askForPlayerChosen(players, reason)
	if reason == "xuanhuo" then
		for _, player in sgs.qlist(players) do
			if (player:getHandcardNum() <= 2 or player:getHp() < 2) and self:isFriend(player) then
				return player
			end
		end
	end
	for _, player in sgs.qlist(players) do
		if self:isFriend(player) then
			return player
		end
	end
	
	
	return super.askForPlayerChosen(self, players, reason)
end



--ganlu
local wuguotai_ai = SmartAI:newSubclass "wuguotai"
wuguotai_ai:setOnceSkill("ganlu")

function wuguotai_ai:activate(use)
	super.activate(self, use)
	if use:isValid() then
		return
	end
	
	local lost_hp = self.player:getLostHp()
	local enemy_equip = 0
	local target
	
	if not self.ganlu_used then
		local equips  = {}
		for _, friend in ipairs(self.friends) do
			if friend:hasSkill("xiaoji") and self:getEquipNumber(friend) > 0 then
				for _, enemy in ipairs(self.enemies) do
					
					if ((self:getEquipNumber(enemy)-self:getEquipNumber(friend))<= lost_hp) or 
						((self:getEquipNumber(friend)-self:getEquipNumber(enemy))<= lost_hp) then
						if self:getEquipNumber(enemy) > enemy_equip then
							target = enemy
							enemy_equip = self:getEquipNumber(enemy)
						end
					end
				end	
			end	
		end
		
		if target and enemy_equip > 0 then				
			use.card = sgs.Card_Parse("@GanluCard=.")
			use.to:append(friend)
			use.to:append(enemy)
			self.ganlu_used = true
			return
		end	
		
		for _, friend in ipairs(self.friends) do
			if self:getEquipNumber(friend) > 0 then
				for _, enemy in ipairs(self.enemies) do
					if not enemy:hasSkill("xiaoji") and self:getEquipNumber(enemy) > 0 then 
						if ((self:getEquipNumber(enemy)-self:getEquipNumber(friend))<= lost_hp) and 
							(self:getEquipNumber(enemy)>=self:getEquipNumber(friend))then
							use.card = sgs.Card_Parse("@GanluCard=.")
							use.to:append(friend)
							use.to:append(enemy)
							self.ganlu_used = true
							return
						end
					end
				end			
			end	
		end	
		
	end
	
	
end


--jujian
local xushu_ai = SmartAI:newSubclass "xushu"
xushu_ai:setOnceSkill("jujian")

function xushu_ai:activate(use)

	local abandon_handcard = {}
	local index = 0
	local hasPeach=false
	local find_peach = self.player:getCards("h")
	for _, ispeach in sgs.qlist(find_peach) do
		if ispeach:inherits("Peach") then hasPeach=true break end
	end

	if not self.jujian_used and self.player:isWounded() and self.player:getHandcardNum() > 2 and not hasPeach then
		
		local cards = self.player:getHandcards()
		cards=sgs.QList2Table(cards)
		local club, spade, diamond = true, true, true
		self:sortByUseValue(cards, true)
		for _, friend in ipairs(self.friends_noself) do
			if (friend:getHandcardNum()<2) or (friend:getHandcardNum()<friend:getHp()+1) then
				for _, card in ipairs(cards) do 
					if card:getSuit() == sgs.Card_Club and club then 
						table.insert(abandon_handcard, card:getEffectiveId())
						index = index + 1
						club = false
					elseif card:getSuit() == sgs.Card_Spade and spade then
						table.insert(abandon_handcard, card:getEffectiveId())
						index = index + 1
						spade = false
					elseif card.getSuit() == sgs.Card_Diamond and not card:inherits("Peach") and diamond then
						table.insert(abandon_handcard, card:getEffectiveId())
						index = index + 1
						diamond = false
					end
				end
				if index == 3 then 
					use.to:append(friend)
					use.card = sgs.Card_Parse("@JujianCard=" .. table.concat(abandon_handcard, "+"))
					self.jujian_used = true
				end	
				break
			end
		end
	
	
	elseif not self.jujian_used then
		local cards = self.player:getHandcards()
		cards=sgs.QList2Table(cards)
		self:sortByUseValue(cards)
		local slash_num = self:getSlashNumber(self.player)
		local jink_num = self:getJinkNumber(self.player)
		for _, friend in ipairs(self.friends_noself) do
			if (friend:getHandcardNum()<2) or (friend:getHandcardNum()<friend:getHp()+1) or self.player:isWounded() then
				for _, card in ipairs(cards) do
					if not card:inherits("Nullification") and not card:inherits("EquipCard") and 
						not card:inherits("Peach") and not card:inherits("Jink") then
						table.insert(abandon_handcard, card:getId())
						index = 5
					elseif card:inherits("Slash") and slash_num > 1 then
						if (self.player:getWeapon() and not self.player:getWeapon():objectName()=="crossbow") or
							not self.player:getWeapon() then
							table.insert(abandon_handcard, card:getId())
							index = 5
							slash_num = slash_num - 1
						end
					elseif card:inherits("Jink") and jink_num > 1 then
						table.insert(abandon_handcard, card:getId())
						index = 5
						jink_num = jink_num - 1
					end
				end	
				if index == 5 then 
					use.card = sgs.Card_Parse("@JujianCard=" .. table.concat(abandon_handcard, "+"))
					use.to:append(friend)
					self.jujian_used = true
					return
				end
			end			
		end	
	
	end
	
	super.activate(self, use)
end


--mingce
local chengong_ai = SmartAI:newSubclass "chengong"

function chengong_ai:activate(use)
	super.activate(self, use)
	if use:isValid() and self:getSlashNumber(self.player) > 1 then
		return
	end
	
    if self.mingce_used then return nil end
		
	local card, target
		
	local hcards = self.player:getCards("h")
	hcards = sgs.QList2Table(hcards)
		for _, hcard in ipairs(hcards) do
		if hcard:inherits("Slash") or hcard:inherits("EquipCard") then
			card = hcard
			break
		end
	end
	
	if self:getEquipNumber(self.player) > 0 and not card then
		if self.player:getArmor() and self.player:getArmor():objectName() == "silver_lion" and self.player:isWounded() then
			card = self.player:getArmor()
		end
		local ecards = self.player:getCards("e")
		ecards = sgs.QList2Table(ecards)
		for _, ecard in ipairs(ecards) do
			if not (ecard:inherits("Armor") and card:inherits("DefensiveHorse")) then
				card = ecard
				break
			end
		end
	end	
	
	
	if card then 
		local friends = self.friends_noself
		for _, friend in ipairs(self.friends_noself) do
			if friend:getHp() <= 2 and friend:getHandcardNum() < 2 then
				target = friend
				break
			end
		end
		if not target then target = friends[1] end
	end
	if card and target then
		use.card = sgs.Card_Parse("@MingceCard=" .. card:getId()) 
		use.to:append(target)
		self.mingce_used=true
		return
	end
	
	return nil
end

