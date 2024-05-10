local DEBUG = false

local function tp_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(msg)
  if DEBUG then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end

-- stop loading addon if no superwow
if not SetAutoloot then
  DEFAULT_CHAT_FRAME:AddMessage("[|cff00ff00Tank|cffff0000Plates|r] requires |cffffd200SuperWoW|r to operate.")
  return
end

local tracked_units = {}

local cc_spells = {
  ["Interface\\Icons\\Spell_Nature_Sleep"] = "Hibernate", -- handles magic dust too
  ["Interface\\Icons\\Spell_Nature_Polymorph"] = "Polymorph",
  ["Interface\\Icons\\Spell_Nature_Slow"] = "Shackle Undead",
  ["Interface\\Icons\\Ability_Gouge"] = "Gouge",
  ["Interface\\Icons\\Ability_Sap"] = "Sap",
  ["Interface\\Icons\\Ability_Hunter_Pet_Turtle"] = "Polymorph: Turtle",
  ["Interface\\Icons\\Spell_Magic_PolymorphPig"] = "Polymorph: Pig",
  ["Interface\\Icons\\Spell_Nature_Polymorph_Cow"] = "Polymorph: Cow",
  ["Interface\\Icons\\Spell_Magic_PolymorphChicken"] = "Polymorph: Chicken",
}

local function UnitIsCC(unit) -- shackle and sheep rly,hibernate,magic dust
  for i=1,40 do
    local dTexture,_ = UnitDebuff(unit,i)
    if dTexture and cc_spells[dTexture] then
      return true
    end
  end
  return false
end

local function UpdatePlate(unitGUID)
  local _,playerGUID = UnitExists("player")
  local _,targetGUID = UnitExists(unitGUID.."target")
  -- tp_print(arg1 .. " " .. unitGUID)
  -- if not tracked_units[unitGUID] then tracked_units[unitGUID].cc = UnitIsCC(unitGUID) end

  -- is this plate even stored yet?
  -- Shouldn't happen, but does
  if not tracked_units[unitGUID] then return end

  -- if we can attack and we're in combat, proceed
  if UnitAffectingCombat("player") and (targetGUID or (UnitReaction(unitGUID,playerGUID) < 4)) then
    -- cc'd mob, avoid it
    if not targetGUID and tracked_units[unitGUID].cc == true then
      debug_print("cc " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(0,0,0,0.5)
      -- tracked_units[unitGUID].targeting_you = false
    -- you have aggro
    elseif targetGUID and (targetGUID == playerGUID) then
      debug_print("aggro " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(0,1,0,1)
      tracked_units[unitGUID].targeting = playerGUID
    -- targeting someone else
    elseif targetGUID and (targetGUID ~= playerGUID) then
      debug_print("aggro not-you: " .. targetGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(1,0,0,1)
      tracked_units[unitGUID].targeting = targetGUID
    else
      debug_print("not aggro " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(1,0,0,1)
      -- tracked_units[unitGUID].targeting_you = false
    end
  else
    local c = tracked_units[unitGUID].original_bar_color
    tracked_units[unitGUID].healthbar:SetStatusBarColor(c[1],c[2],c[3],c[4])
  end
end

local function UpdatePlate2(unitGUID)
  local _,playerGUID = UnitExists("player")
  local _,targetGUID = UnitExists(unitGUID.."target")
  -- tp_print(arg1 .. " " .. unitGUID)
  -- if not tracked_units[unitGUID] then tracked_units[unitGUID].cc = UnitIsCC(unitGUID) end

  -- is this plate even stored yet?
  -- Shouldn't happen, but does
  if not tracked_units[unitGUID] then return end

  -- if we can attack and we're in combat, proceed
  if UnitAffectingCombat("player") and (targetGUID or (UnitReaction(unitGUID,playerGUID) < 4)) then
    -- cc'd mob, avoid it
    if not targetGUID and tracked_units[unitGUID].cc == true then
      debug_print("cc " .. unitGUID)
      this.healthbar:SetStatusBarColor(0,0,0,0.5)
      -- tracked_units[unitGUID].targeting_you = false
    -- you have aggro
    elseif targetGUID and (targetGUID == playerGUID) then
      debug_print("aggro " .. unitGUID)
      this.healthbar:SetStatusBarColor(0,1,0,1)
      tracked_units[unitGUID].targeting = playerGUID
    -- targeting someone else
    elseif targetGUID and (targetGUID ~= playerGUID) then
      debug_print("aggro not-you: " .. targetGUID)
      this.healthbar:SetStatusBarColor(1,0,0,1)
      tracked_units[unitGUID].targeting = targetGUID
    else
      debug_print("not aggro " .. unitGUID)
      this.healthbar:SetStatusBarColor(1,0,0,1)
      -- tracked_units[unitGUID].targeting_you = false
    end
  else
    -- debug_print("not combat " .. unitGUID)
    local c = tracked_units[unitGUID].original_bar_color
    this.healthbar:SetStatusBarColor(c[1],c[2],c[3],c[4])
  end
end

-- this is gross
-- if ShaguTweaks and ShaguTweaks.libnameplate then
--   table.insert(ShaguTweaks.libnameplate.OnUpdate,function ()
--     UpdatePlate(this:GetName(1))
--   end)
--   table.insert(ShaguTweaks.libnameplate.OnInit,function()
--     local unitGUID = this:GetName(1)
--     if tonumber(unitGUID) ~= 0 and this:IsShown() and this:IsObjectType("Button") then
--       -- local original_healthbar,original_castbar = this:GetChildren()
--       local r,g,b,a = this.healthbar:GetStatusBarColor()

--       local v = tracked_units[unitGUID]
--       tracked_units[unitGUID] = {
--         targeting = v and v.targeting or nil,
--         casting_at = v and v.casting_at or nil,
--         original_bar_color = v and v.original_bar_color or { r,g,b,a },
--         cc = v and v.cc or nil,
--         healthbar = this.healthbar,
--         castbar = this.castbar,
--       }
--     end
--   end)
end

local plateTick = 0
local unitsTick = 0
function Update()
  plateTick = plateTick + arg1
  unitsTick = unitsTick + arg1
  if plateTick >= 0.5 then
    plateTick = 0
    local frames = { WorldFrame:GetChildren() }
    parentcount = WorldFrame:GetNumChildren()
    for i, plate in ipairs(frames) do
      if plate then
        if plate:IsShown() and plate:IsObjectType("Button") then
          local unitGUID = plate:GetName(1)

          local original_healthbar,original_castbar = plate:GetChildren()
          local r,g,b,a = original_healthbar:GetStatusBarColor()

          local v = tracked_units[unitGUID]
          tracked_units[unitGUID] = {
            targeting = v and v.targeting or nil,
            casting_at = v and v.casting_at or nil,
            original_bar_color = v and v.original_bar_color or { r,g,b,a },
            cc = v and v.cc or nil,
            healthbar = original_healthbar,
            castbar = original_castbar,
          }
          -- UpdatePlate2(unitGUID)

          tracked_units[unitGUID].healthbar:SetScript("OnValueChanged",function () UpdatePlate(unitGUID) end)
        end
      end
    end
  elseif unitsTick > 5 then -- clean units db
    unitsTick = 0
    for k,unit in pairs(tracked_units) do
      local gone = not UnitExists(k) or UnitIsDead(k)
      if gone then
        debug_print("cleaning: " .. k)
        tracked_units[k] = nil
      end
    end
  end
end

local function Events()
  if event == "UNIT_CASTEVENT" then
    -- if we see a cc get applied on a mob we have plates for, track it
    local _,source = UnitExists(arg1)
    local _,target = UnitExists(arg2)
    local n,_,icon,_,_ = SpellInfo(arg4)
    if target and tracked_units[target] and arg3 == "CAST" and icon and cc_spells[icon] then
      tracked_units[target].cc = true
    end

    -- mob is casting on someone, was it targeting you just before that?
    if source and tracked_units[source] and target and arg3 == "START" then
      tracked_units[source].casting_at = target
    end
  end
end

local tankplates = CreateFrame("Frame")

tankplates:SetScript("OnEvent", Events)
tankplates:SetScript("OnUpdate", Update)
tankplates:RegisterEvent("UNIT_CASTEVENT")
