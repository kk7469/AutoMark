-- AutoMark.lua
-- 魔兽世界 12.x 插件：根据队伍职责自动标记成员（界面与注释均为中文）

local addonName = "AutoMark"
local AM = {}
_G[addonName] = AM

-- 默认设置（SavedVariables: AutoMarkDB）
local defaults = {
  enabled = true,               -- 是否启用自动标记
  useCommand = true,            -- 是否优先使用 /tm 命令（若不可用回退到 SetRaidTarget）
  roleMarkers = {
    TANK = 2,   -- 坦克 -> 圆形
    HEALER = 5, -- 治疗 -> 月亮
  }
}

-- 标记名称（用于下拉菜单显示）
local iconNames = {
  [1] = "星星",
  [2] = "圆形",
  [3] = "钻石",
  [4] = "三角",
  [5] = "月亮",
  [6] = "方块",
  [7] = "十字",
  [8] = "骷髅",
}

-- 加载默认配置（若保存变量缺失则填充）
local function LoadDefaults(db)
  if db.enabled==nil then db.enabled = defaults.enabled end
  if db.useCommand==nil then db.useCommand = defaults.useCommand end
  db.roleMarkers = db.roleMarkers or {}
  for k,v in pairs(defaults.roleMarkers) do
    if db.roleMarkers[k]==nil then db.roleMarkers[k]=v end
  end
end

-- 通过 unit token 列表安全遍历当前队伍/团队成员
local function IterateGroupUnits(callback)
  if IsInRaid() then
    local n = GetNumGroupMembers()
    for i=1, n do
      local unit = "raid"..i
      if UnitExists(unit) then
        callback(unit)
      end
    end
  elseif IsInGroup() then
    -- 队伍中：party1..party4（若存在）和 player
    for i=1, 4 do
      local unit = "party"..i
      if UnitExists(unit) then
        callback(unit)
      end
    end
    -- 包括玩家自己
    if UnitExists("player") then
      callback("player")
    end
  end
end

-- 通过 unit 给玩家标记：优先尝试 /tm 命令（使用玩家名），失败则使用 SetRaidTarget
local function MarkUnit(unit, index, useCommand)
  if not unit or not UnitExists(unit) or index==0 then return end
  local name = UnitName(unit)
  if not name then return end
  local succeeded = false
  if useCommand then
    local cmd = string.format("/tm %s %d", name, index)
    local ok = pcall(RunMacroText, cmd)
    if ok then succeeded = true end
  end
  if not succeeded then
    -- 直接使用 API 标记 unit
    SetRaidTarget(unit, index)
  end
end

-- 对整个队伍进行职责标记（仅标记坦克和治疗）
local function MarkGroup()
  if not AutoMarkDB or not AutoMarkDB.enabled then return end
  if not IsInGroup() then return end

  IterateGroupUnits(function(unit)
    local role = UnitGroupRolesAssigned(unit)
    -- 仅在明确为 TANK 或 HEALER 时标记，忽略输出
    if role == "TANK" or role == "HEALER" then
      local marker = AutoMarkDB.roleMarkers[role]
      if marker and marker > 0 then
        MarkUnit(unit, marker, AutoMarkDB.useCommand)
      end
    end
  end)
end

-- 事件处理：监听队伍变更/进入世界/区域变化，触发延迟标记
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:SetScript("OnEvent", function(self, event, ...)
  if event=="GROUP_ROSTER_UPDATE" or event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" then
    if AutoMarkDB and AutoMarkDB.enabled and IsInGroup() then
      -- 不再限制副本内与否，只要组队就自动标记
      C_Timer.After(1, MarkGroup)
    end
  end
end)

-- Slash 命令：/mak 打开设置界面
SLASH_AUTOMARK1 = "/mak"
SlashCmdList["AUTOMARK"] = function(msg)
  if not AM.UI then AM:CreateUI() end
  if AM.UI:IsShown() then AM.UI:Hide() else AM.UI:Show() end
end

-- 一键标记命令：/amark
SLASH_AUTOMARKONE1 = "/amark"
SlashCmdList["AUTOMARKONE"] = function(msg)
  MarkGroup()
end

-- 创建设置界面（中文界面文本），已移除输出（DPS）下拉
function AM:CreateUI()
  local ui = CreateFrame("Frame", "AutoMarkUI", UIParent, "BasicFrameTemplateWithInset")
  ui:SetSize(320,180)
  ui:SetPoint("CENTER")
  ui:SetMovable(true)
  ui:EnableMouse(true)
  ui:RegisterForDrag("LeftButton")
  ui:SetScript("OnDragStart", ui.StartMoving)
  ui:SetScript("OnDragStop", ui.StopMovingOrSizing)

  ui.title = ui:CreateFontString(nil, "OVERLAY")
  ui.title:SetFontObject("GameFontHighlight")
  ui.title:SetPoint("LEFT", ui.TitleBg, "LEFT", 5, 0)
  ui.title:SetText("AutoMark 设置")

  -- 启用自动标记复选框
  ui.chkAuto = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
  ui.chkAuto:SetPoint("TOPLEFT", 16, -40)
  ui.chkAuto.text:SetText("启用自动标记")
  ui.chkAuto:SetChecked(AutoMarkDB.enabled)
  ui.chkAuto:SetScript("OnClick", function(self)
    AutoMarkDB.enabled = self:GetChecked()
    if AutoMarkDB.enabled and IsInGroup() then
      -- 立即标记一次
      C_Timer.After(0.5, MarkGroup)
    end
  end)

  -- 使用 /tm 命令复选框
  ui.chkCmd = CreateFrame("CheckButton", nil, ui, "UICheckButtonTemplate")
  ui.chkCmd:SetPoint("TOPLEFT", 16, -70)
  ui.chkCmd.text:SetText("优先使用 /tm 命令（不可用时回退到 API）")
  ui.chkCmd:SetChecked(AutoMarkDB.useCommand)
  ui.chkCmd:SetScript("OnClick", function(self)
    AutoMarkDB.useCommand = self:GetChecked()
  end)

  -- 一键标记按钮
  ui.btnMark = CreateFrame("Button", nil, ui, "GameMenuButtonTemplate")
  ui.btnMark:SetPoint("BOTTOMLEFT", 16, 16)
  ui.btnMark:SetSize(120,24)
  ui.btnMark:SetText("一键标记")
  ui.btnMark:SetScript("OnClick", function()
    MarkGroup()
  end)

  -- 为坦克和治疗创建下拉菜单（用于选择标记编号）
  local function CreateRoleDropdown(parent, label, x, y, roleKey)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", x, y)
    lbl:SetText(label)

    local dd = CreateFrame("Frame", "AutoMarkDD_"..roleKey, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x+120, y+6)
    UIDropDownMenu_SetWidth(dd, 140)

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

  ui.ddTank = CreateRoleDropdown(ui, "坦克：", 16, -100, "TANK")
  ui.ddHealer = CreateRoleDropdown(ui, "治疗：", 16, -130, "HEALER")

  ui:Hide()
  AM.UI = ui
end

-- 初始化保存变量并创建 UI
local function OnInitialize()
  AutoMarkDB = AutoMarkDB or {}
  LoadDefaults(AutoMarkDB)
  AM:CreateUI()
end

OnInitialize()

-- 暴露 MarkGroup 以便手动调用
AM.MarkGroup = MarkGroup

print("AutoMark 已加载。输入 /mak 打开设置，/amark 执行一键标记。")
