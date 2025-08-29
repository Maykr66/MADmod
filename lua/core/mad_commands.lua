MAD.Commands = MAD.Commands or {}

local commands = {}

function MAD.Commands.Initialize()
    MAD.Log.Info("Commands system initialized")
    
    -- Register built-in help command
    MAD.Commands.Register({
        name = "help",
        privilege = "", -- No privilege required
        description = "Show available commands",
        syntax = "help [command]",
        callback = function(caller, args, silent)
            if #args > 0 then
                -- Show specific command help
                local cmdName = args[1]
                local cmd = MAD.Commands.Get(cmdName)
                
                if not cmd then
                    return "Command '" .. cmdName .. "' not found"
                end
                
                -- Check if player has access to this command
                if cmd.privilege ~= "" and IsValid(caller) and not MAD.Privileges.HasAccess(caller, cmd.privilege) then
                    return "Command '" .. cmdName .. "' not found"
                end
                
                local result = "Command: " .. cmd.name .. "\n"
                result = result .. "Description: " .. (cmd.description or "No description") .. "\n"
                result = result .. "Syntax: " .. (cmd.syntax or cmd.name)
                
                if cmd.privilege and cmd.privilege ~= "" then
                    result = result .. "\nRequired privilege: " .. cmd.privilege
                end
                
                return result
            else
                -- Show available commands
                local availableCommands = {}
                
                for name, cmd in pairs(commands) do
                    local hasAccess = true
                    if cmd.privilege ~= "" and IsValid(caller) then
                        hasAccess = MAD.Privileges.HasAccess(caller, cmd.privilege)
                    end
                    
                    if hasAccess then
                        table.insert(availableCommands, {
                            name = name,
                            description = cmd.description or ""
                        })
                    end
                end
                
                if #availableCommands == 0 then
                    return "No commands available"
                end
                
                table.sort(availableCommands, function(a, b) return a.name < b.name end)
                
                local result = "Available commands (" .. #availableCommands .. "):\n"
                for _, cmd in ipairs(availableCommands) do
                    if cmd.description ~= "" then
                        result = result .. "  " .. cmd.name .. " - " .. cmd.description .. "\n"
                    else
                        result = result .. "  " .. cmd.name .. "\n"
                    end
                end
                
                result = result .. "Use 'help <command>' for detailed information"
                return result:sub(1, -2) -- Remove trailing newline
            end
        end
    })
    
    -- Register version command
    MAD.Commands.Register({
        name = "version",
        privilege = "",
        description = "Show MADmod version information",
        syntax = "version",
        callback = function(caller, args, silent)
            local info = {
                "MADmod Version: " .. MAD.Version,
                "Running on: " .. (game.GetMap() or "Unknown"),
                "Players online: " .. #player.GetAll(),
                "Extensions loaded: " .. table.Count(MAD.Extensions.Loaded or {})
            }
            return table.concat(info, "\n")
        end
    })
end

function MAD.Commands.Register(data)
    if not data or not data.name or not data.callback then
        MAD.Log.Error("Invalid command registration data")
        return false
    end
    
    local name = data.name -- Keep case sensitivity
    local privilege = data.privilege or ""
    local description = data.description or ""
    local callback = data.callback
    local syntax = data.syntax or ""
    
    if commands[name] then
        MAD.Log.Error("Command '" .. name .. "' already exists, registration failed")
        return false
    end
    
    commands[name] = {
        name = name,
        privilege = privilege,
        description = description,
        callback = callback,
        syntax = syntax,
        registered_by = debug.getinfo(2, "S").source or "unknown"
    }
    
    MAD.Log.Info("Registered command: " .. name .. (privilege ~= "" and (" (requires: " .. privilege .. ")") or ""))
    hook.Call("MAD.OnCommandRegistered", nil, name, data)
    
    return true
end

function MAD.Commands.Deregister(name)
    if not commands[name] then
        return false
    end
    
    commands[name] = nil
    MAD.Log.Info("Deregistered command: " .. name)
    
    return true
end

function MAD.Commands.Get(name)
    return commands[name] and table.Copy(commands[name]) or nil
end

function MAD.Commands.GetAll()
    return table.Copy(commands)
end

function MAD.Commands.Execute(player, commandName, args, silent)
    local cmd = commands[commandName]
    
    if not cmd then
        local config = MAD.Data.GetConfig()
        if config.verbose_errors then
            return false, "Unknown command: " .. commandName .. ". Use 'help' to see available commands."
        else
            return false, "Unknown command: " .. commandName
        end
    end
    
    -- Check privilege access
    if cmd.privilege ~= "" then
        if IsValid(player) and not MAD.Privileges.HasAccess(player, cmd.privilege) then
            return false, "Access denied"
        end
    end
    
    -- Log command execution
    MAD.Log.Command(player, commandName, args)
    
    -- Execute command
    local success, result = pcall(cmd.callback, player, args or {}, silent)
    
    if not success then
        MAD.Log.Error("Command '" .. commandName .. "' failed: " .. tostring(result))
        
        local config = MAD.Data.GetConfig()
        if config.verbose_errors then
            return false, "Command execution failed: " .. tostring(result)
        else
            return false, "Command execution failed"
        end
    end
    
    return true, result
end

-- Chat command handler
hook.Add("PlayerSay", "MAD_ChatCommands", function(sender, text, teamChat)
    local config = MAD.Data.GetConfig()
    local publicPrefix = config.chat_prefix_public
    local silentPrefix = config.chat_prefix_silent
    
    local silent = false
    local prefix = nil
    
    if string.StartWith(text, publicPrefix) then
        prefix = publicPrefix
        silent = false
    elseif string.StartWith(text, silentPrefix) then
        prefix = silentPrefix
        silent = true
    else
        return
    end
    
    -- Remove prefix and parse command
    local commandText = string.sub(text, string.len(prefix) + 1)
    local parts = MAD.Utils.Split(commandText, " ")
    local commandName = parts[1]
    table.remove(parts, 1) -- Remove command name
    local args = parts
    
    if commandName == "" then return end
    
    local success, result = MAD.Commands.Execute(sender, commandName, args, silent)
    
    if not success then
        sender:ChatPrint("[MAD] " .. (result or "Command failed"))
    elseif result and not silent then
        -- Broadcast non-silent command results
        for _, ply in pairs(player.GetAll()) do
            ply:ChatPrint("[MAD] " .. result)
        end
    elseif result and silent then
        -- Send result only to command executor
        sender:ChatPrint("[MAD] " .. result)
    end
    
    return "" -- Suppress original chat message
end)

-- Console command handler
concommand.Add("mad", function(ply, cmd, args)
    if #args == 0 then
        if IsValid(ply) then
            ply:ChatPrint("[MAD] Usage: mad <command> [arguments]")
        else
            print("[MAD] Usage: mad <command> [arguments]")
        end
        return
    end
    
    local commandName = args[1]
    table.remove(args, 1)
    
    local success, result = MAD.Commands.Execute(ply, commandName, args, false)
    
    if IsValid(ply) then
        ply:ChatPrint("[MAD] " .. (result or (success and "Command executed" or "Command failed")))
    else
        print("[MAD] " .. (result or (success and "Command executed" or "Command failed")))
    end
end)