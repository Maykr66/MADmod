-- MADmod Enhanced Logging System
MAD.Log = MAD.Log or {}

-- Initialization state
MAD.Log.Initialized = false

-- Log levels
MAD.Log.LEVEL_DEBUG = 0
MAD.Log.LEVEL_INFO = 1
MAD.Log.LEVEL_WARNING = 2
MAD.Log.LEVEL_ERROR = 3
MAD.Log.LEVEL_CRITICAL = 4

-- Default configuration
MAD.Log.Config = {
    enabled = true,
    log_to_file = true,
    log_to_console = true,
    max_log_age = 7, -- days
    
    events = {
        player_join = false,
        player_spawn = false,
        player_death = false,
        player_disconnect = false,
        prop_spawn = false,
        prop_destroy = false,
        prop_delete = false,
        tool_use = false,
        player_kill = false,
        admin_actions = true
    },
    
    level_output = {
        [MAD.Log.LEVEL_DEBUG] = false,
        [MAD.Log.LEVEL_INFO] = true,
        [MAD.Log.LEVEL_WARNING] = true,
        [MAD.Log.LEVEL_ERROR] = true,
        [MAD.Log.LEVEL_CRITICAL] = true
    }
}

-- File handling
MAD.Log.FilePath = "madmod/logs/"
MAD.Log.FilePrefix = "mad_"
MAD.Log.FileExtension = ".log"
MAD.Log.CurrentFile = nil
MAD.Log.CurrentDate = nil

-- Initialize logging system
function MAD.Log.Initialize()
    -- Prevent double initialization
    if MAD.Log.Initialized then
        MAD.Log.Debug("Logging system already initialized, skipping...")
        return
    end
    
    if not file.Exists(MAD.Log.FilePath, "DATA") then
        file.CreateDir(MAD.Log.FilePath)
    end
    
    MAD.Log.PurgeOldLogs()
    MAD.Log.OpenCurrentLog()
    
    -- Mark as initialized
    MAD.Log.Initialized = true
    
    MAD.Log.RegisterCommands()
    MAD.Log.Info("Logging system initialized")
end

-- Purge old log files
function MAD.Log.PurgeOldLogs()
    local files = file.Find(MAD.Log.FilePath .. MAD.Log.FilePrefix .. "*" .. MAD.Log.FileExtension, "DATA")
    
    if not files or #files == 0 then
        MAD.Log.Debug("No log files found to purge")
        return
    end
    
    local cutoff_time = os.time() - (MAD.Log.Config.max_log_age * 24 * 60 * 60)
    local purged_count = 0
    
    for _, filename in ipairs(files) do
        local date_str = string.match(filename, "^" .. MAD.Log.FilePrefix .. "(%d%d%d%d%-%d%d%-%d%d)" .. MAD.Log.FileExtension .. "$")
        
        if date_str then
            local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
            if year and month and day then
                local file_time = os.time({
                    year = tonumber(year),
                    month = tonumber(month),
                    day = tonumber(day),
                    hour = 0,
                    min = 0,
                    sec = 0
                })
                
                if file_time < cutoff_time then
                    local full_path = MAD.Log.FilePath .. filename
                    if file.Delete(full_path) then
                        purged_count = purged_count + 1
                    else
                        MAD.Log.Warning("Failed to delete log file: " .. filename)
                    end
                end
            end
        end
    end
    
    if purged_count > 0 then
        MAD.Log.Info(string.format("Purged %d old log files", purged_count))
    end
end

-- Open current log file
function MAD.Log.OpenCurrentLog()
    local current_date = os.date("%Y-%m-%d")
    
    if MAD.Log.CurrentDate ~= current_date then
        if MAD.Log.CurrentFile then
            MAD.Log.CurrentFile:close()
            MAD.Log.CurrentFile = nil
        end
        
        MAD.Log.CurrentDate = current_date
        local filename = MAD.Log.FilePath .. MAD.Log.FilePrefix .. current_date .. MAD.Log.FileExtension
        MAD.Log.CurrentFile = file.Open(filename, "a", "DATA")
    end
end

-- Write log message
function MAD.Log.Write(level, message, event_type)
    if not MAD.Log.Config.enabled then return end
    if event_type and not MAD.Log.Config.events[event_type] then return end
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_name = "UNKNOWN"
    local level_color = Color(255, 255, 255)
    
    if level == MAD.Log.LEVEL_DEBUG then level_name = "DEBUG"; level_color = Color(150, 150, 150)
    elseif level == MAD.Log.LEVEL_INFO then level_name = "INFO"; level_color = Color(100, 200, 255)
    elseif level == MAD.Log.LEVEL_WARNING then level_name = "WARNING"; level_color = Color(255, 255, 100)
    elseif level == MAD.Log.LEVEL_ERROR then level_name = "ERROR"; level_color = Color(255, 150, 100)
    elseif level == MAD.Log.LEVEL_CRITICAL then level_name = "CRITICAL"; level_color = Color(255, 50, 50) end
    
    local formatted = string.format("[%s] [%s%s] %s", 
        timestamp, 
        level_name,
        event_type and ("/"..event_type:upper()) or "",
        message
    )
    
    if MAD.Log.Config.log_to_console and MAD.Log.Config.level_output[level] then
        MsgC(level_color, formatted .. "\n")
    end
    
    if MAD.Log.Config.log_to_file then
        MAD.Log.WriteToFile(formatted)
    end
end

-- Write to file
function MAD.Log.WriteToFile(message)
    if not MAD.Log.CurrentFile then
        MAD.Log.OpenCurrentLog()
        if not MAD.Log.CurrentFile then return end
    end
    
    local current_date = os.date("%Y-%m-%d")
    if MAD.Log.CurrentDate ~= current_date then
        MAD.Log.OpenCurrentLog()
    end
    
    MAD.Log.CurrentFile:Write(message .. "\n")
    MAD.Log.CurrentFile:Flush()
end

-- Convenience functions
function MAD.Log.Debug(message, event_type) MAD.Log.Write(MAD.Log.LEVEL_DEBUG, message, event_type) end
function MAD.Log.Info(message, event_type) MAD.Log.Write(MAD.Log.LEVEL_INFO, message, event_type) end
function MAD.Log.Warning(message, event_type) MAD.Log.Write(MAD.Log.LEVEL_WARNING, message, event_type) end
function MAD.Log.Error(message, event_type) MAD.Log.Write(MAD.Log.LEVEL_ERROR, message, event_type) end
function MAD.Log.Critical(message, event_type) MAD.Log.Write(MAD.Log.LEVEL_CRITICAL, message, event_type) end

-- Event logging functions
function MAD.Log.PlayerJoin(ply)
    if not IsValid(ply) then return end
    MAD.Log.Info(string.format("%s (%s) joined", ply:Name(), ply:SteamID()), "player_join")
end

function MAD.Log.PlayerDisconnect(ply)
    if not IsValid(ply) then return end
    MAD.Log.Info(string.format("%s (%s) disconnected", ply:Name(), ply:SteamID()), "player_disconnect")
end

-- ... (other event logging functions from previous version)

-- Configuration management
function MAD.Log.SetConfig(key, value)
    if MAD.Log.Config[key] ~= nil then
        MAD.Log.Config[key] = value
        return true
    end
    return false
end

function MAD.Log.SetEventLogging(event_type, enabled)
    if MAD.Log.Config.events[event_type] ~= nil then
        MAD.Log.Config.events[event_type] = enabled
        return true
    end
    return false
end

-- Console commands
function MAD.Log.RegisterCommands()
    -- Only register commands if MADmod commands system is initialized
    if not MAD.Commands or not MAD.Commands.Register then
        return
    end
    
    MAD.Commands.Register("log_config", {
        permission = "manage_server",
        description = "Configure logging",
        usage = "mad log_config <setting> <value>",
        args_min = 2,
        args_max = 2,
        func = function(ply, args)
            local setting = args[1]
            local value = args[2]
            
            if value == "true" then value = true
            elseif value == "false" then value = false
            elseif tonumber(value) then value = tonumber(value) end
            
            if MAD.Log.SetConfig(setting, value) then
                MAD.Message(ply, string.format("Log setting %s set to %s", setting, tostring(value)))
            else
                MAD.Message(ply, "Invalid setting")
            end
        end
    })
end

-- Reset initialization state (for hot reload)
function MAD.Log.Reset()
    MAD.Log.Initialized = false
    MAD.Log.Info("Logging system reset for reinitialization")
end