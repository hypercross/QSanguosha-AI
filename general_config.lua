--This file stores the values I used in this AI. It controls whether a card should be played or not, the sequence of the card play, and how to discard useless cards.
--This file is the second most important file for the AI strategy.

--there are 3 most important values here:useValue, usePriority and keepValue.
--useValue determines the importance of using a card. A card with a higher useValue has a higher priority to be played.
--usePriority determines the sequence of using a card. A card with a higher usePriority is played earlier than other cards.

--the difference of useValue and usePriority is that, AI will ensure that a high useValue card is played in the turn, but AI doesn't have play that card first.
--an example is indulgence card. this card has a high useValue, and AI will make sure that he plays it in the turn. But since indulgence has a low priority, the AI plays it after most other cards.

sgs.ai_keep_value = {
        Shit = 6,

        Peach = 5,

        Analeptic = 4.5,
        Jink = 4,

        Nullification = 3,

        Slash = 2,
        ThunderSlash = 2.5,
        FireSlash = 2.6,

        ExNihilo=4.6,

        AmazingGrace=-1,
        Lightning=-1,

}

sgs.ai_use_value =
{

--skill cards

        TianyiCard = 8.5,
        HuangtianCard = 8.5,
        JijiangCard=8.5,
        DimengCard=3.5,
--normal cards
        ExNihilo=10,
        
        Snatch=9,
        Collateral=8.8,
        
        
        Indulgence=8,
        SupplyShortage=7,
        
        Peach = 6,
        Dismantlement=5.6,
        IronChain = 5.4,

        --retain_value=5
        
        FireAttack=4.8,
        
        
        FireSlash = 4.4,
        ThunderSlash = 4.5,
        Slash = 4.6,
        
        ArcheryAttack=3.8,
        SavageAssault=3.9,
        Duel=3.7,
        
        
        AmazingGrace=3,
        
        --special
        Analeptic = 5.98,
        Jink=8.9,
}

sgs.ai_use_priority = {
--priority of using an active card

--skill cards

        TianyiCard = 10,
        HuangtianCard = 10,
        JijiangCard = 2.4,
        DimengCard=2.3,
--

        Collateral=5.8,
        Peach = 5,

        Dismantlement=4.5,
        Snatch=4.3,
        ExNihilo=4.6,

        GodSalvation=3.9,

        ArcheryAttack=3.5,
        SavageAssault=3.5,

        
        Duel=2.9,
        IronChain = 2.8,

        Analeptic = 2.7,

        FireSlash = 2.6,
        ThunderSlash = 2.5,
        Slash = 2.4,

        FireAttack=2,
        AmazingGrace=1.0,


        --god_salvation
        --deluge
        --supply_shortage
        --earthquake
        --indulgence
        --mudslide
        --lightning
        --typhoon
}


-- this table stores the chaofeng value for some generals
-- all other generals' chaofeng value should be 0
sgs.ai_chaofeng = {
        huatuo = 5,

        sunshangxiang = 4,
        huangyueying = 4,
        diaochan = 4,
        zhangjiao = 4,
        lusu = 4,

        zhangfei = 3,
        taishici = 3,
        xuchu = 3,

        zhangliao = 2,
        xuhuang = 2,
        ganning = 2,

        lubu = 1,
        huangzhong = 1,
        machao = 1,

        simayi = -1,
        caopi = -2,
        xiahoudun = -2,
        xunyu = -2,
        guojia = -3,

        shencaocao = -4,
        shenguanyu = -4,
}


function SmartAI:sortByKeepValue(cards)
	local compare_func = function(a,b)
		local value1 = self:getKeepValue(a)
		local value2 = self:getKeepValue(b)

		if value1 ~= value2 then
			return value1 < value2
		else
			return a:getNumber() < b:getNumber()
		end
	end

	table.sort(cards, compare_func)
end

function SmartAI:sortByUseValue(cards,inverse)
        local compare_func = function(a,b)
                local value1 = self:getUseValue(a)
                local value2 = self:getUseValue(b)

                if value1 ~= value2 then
                        if not inverse then return value1 > value2
                        else return value1 < value2
                        end
                else
                        return a:getNumber() > b:getNumber()
                end
        end

        table.sort(cards, compare_func)
end

function SmartAI:sortByUsePriority(cards)
	local compare_func = function(a,b)
                local value1 = self:getUsePriority(a)
                local value2 = self:getUsePriority(b)

		if value1 ~= value2 then
			return value1 > value2
		else
			return a:getNumber() > b:getNumber()
		end
	end

	table.sort(cards, compare_func)
end

function SmartAI:sortByCardNeed(cards)
	local compare_func = function(a,b)
                local value1 = self:cardNeed(a)
                local value2 = self:cardNeed(b)

		if value1 ~= value2 then
			return value1 < value2
		else
			return a:getNumber() > b:getNumber()
		end
	end

	table.sort(cards, compare_func)
end


function SmartAI:getKeepValue(card)
	local class_name = card:className()
        local value
        if sgs[self.player:getGeneralName().."_keep_value"] then
            value=sgs[self.player:getGeneralName().."_keep_value"][class_name]
        end
        return value or sgs.ai_keep_value[class_name] or 0
end

function SmartAI:getUseValue(card)
        local class_name = card:className()
        local v
        if card:inherits("EquipCard") then 
            if self:hasEquip(card) then return 9 end
            if card:inherits("Armor") and not self.player:getArmor() then v = 8.9
            elseif card:inherits("Weapon") and not self.player:getWeapon() then v = 6.2
            elseif card:inherits("DefensiveHorse") and not self.player:getDefensiveHorse() then v = 5.8
            elseif card:inherits("OffensiveHorse") and not self.player:getOffensiveHorse() then v = 5.5
            elseif self:hasSkill("bazhen") and card:inherits("Armor") then v=2
            else v = 2 end
            if self.weaponUsed and card:inherits("Weapon") then v=2 end
            
        else
            if card:inherits("Slash") and (self.player:hasFlag("drank") or self.player:hasFlag("tianyi_success") or self.player:hasFlag("luoyi")) then v = 8.7 --self:log("must slash")
            elseif self.player:getWeapon() and card:inherits("Collateral") then v=2
            elseif self.player:getMark("shuangxiong") and card:inherits("Duel") then v=8
            else v = sgs.ai_use_value[class_name] or 0 end
            
        end
        --if self.room:getCurrent():objectName()==self.player:objectName() then self:log(class_name..v) end
        if card:inherits("Slash") and (self:getSlashNumber(self.player)>1) then v=v+1 end
        if card:inherits("Jink") and (self:getJinkNumber(self.player)>1) then v=v-6 end
        
        return v
end

function SmartAI:getUsePriority(card)
	local class_name = card:className()
	if card:inherits("EquipCard") then
	    local v=1
        if card:inherits("Armor") and not self.player:getArmor() then v = 6
        elseif card:inherits("Weapon") and not self.player:getWeapon() then v = 5.7
        elseif card:inherits("DefensiveHorse") and not self.player:getDefensiveHorse() then v = 5.8
        elseif card:inherits("OffensiveHorse") and not self.player:getOffensiveHorse() then v = 5.5
        end
        return v
    end
        return sgs.ai_use_priority[class_name] or 0
end

function SmartAI:cardNeed(card)
    if card:inherits("Jink") and (self:getJinkNumber(self.player)==0) then return 5.9 end
    if card:inherits("Peach") then
        self:sort(self.friends,"hp")
        if self.friends[1]:getHp()<2 then return 10 end
        return self:getUseValue(card)
    end
    if card:inherits("Analeptic") then
        if self.player:getHp()<2 then return 10 end
    end
    if card:inherits("Slash") and (self:getSlashNumber(self.player)>0) then return 4 end
    if card:inherits("Weapon") and (not self.player:getWeapon()) and (self:getSlashNumber(self.player)>1) then return 6 end
    return self:getUseValue(card)
end


