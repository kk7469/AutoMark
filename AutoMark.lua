-- AutoMark - 自动标记队友插件
-- 版本: 1.0.1
-- 支持版本: WoW 12.0.5

local ADDON_NAME = "AutoMark"
local AutoMark = {}
_G[ADDON_NAME] = AutoMark

-- 默认配置
local DEFAULT_CONFIG = {
    enabled = false,
    autoMark = true,
    quickMarkKey = "M",
    marks = {
        TANK = 1,        -- 1 = 黄色圆形 (YELLOW)
        HEALER = 2,      -- 2 = 月亮 (CIRCLE)
        DAMAGER = 0,     -- 0 = 无标记
    }
}

-- 标记映射表
local MARK_NAMES = {
    [0] = "无标记",
    [1] = "黄色圆形",
    [2] = "月亮",
    [3] = "绿色方块",
    [4] = "紫色星形",
    [5] = "白色十字",
    [6] = "红色X",
    [7] = "蓝色三角形",
    [8] = "褐色五角星",
}

-- 标记宏命令
local MARK_COMMANDS = {
    [1] = "/tm",      -- 黄色圆形
    [2] = "/tm1",     -- 月亮
    [3] = "/tm2",     -- 绿色方块
    [4] = "/tm3",     -- 紫色星形
    [5] = "/tm4",     -- 白色十字
    [6] = "/tm5",     -- 红色X
    [7] = "/tm6",     -- 蓝色三角形
    [8] = "/tm7",     -- 褐色五角星
}

-- 初始化数据库
local function InitDB()
    if not AutoMarkDB then
        AutoMarkDB = {}
    end
    
    for key, value in pairs(DEFAULT_CONFIG) do
        if AutoMarkDB[key] == nil then
            AutoMarkDB[key] = value
        end
    end
    
    -- 合并标记配置
    if not AutoMarkDB.marks then
        AutoMarkDB.marks = {}
    end
    for key, value in pairs(DEFAULT_CONFIG.marks) do
        if AutoMarkDB.marks[key] == nil then
            AutoMarkDB.marks[key] = value
        end
    end
end

-- 获取队友职责
local function GetGroupMemberRole(unitId)
    local role = UnitGroupRolesAssigned(unitId)
    return role
end

-- 标记队友
local function MarkUnit(unit, markId)
    if markId == 0 then
        return  -- 无标记
    end
    
    -- 设置新标记
    if markId >= 1 and markId <= 8 then
        SetRaidTarget(unit, markId)
    end
end

-- 自动标记队伍（只在首次标记时提示）
local lastMarkedCount = 0
local function AutoMarkGroup()
    if not AutoMarkDB.enabled or not AutoMarkDB.autoMark then
        return
    end
    
    local groupSize = GetNumGroupMembers()
    if groupSize == 0 then
        lastMarkedCount = 0
        return
    end
    
    local marked = false
    
    -- 检查是否在副本中
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    
    for i = 1, groupSize do
        local unitId = prefix .. i
        if UnitExists(unitId) then
            local role = GetGroupMemberRole(unitId)
            if role then  -- 确保角色不为空
                local markId = AutoMarkDB.marks[role] or 0
                
                if markId > 0 then
                    MarkUnit(unitId, markId)
                    marked = true
                end
            end
        end
    end
    
    -- 只在首次标记时提示
    if marked and groupSize ~= lastMarkedCount then
        print("|cff00ff00[AutoMark] 自动标记完成|r")
        lastMarkedCount = groupSize
    end
end

-- 一键标记队伍
local function QuickMarkGroup()
    local groupSize = GetNumGroupMembers()
    if groupSize == 0 then
        print("|cfffe0000[AutoMark] 未进入队伍|r")
        return
    end
    
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    
    for i = 1, groupSize do
        local unitId = prefix .. i
        if UnitExists(unitId) then
            local role = GetGroupMemberRole(unitId)
            if role then  -- 确保角色不为空
                local markId = AutoMarkDB.marks[role] or 0
                
                if markId > 0 then
                    MarkUnit(unitId, markId)
                end
            end
        end
    end
    
    print("|cff00ff00[AutoMark] 一键标记完成|r")
end

-- 清除所有标记
local function ClearAllMarks()
    local groupSize = GetNumGroupMembers()
    if groupSize == 0 then
        return
    end
    
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    
    for i = 1, groupSize do
        local unitId = prefix .. i
        if UnitExists(unitId) then
            SetRaidTarget(unitId, 0)
        end
    end
    
    print("|cff00ff00[AutoMark] 已清除所有标记|r")
    lastMarkedCount = 0
end

-- 打印当前配置
local function PrintConfig()
    print("|cff00ff00=== AutoMark 配置 ===|r")
    print(string.format("|cff00ff00启用状态: %s|r", AutoMarkDB.enabled and "启用" or "禁用"))
    print(string.format("|cff00ff00自动标记: %s|r", AutoMarkDB.autoMark and "启用" or "禁用"))
    print("|cff00ff00标记配置:|r")
    print(string.format("|cffff9900坦克: %s|r", MARK_NAMES[AutoMarkDB.marks.TANK]))
    print(string.format("|cff00ff00治疗: %s|r", MARK_NAMES[AutoMarkDB.marks.HEALER]))
    print(string.format("|cffff0000DPS: %s|r", MARK_NAMES[AutoMarkDB.marks.DAMAGER]))
    print("|cff00ff00使用 /mak 打开设置界面|r")
end

-- 斜杠命令处理
local function SlashCommand(msg)
    local cmd, args = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()
    
    if cmd == "" or cmd == "set" or cmd == "设置" then
        if AutoMarkSettings then
            AutoMarkSettings:Show()
        else
            print("|cfffe0000[AutoMark] 设置界面还未加载，请稍后...|r")
        end
    elseif cmd == "auto" then
        AutoMarkDB.autoMark = not AutoMarkDB.autoMark
        print(string.format("|cff00ff00[AutoMark] 自动标记已%s|r", AutoMarkDB.autoMark and "启用" or "禁用"))
    elseif cmd == "quick" then
        QuickMarkGroup()
    elseif cmd == "clear" then
        ClearAllMarks()
    elseif cmd == "enable" then
        AutoMarkDB.enabled = true
        print("|cff00ff00[AutoMark] 插件已启用|r")
    elseif cmd == "disable" then
        AutoMarkDB.enabled = false
        print("|cff00ff00[AutoMark] 插件已禁用|r")
    elseif cmd == "config" or cmd == "配置" then
        PrintConfig()
    else
        PrintConfig()
        print("\n|cff00ff00可用命令:|r")
        print("|cffff9900/mak set - 打开设置界面|r")
        print("|cffff9900/mak auto - 切换自动标记|r")
        print("|cffff9900/mak quick - 一键标记|r")
        print("|cffff9900/mak clear - 清除所有标记|r")
        print("|cffff9900/mak config - 显示配置|r")
    end
end

-- 注册斜杠命令
SLASH_AUTOMARK1 = "/mak"
SLASH_AUTOMARK2 = "/automark"
SlashCmdList["AUTOMARK"] = SlashCommand

-- 事件处理
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("GROUP_JOINED")
EventFrame:RegisterEvent("ENCOUNTER_START")
EventFrame:RegisterEvent("UNIT_FACTION")
EventFrame:RegisterEvent("PARTY_MEMBER_ENABLE")
EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- 控制标记的时机
local inCombat = false
local hasMarked = false
local checkTimer = 0

local function OnUpdate(self, elapsed)
    checkTimer = checkTimer + elapsed
    
    -- 每1秒检查一次
    if checkTimer >= 1 then
        if AutoMarkDB.enabled and AutoMarkDB.autoMark and IsInGroup() then
            -- 在副本中自动标记
            if IsInRaid() and not inCombat then
                AutoMarkGroup()
            end
        end
        checkTimer = 0
    end
end

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_START" then
        inCombat = true
        hasMarked = false
    elseif event == "ENCOUNTER_END" then
        inCombat = false
    elseif event == "GROUP_JOINED" or event == "ZONE_CHANGED_NEW_AREA" then
        -- 进入新区域或加入队伍时重置标记状态
        lastMarkedCount = 0
        hasMarked = false
        if AutoMarkDB.enabled and AutoMarkDB.autoMark and IsInGroup() then
            -- 延迟标记，确保职责信息已更新
            C_Timer.After(0.5, AutoMarkGroup)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- 队伍成员变化时重新标记
        if AutoMarkDB.enabled and AutoMarkDB.autoMark and IsInGroup() and not inCombat then
            checkTimer = 1  -- 立即检查
        end
    end
end)

EventFrame:SetScript("OnUpdate", OnUpdate)

-- 插件���始化
local function Initialize()
    InitDB()
    print("|cff00ff00[AutoMark] 插件已加载 v1.0.1|r")
    print("|cffff9900使用 /mak 打开设置界面|r")
end

-- 延迟初始化（确保插件完全加载）
C_Timer.After(0.1, Initialize)

-- 导出函数供UI使用
AutoMark.MarkUnit = MarkUnit
AutoMark.AutoMarkGroup = AutoMarkGroup
AutoMark.QuickMarkGroup = QuickMarkGroup
AutoMark.ClearAllMarks = ClearAllMarks
AutoMark.GetConfig = function() return AutoMarkDB end
AutoMark.UpdateConfig = function(config) AutoMarkDB = config end
AutoMark.MARK_NAMES = MARK_NAMES
