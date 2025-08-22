-- MADmod Command System with Duplicate Protection
MAD.Commands = MAD.Commands or {}

-- Command storage
MAD.Commands.List = MAD.Commands.List or {}
MAD.Commands.ChatPrefix = "!"           -- visible commands
MAD.Commands.SilentChatPrefix = "@"     -- hidden commands
MAD.Commands.ConsolePrefix = "mad"      -- configurable console command prefix
MAD.Commands.ConsoleRegistered = false
MAD.Commands.RegisteredCommands = {} -- Track registered commands to prevent duplicates

-- Initialize command system
function MAD.Commands.Initialize()
    -- Hook into chat for chat commands
    hook.Add("PlayerSay", "MAD_ChatCommands", MAD.Commands.HandleChatCommand)
    
    -- Register main console command handler
    if not MAD.Commands.ConsoleRegistered then
        concommand.Add(MAD.Commands.ConsolePrefix, MAD.Commands.HandleConsoleCommand)
        MAD.Commands.ConsoleRegistered = true
    end
    
    -- Register core commands
    MAD.Commands.RegisterCoreCommands()
    
    MAD.Log.Info("Command system initialized")
end

-- Enhanced Register function with duplicate protection
function MAD.Commands.Register(name, data, allowOverride)
    if not name or not data then
        MAD.Log.Warning("Invalid command registration")
        return false
    end
    
    -- Check if command exists and handle accordingly
    if MAD.Commands.RegisteredCommands[name] then
        if allowOverride then
            MAD.Log.Debug("Overriding existing command: " .. name)
        else
            MAD.Log.Debug("Command already registered: " .. name .. " (skipping)")
            return false
        end
    end
    
    -- Register the command
    MAD.Commands.List[name] = {
        permission = data.permission or "user",
        description = data.description or "No description",
        usage = data.usage or name,
        func = data.func,
        console = data.console ~= false, -- Default true
        chat = data.chat ~= false, -- Default true
        args_min = data.args_min or 0,
        args_max = data.args_max or math.huge
    }
    
    -- Mark as registered
    MAD.Commands.RegisteredCommands[name] = true
    
    MAD.Log.Debug("Command registered: " .. name)
    return true
end

-- Execute a command
function MAD.Commands.Execute(ply, cmd_name, args)
    local cmd = MAD.Commands.List[cmd_name]
    if not cmd then
        -- Use fallback for system messages if MAD.Message not available
        if MAD.Message then
            MAD.Message(ply, "Unknown command: " .. cmd_name)
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Unknown command: " .. cmd_name)
            else print("[MADmod] Unknown command: " .. cmd_name) end
        end
        return false
    end
    
    -- Skip permission check for help
    if cmd_name ~= "help" and not MAD.Permissions.HasPermission(ply, cmd.permission) then
        if MAD.Message then
            MAD.Message(ply, "Access denied")
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Access denied")
            else print("[MADmod] Access denied") end
        end
        return false
    end
    
    -- Validate argument count
    local arg_count = #args
    if arg_count < cmd.args_min then
        if MAD.Message then
            MAD.Message(ply, "Usage: " .. cmd.usage)
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Usage: " .. cmd.usage)
            else print("[MADmod] Usage: " .. cmd.usage) end
        end
        return false
    end
    
    if arg_count > cmd.args_max then
        if MAD.Message then
            MAD.Message(ply, "Too many arguments. Usage: " .. cmd.usage)
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Too many arguments. Usage: " .. cmd.usage)
            else print("[MADmod] Too many arguments. Usage: " .. cmd.usage) end
        end
        return false
    end
    
    -- Execute command
    local success, result = pcall(cmd.func, ply, args)
    if not success then
        if MAD.Message then
            MAD.Message(ply, "Command error: " .. tostring(result))
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Command error: " .. tostring(result))
            else print("[MADmod] Command error: " .. tostring(result)) end
        end
        MAD.Log.Error("Command error in '" .. cmd_name .. "': " .. tostring(result))
        return false
    end
    
    return true
end

-- Handle console commands
function MAD.Commands.HandleConsoleCommand(ply, cmd, args)
    if #args == 0 then
        if MAD.Message then
            MAD.Message(ply, "MADmod v" .. MAD.Version)
            MAD.Message(ply, "Usage: " .. MAD.Commands.ConsolePrefix .. " <command> [arguments]")
            MAD.Message(ply, "Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
        else
            if IsValid(ply) then
                ply:ChatPrint("[MADmod] MADmod v" .. MAD.Version)
                ply:ChatPrint("[MADmod] Usage: " .. MAD.Commands.ConsolePrefix .. " <command> [arguments]")
                ply:ChatPrint("[MADmod] Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
            else
                print("[MADmod] MADmod v" .. MAD.Version)
                print("[MADmod] Usage: " .. MAD.Commands.ConsolePrefix .. " <command> [arguments]")
                print("[MADmod] Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
            end
        end
        return
    end
    
    local cmd_name = args[1]
    table.remove(args, 1)
    
    local cmd = MAD.Commands.List[cmd_name]
    if not cmd then
        if MAD.Message then
            MAD.Message(ply, "Unknown command: " .. cmd_name)
            MAD.Message(ply, "Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
        else
            if IsValid(ply) then
                ply:ChatPrint("[MADmod] Unknown command: " .. cmd_name)
                ply:ChatPrint("[MADmod] Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
            else
                print("[MADmod] Unknown command: " .. cmd_name)
                print("[MADmod] Type '" .. MAD.Commands.ConsolePrefix .. " help' for available commands")
            end
        end
        return
    end
    
    if cmd.console == false then
        if MAD.Message then
            MAD.Message(ply, "Command '" .. cmd_name .. "' is not available from console")
        else
            if IsValid(ply) then ply:ChatPrint("[MADmod] Command '" .. cmd_name .. "' is not available from console")
            else print("[MADmod] Command '" .. cmd_name .. "' is not available from console") end
        end
        return
    end
    
    MAD.Commands.Execute(ply, cmd_name, args)
end

-- Handle chat commands (supports ! for visible, @ for hidden)
function MAD.Commands.HandleChatCommand(ply, text, team)
    local prefix = nil
    local silent = false

    if string.StartWith(text, MAD.Commands.ChatPrefix) then
        prefix = MAD.Commands.ChatPrefix
        silent = false
    elseif string.StartWith(text, MAD.Commands.SilentChatPrefix) then
        prefix = MAD.Commands.SilentChatPrefix
        silent = true
    else
        return
    end

    -- Parse command
    local args = string.Explode(" ", text)
    local cmd_name = string.sub(args[1], 2)
    table.remove(args, 1)
    
    local cmd = MAD.Commands.List[cmd_name]
    if not cmd or cmd.chat == false then return end
    
    -- If visible mode, echo to chat before executing
    if not silent then
        PrintMessage(HUD_PRINTTALK, ply:Name() .. " ran command: " .. prefix .. cmd_name .. " " .. table.concat(args, " "))
    end

    MAD.Commands.Execute(ply, cmd_name, args)
    
    return "" -- Always suppress original message
end

-- Register core commands
function MAD.Commands.RegisterCoreCommands()
    -- Help command (no permission required)
    MAD.Commands.Register("help", {
        permission = "none",
        description = "Show available commands",
        usage = "!help [command] OR " .. MAD.Commands.ConsolePrefix .. " help [command]",
        args_min = 0,
        args_max = 1,
        func = function(ply, args)
            if args[1] then
                local cmd = MAD.Commands.List[args[1]]
                if cmd then
                    -- Only show if player has permission OR is server
                    if not IsValid(ply) or MAD.Permissions.HasPermission(ply, cmd.permission) then
                        if MAD.Message then
                            MAD.Message(ply, cmd.description)
                            MAD.Message(ply, "Usage: " .. cmd.usage)
                        else
                            if IsValid(ply) then
                                ply:ChatPrint("[MADmod] " .. cmd.description)
                                ply:ChatPrint("[MADmod] Usage: " .. cmd.usage)
                            else
                                print("[MADmod] " .. cmd.description)
                                print("[MADmod] Usage: " .. cmd.usage)
                            end
                        end
                    else
                        if MAD.Message then
                            MAD.Message(ply, "Command not found or no access")
                        else
                            if IsValid(ply) then ply:ChatPrint("[MADmod] Command not found or no access")
                            else print("[MADmod] Command not found or no access") end
                        end
                    end
                else
                    if MAD.Message then
                        MAD.Message(ply, "Command not found")
                    else
                        if IsValid(ply) then ply:ChatPrint("[MADmod] Command not found")
                        else print("[MADmod] Command not found") end
                    end
                end
            else
                local cmds = {}
                for name, cmd in pairs(MAD.Commands.List) do
                    if not IsValid(ply) or MAD.Permissions.HasPermission(ply, cmd.permission) then
                        table.insert(cmds, {name = name, desc = cmd.description})
                    end
                end
                table.sort(cmds, function(a, b) return a.name < b.name end)
                
                -- Different output format for console vs chat
                if not IsValid(ply) then
                    -- Console output - one command per line
                    if MAD.Message then
                        MAD.Message(ply, "Available commands:")
                        for _, cmd in ipairs(cmds) do
                            MAD.Message(ply, "  " .. cmd.name .. " - " .. cmd.desc)
                        end
                        MAD.Message(ply, "Usage: " .. MAD.Commands.ConsolePrefix .. " <command> [arguments]")
                    else
                        print("[MADmod] Available commands:")
                        for _, cmd in ipairs(cmds) do
                            print("[MADmod]   " .. cmd.name .. " - " .. cmd.desc)
                        end
                        print("[MADmod] Usage: " .. MAD.Commands.ConsolePrefix .. " <command> [arguments]")
                    end
                else
                    -- Chat output - chunked list to avoid overflow
                    local cmd_names = {}
                    for _, cmd in ipairs(cmds) do
                        table.insert(cmd_names, cmd.name)
                    end
                    
                    -- Only use chunking if MAD.Message is available
                    if MAD.Message then
                        -- Split command list into chunks if too long
                        local cmd_list = table.concat(cmd_names, ", ")
                        if string.len(cmd_list) > 180 then -- Leave room for prefix text
                            -- Split into multiple messages
                            local chunks = {}
                            local current_chunk = ""
                            
                            for i, cmd_name in ipairs(cmd_names) do
                                local addition = (current_chunk == "") and cmd_name or (", " .. cmd_name)
                                
                                if string.len(current_chunk .. addition) > 180 then
                                    table.insert(chunks, current_chunk)
                                    current_chunk = cmd_name
                                else
                                    current_chunk = current_chunk .. addition
                                end
                            end
                            
                            if current_chunk ~= "" then
                                table.insert(chunks, current_chunk)
                            end
                            
                            -- Send chunks
                            for i, chunk in ipairs(chunks) do
                                if i == 1 then
                                    MAD.Message(ply, "Available commands: " .. chunk)
                                else
                                    MAD.Message(ply, "  " .. chunk)
                                end
                            end
                        else
                            MAD.Message(ply, "Available commands: " .. cmd_list)
                        end
                        
                        MAD.Message(ply, "Chat: !<command> | Console: " .. MAD.Commands.ConsolePrefix .. " <command>")
                    else
                        -- Fallback - simple list without chunking
                        ply:ChatPrint("[MADmod] Available commands: " .. table.concat(cmd_names, ", "))
                        ply:ChatPrint("[MADmod] Chat: !<command> | Console: " .. MAD.Commands.ConsolePrefix .. " <command>")
                    end
                end
            end
        end
    }, true)
end