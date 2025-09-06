-- MADmod RCON Extension v2.0.0
-- Allows trusted players to execute server console commands
-- Compatible with MADmod v1.0.0

-- Only run on server
if CLIENT then return end

local EXTENSION_NAME = "RCON Extension"
local EXTENSION_VERSION = "2.0.0"

MAD.Log.Info("Loading " .. EXTENSION_NAME .. " v" .. EXTENSION_VERSION)

-- Execute console command safely
local function ExecuteRCONCommand(caller, commandString)
    local callerName = IsValid(caller) and caller:Nick() or "Console"
    
    -- Log the command execution
    MAD.Log.Info(string.format("RCON: %s executed: %s", callerName, commandString))
    
    -- Execute the command
    local success, result = pcall(function()
        game.ConsoleCommand(commandString .. "\n")
    end)
    
    if not success then
        MAD.Log.Error("RCON command failed: " .. tostring(result))
        return false, "Command execution failed: " .. tostring(result)
    end
    
    return true
end

-- Register RCON command
MAD.Commands.Register({
    name = "rcon",
    privilege = "rcon_access",
    description = "Execute server console commands",
    syntax = "rcon <command> [args]",
    callback = function(caller, args, silent)
        if #args < 1 then
            return "Usage: rcon <command> [args]"
        end
        
        local commandString = table.concat(args, " ")
        
        if not commandString or commandString == "" then
            return "No command specified"
        end
        
        -- Security check for dangerous commands
        local lowerCommand = string.lower(commandString)
        local dangerousCommands = {
            "rcon_password",
            "quit",
            "exit", 
            "restart",
            "changelevel",
            "sv_password",
            "lua_run",
            "lua_run_cl"
        }
        
        for _, dangerous in ipairs(dangerousCommands) do
            if string.find(lowerCommand, dangerous, 1, true) then
                MAD.Log.Warning(string.format("RCON: %s attempted dangerous command: %s", 
                    IsValid(caller) and caller:Nick() or "Console", commandString))
                return "Access to command '" .. dangerous .. "' is restricted for security"
            end
        end
        
        -- Execute the command
        local success, errorMsg = ExecuteRCONCommand(caller, commandString)
        
        if success then
            return "Executed: " .. commandString
        else
            return "Failed: " .. errorMsg
        end
    end
})

-- Register server info command
MAD.Commands.Register({
    name = "serverinfo",
    privilege = "view_server_info",
    description = "Display server information",
    syntax = "serverinfo",
    callback = function(caller, args, silent)
        local info = {
            "=== Server Information ===",
            "Hostname: " .. GetHostName(),
            "Map: " .. game.GetMap(),
            "Players: " .. #player.GetAll() .. "/" .. game.MaxPlayers(),
            "Gamemode: " .. engine.ActiveGamemode(),
            "Tickrate: " .. math.floor(1 / engine.TickInterval()),
            "Uptime: " .. string.FormattedTime(CurTime(), "%02i:%02i:%02i")
        }
        
        MAD.Log.Info(string.format("%s requested server info", 
            IsValid(caller) and caller:Nick() or "Console"))
        
        return table.concat(info, "\n")
    end
})

-- Register cvar command to get/set console variables
MAD.Commands.Register({
    name = "cvar",
    privilege = "manage_cvars",
    description = "Get or set console variables",
    syntax = "cvar <name> [value]",
    callback = function(caller, args, silent)
        if #args < 1 then
            return "Usage: cvar <name> [value]"
        end
        
        local cvarName = args[1]
        local cvarValue = args[2]
        
        -- Security check for dangerous cvars
        local dangerousCvars = {
            "rcon_password",
            "sv_password", 
            "hostname",
            "sv_lan"
        }
        
        for _, dangerous in ipairs(dangerousCvars) do
            if string.lower(cvarName) == dangerous then
                return "Access to cvar '" .. cvarName .. "' is restricted"
            end
        end
        
        local cvar = GetConVar(cvarName)
        if not cvar then
            return "ConVar '" .. cvarName .. "' not found"
        end
        
        if cvarValue then
            -- Set the cvar
            local oldValue = cvar:GetString()
            cvar:SetString(cvarValue)
            
            MAD.Log.Info(string.format("CVAR: %s set %s from '%s' to '%s'", 
                IsValid(caller) and caller:Nick() or "Console", cvarName, oldValue, cvarValue))
            
            return string.format("Set %s from '%s' to '%s'", cvarName, oldValue, cvarValue)
        else
            -- Get the cvar value
            local value = cvar:GetString()
            local defaultValue = cvar:GetDefault()
            
            return string.format("%s = '%s' (default: '%s')", cvarName, value, defaultValue)
        end
    end
})

-- Register status command for player list
MAD.Commands.Register({
    name = "status",
    privilege = "view_server_info",
    description = "Show connected players",
    syntax = "status",
    callback = function(caller, args, silent)
        local players = player.GetAll()
        
        if #players == 0 then
            return "No players connected"
        end
        
        local result = "Connected players (" .. #players .. "/" .. game.MaxPlayers() .. "):\n"
        
        for _, ply in pairs(players) do
            local rank = MAD.Players.GetRank(ply:SteamID64())
            local ping = ply:Ping()
            local steamid = ply:SteamID()
            
            result = result .. string.format("  %s [%s] - %s (ping: %dms)\n", 
                ply:Nick(), rank, steamid, ping)
        end
        
        return result:sub(1, -2) -- Remove trailing newline
    end
})

-- Register map command
MAD.Commands.Register({
    name = "map",
    privilege = "change_map",
    description = "Change the server map",
    syntax = "map <mapname>",
    callback = function(caller, args, silent)
        if #args < 1 then
            return "Usage: map <mapname>"
        end
        
        local mapName = args[1]
        
        -- Validate map exists
        if not file.Exists("maps/" .. mapName .. ".bsp", "GAME") then
            return "Map '" .. mapName .. "' not found on server"
        end
        
        local callerName = IsValid(caller) and caller:Nick() or "Console"
        MAD.Log.Info(string.format("%s changing map to: %s", callerName, mapName))
        
        -- Notify players
        for _, ply in pairs(player.GetAll()) do
            ply:ChatPrint("[MAD] " .. callerName .. " is changing map to " .. mapName)
        end
        
        -- Change map after a short delay
        timer.Simple(3, function()
            RunConsoleCommand("changelevel", mapName)
        end)
        
        return "Changing map to " .. mapName .. " in 3 seconds..."
    end
})

-- Register gamemode command
MAD.Commands.Register({
    name = "gamemode",
    privilege = "change_gamemode",
    description = "Change the server gamemode",
    syntax = "gamemode <gamemode>",
    callback = function(caller, args, silent)
        if #args < 1 then
            return "Usage: gamemode <gamemode>"
        end
        
        local gamemodeName = args[1]
        local callerName = IsValid(caller) and caller:Nick() or "Console"
        
        MAD.Log.Info(string.format("%s changing gamemode to: %s", callerName, gamemodeName))
        
        -- Execute gamemode change
        RunConsoleCommand("gamemode", gamemodeName)
        
        return "Changed gamemode to " .. gamemodeName
    end
})

-- Register restart command
MAD.Commands.Register({
    name = "restart",
    privilege = "restart_server",
    description = "Restart the current map",
    syntax = "restart",
    callback = function(caller, args, silent)
        local callerName = IsValid(caller) and caller:Nick() or "Console"
        local currentMap = game.GetMap()
        
        MAD.Log.Info(string.format("%s restarting map: %s", callerName, currentMap))
        
        -- Notify players
        for _, ply in pairs(player.GetAll()) do
            ply:ChatPrint("[MAD] " .. callerName .. " is restarting the map")
        end
        
        -- Restart map after a short delay
        timer.Simple(3, function()
            RunConsoleCommand("changelevel", currentMap)
        end)
        
        return "Restarting map in 3 seconds..."
    end
})

-- Cleanup function for extension system
function MAD_RCON_CLEANUP()
    MAD.Log.Info("RCON extension cleanup completed")
end

MAD.Log.Success(EXTENSION_NAME .. " v" .. EXTENSION_VERSION .. " loaded successfully!")