sgs.life_point_value={0,10,17,22,26,30,34,38,42,46}
sgs.hand_number_value={0,10,17,22,26,30,34,38,42,46}

sgs.ai_result_evaluation=
{
    dmg=function(self,from,to,param)
        local score=0
        
        local element=param.element
        local value=param.value or 1
        
        score=sgs.life_point_value[to:getHp()]-(sgs.life_point_value[to:getHp()-value] or 0)
        if self:isFriend(to) then score=-score end
        
        if to:hasSkill("ganglie") then 
            local feedback=sgs.ai_result_evaluation.dmg(self,to,from)
            local feedback_alt=sgs.ai_result_evaluation.discard(self,to,from,{value=2})
            if feedback_alt>feedback then feedback = feedback_alt end
            
            score=score+feedback
        end
    
        if to:hasSkill("yiji") then 
            local feedback=sgs.ai_result_evaluation.draw(self,from,to,{value=2})
        
            score=score+feedback
            
        end
        
        if to:hasSkill("benghuai") then 
            local feedback=0
            players=self.room:getAllPlayers()
            for _,player in sgs.qlist(players) do
                if player:getHp()<to:getHp() then feedback=-1 break end 
            end
        
            score=score+feedback
            
        end
        
        return score
    end,
    
    recover=function(self,from,to,param)
        local score=0
        
        local value=param.value or 1
        
        score=sgs.life_point_value[to:getHp()+value]-sgs.life_point_value[to:getHp()]
        if self:isEnemy(to) then score=-score end
        
        return score
    end,
    
    draw=function(self,from,to,param)
        local score=0
        
        local value=param.value or 1
        
        score=sgs.hand_number_value[to:getHp()+value]-sgs.hand_number_value[to:getHp()]
        if self:isEnemy(to) then score=-score end
        
        return score
    end,
    
    discard=function(self,from,to,param)
        local score=0
        
        local value=param.value or 1
        
        score=sgs.hand_number_value[to:getHp()]-sgs.hand_number_value[to:getHp()-value]
        if self:isFriend(to) then score=-score end
        
        return score
    end,
    
    gainBuff=function(self,from,to,param)
        local score=0
        
        local skill=param.skill
        
        score=sgs.skill_value[skill](to)
        if self:isEnemy(to) then score=-score end
        
        return score
    end,
    
    deBuff=function(self,from,to,param)
        return -gainBuff(self,from,to,param)
    end,

}

sgs.skill_value={}
sgs.skill_value.KylinBow=function(player)
{
    
}

--function SmartAI:get