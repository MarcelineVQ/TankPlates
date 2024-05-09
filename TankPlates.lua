
local DEBUG = false

function tp_print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function debug_print(msg)
  if DEBUG then DEFAULT_CHAT_FRAME:AddMessage(msg) end
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

-- local function PlateUpdate(guid,healthbar)
--   local _,playerGUID = UnitExists("player")
--   -- if we can attack if and we're in combat, proceed
--   if UnitCanAttack("player",guid) and UnitAffectingCombat("player") then
--     -- cc'd mob, avoid it
--     if not UnitIsUnit(playerGUID,guid.."target") and tracked_units[guid] == true then
--       healthbar:SetStatusBarColor(0,0,0,0.5)
--     -- you have aggro
--     elseif UnitIsUnit(playerGUID,guid.."target") then
--       healthbar:SetStatusBarColor(0,1,0,1)
--     -- you don't have aggro
--     else
--       healthbar:SetStatusBarColor(1,0,0,1)
--     end
--   end
-- end

local function UpdatePlate(unitGUID)
  local _,playerGUID = UnitExists("player")
  -- tp_print(arg1 .. " " .. unitGUID)
  -- if not tracked_units[unitGUID] then tracked_units[unitGUID].cc = UnitIsCC(unitGUID) end

  -- is this plate even stored yet?
  -- Shouldn't happen, but does
  if not tracked_units[unitGUID] then return end

  -- if we can attack and we're in combat, proceed
  if UnitCanAttack("player",unitGUID) and UnitAffectingCombat("player") then
    -- cc'd mob, avoid it
    if not UnitIsUnit(playerGUID,unitGUID.."target") and tracked_units[unitGUID].cc == true then
      -- tp_print("cc " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(0,0,0,0.5)
    -- you have aggro
    elseif UnitIsUnit(playerGUID,unitGUID.."target") then
      -- tp_print("aggro " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(0,1,0,1)
    -- you don't have aggro
    else
      -- tp_print("not aggro " .. unitGUID)
      tracked_units[unitGUID].healthbar:SetStatusBarColor(1,0,0,1)
    end
  end
end

local plateTick = 0
local unitsTick = 0
function Update()
  plateTick = plateTick + arg1
  unitsTick = unitsTick + arg1
  if plateTick >= 0.5 then
    plateTick = 0
    local frames = { WorldFrame:GetChildren() }
    for i, plate in ipairs(frames) do
      if plate then
        if plate:IsShown() and plate:IsObjectType("Button") then
          -- plate:SetScale(UIParent:GetScale())
          -- local unitGUIDP = plate:GetName(1)
          local unitGUID = plate:GetName(1)
          -- if not unitGUIDP then return end
          -- local unitGUID = string.lower(unitGUIDP)

          local original_healthbar,original_castbar = plate:GetChildren()
          tracked_units[unitGUID] = { cc = (tracked_units[unitGUID] and tracked_units[unitGUID].cc) or nil, healthbar = original_healthbar, castbar = original_castbar }
          UpdatePlate(unitGUID)

          original_healthbar:SetScript("OnValueChanged",function () UpdatePlate(unitGUID) end)
        end
      end
    end
  elseif unitsTick > 5 then -- clean units db
    unitsTick = 0
    for k,unit in pairs(tracked_units) do
      local gone = not UnitExists(k) or UnitIsDead(k)
      if gone then
        -- tp_print("cleaning: " .. k)
        tracked_units[k] = nil
      end
    end
  end
end

local function Events()
  if event == "UNIT_CASTEVENT" then
    -- if we see a cc get applied on a mob we have plates for, track it
    local _,guid = UnitExists(arg2)
    local n,_,icon,_,_ = SpellInfo(arg4)
    if guid and tracked_units[guid] and arg3 == "CAST" and icon and cc_spells[icon] then
      tracked_units[guid].cc = true
    end
  end
end

local tankplates = CreateFrame("Frame")

tankplates:SetScript("OnEvent", Events)
tankplates:SetScript("OnUpdate", Update)
tankplates:RegisterEvent("UNIT_CASTEVENT")
