-- AutoMark - 自动标记队友插件
-- 版本: 1.1.0
-- 支持版本: WoW 12.0.5

local ADDON_NAME = "AutoMark"
local AutoMark = {}
_G[ADDON_NAME] = AutoMark

-- 默认配置
local DEFAULT_CONFIG = {
    enabled = true,  -- 默认启用
    autoMark = true,
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

-- 获取队友专精（坦克/治疗/DPS）
local function GetUnitSpec(unitId)
    if not UnitExists(unitId) then
        return nil
    end
    
    -- 优先使用 UnitGroupRolesAssigned 获取职责
    local role = UnitGroupRolesAssigned(unitId)
    if role and role ~= "NONE" then
        return role
    end
    
    -- 如果职责为空，尝试通过获取玩家职业和专精来判断
    local class = select(2, UnitClass(unitId))
    
    if class == "DEATHKNIGHT" or class == "DEMON_HUNTER" or class == "DRUID" or class == "MONK" or class == "PALADIN" or class == "WARRIOR" then
        -- 这些职业可能是坦克
        local spec = GetInspectSpecialization(unitId)
        if spec then
            local _, _, _, _, role = GetSpecializationInfo(spec)
            if role then
                return role
            end
        end
        
        -- 如果获取不到，检查是否穿着重甲（可能是坦克）
        local armorCategory = select(5, GetItemInfo(GetInventoryItemLink(unitId, 3)))
        if armorCategory == "Plate" then
            return "TANK"
        end
    end
    
    return "DAMAGER"
end

-- 标记队友
local function MarkUnit(unitId, markId)
    if markId == 0 or not markId then
        return  -- 无标记
    end
    
    -- 设置新标记
    if markId >= 1 and markId <= 8 then
        SetRaidTarget(unitId, markId)
    end
end

-- 标记当前目标
local function MarkTarget(markId)
    if not UnitExists("target") then
        print("|cfffe0000[AutoMark] 请先选中一个目标|r")
        return
    end
    
    if markId == 0 then
        SetRaidTarget("target", 0)
        print("|cff00ff00[AutoMark] 已清除目标标记|r")
    elseif markId >= 1 and markId <= 8 then
        SetRaidTarget("target", markId)
        print(string.format("|cff00ff00[AutoMark] 已标记目标为: %s|r", MARK_NAMES[markId]))
    end
end

-- 自动标记队伍
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
    local isRaid = IsInRaid()
    local prefix = isRaid and "raid" or "party"
    
    -- 包括自己
    for i = 0, groupSize do
        local unitId
        if i == 0 then
            unitId = "player"
        else
            unitId = prefix .. i
        end
        
        if UnitExists(unitId) then
            local spec = GetUnitSpec(unitId)
            if spec then
                local markId = AutoMarkDB.marks[spec] or 0
                
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
    
    -- 包括自己
    for i = 0, groupSize do
        local unitId
        if i == 0 then
            unitId = "player"
        else
            unitId = prefix .. i
        end
        
        if UnitExists(unitId) then
            local spec = GetUnitSpec(unitId)
            if spec then
                local markId = AutoMarkDB.marks[spec] or 0
                
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
    
    -- 包括自己
    for i = 0, groupSize do
        local unitId
        if i == 0 then
            unitId = "player"
        else
            unitId = prefix .. i
        end
        
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

-- /tm 命令处理器
local function TMSlashCommand(msg)
    local markId = tonumber(msg) or 1  -- 默认为 1（黄色圆形）
    
    if markId < 0 or markId > 8 then
        print("|cfffe0000[AutoMark] 标记ID必须在 0-8 之间|r")
        print("|cff00ff00标记列表:|r")
        for i = 0, 8 do
            print(string.format("|cffff9900%d: %s|r", i, MARK_NAMES[i]))
        end
        return
    end
    
    MarkTarget(markId)
end

-- 注册斜杠命令
SLASH_AUTOMARK1 = "/mak"
SLASH_AUTOMARK2 = "/automark"
SlashCmdList["AUTOMARK"] = SlashCommand

SLASH_AUTOMARK_TM1 = "/tm"
SlashCmdList["AUTOMARK_TM"] = TMSlashCommand

-- 事件处理
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("GROUP_JOINED")
EventFrame:RegisterEvent("GROUP_LEFT")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")

local markTimer = 0

local function OnUpdate(self, elapsed)
    markTimer = markTimer + elapsed
    
    -- 每1.5秒检查一次
    if markTimer >= 1.5 then
        if AutoMarkDB.enabled and AutoMarkDB.autoMark and IsInGroup() then
            AutoMarkGroup()
        end
        markTimer = 0
    end
end

EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "GROUP_JOINED" then
        -- 进入队伍时立即标记
        lastMarkedCount = 0
        print("|cff00ff00[AutoMark] 已进入队伍|r")
        C_Timer.After(0.5, AutoMarkGroup)
    elseif event == "GROUP_LEFT" then
        -- 离开队伍
        lastMarkedCount = 0
        print("|cff00ff00[AutoMark] 已离开队伍|r")
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- 进入新��域时重置标记状态
        lastMarkedCount = 0
        if IsInGroup() and AutoMarkDB.enabled and AutoMarkDB.autoMark then
            C_Timer.After(0.5, AutoMarkGroup)
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        -- 队伍成员变化时重新标记（如有人加入或离开）
        if IsInGroup() and AutoMarkDB.enabled and AutoMarkDB.autoMark then
            C_Timer.After(0.3, AutoMarkGroup)
        end
    end
end)

EventFrame:SetScript("OnUpdate", OnUpdate)

-- 插件初始化
local function Initialize()
    InitDB()
    print("|cff00ff00[AutoMark] 插件已加载 v1.1.0|r")
    print("|cffff9900使用 /mak 打开设置界面|r")
    print("|cffff9900使用 /tm [0-8] 标记当前目标|r")
    print(string.format("|cffff9900当前状态: %s|r", AutoMarkDB.enabled and "已启用" or "已禁用"))
end

-- 延迟初始化（确保插件完全加载）
C_Timer.After(0.1, Initialize)

-- 导出函数供UI使用
AutoMark.MarkUnit = MarkUnit
AutoMark.MarkTarget = MarkTarget
AutoMark.AutoMarkGroup = AutoMarkGroup
AutoMark.QuickMarkGroup = QuickMarkGroup
AutoMark.ClearAllMarks = ClearAllMarks
AutoMark.GetConfig = function() return AutoMarkDB end
AutoMark.UpdateConfig = function(config) AutoMarkDB = config end
AutoMark.MARK_NAMES = MARK_NAMES
