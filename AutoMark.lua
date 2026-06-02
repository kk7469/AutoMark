-- AutoMark.lua
-- World of Warcraft 12.x addon to auto-mark party/raid members by role

local addonName = "AutoMark"
local AM = {}
_G[addonName] = AM

-- Default settings
local defaults = {
  enabled = true,
  useCommand = true, -- use /tm command if available, fallback to SetRaidTarget
  roleMarkers = {
    TANK = 2,   -- Circle
    HEALER = 5, -- Moon
    DAMAGER = 8 -- Skull
  }
}

local iconNames = {
  [1] = "STAR",
  [2] = "CIRCLE",
  [3] = "DIAMOND",
  [4] = "TRIANGLE",
  [5] = "MOON",
  [6] = "SQUARE",
  [7] = "CROSS",
  [8] = "SKULL",
}

local function LoadDefaults(db)
  if not db.enabled then db.enabled = defaults.enabled end
  if db.useCommand==nil then db.useCommand = defaults.useCommand end
  db.roleMarkers = db.roleMarkers or {}
  for k,v in pairs(defaults.roleMarkers) do
    if db.roleMarkers[k]==nil then db.roleMarkers[k]=v end
  end
end

-- Utility to get unit token for group index
local function UnitTokenForIndex(i)
  if IsInRaid() then
    return "raid"..i
  else
    if i==GetNumGroupMembers() then
      return "player"
    else
      return "party"..i
    end
  end
end

-- Mark a unit by name using /tm command if requested, fallback to SetRaidTarget
local function MarkUnitByName(name, index, useCommand)
  if not name or name=="" or index==0 then return end
  local succeeded = false
  if useCommand then
    -- Try to run /tm command (user requested). Format uncertain across servers/addons; attempt `/tm <name> <icon>` where icon is a number 1-8
    -- If /tm is not available this will silently fail; we fallback to API SetRaidTarget by locating the unit
    local cmd = string.format("/tm %s %d", name, index)
    -- RunMacroText executes as if the player typed the macro / command
    local ok, err = pcall(RunMacroText, cmd)
    if ok then succeeded = true end
  end
  if not succeeded then
    -- Find a unit token for that name in group or raid
    for i=1,GetNumGroupMembers() do
      local unit = UnitTokenForIndex(i)
      if UnitName(unit) == name then
        SetRaidTarget(unit, index)
        return
      end
    end
    -- as last resort try player's target
    if UnitName("target") == name then
      SetRaidTarget("target", index)
    end
  end
end

local function MarkGroup()
  if not AutoMarkDB or not AutoMarkDB.enabled then return end
  if not IsInGroup() then return end
  -- Loop members and mark according to role
  local n = GetNumGroupMembers()
  if n==0 and not IsInGroup() then return end
  -- include player in iteration
  for i=1, math.max(1,n) do
    local unit
    if IsInRaid() then
      unit = "raid"..i
    else
      if i==n then unit = "player" else unit = "party"..i end
    end
    if UnitExists(unit) then
      local role = UnitGroupRolesAssigned(unit) or "DAMAGER"
      local name = UnitName(unit)
      local marker = AutoMarkDB.roleMarkers[role] or AutoMarkDB.roleMarkers["DAMAGER"]
      if name and marker and marker>0 then
        MarkUnitByName(name, marker, AutoMarkDB.useCommand)
      end
    end
  end
end

-- Event handling
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
  if event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
    -- If enabled and in instance then mark
    if AutoMarkDB and AutoMarkDB.enabled and IsInGroup() then
      -- Optionally only in instances:
      if IsInInstance() then
        C_Timer.After(1, MarkGroup)
      else
        -- also allow marking outside instances if enabled
        C_Timer.After(1, MarkGroup)
      end
    end
  end
end)

-- Slash command to open the config
SLASH_AUTOMARK1 = "/mak"
SlashCmdList["AUTOMARK"] = function(msg)
  if not AM.UI then AM:CreateUI() end
  if AM.UI:IsShown() then AM.UI:Hide() else AM.UI:Show() end
end

-- One-click mark command
SLASH_AUTOMARKONE1 = "/amark"
SlashCmdList["AUTOMARKONE"] = function(msg)
  MarkGroup()
end

-- UI
function AM:CreateUI()
  local ui = CreateFrame("Frame", "AutoMarkUI", UIParent, "BasicFrameTemplateWithInset")
  ui:SetSize(300,200)
  ui:SetPoint("CENTER")
  ui:SetMovable(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)

  ui.title = ui:CreateFontString(nil, "OVERLAY")
  ui.title:SetFontObject("GameFontHighlight")
  ui.title:SetPoint("LEFT", ui.TitleBg, "LEFT", 5, 0)
  ui.title:SetText("AutoMark Settings")

  -- Auto enable checkbox
  ui.chkAuto = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
  ui.chkAuto:SetPoint("TOPLEFT", 16, -40)
  ui.chkAuto.text:SetText("Enable Auto Mark")
  ui.chkAuto:SetChecked(AutoMarkDB.enabled)
  ui.chkAuto:SetScript("OnClick", function(self)
    AutoMarkDB.enabled = self:GetChecked()
  end)

  -- Use /tm command checkbox
  ui.chkCmd = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
  ui.chkCmd:SetPoint("TOPLEFT", 16, -70)
  ui.chkCmd.text:SetText("Use /tm command (fallback to API)")
  ui.chkCmd:SetChecked(AutoMarkDB.useCommand)
  ui.chkCmd:SetScript("OnClick", function(self)
    AutoMarkDB.useCommand = self:GetChecked()
  end)

  -- One-click button
  ui.btnMark = CreateFrame("Button", nil, ui, "GameMenuButtonTemplate")
  ui.btnMark:SetPoint("BOTTOMLEFT", 16, 16)
  ui.btnMark:SetSize(120,24)
  ui.btnMark:SetText("One-Click Mark")
  ui.btnMark:SetScript("OnClick", function()
    MarkGroup()
  end)

  -- Dropdowns for roles
  local function CreateRoleDropdown(parent, label, x, y, roleKey)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(label)

    local dd = CreateFrame("Frame", "AutoMarkDD_"..roleKey, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x+120, y+6)
    UIDropDownMenu_SetWidth(dd, 120)

    local function OnClick(self)
      AutoMarkDB.roleMarkers[roleKey] = self.value
      UIDropDownMenu_SetText(dd, self:GetText())
    end

    local function Initialize(self, level)
      local info = UIDropDownMenu_CreateInfo()
      for i=1,8 do
        info.text = string.format("%d - %s", i, iconNames[i])
        info.value = i
        info.func = OnClick
        info.checked = (AutoMarkDB.roleMarkers[roleKey]==i)
        UIDropDownMenu_AddButton(info)
      end
    end
    UIDropDownMenu_Initialize(dd, Initialize)
    UIDropDownMenu_SetSelectedValue(dd, AutoMarkDB.roleMarkers[roleKey])
    UIDropDownMenu_SetText(dd, string.format("%d - %s", AutoMarkDB.roleMarkers[roleKey], iconNames[AutoMarkDB.roleMarkers[roleKey]]))
    return dd
  end

  ui.ddTank = CreateRoleDropdown(ui, "Tank:", 16, -100, "TANK")
  ui.ddHealer = CreateRoleDropdown(ui, "Healer:", 16, -130, "HEALER")
  ui.ddDPS = CreateRoleDropdown(ui, "Damager:", 16, -160, "DAMAGER")

  ui:Hide()
  AM.UI = ui
end

-- Initialize saved vars
local function OnInitialize()
  AutoMarkDB = AutoMarkDB or {}
  LoadDefaults(AutoMarkDB)
  -- Create UI ready to show when slash used
  AM:CreateUI()
end

OnInitialize()

-- Expose MarkGroup for manual use
AM.MarkGroup = MarkGroup

print("AutoMark loaded. Use /mak to open settings, /amark to run one-click mark.")
