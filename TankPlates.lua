local DEBUG = false

local function tp_print(msg)
  if type(msg) == "boolean" then msg = msg and "true" or "false" end
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

local function debug_print(msg)
  if DEBUG then tp_print(msg) end
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

function UpdateTarget(plate)
  local _, targeting = UnitExists(plate.guid.."target")
  if targeting ~= plate.current_target then
    -- only update previous target if there is a current one
    if plate.current_target then
      plate.previous_target = plate.current_target
    end
    plate.current_target = targeting
  end
end

local function InitPlate(plate)

  plate.npc_name = "<unknown>"
  plate.namefontstring = nil
  plate.npc_name_color = {}

  local regions = { plate:GetRegions() }
  for _, region in ipairs(regions) do
    if region:IsObjectType("FontString") and region:GetText() then
      local text = region:GetText()
      if not (tonumber(text) ~= nil or text == "??") then
        plate.npc_name = text
        plate.namefontstring = region
        plate.npc_name_color = { region:GetTextColor() }
      end
    end
  end

  local guid = plate:GetName(1)

  plate.guid = guid
  _, plate.current_target = UnitExists(guid.."target")
  plate.previous_target = nil
  
  plate.healthbar = plate:GetChildren()
  plate.original_color = { plate.healthbar:GetStatusBarColor() }

  plate.tick = 0
  plate.cc = false
  plate.casting = false

  HookScript(plate,"OnUpdate", function ()
    this.tick = this.tick + arg1

    UpdateTarget(this)

    -- cc check
    if this.tick > 0.1 then
      this.tick = 0
      this.cc = UnitIsCC(this.guid)
    end
  end)

  local function UpdateHealth()
    local _, playerGUID = UnitExists("player")
    local plate = this:GetParent()
    if not plate.guid then return end
    local reaction_level = UnitReaction(plate.guid, playerGUID)

    if UnitIsUnit("target",plate.guid) then
      -- plate.namefontstring:SetText(plate.npc_name)
      plate.namefontstring:SetTextColor(1,1,0,1)
    else
      -- plate.namefontstring:SetText(plate.npc_name)
      local c = plate.npc_name_color
      plate.namefontstring:SetTextColor(c[1],c[2],c[3],c[4])
    end

    -- The cases we want 'green' for are:
    -- 1. Being the previous target if a mob is casting on someone else
    -- 2. Being targeted
    -- 3. Being the previous target when a mob has no current target
    if UnitAffectingCombat("player") and (plate.current_target or reaction_level < 4) then
      if not plate.current_target and plate.cc then
        this:SetStatusBarColor(1, 1, 1, 0.6)
      elseif (plate.casting and (plate.previous_target == playerGUID)) then
        -- casting on someone else now, but was attacking you
        this:SetStatusBarColor(0, 1, 0, 1)
        -- tp_print(UnitName(plate.guid).." casting on "..UnitName(plate.current_target))
      elseif plate.current_target == playerGUID then
        -- attacking you
        this:SetStatusBarColor(0, 1, 0, 1)
      elseif not plate.casting and (not plate.current_target and plate.previous_target == playerGUID) then
        -- fleeing, usually
        this:SetStatusBarColor(0, 1, 0, 1)
      else
        -- not attacking you
        this:SetStatusBarColor(1, 0, 0, 1)
      end
    else
      local c = plate.original_color
      this:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end
  end

  -- OnShow is when real plate init happens, doing it on the healthbar
  -- because it's less likely to be molested by other addons
  plate.healthbar:SetScript("OnShow", function()
    local plate = this:GetParent()
    plate.original_color = { this:GetStatusBarColor() }
    plate.npc_name = plate.namefontstring:GetText()
    plate.npc_name_color = { plate.namefontstring:GetTextColor() }
    plate.guid = plate:GetName(1)
  end)

  -- OnHide is when a plate 'expires' and needs resetting since the game might re-use it on another unit
  plate.healthbar:SetScript("OnHide", function()
    -- plate  has 'gone away' need to reset state
    -- next update will restore it
    local p = this:GetParent()
    p.current_target = nil
    p.previous_target = nil
    p.cc = false
    p.casting = false
    p.guid = nil
    p.previous_target = nil
    p.npc_name = "<unknown>"

    p.healthbar = plate:GetChildren()
    p.original_color = { p.healthbar:GetStatusBarColor() }

    p.tick = 0
    p.cc = false
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
  if event == "UNIT_CASTEVENT" then
    local _,source = UnitExists(arg1)
    local _,target = UnitExists(arg2)
    local n,_,icon,_,_ = SpellInfo(arg4)

    for k,plate in pairs(registry) do
      if source == plate.guid then
        if arg3 == "START" then
          plate.casting = true
        elseif arg3 == "FAIL" or arg3 == "CAST" then
          plate.casting = false
        end
        break
      end
    end
  end
end

local tankplates = CreateFrame("Frame")

tankplates:SetScript("OnEvent", Events)
tankplates:SetScript("OnUpdate", Update)
tankplates:RegisterEvent("UNIT_CASTEVENT")
