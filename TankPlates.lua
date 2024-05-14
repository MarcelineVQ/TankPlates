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

-- local plates = {}

local cc_spells = {
  "Hibernate",
  "Magic Dust",
  "Polymorph",
  "Shackle Undead",
  "Gouge",
  "Sap",
  "Polymorph: Turtle",
  "Polymorph: Pig",
  "Polymorph: Cow",
  "Polymorph: Chicken",
}

-- shackle, sheep, hibernate, magic dust, etc
local function UnitIsCC(unit)
  for i=1,40 do
    local dTexture,_,_,spell_id = UnitDebuff(unit,i)
    local name = SpellInfo(spell_id)
    for _,spell in ipairs(cc_spells) do
      if name == spell then
        return true
      end
    end
  end
  return false
end

-- local function UpdatePlate(vplate)
--   if not plates[vplate.unit] then
--     tp_print("|cffff0000impossible error:|r plate not tracked, report this")
--     return
--   end
--   local _,playerGUID = UnitExists("player")
--   local _,targetGUID = UnitExists(vplate.unit.."target")
--   local unitGUID = vplate.unit
--   local healthbar = vplate.healthbar

--   -- if we can attack and we're in combat, proceed
--   if UnitAffectingCombat("player") and (targetGUID or (UnitReaction(unitGUID,playerGUID) < 4)) then
--     -- cc'd mob, avoid it
--     if not targetGUID and vplate.cc == true then
--       debug_print("cc " .. unitGUID .. " " .. UnitName(unitGUID))
--       healthbar:SetStatusBarColor(0,0,0,0.5)
--     -- you have aggro
--     elseif targetGUID and (targetGUID == playerGUID) then
--       debug_print("aggro " .. unitGUID .. " " .. UnitName(unitGUID))
--       healthbar:SetStatusBarColor(0,1,0,1)
--     -- targeting someone else
--     elseif targetGUID and (targetGUID ~= playerGUID) then
--       debug_print("aggro not-you: " .. unitGUID .. " " .. UnitName(unitGUID))
--       healthbar:SetStatusBarColor(1,0,0,1)
--     else
--       -- no target
--       debug_print("not aggro " .. unitGUID .. " " .. UnitName(unitGUID))
--       healthbar:SetStatusBarColor(1,0,0,1)
--     end
--   else
--     local c = vplate.original_color
--     healthbar:SetStatusBarColor(c[1],c[2],c[3],c[4])
--   end
-- end

-- local function UpdateHealth(plate,cc,original_color)
--   -- if not plates[vplate.unit] then
--   --   tp_print("|cffff0000impossible error:|r plate not tracked, report this")
--   --   return
--   -- end
--   local unitGUID = plate:GetName(1)
--   local _,playerGUID = UnitExists("player")
--   local _,targetGUID = UnitExists(unitGUID.."target")

--   -- if we can attack and we're in combat, proceed
--   if UnitAffectingCombat("player") and (targetGUID or (UnitReaction(unitGUID,playerGUID) < 4)) then
--     -- cc'd mob, avoid it
--     if not targetGUID and cc then
--       debug_print("cc " .. unitGUID .. " " .. UnitName(unitGUID))
--       this:SetStatusBarColor(0,0,0,0.5)
--     -- you have aggro
--     elseif targetGUID and (targetGUID == playerGUID) then
--       debug_print("aggro " .. unitGUID .. " " .. UnitName(unitGUID))
--       this:SetStatusBarColor(0,1,0,1)
--     -- targeting someone else
--     elseif targetGUID and (targetGUID ~= playerGUID) then
--       debug_print("aggro not-you: " .. unitGUID .. " " .. UnitName(unitGUID))
--       this:SetStatusBarColor(1,0,0,1)
--     else
--       -- no target
--       debug_print("not aggro " .. unitGUID .. " " .. UnitName(unitGUID))
--       this:SetStatusBarColor(1,0,0,1)
--     end
--   else
--     local c = original_color
--     this:SetStatusBarColor(c[1],c[2],c[3],c[4])
--   end
-- end

-- local function PlateUpdate()
--   local guid = this:GetName(1)
--   if not plates[guid] then
--     tp_print("unit it not tracked")
--     return
--   end
--   local healthbar = this:GetChildren()
--   healthbar:SetScript("OnUpdate",function UpdateHealth(this,false,{ healthbar:GetStatusBarColor() }) end)
-- end

-- Copied from shagu since it resembled what I was trying to do anyway
-- [ HookScript ]
-- Securely post-hooks a script handler.
-- 'f'          [frame]             the frame which needs a hook
-- 'script'     [string]            the handler to hook
-- 'func'       [function]          the function that should be added
function HookScript(f, script, func)
  local prev = f:GetScript(script)
  f:SetScript(script, function(a1,a2,a3,a4,a5,a6,a7,a8,a9)
    if prev then prev(a1,a2,a3,a4,a5,a6,a7,a8,a9) end
    func(a1,a2,a3,a4,a5,a6,a7,a8,a9)
  end)
end

local function IsNamePlate(frame)
  return frame and (frame:IsShown() and frame:IsObjectType("Button")) and (frame:GetName(1) ~= "0x0000000000000000")
end

local function InitPlate(plate)
  -- tp_print("plate init")

  local guid = plate:GetName(1)

  plate.guid = guid
  _, plate.current_target = UnitExists(guid.."target")
  plate.previous_target = nil
  
  plate.healthbar = plate:GetChildren()
  plate.original_color = { plate.healthbar:GetStatusBarColor() }

  plate.tick = 0
  plate.cc = nil

  HookScript(plate,"OnUpdate", function (x,y,z)
    -- the game re-uses plates, update the mob it's for
    plate.tick = plate.tick + arg1
    local guid = plate:GetName(1)

    local _,targeting = UnitExists(plate.guid.."target")
    if targeting ~= plate.current_target then
      plate.previous_target = plate.current_targete
      plate.current_target = targeting
    end

    -- cc check
    if plate.tick > 0.1 then
      plate.tick = 0
      plate.cc = UnitIsCC(plate.guid)
    end
  end)

  local function UpdateHealth()
    local _,playerGUID = UnitExists("player")
    local plate = this:GetParent()
    local is_hostile = UnitReaction(plate.guid,playerGUID)

    -- if we can attack and we're in combat, proceed
    if UnitAffectingCombat("player") and (plate.current_target or is_hostile) then
      -- cc'd mob, avoid it
      if not plate.current_target and plate.cc then
        -- tp_print("cc " .. plate.guid .. " " .. UnitName(plate.guid))
        this:SetStatusBarColor(0,0,0,0.5)
      -- you have aggro
      elseif plate.current_target and (plate.current_target == playerGUID) then
        -- tp_print("aggro " .. plate.guid .. " " .. UnitName(plate.guid))
        this:SetStatusBarColor(0,1,0,1)
      -- targeting someone else
      elseif plate.current_target and (plate.current_target ~= playerGUID) then
        -- tp_print("aggro not-you: " .. plate.guid .. " " .. UnitName(plate.guid))
        this:SetStatusBarColor(1,0,0,1)
      else
        -- no target
        -- tp_print("not aggro " .. plate.guid .. " " .. UnitName(plate.guid))
        this:SetStatusBarColor(1,0,0,1)
      end
    else
      -- tp_print("else")
      local c = plate.original_color
      this:SetStatusBarColor(c[1],c[2],c[3],c[4])
    end
  end

  -- might be a critter now, etc
  plate.healthbar:SetScript("OnShow", function()
    this:GetParent().original_color = { this:GetStatusBarColor() }
  end)

  plate.healthbar:SetScript("OnUpdate", UpdateHealth)
  plate.healthbar:SetScript("OnValueChanged", UpdateHealth)
end

-- Copied from shagu since it resembled what I was trying to do anyway
local initialized = 0
local parentcount = 0
local registry = {}
local plateTick = 0
local function Update()
  plateTick = plateTick + arg1
  if plateTick >= 0.1 then
    plateTick = 0 
    parentcount = WorldFrame:GetNumChildren()
    if initialized < parentcount then
      local children = { WorldFrame:GetChildren() }
      for i = initialized + 1, parentcount do
        plate = children[i]
        if IsNamePlate(plate) and not registry[plate] then
          InitPlate(plate)
          registry[plate] = plate
        end
      end
      initialized = parentcount
    end
  end
end

local function Events()
  -- if event == "UNIT_CASTEVENT" then
  --   -- if we see a cc get applied on a mob we have plates for, track it
  --   local _,source = UnitExists(arg1)
  --   local _,target = UnitExists(arg2)
  --   local n,_,icon,_,_ = SpellInfo(arg4)
  --   if target and plates[target] and arg3 == "CAST" and icon and cc_spells[icon] then
  --     plates[target].cc = true
  --   end

  --   -- mob is casting on someone, was it targeting you just before that?
  --   if source and plates[source] and target and arg3 == "START" then
  --     plates[source].casting_at = target
  --   end
  -- end
end

local tankplates = CreateFrame("Frame")

tankplates:SetScript("OnEvent", Events)
tankplates:SetScript("OnUpdate", Update)
tankplates:RegisterEvent("UNIT_CASTEVENT")
