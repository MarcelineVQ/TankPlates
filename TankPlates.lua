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

local tracked_guids = {}

local function UpdateTarget(plate)
  local guid = plate:GetName(1)
  if not guid then return end
  local _, targeting = UnitExists(guid.."target")
  if targeting ~= tracked_guids[guid].current_target then
    -- only update previous target if there is a current one
    if tracked_guids[guid].current_target then
      tracked_guids[guid].previous_target = tracked_guids[guid].current_target
    end
    tracked_guids[guid].current_target = targeting
  end
end

local function InitPlate2(plate)

  local guid = plate:GetName(1)

  if tracked_guids[guid] then
    debug_print("already tracked")
    return
  end

  debug_print("adding "..guid.." "..UnitName(guid))
  -- save orignal guid's color now
  tracked_guids[guid] = {
    unit_namefontstring = nil,
    unit_name_color = {},
    healthbar_color = { plate:GetChildren():GetStatusBarColor() },
    current_target = nil,
    previous_target = nil,
    tick = 0,
    cc = false,
    casting = false,
  }

  for _, region in ipairs( { plate:GetRegions() } ) do
    if region:IsObjectType("FontString") and region:GetText() then
      local text = region:GetText()
      if not (tonumber(text) ~= nil or text == "??") then
        plate.namefontstring = region
        tracked_guids[guid].unit_name_color = { region:GetTextColor() }
      end
    end
  end

  HookScript(plate,"OnUpdate", function ()
    local guid = this:GetName(1)
    if not tracked_guids[guid] then
      debug_print("init loop hasn't grabbed this guid yet")
      return
    end
    tracked_guids[guid].tick = tracked_guids[guid].tick + arg1

    UpdateTarget(this)

    -- cc check
    if tracked_guids[guid].tick > 0.1 then
      tracked_guids[guid].tick = 0
      tracked_guids[guid].cc = UnitIsCC(guid)
    end
  end)

  local function UpdateHealth()
    local _, playerGUID = UnitExists("player")
    local plate = this:GetParent()
    local guid = plate:GetName(1)
    if not guid then
      debug_print("plate didn't have guid?")
      return end
    if not tracked_guids[guid] then
      debug_print("plate init loop hasn't added this guid yet")
      return
    end
    local reaction_level = UnitReaction(guid, playerGUID)

    if UnitIsUnit("target",guid) then
      plate.namefontstring:SetTextColor(1,1,0,1)
    else
      local c = tracked_guids[guid].unit_name_color
      plate.namefontstring:SetTextColor(c[1],c[2],c[3],c[4])
    end

    -- The cases we want 'green' for are:
    -- 1. Being the previous target if a mob is casting on someone else
    -- 2. Being targeted
    -- 3. Being the previous target when a mob has no current target
    if UnitAffectingCombat("player") and (tracked_guids[guid].current_target or reaction_level < 4) then
      if not tracked_guids[guid].current_target and tracked_guids[guid].cc then
        this:SetStatusBarColor(1, 1, 1, 0.6)
      elseif (tracked_guids[guid].casting and (tracked_guids[guid].previous_target == playerGUID)) then
        -- casting on someone else now, but was attacking you
        this:SetStatusBarColor(0, 1, 0, 1)
        -- tp_print(UnitName(plate.guid).." casting on "..UnitName(plate.current_target))
      elseif tracked_guids[guid].current_target == playerGUID then
        -- attacking you
        this:SetStatusBarColor(0, 1, 0, 1)
      elseif not tracked_guids[guid].casting and (not tracked_guids[guid].current_target and tracked_guids[guid].previous_target == playerGUID) then
        -- fleeing, usually
        this:SetStatusBarColor(0, 1, 0, 0.8)
      else
        -- not attacking you
        this:SetStatusBarColor(1, 0, 0, 1)
      end
    else
      local c = tracked_guids[guid].healthbar_color
      this:SetStatusBarColor(c[1], c[2], c[3], c[4])
    end
  end

  -- if not plate:GetChildren().set then
    -- plate:GetChildren().set = guid
  plate:GetChildren():SetScript("OnUpdate", UpdateHealth)
  plate:GetChildren():SetScript("OnValueChanged", UpdateHealth)
  -- end
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
        InitPlate2(plate)
      end
    end
  end
  if cleanTick > 10 then
    cleanTick = 0
    for guid,_ in pairs(tracked_guids) do
      if not UnitExists(guid) then
        tracked_guids[guid] = nil
      end
    end
  end
end

local function Events()
  if event == "UNIT_CASTEVENT" then
    local _,source = UnitExists(arg1)
    local _,target = UnitExists(arg2)
    local n,_,icon,_,_ = SpellInfo(arg4)

    for guid,data in pairs(tracked_guids) do
      if source == guid then
        if arg3 == "START" then
          data.casting = true
        elseif arg3 == "FAIL" or arg3 == "CAST" then
          data.casting = false
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
