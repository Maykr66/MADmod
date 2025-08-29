MAD.Log = MAD.Log or {}

local currentLogFile = nil

-- Log level priorities (higher number = higher priority)
local logLevels = {
    ["error"] = 4,
    ["warning"] = 3,
    ["success"] = 2,
    ["info"] = 1
}

function MAD.Log.Initialize()
    MAD.Log.Info("Logging system initialized")
end

local function GetLogFileName()
    return "madmod/Logs/" .. MAD.Utils.GetDateString() .. "_log.txt"
end

local function WriteToFile(message)
    local config = MAD.Data.GetConfig()
    if not config.enable_file_logging then return end
    
    local logFile = GetLogFileName()
    if currentLogFile ~= logFile then
        currentLogFile = logFile
    end
    
    local timestamp = "[" .. MAD.Utils.GetTimeString() .. "] "
    local content = MAD.Utils.FileExists(logFile) and MAD.Utils.ReadFile(logFile) or ""
    content = content .. timestamp .. message .. "\n"
    MAD.Utils.WriteFile(logFile, content)
end

local function ShouldShowInConsole(messageLevel)
    local config = MAD.Data.GetConfig()
    if not config.enable_console_logging then return false end
    
    local consoleLevel = config.console_log_level or "info"
    local consoleLevelPriority = logLevels[string.lower(consoleLevel)] or logLevels["info"]
    local messageLevelPriority = logLevels[string.lower(messageLevel)] or logLevels["info"]
    
    return messageLevelPriority >= consoleLevelPriority
end

local function WriteToConsole(message, color, level)
    if ShouldShowInConsole(level) then
        MsgC(MAD.Utils.Colors.PRIMARY, "[MAD] ", color or MAD.Utils.Colors.INFO, message .. "\n")
    end
end

function MAD.Log.Info(message)
    WriteToConsole(message, MAD.Utils.Colors.INFO, "info")
    if SERVER then WriteToFile("INFO: " .. message) end
end

function MAD.Log.Warning(message)
    WriteToConsole("WARNING: " .. message, MAD.Utils.Colors.WARNING, "warning")
    if SERVER then WriteToFile("WARNING: " .. message) end
end

function MAD.Log.Error(message)
    WriteToConsole("ERROR: " .. message, MAD.Utils.Colors.ERROR, "error")
    if SERVER then WriteToFile("ERROR: " .. message) end
end

function MAD.Log.Success(message)
    WriteToConsole(message, MAD.Utils.Colors.SUCCESS, "success")
    if SERVER then WriteToFile("SUCCESS: " .. message) end
end

function MAD.Log.Command(player, command, args)
    local config = MAD.Data.GetConfig()
    if not config.log_commands then return end
    
    local message = string.format("COMMAND: %s (%s) executed '%s %s'", 
        IsValid(player) and player:Nick() or "Console", 
        IsValid(player) and player:SteamID() or "SERVER", 
        command, 
        table.concat(args or {}, " "))
    WriteToConsole(message, MAD.Utils.Colors.INFO, "info")
    if SERVER then WriteToFile(message) end
end

function MAD.Log.Player(event, player, extra)
    local config = MAD.Data.GetConfig()
    local logKey = "log_player_" .. event
    if not config[logKey] then return end
    
    local message = string.format("PLAYER_%s: %s (%s)%s", 
        string.upper(event),
        IsValid(player) and player:Nick() or "Unknown", 
        IsValid(player) and player:SteamID() or "Unknown",
        extra and (" - " .. extra) or "")
    WriteToConsole(message, MAD.Utils.Colors.INFO, "info")
    if SERVER then WriteToFile(message) end
end