-- MADmod RCON Extension
-- Allows trusted players to execute server console commands

-- Only run on server
if CLIENT then return end

-- Execute console command
local function ExecuteRCONCommand(ply, command_string)
    -- Log the command execution
    MAD.Log.Info(string.format("RCON: %s executed: %s", 
        IsValid(ply) and ply:Name() or "Console", command_string), "admin_actions")
    
    -- Execute the command
    local success, result = pcall(function()
        game.ConsoleCommand(command_string .. "\n")
    end)
    
    if not success then
        return false, "Command execution failed: " .. tostring(result)
    end
    
    return true
end

-- Register RCON command
MAD.Commands.Register("rcon", {
    permission = "rcon",
    description = "Execute server console commands",
    usage = "!rcon <command> [args] | mad rcon <command> [args]",
    args_min = 1,
    args_max = math.huge,
    func = function(ply, args)
        local command_string = table.concat(args, " ")
        
        if not command_string or command_string == "" then
            MAD.Message(ply, "No command specified")
            return
        end
        
        -- Execute the command
        local success, error_msg = ExecuteRCONCommand(ply, command_string)
        
        if success then
            MAD.Message(ply, "Executed: " .. command_string)
        else
            MAD.Message(ply, "Failed: " .. error_msg)
        end
    end
})

-- Register safe server info command
MAD.Commands.Register("serverinfo", {
    permission = "rcon",
    description = "Display server information",
    usage = "!serverinfo | mad serverinfo",
    args_min = 0,
    args_max = 0,
    func = function(ply, args)
        local info = {
            "=== Server Information ===",
            "Hostname: " .. GetHostName(),
            "Map: " .. game.GetMap(),
            "Players: " .. #player.GetAll() .. "/" .. game.MaxPlayers(),
            "Gamemode: " .. engine.ActiveGamemode(),
            "Tickrate: " .. math.floor(1 / engine.TickInterval()),
            "Uptime: " .. string.FormattedTime(CurTime(), "%02i:%02i:%02i")
        }
        
        for _, line in ipairs(info) do
            MAD.Message(ply, line)
        end
        
        MAD.Log.Info(string.format("%s requested server info", 
            IsValid(ply) and ply:Name() or "Console"), "admin_actions")
    end
})

-- Register convars command to list/modify server variables
MAD.Commands.Register("cvar", {
    permission = "rcon",
    description = "Get or set console variables",
    usage = "!cvar <name> [value] | mad cvar <name> [value]",
    args_min = 1,
    args_max = 2,
    func = function(ply, args)
        local cvar_name = args[1]
        local cvar_value = args[2]
        
        -- Security check for dangerous cvars
        local dangerous_cvars = {
            "rcon_password",
            "sv_password", 
            "hostname",
            "sv_lan"
        }
        
        for _, dangerous in ipairs(dangerous_cvars) do
            if string.lower(cvar_name) == dangerous then
                MAD.Commands.Message(ply, "Access to cvar '" .. cvar_name .. "' is restricted")
                return
            end
        end
        
        local cvar = GetConVar(cvar_name)
        if not cvar then
            MAD.Message(ply, "ConVar '" .. cvar_name .. "' not found")
            return
        end
        
        if cvar_value then
            -- Set the cvar
            local old_value = cvar:GetString()
            cvar:SetString(cvar_value)
            
            MAD.Message(ply, string.format("Set %s from '%s' to '%s'", 
                cvar_name, old_value, cvar_value))
            
            MAD.Log.Info(string.format("CVAR: %s set %s from '%s' to '%s'", 
                IsValid(ply) and ply:Name() or "Console", cvar_name, old_value, cvar_value), "admin_actions")
        else
            -- Get the cvar value
            local value = cvar:GetString()
            local default_value = cvar:GetDefault()
            
            MAD.Message(ply, string.format("%s = '%s' (default: '%s')", 
                cvar_name, value, default_value))
        end
    end
})

-- Register kick command wrapper
MAD.Commands.Register("kick", {
    permission = "kick",
    description = "Kick a player from the server",
    usage = "!kick <player> [reason] | mad kick <player> [reason]",
    args_min = 1,
    args_max = math.huge,
    func = function(ply, args)
        local target, err = MAD.FindPlayer(ply, args[1])
        if not target then
            MAD.Message(ply, err)
            return
        end
        
        -- Check immunity
        if IsValid(ply) and not MAD.Permissions.CanTarget(ply, target) then
            MAD.Message(ply, "You cannot kick " .. target:Name() .. " (insufficient immunity)")
            return
        end
        
        local reason = "Kicked by admin"
        if #args > 1 then
            table.remove(args, 1) -- Remove player name
            reason = table.concat(args, " ")
        end
        
        -- Execute kick
        target:Kick(reason)
        
        MAD.Message(ply, "Kicked " .. target:Name() .. " (" .. reason .. ")")
        MAD.Log.Info(string.format("%s kicked %s (%s)", 
            IsValid(ply) and ply:Name() or "Console", target:Name(), reason), "admin_actions")
    end
})

-- Cleanup function (called when extension is unloaded)
function MAD_RCON_CLEANUP()
end