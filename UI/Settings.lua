-- AutoMark 设置界面

local ADDON_NAME = "AutoMark"
local AutoMark = _G[ADDON_NAME]

local MARK_NAMES = AutoMark.MARK_NAMES

-- 创建设置窗口
local function CreateSettingsUI()
    if AutoMarkSettings then
        return
    end
    
    local frame = CreateFrame("Frame", "AutoMarkSettings", UIParent, "BackdropTemplate")
    frame:SetSize(400, 500)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 }
    })
    frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetUserPlaced(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    
    -- 标题
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -15)
    title:SetText("|cff00ff00AutoMark 设置|r")
    
    -- 关闭按钮
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    
    -- 启用插件复选框
    local enableCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -50)
    enableCheckbox:SetSize(20, 20)
    local enableLabel = enableCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enableLabel:SetPoint("LEFT", enableCheckbox, "RIGHT", 5, 0)
    enableLabel:SetText("启用插件")
    
    enableCheckbox:SetScript("OnClick", function(self)
        AutoMarkDB.enabled = self:GetChecked()
        print(string.format("|cff00ff00[AutoMark] 插件已%s|r", AutoMarkDB.enabled and "启用" or "禁用"))
    end)
    
    -- 自动标记复选框
    local autoCheckbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoCheckbox:SetPoint("TOPLEFT", enableCheckbox, "BOTTOMLEFT", 0, -10)
    autoCheckbox:SetSize(20, 20)
    local autoLabel = autoCheckbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoLabel:SetPoint("LEFT", autoCheckbox, "RIGHT", 5, 0)
    autoLabel:SetText("启用自动标记")
    
    autoCheckbox:SetScript("OnClick", function(self)
        AutoMarkDB.autoMark = self:GetChecked()
        print(string.format("|cff00ff00[AutoMark] 自动标记已%s|r", AutoMarkDB.autoMark and "启用" or "禁用"))
    end)
    
    -- 标记设置区域
    local settingsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsLabel:SetPoint("TOPLEFT", autoCheckbox, "BOTTOMLEFT", 0, -30)
    settingsLabel:SetText("|cff00ff00标记配置|r")
    
    -- 坦克标记选择
    local tankLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tankLabel:SetPoint("TOPLEFT", settingsLabel, "BOTTOMLEFT", 0, -20)
    tankLabel:SetText("|cffff9900坦克标记:|r")
    
    local tankDropdown = CreateFrame("Frame", "AutoMarkTankDropdown", frame, "UIDropDownMenuTemplate")
    tankDropdown:SetPoint("LEFT", tankLabel, "RIGHT", 10, 0)
    UIDropDownMenu_SetWidth(tankDropdown, 120)
    
    local function SetupTankDropdown()
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, 8 do
            info.text = MARK_NAMES[i]
            info.value = i
            info.func = function(button)
                AutoMarkDB.marks.TANK = button.value
                UIDropDownMenu_SetSelectedValue(tankDropdown, button.value)
                print(string.format("|cff00ff00[AutoMark] 坦克标记已设置为: %s|r", MARK_NAMES[button.value]))
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(tankDropdown, SetupTankDropdown)
    UIDropDownMenu_SetSelectedValue(tankDropdown, AutoMarkDB.marks.TANK)
    
    -- 治疗标记选择
    local healerLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    healerLabel:SetPoint("TOPLEFT", tankLabel, "BOTTOMLEFT", 0, -30)
    healerLabel:SetText("|cff00ff00治疗标记:|r")
    
    local healerDropdown = CreateFrame("Frame", "AutoMarkHealerDropdown", frame, "UIDropDownMenuTemplate")
    healerDropdown:SetPoint("LEFT", healerLabel, "RIGHT", 10, 0)
    UIDropDownMenu_SetWidth(healerDropdown, 120)
    
    local function SetupHealerDropdown()
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, 8 do
            info.text = MARK_NAMES[i]
            info.value = i
            info.func = function(button)
                AutoMarkDB.marks.HEALER = button.value
                UIDropDownMenu_SetSelectedValue(healerDropdown, button.value)
                print(string.format("|cff00ff00[AutoMark] 治疗标记已设置为: %s|r", MARK_NAMES[button.value]))
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(healerDropdown, SetupHealerDropdown)
    UIDropDownMenu_SetSelectedValue(healerDropdown, AutoMarkDB.marks.HEALER)
    
    -- DPS标记选择
    local dpsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dpsLabel:SetPoint("TOPLEFT", healerLabel, "BOTTOMLEFT", 0, -30)
    dpsLabel:SetText("|cfffe0000DPS标记:|r")
    
    local dpsDropdown = CreateFrame("Frame", "AutoMarkDPSDropdown", frame, "UIDropDownMenuTemplate")
    dpsDropdown:SetPoint("LEFT", dpsLabel, "RIGHT", 10, 0)
    UIDropDownMenu_SetWidth(dpsDropdown, 120)
    
    local function SetupDPSDropdown()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "无标记"
        info.value = 0
        info.func = function(button)
            AutoMarkDB.marks.DAMAGER = button.value
            UIDropDownMenu_SetSelectedValue(dpsDropdown, button.value)
            print("[AutoMark] DPS标记已设置为: 无标记")
        end
        UIDropDownMenu_AddButton(info)
        
        for i = 1, 8 do
            info.text = MARK_NAMES[i]
            info.value = i
            info.func = function(button)
                AutoMarkDB.marks.DAMAGER = button.value
                UIDropDownMenu_SetSelectedValue(dpsDropdown, button.value)
                print(string.format("|cff00ff00[AutoMark] DPS标记已设置为: %s|r", MARK_NAMES[button.value]))
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    
    UIDropDownMenu_Initialize(dpsDropdown, SetupDPSDropdown)
    UIDropDownMenu_SetSelectedValue(dpsDropdown, AutoMarkDB.marks.DAMAGER)
    
    -- 按钮区域
    local quickMarkBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    quickMarkBtn:SetPoint("TOPLEFT", dpsLabel, "BOTTOMLEFT", 0, -40)
    quickMarkBtn:SetSize(120, 25)
    quickMarkBtn:SetText("|cff00ff00一键标记|r")
    quickMarkBtn:SetScript("OnClick", function()
        AutoMark.QuickMarkGroup()
    end)
    
    local clearMarkBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    clearMarkBtn:SetPoint("LEFT", quickMarkBtn, "RIGHT", 10, 0)
    clearMarkBtn:SetSize(120, 25)
    clearMarkBtn:SetText("|cfffe0000清除标记|r")
    clearMarkBtn:SetScript("OnClick", function()
        AutoMark.ClearAllMarks()
    end)
    
    local autoMarkBtn = CreateFrame("Button", nil, frame, "GameMenuButtonTemplate")
    autoMarkBtn:SetPoint("TOPLEFT", quickMarkBtn, "BOTTOMLEFT", 0, -10)
    autoMarkBtn:SetSize(250, 25)
    autoMarkBtn:SetText("|cff00ff00立即自动标记队伍|r")
    autoMarkBtn:SetScript("OnClick", function()
        AutoMark.AutoMarkGroup()
    end)
    
    -- 更新复选框状态
    local function UpdateCheckboxes()
        enableCheckbox:SetChecked(AutoMarkDB.enabled)
        autoCheckbox:SetChecked(AutoMarkDB.autoMark)
    end
    
    frame:SetScript("OnShow", UpdateCheckboxes)
    -- 隐藏设置界面（不在加载时自动打开）
    frame:Hide()
    
    _G["AutoMarkSettings"] = frame
    return frame
end

-- 在插件加载时创建UI（但不显示）
C_Timer.After(0.5, CreateSettingsUI)
