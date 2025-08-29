MAD.Data = MAD.Data or {}

-- Default configuration
local defaultConfig = {
    chat_prefix_public = "!",
    chat_prefix_silent = "@", 
    console_prefix = "mad",
    enable_file_logging = false,
    enable_console_logging = true,
    console_log_level = "info",
    verbose_errors = false,
    autosave_interval = 300, -- seconds
    log_player_connect = true,
    log_player_disconnect = true,
    log_player_death = true,
    log_player_spawn = true,
    log_player_kill = true,
    log_commands = true,
    log_prop_spawn = true,
    log_prop_remove = true,
    log_toolgun = true
}

local config = {}

function MAD.Data.Initialize()
    -- Create necessary directories
    MAD.Data.CreateDirectories()
    
    -- Load configuration
    MAD.Data.LoadConfig()
    
    -- Register data management commands
    MAD.Commands.Register({
        name = "config",
        privilege = "",
        description = "Show current configuration",
        syntax = "config [setting]",
        callback = function(caller, args, silent)
            if #args > 0 then
                local setting = args[1]
                local value = MAD.Data.GetConfig(setting)
                
                if value ~= nil then
                    return string.format("%s = %s", setting, tostring(value))
                else
                    return "Configuration setting '" .. setting .. "' not found"
                end
            else
                local currentConfig = MAD.Data.GetConfig()
                local result = "Current configuration:\n"
                
                local sortedKeys = {}
                for key, _ in pairs(currentConfig) do
                    table.insert(sortedKeys, key)
                end
                table.sort(sortedKeys)
                
                for _, key in ipairs(sortedKeys) do
                    result = result .. string.format("  %s = %s\n", key, tostring(currentConfig[key]))
                end
                
                return result:sub(1, -2)
            end
        end
    })
    
    MAD.Commands.Register({
        name = "setconfig",
        privilege = "manage_config",
        description = "Set a configuration value",
        syntax = "setconfig <setting> <value>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: setconfig <setting> <value>"
            end
            
            local setting = args[1]
            local value = args[2]
            
            if value == "true" then
                value = true
            elseif value == "false" then
                value = false
            elseif tonumber(value) then
                value = tonumber(value)
            end
            
            local success = MAD.Data.SetConfig(setting, value)
            
            if success then
                return string.format("Set %s = %s", setting, tostring(value))
            else
                return "Invalid configuration setting: " .. setting
            end
        end
    })
    
    MAD.Commands.Register({
        name = "save",
        privilege = "manage_config",
        description = "Save all data to disk",
        syntax = "save",
        callback = function(caller, args, silent)
            MAD.Data.SaveConfig()
            MAD.Data.SaveAllRanks()
            MAD.Data.SaveAllPlayers()
            return "All data saved to disk"
        end
    })
    
    MAD.Commands.Register({
        name = "backup",
        privilege = "manage_config", 
        description = "Create a backup of all data",
        syntax = "backup",
        callback = function(caller, args, silent)
            local backupPath = MAD.Data.CreateBackup()
            return "Backup created: " .. backupPath
        end
    })
    
    MAD.Log.Info("Data system initialized")
end

function MAD.Data.CreateDirectories()
    local directories = {
        "madmod",
        "madmod/Ranks",
        "madmod/Players", 
        "madmod/Logs"
    }
    
    for _, dir in ipairs(directories) do
        file.CreateDir(dir)
    end
end

function MAD.Data.LoadConfig()
    local configPath = "madmod/config.txt"
    
    if MAD.Utils.FileExists(configPath) then
        local configStr = MAD.Utils.ReadFile(configPath)
        if configStr then
            local success, loadedConfig = pcall(util.JSONToTable, configStr)
            if success and loadedConfig then
                -- Merge with defaults to ensure all keys exist
                config = table.Merge(table.Copy(defaultConfig), loadedConfig)
                MAD.Log.Info("Configuration loaded from file")
                return
            else
                MAD.Log.Warning("Failed to parse config file, using defaults")
            end
        end
    end
    
    -- Use defaults and create file
    config = table.Copy(defaultConfig)
    MAD.Data.SaveConfig()
    MAD.Log.Info("Created default configuration")
end

function MAD.Data.SaveConfig()
    local configPath = "madmod/config.txt"
    local success = pcall(function()
        MAD.Utils.WriteFile(configPath, MAD.Utils.TableToJSON(config))
    end)
    
    if not success then
        MAD.Log.Error("Failed to save configuration")
    end
end

function MAD.Data.GetConfig(key)
    if key then
        return config[key]
    end
    return table.Copy(config)
end

function MAD.Data.SetConfig(key, value)
    if config[key] ~= nil then -- Only allow existing keys
        config[key] = value
        MAD.Data.SaveConfig()
        return true
    end
    return false
end

function MAD.Data.ResetConfig()
    config = table.Copy(defaultConfig)
    MAD.Data.SaveConfig()
    MAD.Log.Info("Configuration reset to defaults")
end

function MAD.Data.LoadRank(rankName)
    local rankPath = "madmod/Ranks/" .. rankName .. ".txt"
    
    if not MAD.Utils.FileExists(rankPath) then
        return nil
    end
    
    local rankData = MAD.Utils.ReadFile(rankPath)
    if not rankData then return nil end
    
    local success, parsedData = pcall(MAD.Utils.JSONToTable, rankData)
    if success and parsedData then
        return parsedData
    end
    
    MAD.Log.Error("Failed to parse rank file: " .. rankName)
    return nil
end

function MAD.Data.SaveRank(rankName, rankData)
    local rankPath = "madmod/Ranks/" .. rankName .. ".txt"
    local success = pcall(function()
        MAD.Utils.WriteFile(rankPath, MAD.Utils.TableToJSON(rankData))
    end)
    
    if not success then
        MAD.Log.Error("Failed to save rank: " .. rankName)
        return false
    end
    
    return true
end

function MAD.Data.SaveAllRanks()
    local ranks = MAD.Ranks.GetAll()
    for name, data in pairs(ranks) do
        MAD.Data.SaveRank(name, data)
    end
end

function MAD.Data.DeleteRank(rankName)
    local rankPath = "madmod/Ranks/" .. rankName .. ".txt"
    local success = pcall(function()
        MAD.Utils.DeleteFile(rankPath)
    end)
    
    if not success then
        MAD.Log.Error("Failed to delete rank file: " .. rankName)
        return false
    end
    
    return true
end

function MAD.Data.LoadPlayer(steamid64)
    local playerPath = "madmod/Players/" .. steamid64 .. ".txt"
    
    if not MAD.Utils.FileExists(playerPath) then
        return nil
    end
    
    local playerData = MAD.Utils.ReadFile(playerPath)
    if not playerData then return nil end
    
    local success, parsedData = pcall(MAD.Utils.JSONToTable, playerData)
    if success and parsedData then
        return parsedData
    end
    
    MAD.Log.Error("Failed to parse player file: " .. steamid64)
    return nil
end

function MAD.Data.SavePlayer(steamid64, playerData)
    local playerPath = "madmod/Players/" .. steamid64 .. ".txt"
    local success = pcall(function()
        MAD.Utils.WriteFile(playerPath, MAD.Utils.TableToJSON(playerData))
    end)
    
    if not success then
        MAD.Log.Error("Failed to save player data: " .. steamid64)
        return false
    end
    
    return true
end

function MAD.Data.SaveAllPlayers()
    local loadedPlayers = MAD.Players.GetAllLoaded()
    for steamid64, data in pairs(loadedPlayers) do
        MAD.Data.SavePlayer(steamid64, data)
    end
end

-- Backup functionality
function MAD.Data.CreateBackup()
    local backupDir = "madmod/Backups/" .. MAD.Utils.GetDateString() .. "_" .. os.time()
    file.CreateDir("madmod/Backups")
    file.CreateDir(backupDir)
    
    -- Backup config
    local configData = MAD.Utils.ReadFile("madmod/config.txt")
    if configData then
        MAD.Utils.WriteFile(backupDir .. "/config.txt", configData)
    end
    
    -- Backup ranks
    local rankFiles, _ = file.Find("madmod/Ranks/*.txt", "DATA")
    file.CreateDir(backupDir .. "/Ranks")
    for _, fileName in pairs(rankFiles or {}) do
        local rankData = MAD.Utils.ReadFile("madmod/Ranks/" .. fileName)
        if rankData then
            MAD.Utils.WriteFile(backupDir .. "/Ranks/" .. fileName, rankData)
        end
    end
    
    -- Backup players
    local playerFiles, _ = file.Find("madmod/Players/*.txt", "DATA")
    file.CreateDir(backupDir .. "/Players")
    for _, fileName in pairs(playerFiles or {}) do
        local playerData = MAD.Utils.ReadFile("madmod/Players/" .. fileName)
        if playerData then
            MAD.Utils.WriteFile(backupDir .. "/Players/" .. fileName, playerData)
        end
    end
    
    MAD.Log.Info("Backup created: " .. backupDir)
    return backupDir
end