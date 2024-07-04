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

local player_guid = nil
local tracked_guids = {}

local cc_spells = {
  "Polymorph",
  "Shackle Undead",
  "Freezing Trap",
  "Hibernate",
  "Gouge",
  "Sap",
  "Magic Dust",
}

-- shackle, sheep, hibernate, magic dust, etc
local function UnitIsCC(unit)
  for i=1,40 do
    local dTexture,_,_,spell_id = UnitDebuff(unit,i)
    if spell_id then
      local name = SpellInfo(spell_id)
      for _,spell in ipairs(cc_spells) do
        if string.find(name,"^"..spell) then
          return true
        end
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
  local guid = frame:GetName(1)
  return frame and (frame:IsShown() and frame:IsObjectType("Button")) and (guid and guid ~= "0x0000000000000000")
end

local function UpdateTarget(guid,targetArg)
  if not guid then return end
  local _, targeting = UnitExists(guid.."target")
  targeting = targetArg or targeting
  if targeting ~= tracked_guids[guid].current_target then
    -- only update previous target if there is a current one
    if tracked_guids[guid].current_target then
      tracked_guids[guid].previous_target = tracked_guids[guid].current_target
    end
    tracked_guids[guid].current_target = targeting
  end
end

local function InitPlate(plate)
  if plate.initialized then return end
  local guid = plate:GetName(1)

  for _, region in ipairs( { plate:GetRegions() } ) do
    if region:IsObjectType("FontString") and region:GetText() then
      local text = region:GetText()
      if not (tonumber(text) ~= nil or text == "??") then
        plate.namefontstring = region
      end
    end
  end

  if not plate.namefontstring then
    debug_print("tried to init a non-plate frame")
    return
  end

  HookScript(plate,"OnUpdate", function ()
    local guid = this:GetName(1)
    if not tracked_guids[guid] then
      debug_print("init loop hasn't grabbed this guid yet")
      return
    end
    tracked_guids[guid].tick = tracked_guids[guid].tick + arg1

    UpdateTarget(guid)

    -- cc check
    if tracked_guids[guid].tick > 0.1 then
      tracked_guids[guid].tick = 0
      tracked_guids[guid].cc = UnitIsCC(guid)
    end
  end)

  local origname = plate.namefontstring:GetText()
  local function UpdateHealth()
    local plate = this:GetParent()
    local guid = plate:GetName(1)
    if not guid then
      debug_print("plate didn't have guid?")
      return end
    if not tracked_guids[guid] then
      debug_print("plate init loop hasn't added this guid yet")
      return
    end
    local unit = tracked_guids[guid]

    if UnitIsUnit("target",guid) then
      -- plate.namefontstring:SetTextColor(1,0,1,1)
      plate.namefontstring:SetTextColor(1,1,0,1)
      -- plate.namefontstring:SetTextColor(0.825,0.144,0.825,1)
    else
      plate.namefontstring:SetTextColor(unpack(unit.unit_name_color))
    end

    if DEBUG then
      if unit.current_target then
        plate.namefontstring:SetText(UnitName(unit.current_target))
      else
        plate.namefontstring:SetText(origname)
      end
    end

    -- First, determine if this is a unit we should care to color.
    -- Is the player in combat, and is the unit in combat?
    -- if UnitAffectingCombat("player") and UnitAffectingCombat(guid) then
    if UnitAffectingCombat("player") and UnitAffectingCombat(guid) and
      not UnitCanAssist("player",guid) then -- don't color friendlies

      -- The cases we want 'green' for are:
      -- 1. Being the previous target if a mob is casting on someone else
      -- 2. Being targeted
      -- 3. Being the previous target when a mob has no current target

      if unit.cc then
        -- PFUI and ShaguPlates use enemy bar colors to determine types, this can really mess with things.
        -- For instance if we choose (0,0,1,1) blue, the shagu reads this as friendly player and may color based on class.
        -- Due to this yellow (neutral) has been chosen for now.
        this:SetStatusBarColor(1, 1, 0, 0.6)
      elseif (unit.casting and (unit.casting_at == player_guid or unit.previous_target == player_guid)) then
        -- casting on someone but was attacking you
        this:SetStatusBarColor(0, 1, 0, 1) -- green
      elseif unit.current_target == player_guid then
        -- attacking you
        this:SetStatusBarColor(0, 1, 0, 1) -- green
      elseif not unit.casting and (not unit.current_target and unit.previous_target == player_guid) then
        -- fleeing but was attacking you
        this:SetStatusBarColor(0, 1, 0, 1) -- green
      else
        -- not attacking you
        this:SetStatusBarColor(1, 0, 0, 1) -- red
      end
    else
      this:SetStatusBarColor(unpack(unit.healthbar_color))
    end
  end

  HookScript(plate:GetChildren(), "OnUpdate", UpdateHealth)
  HookScript(plate:GetChildren(), "OnValueChanged", UpdateHealth)

  plate.initialized = true
end

local plateTick = 0
local cleanTick = 0
local function Update()
  plateTick = plateTick + arg1
  cleanTick = cleanTick + arg1
  if plateTick >= 0.075 then
    plateTick = 0 
    for _,plate in pairs({ WorldFrame:GetChildren() }) do
      if IsNamePlate(plate) then
        -- the plate can refer to a different unit constantly, check for new id's here and set the plate logic once
        -- to depend on its current guid
        InitPlate(plate)

        local guid = plate:GetName(1)
        if not tracked_guids[guid] then
          debug_print("adding "..guid.." "..UnitName(guid))
          -- store the original plate text color and health bar color, to revert to when needed
          tracked_guids[guid] = {
            unit_name_color = { plate.namefontstring:GetTextColor() },
            healthbar_color = { plate:GetChildren():GetStatusBarColor() },
            current_target = nil,
            previous_target = nil,
            tick = 0,
            cc = false,
            casting = false,
            casting_at = nil,
          }
        end
      end
    end
  end
  if cleanTick > 10 then
    local count = 0
    cleanTick = 0
    for guid,_ in pairs(tracked_guids) do
      count = count + 1
      if not UnitExists(guid) then
        tracked_guids[guid] = nil
      end
    end
    debug_print("table size: "..count)
  end
end

local function Events()
  if event == "UNIT_CASTEVENT" then
    local _,source = UnitExists(arg1)
    local _,target = UnitExists(arg2)

    if not source then return end

    for guid,data in pairs(tracked_guids) do
      if source == guid then
        if arg3 == "START" then
          tracked_guids[guid].casting = true
          if target and target ~= "" then
            tracked_guids[guid].casting_at = target
          end
        elseif arg3 == "FAIL" or arg3 == "CAST" then
          tracked_guids[guid].casting = false
          tracked_guids[guid].casting_at = nil
        end
        break
      end
    end
  end
end

local function Init()
  if event == "PLAYER_ENTERING_WORLD" then
    _,player_guid = UnitExists("player")
    this:SetScript("OnEvent", Events)
    this:SetScript("OnUpdate", Update)
    this:UnregisterEvent("PLAYER_ENTERING_WORLD")
  end
end

local tankplates = CreateFrame("Frame")
tankplates:SetScript("OnEvent", Init)
tankplates:RegisterEvent("PLAYER_ENTERING_WORLD")
tankplates:RegisterEvent("UNIT_CASTEVENT")
