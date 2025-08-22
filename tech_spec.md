Garry's mod add for server administration called MAD (MADmod) here is the folder structure 
madmod/
├── lua/
│   ├── autorun/
│   │   └── init_madmod.lua
│   ├── madmod.lua
│   ├── core/
│   │   └── <core extension critical for basic functionality>
│   │   └── mad_permissions.lua
│   │   └── mad_commands.lua
│   │   └── mad_extensions.lua
│   │   └── mad_network.lua
│   │   └── mad_data.lua
│   │   └── mad_log.lua
│   │   └── CAMI.lua (common admin mod interface)
│   │   └── CPPI.lua (common prop protection interface)
│   ├── shared/  (both client and server has usage. if only server requires then it's core
│   │   └── utils.lua (common utilities such has string manipulation, argument handlers, de-manglers, etc)
│   ├── ext/ (extensions)
│   │   └── <extension_name>.lua (extensions are narrow scoped in what they implement)

Purpose and function
- init_madmod.lua : exists in the autorun to "bootstrap" or "start" MADmod.
- madmod.lua : handles initialization of MADmod, core, starting extensions, starting a logger, data loading / saving to the data folder, showdown and clean up, executing player connections and disconnects.
- mad_data.lua : stores each players data as an individual text document in data/madmod/ply. the file is named as there <steamID64>.txt Each player data file contains there rank, time played(seconds), steam name from last session, banned status/time/message (0 being permanent).
It also handles the storage and loading of ranks. a rank consists of immunity (a higher immunity can't be affected by another rank of lower), Order (which is used for the scoreboard later), color (display color), permissions (used by permissions system and commands to verify a player has access), display name (the public facing name for a rank), derived from rank for CAMI purposes (user, admin, superadmin), etc as required. The internal rank name is what the file is named.
- mad_extensions.lua : handles the loading / unloading / hot reload of extensions. It checks for command collisions (to include calling convention), It adds permissions to the global list. 
- mad_network.lua : network strings for sending data back and forth from server to client. 
- mad_commands.lua : ensures the caller executing a command has the permission to use it per there rank. If a command targets a player besides the caller, it checks if they have the permissions to do so. If the caller is the server then it bypasses all permissions (superuser), etc

Rank overview
- User : is the core rank which has no special characteristics and exists to satisfy CAMI requirements.
- Admin : also exists to satisfy CAMI requirements.
- SuperAdmin : is a flag which grants the rank all permissions. (note should be handed out with care.

If you have further questions please ask. My goal is to build a successor to "mercury 2" which is another admin mod for garry's mod. The core of MADmod is to remain as light weight as possible and enable the extension system to implement all non core critical commands.

Here are examples of my previous attempt with my mod called quicksilver

qs_entry.lua{
-- QuickSilver initialization file

if SERVER then
    AddCSLuaFile("quicksilver.lua")
    include("quicksilver.lua")
elseif CLIENT then
    include("quicksilver.lua")
end
}

quicksilver.lua{
-- QuickSilver Admin System - Main Core
-- Lightweight server administration addon with hot-reloadable extensions

if SERVER then
    AddCSLuaFile()
end

-- Global QuickSilver namespace
QuickSilver = QuickSilver or {}
QuickSilver.Version = "1.0.0"
QuickSilver.Extensions = QuickSilver.Extensions or {}
QuickSilver.Config = QuickSilver.Config or {}

-- Core modules
local QS = QuickSilver

-- Include core modules
if SERVER then
    include("core/qs_data.lua")
    include("core/qs_permissions.lua")
    include("core/qs_commands.lua")
    include("core/qs_extensions.lua")
    include("core/qs_network.lua")
    include("core/qs_cppi.lua")
    include("core/qs_cami.lua")
else
    include("core/qs_network.lua")
end

-- Add client files
if SERVER then
    AddCSLuaFile("core/qs_network.lua")
end

-- Initialize QuickSilver
function QS.Initialize()
    if SERVER then
        print("[QuickSilver] Initializing server-side...")
        
        -- Initialize core systems
        QS.Data.Initialize()
        QS.Permissions.Initialize()
        QS.Commands.Initialize()
        QS.Network.Initialize()
        QS.CPPI.Initialize()
        --QS.CAMI.Initialize()
        QS.Extensions.Initialize()
        
        -- Load saved data
        QS.Data.Load()
        
        -- Start auto-save timer
        QS.StartAutoSave()
        
        print("[QuickSilver] Server initialization complete!")
    else
        print("[QuickSilver] Initializing client-side...")
        QS.Network.Initialize()
        print("[QuickSilver] Client initialization complete!")
    end
end

-- Auto-save functionality
function QS.StartAutoSave()
    if SERVER then
        timer.Create("QS_AutoSave", 300, 0, function() -- Save every 5 minutes
            QS.Data.Save()
        end)
    end
end

-- Shutdown cleanup
function QS.Shutdown()
    if SERVER then
        print("[QuickSilver] Shutting down...")
        QS.Data.Save()
        timer.Remove("QS_AutoSave")
    end
end

-- Initialize on addon load
hook.Add("Initialize", "QS_Initialize", QS.Initialize)
hook.Add("ShutDown", "QS_Shutdown", QS.Shutdown)

-- Player connection hooks
if SERVER then
    hook.Add("PlayerInitialSpawn", "QS_PlayerConnect", function(ply)
        QS.Permissions.LoadPlayer(ply)
    end)
    
    hook.Add("PlayerDisconnected", "QS_PlayerDisconnect", function(ply)
        QS.Data.SavePlayer(ply)
    end)
end
}

commands.lua{
-- QuickSilver Command System
-- Handles console and chat command registration and execution

local QS = QuickSilver
QS.Commands = QS.Commands or {}

-- Command storage
QS.Commands.List = QS.Commands.List or {}
QS.Commands.ChatPrefix = "!"
QS.Commands.ConsoleRegistered = false

-- Initialize command system
function QS.Commands.Initialize()
    -- Hook into chat for chat commands
    hook.Add("PlayerSay", "QS_ChatCommands", QS.Commands.HandleChatCommand)
    
    -- Register main console command handler
    if not QS.Commands.ConsoleRegistered then
        concommand.Add("qs", QS.Commands.HandleConsoleCommand)
        QS.Commands.ConsoleRegistered = true
    end
    
    -- Register core commands
    QS.Commands.RegisterCoreCommands()
    
    print("[QuickSilver] Command system initialized")
end

-- Register a new command
function QS.Commands.Register(name, data)
    if not name or not data then
        print("[QuickSilver] Invalid command registration")
        return false
    end
    
    QS.Commands.List[name] = {
        permission = data.permission or "user",
        description = data.description or "No description",
        usage = data.usage or name,
        func = data.func,
        console = data.console ~= false, -- Default true
        chat = data.chat ~= false, -- Default true
        args_min = data.args_min or 0,
        args_max = data.args_max or math.huge
    }
    
    return true
end

-- Execute a command
function QS.Commands.Execute(ply, cmd_name, args)
    local cmd = QS.Commands.List[cmd_name]
    if not cmd then
        QS.Commands.Message(ply, "Unknown command: " .. cmd_name)
        return false
    end
    
    -- Check permission
    if not QS.Permissions.HasPermission(ply, cmd.permission) then
        QS.Commands.Message(ply, "Access denied")
        return false
    end
    
    -- Validate argument count
    local arg_count = #args
    if arg_count < cmd.args_min then
        QS.Commands.Message(ply, "Usage: " .. cmd.usage)
        return false
    end
    
    if arg_count > cmd.args_max then
        QS.Commands.Message(ply, "Too many arguments. Usage: " .. cmd.usage)
        return false
    end
    
    -- Execute command
    local success, result = pcall(cmd.func, ply, args)
    if not success then
        QS.Commands.Message(ply, "Command error: " .. tostring(result))
        print("[QuickSilver] Command error in '" .. cmd_name .. "': " .. tostring(result))
        return false
    end
    
    return true
end

-- Handle console commands
function QS.Commands.HandleConsoleCommand(ply, cmd, args)
    if #args == 0 then
        QS.Commands.Message(ply, "QuickSilver v" .. QS.Version)
        QS.Commands.Message(ply, "Usage: qs <command> [arguments]")
        QS.Commands.Message(ply, "Type 'qs help' for available commands")
        return
    end
    
    local cmd_name = args[1]
    table.remove(args, 1) -- Remove command name from args
    
    -- Check if command exists and supports console
    local cmd = QS.Commands.List[cmd_name]
    if not cmd then
        QS.Commands.Message(ply, "Unknown command: " .. cmd_name)
        QS.Commands.Message(ply, "Type 'qs help' for available commands")
        return
    end
    
    if cmd.console == false then
        QS.Commands.Message(ply, "Command '" .. cmd_name .. "' is not available from console")
        return
    end
    
    -- Execute command
    QS.Commands.Execute(ply, cmd_name, args)
end

-- Handle chat commands
function QS.Commands.HandleChatCommand(ply, text, team)
    if not string.StartWith(text, QS.Commands.ChatPrefix) then
        return
    end
    
    -- Parse command and arguments
    local args = string.Explode(" ", text)
    local cmd_name = string.sub(args[1], 2) -- Remove prefix
    table.remove(args, 1) -- Remove command from args
    
    -- Check if command exists and supports chat
    local cmd = QS.Commands.List[cmd_name]
    if not cmd or cmd.chat == false then
        return
    end
    
    -- Execute command
    QS.Commands.Execute(ply, cmd_name, args)
    
    return ""  -- Suppress chat message
end

-- Send message to player
function QS.Commands.Message(ply, msg)
    if IsValid(ply) then
        ply:ChatPrint("[QuickSilver] " .. msg)
    else
        print("[QuickSilver] " .. msg)
    end
end

-- Send message to all players
function QS.Commands.MessageAll(msg, exclude)
    for _, p in ipairs(player.GetAll()) do
        if p ~= exclude then
            p:ChatPrint("[QuickSilver] " .. msg)
        end
    end
    print("[QuickSilver] " .. msg)
end

-- Find player by partial name
function QS.Commands.FindPlayer(ply, target_name)
    if not target_name or target_name == "" then
        return nil, "No target specified"
    end
    
    -- Self reference
    if target_name == "^" or target_name == "self" then
        return ply, nil
    end
    
    local targets = {}
    target_name = string.lower(target_name)
    
    -- Find matching players
    for _, p in ipairs(player.GetAll()) do
        local name = string.lower(p:Name())
        if string.find(name, target_name, 1, true) then
            table.insert(targets, p)
        end
    end
    
    if #targets == 0 then
        return nil, "Player not found"
    elseif #targets > 1 then
        local names = {}
        for _, p in ipairs(targets) do
            table.insert(names, p:Name())
        end
        return nil, "Multiple matches: " .. table.concat(names, ", ")
    end
    
    return targets[1], nil
end

-- Register core commands
function QS.Commands.RegisterCoreCommands()
    
    -- Reload extensions command
    QS.Commands.Register("reload", {
        permission = "reload",
        description = "Reload all extensions",
        usage = "!reload | qs reload",
        args_min = 0,
        args_max = 0,
        func = function(ply, args)
            QS.Extensions.ReloadAll()
            QS.Commands.Message(ply, "Extensions reloaded")
        end
    })
    
    -- Help command
    QS.Commands.Register("help", {
        permission = "user",
        description = "Show available commands",
        usage = "!help [command] OR qs help [command]",
        args_min = 0,
        args_max = 1,
        func = function(ply, args)
            if args[1] then
                -- Show specific command help
                local cmd = QS.Commands.List[args[1]]
                if cmd and QS.Permissions.HasPermission(ply, cmd.permission) then
                    QS.Commands.Message(ply, cmd.description)
                    QS.Commands.Message(ply, "Usage: " .. cmd.usage)
                else
                    QS.Commands.Message(ply, "Command not found or no access")
                end
            else
                -- List all available commands
                local cmds = {}
                for name, cmd in pairs(QS.Commands.List) do
                    if QS.Permissions.HasPermission(ply, cmd.permission) then
                        table.insert(cmds, name)
                    end
                end
                table.sort(cmds)
                QS.Commands.Message(ply, "Available commands: " .. table.concat(cmds, ", "))
                QS.Commands.Message(ply, "Chat: !<command> | Console: qs <command>")
            end
        end
    })
    
    -- Rank management
    QS.Commands.Register("setrank", {
        permission = "manage_users", 
        description = "Set player rank",
        usage = "!setrank <player> <rank> | qs setrank <player> <rank>",
        args_min = 2,
        args_max = 2,
        func = function(ply, args)
            local target, err = QS.Commands.FindPlayer(ply, args[1])
            if not target then
                QS.Commands.Message(ply, err)
                return
            end
            
            -- Check immunity
            if not QS.Permissions.CanTarget(ply, target) then
                QS.Commands.Message(ply, "Cannot target this player")
                return
            end
            
            local success, result = QS.Permissions.SetRank(target, args[2])
            if success then
                QS.Commands.MessageAll(target:Name() .. " has been promoted to " .. args[2] .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
            else
                QS.Commands.Message(ply, result)
            end
        end
    })
    
    -- Save data command
    QS.Commands.Register("save", {
        permission = "manage_server",
        description = "Save all data",
        usage = "!save | qs save",
        args_min = 0,
        args_max = 0,
        func = function(ply, args)
            QS.Data.Save()
            QS.Commands.Message(ply, "Data saved successfully")
        end
    })
    
    -- CPPI cleanup command
    QS.Commands.Register("cleanup", {
        permission = "cppi.bypass",
        description = "Cleanup player props",
        usage = "!cleanup [player] | qs cleanup [player]",
        args_min = 0,
        args_max = 1,
        func = function(ply, args)
            if args[1] then
                local target, err = QS.Commands.FindPlayer(ply, args[1])
                if not target then
                    QS.Commands.Message(ply, err)
                    return
                end
                
                local count = QS.CPPI.CleanupPlayerProps(target)
                QS.Commands.MessageAll(target:Name() .. "'s props cleaned up (" .. count .. " entities) by " .. (IsValid(ply) and ply:Name() or "Console"))
            else
                if not IsValid(ply) then
                    QS.Commands.Message(ply, "Console must specify a target player")
                    return
                end
                
                local count = QS.CPPI.CleanupPlayerProps(ply)
                QS.Commands.Message(ply, "Cleaned up " .. count .. " of your props")
            end
        end
    })
    
    -- CPPI transfer ownership command
    QS.Commands.Register("transfer", {
        permission = "cppi.bypass",
        description = "Transfer prop ownership",
        usage = "!transfer <from_player> <to_player> | qs transfer <from_player> <to_player>",
        args_min = 2,
        args_max = 2,
        func = function(ply, args)
            local from_player, err1 = QS.Commands.FindPlayer(ply, args[1])
            if not from_player then
                QS.Commands.Message(ply, "From player: " .. err1)
                return
            end
            
            local to_player, err2 = QS.Commands.FindPlayer(ply, args[2])
            if not to_player then
                QS.Commands.Message(ply, "To player: " .. err2)
                return
            end
            
            local count = QS.CPPI.TransferOwnership(from_player, to_player)
            QS.Commands.MessageAll("Transferred " .. count .. " props from " .. from_player:Name() .. " to " .. to_player:Name() .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
        end
    })
    
end
}

data.lua{
-- QuickSilver Data Management System
-- Handles loading/saving of player data and system state

local QS = QuickSilver
QS.Data = QS.Data or {}

-- Data storage
QS.Data.PlayerData = QS.Data.PlayerData or {}
QS.Data.SystemData = QS.Data.SystemData or {}

-- File paths
local DATA_PATH = "quicksilver/"
local PLAYER_DATA_PATH = DATA_PATH .. "players/"
local SYSTEM_DATA_PATH = DATA_PATH .. "system.json"

-- Initialize data system
function QS.Data.Initialize()
    -- Ensure directories exist
    if not file.Exists(DATA_PATH, "DATA") then
        file.CreateDir(DATA_PATH)
    end
    if not file.Exists(PLAYER_DATA_PATH, "DATA") then
        file.CreateDir(PLAYER_DATA_PATH)
    end
    
    print("[QuickSilver] Data system initialized")
end

-- Load all data
function QS.Data.Load()
    QS.Data.LoadSystem()
    QS.Data.LoadAllPlayers()
    print("[QuickSilver] All data loaded")
end

-- Save all data
function QS.Data.Save()
    QS.Data.SaveSystem()
    QS.Data.SaveAllPlayers()
    print("[QuickSilver] All data saved")
end

-- System data management
function QS.Data.LoadSystem()
    if file.Exists(SYSTEM_DATA_PATH, "DATA") then
        local data = file.Read(SYSTEM_DATA_PATH, "DATA")
        if data then
            local success, decoded = pcall(util.JSONToTable, data)
            if success and decoded then
                QS.Data.SystemData = decoded
                print("[QuickSilver] System data loaded")
            else
                print("[QuickSilver] Failed to decode system data")
            end
        end
    else
        print("[QuickSilver] No system data found, using defaults")
        QS.Data.ResetSystemData()
    end
end

function QS.Data.SaveSystem()
    local data = util.TableToJSON(QS.Data.SystemData, true)
    file.Write(SYSTEM_DATA_PATH, data)
end

function QS.Data.ResetSystemData()
    QS.Data.SystemData = {
        version = QS.Version,
        created = os.time(),
        last_save = os.time()
    }
end

-- Player data management
function QS.Data.LoadPlayer(ply)
    local steamid = ply:SteamID64()
    local filepath = PLAYER_DATA_PATH .. steamid .. ".json"
    
    if file.Exists(filepath, "DATA") then
        local data = file.Read(filepath, "DATA")
        if data then
            local success, decoded = pcall(util.JSONToTable, data)
            if success and decoded then
                QS.Data.PlayerData[steamid] = decoded
                -- Update last seen
                QS.Data.PlayerData[steamid].last_seen = os.time()
                QS.Data.PlayerData[steamid].name = ply:Name()
                return decoded
            end
        end
    end
    
    -- Create new player data
    QS.Data.PlayerData[steamid] = QS.Data.CreateNewPlayerData(ply)
    return QS.Data.PlayerData[steamid]
end

function QS.Data.SavePlayer(ply)
    local steamid = ply:SteamID64()
    if QS.Data.PlayerData[steamid] then
        -- Update disconnect time
        QS.Data.PlayerData[steamid].last_seen = os.time()
        QS.Data.PlayerData[steamid].total_time = (QS.Data.PlayerData[steamid].total_time or 0) + 
            (os.time() - (QS.Data.PlayerData[steamid].session_start or os.time()))
        
        local filepath = PLAYER_DATA_PATH .. steamid .. ".json"
        local data = util.TableToJSON(QS.Data.PlayerData[steamid], true)
        file.Write(filepath, data)
    end
end

function QS.Data.LoadAllPlayers()
    for _, ply in ipairs(player.GetAll()) do
        QS.Data.LoadPlayer(ply)
    end
end

function QS.Data.SaveAllPlayers()
    for _, ply in ipairs(player.GetAll()) do
        QS.Data.SavePlayer(ply)
    end
end

function QS.Data.CreateNewPlayerData(ply)
    local steamid = ply:SteamID64()
    return {
        steamid = steamid,
        name = ply:Name(),
        rank = "user",
        permissions = {},
        first_join = os.time(),
        last_seen = os.time(),
        session_start = os.time(),
        total_time = 0,
        flags = {}
    }
end

-- Utility functions
function QS.Data.GetPlayerData(ply)
    local steamid = ply:SteamID64()
    return QS.Data.PlayerData[steamid]
end

function QS.Data.SetPlayerData(ply, key, value)
    local steamid = ply:SteamID64()
    if QS.Data.PlayerData[steamid] then
        QS.Data.PlayerData[steamid][key] = value
    end
end

function QS.Data.GetSystemData(key)
    return QS.Data.SystemData[key]
end

function QS.Data.SetSystemData(key, value)
    QS.Data.SystemData[key] = value
end
}

extensions.lua{
-- QuickSilver Extension System
-- Handles loading, hot-reloading, and management of extensions

local QS = QuickSilver
QS.Extensions = QS.Extensions or {}

-- Extension storage
QS.Extensions.Loaded = QS.Extensions.Loaded or {}
QS.Extensions.Path = "quicksilver/ext/"
QS.Extensions.RegisteredPermissions = QS.Extensions.RegisteredPermissions or {}

-- Initialize extension system
function QS.Extensions.Initialize()
    QS.Extensions.LoadAll()
    print("[QuickSilver] Extension system initialized")
end

-- Load all extensions from ext directory
function QS.Extensions.LoadAll()
    local files, dirs = file.Find(QS.Extensions.Path .. "*.lua", "LUA")
    
    print("[QuickSilver] Loading extensions...")
    
    for _, filename in ipairs(files) do
        QS.Extensions.LoadExtension(filename)
    end
    
    print("[QuickSilver] Loaded " .. #files .. " extensions")
end

-- Load a single extension
function QS.Extensions.LoadExtension(filename)
    local filepath = QS.Extensions.Path .. filename
    local name = string.StripExtension(filename)
    
    -- Check if file exists
    if not file.Exists(filepath, "LUA") then
        print("[QuickSilver] Extension file not found: " .. filepath)
        return false
    end
    
    -- Unload existing extension
    if QS.Extensions.Loaded[name] then
        QS.Extensions.UnloadExtension(name)
    end
    
    -- Create extension environment
    local ext = {
        name = name,
        filename = filename,
        filepath = filepath,
        loaded = false,
        error = nil,
        permissions = {} -- Track permissions used by this extension
    }
    
    -- Store original command registration to intercept permission checks
    local original_register = QS.Commands.Register
    local temp_permissions = {}
    
    -- Override command registration temporarily to collect permissions
    QS.Commands.Register = function(cmd_name, cmd_data)
        if cmd_data.permission and cmd_data.permission ~= "user" then
            table.insert(temp_permissions, cmd_data.permission)
        end
        return original_register(cmd_name, cmd_data)
    end
    
    -- Load and execute extension
    local success, err = pcall(function()
        -- Include the extension file
        include(filepath)
        
        -- Add to client if needed
        if SERVER then
            AddCSLuaFile(filepath)
        end
        
        ext.loaded = true
        print("[QuickSilver] Loaded extension: " .. name)
    end)
    
    -- Restore original command registration
    QS.Commands.Register = original_register
    
    if not success then
        ext.error = err
        print("[QuickSilver] Failed to load extension '" .. name .. "': " .. tostring(err))
        QS.Extensions.Loaded[name] = ext
        return false
    end
    
    -- Check for permission conflicts
    local conflicts = QS.Extensions.CheckPermissionConflicts(name, temp_permissions)
    if #conflicts > 0 then
        ext.loaded = false
        ext.error = "Permission conflicts detected: " .. table.concat(conflicts, ", ")
        print("[QuickSilver] PERMISSION CONFLICT - Extension '" .. name .. "' failed to load:")
        print("[QuickSilver] Conflicting permissions: " .. table.concat(conflicts, ", "))
        for _, perm in ipairs(conflicts) do
            local owner = QS.Extensions.RegisteredPermissions[perm]
            print("[QuickSilver] Permission '" .. perm .. "' is already used by extension: " .. owner)
        end
        QS.Extensions.Loaded[name] = ext
        return false
    end
    
    -- Register permissions for this extension
    ext.permissions = temp_permissions
    for _, perm in ipairs(temp_permissions) do
        QS.Extensions.RegisteredPermissions[perm] = name
    end
    
    QS.Extensions.Loaded[name] = ext
    return success
end

-- Unload an extension
function QS.Extensions.UnloadExtension(name)
    local ext = QS.Extensions.Loaded[name]
    if not ext then
        return false
    end
    
    -- Call cleanup function if it exists
    local cleanup_func = _G["QS_" .. string.upper(name) .. "_CLEANUP"]
    if cleanup_func and type(cleanup_func) == "function" then
        pcall(cleanup_func)
    end
    
    -- Remove registered permissions
    if ext.permissions then
        for _, perm in ipairs(ext.permissions) do
            QS.Extensions.RegisteredPermissions[perm] = nil
        end
    end
    
    -- Remove from hooks (basic cleanup)
    -- Extensions should implement their own cleanup functions
    
    print("[QuickSilver] Unloaded extension: " .. name)
    return true
end

-- Reload a specific extension
function QS.Extensions.ReloadExtension(name)
    local ext = QS.Extensions.Loaded[name]
    if not ext then
        print("[QuickSilver] Extension not found: " .. name)
        return false
    end
    
    print("[QuickSilver] Reloading extension: " .. name)
    return QS.Extensions.LoadExtension(ext.filename)
end

-- Reload all extensions
function QS.Extensions.ReloadAll()
    print("[QuickSilver] Reloading all extensions...")
    
    -- Store current extension list
    local current_extensions = {}
    for name, ext in pairs(QS.Extensions.Loaded) do
        current_extensions[name] = ext.filename
    end
    
    -- Unload all current extensions
    for name, _ in pairs(current_extensions) do
        QS.Extensions.UnloadExtension(name)
    end
    
    -- Clear loaded extensions and permissions
    QS.Extensions.Loaded = {}
    QS.Extensions.RegisteredPermissions = {}
    
    -- Load all extensions fresh
    QS.Extensions.LoadAll()
    
    print("[QuickSilver] Extension reload complete")
end

-- Check for permission conflicts
function QS.Extensions.CheckPermissionConflicts(extension_name, permissions)
    local conflicts = {}
    
    for _, perm in ipairs(permissions) do
        if QS.Extensions.RegisteredPermissions[perm] then
            local owner = QS.Extensions.RegisteredPermissions[perm]
            if owner ~= extension_name then
                table.insert(conflicts, perm .. " (used by: " .. owner .. ")")
            end
        end
    end
    
    return conflicts
end

-- Get extension status
function QS.Extensions.GetStatus()
    local status = {
        total = 0,
        loaded = 0,
        failed = 0,
        extensions = {}
    }
    
    for name, ext in pairs(QS.Extensions.Loaded) do
        status.total = status.total + 1
        
        local ext_status = {
            name = name,
            loaded = ext.loaded,
            error = ext.error
        }
        
        if ext.loaded then
            status.loaded = status.loaded + 1
        else
            status.failed = status.failed + 1
        end
        
        table.insert(status.extensions, ext_status)
    end
    
    return status
end

-- Check if extension is loaded
function QS.Extensions.IsLoaded(name)
    local ext = QS.Extensions.Loaded[name]
    return ext and ext.loaded
end

-- Get extension info
function QS.Extensions.GetExtension(name)
    return QS.Extensions.Loaded[name]
end

-- List all extensions
function QS.Extensions.ListExtensions()
    local extensions = {}
    for name, ext in pairs(QS.Extensions.Loaded) do
        table.insert(extensions, {
            name = name,
            loaded = ext.loaded,
            error = ext.error,
            permissions = ext.permissions or {}
        })
    end
    return extensions
end

-- Get all registered permissions
function QS.Extensions.GetRegisteredPermissions()
    return QS.Extensions.RegisteredPermissions
end

-- Check if permission is registered
function QS.Extensions.IsPermissionRegistered(permission)
    return QS.Extensions.RegisteredPermissions[permission] ~= nil
end

-- Get extension that owns a permission
function QS.Extensions.GetPermissionOwner(permission)
    return QS.Extensions.RegisteredPermissions[permission]
end
}

permissions.lua{
-- QuickSilver Permission System
-- Handles player ranks, permissions, and access control

local QS = QuickSilver
QS.Permissions = QS.Permissions or {}

-- Rank definitions with permissions
QS.Permissions.Ranks = {
    ["superadmin"] = {
        name = "Super Admin",
        immunity = 100,
        permissions = {"*"} -- All permissions
    },
    ["admin"] = {
        name = "Admin",
        immunity = 80,
        permissions = {
            "teleport",
            "teleport.others",
            "god",
            "noclip",
            "kick",
            "ban",
            "unban",
            "manage_users",
            "manage_server",
            "reload",
            "cppi.bypass"
        }
    },
    ["moderator"] = {
        name = "Moderator", 
        immunity = 60,
        permissions = {
            "teleport",
            "god",
            "noclip",
            "kick"
        }
    },
    ["vip"] = {
        name = "VIP",
        immunity = 20,
        permissions = {
            "god",
            "noclip"
        }
    },
    ["user"] = {
        name = "User",
        immunity = 0,
        permissions = {}
    }
}

-- Initialize permissions system
function QS.Permissions.Initialize()
    print("[QuickSilver] Permission system initialized")
end

-- Check if caller is server console
function QS.Permissions.IsConsole(caller)
    return not IsValid(caller) or caller == NULL
end

-- Load player permissions on spawn
function QS.Permissions.LoadPlayer(ply)
    local data = QS.Data.LoadPlayer(ply)
    if data then
        -- Ensure player has a valid rank
        if not QS.Permissions.Ranks[data.rank] then
            data.rank = "user"
            QS.Data.SetPlayerData(ply, "rank", "user")
        end
    end
end

-- Check if player has permission (with console bypass)
function QS.Permissions.HasPermission(ply, permission)
    -- Console always has all permissions
    if QS.Permissions.IsConsole(ply) then
        return true
    end
    
    if not IsValid(ply) then return false end
    
    local data = QS.Data.GetPlayerData(ply)
    if not data then return false end
    
    local rank = QS.Permissions.Ranks[data.rank]
    if not rank then return false end
    
    -- Check for wildcard permission
    if table.HasValue(rank.permissions, "*") then
        return true
    end
    
    -- Check specific permission
    if table.HasValue(rank.permissions, permission) then
        return true
    end
    
    -- Check individual permissions
    if data.permissions and table.HasValue(data.permissions, permission) then
        return true
    end
    
    return false
end

-- Check if player can target another player (immunity check with console bypass)
function QS.Permissions.CanTarget(ply, target)
    -- Console can target anyone
    if QS.Permissions.IsConsole(ply) then
        return true
    end
    
    if not IsValid(ply) or not IsValid(target) then return false end
    if ply == target then return true end
    
    local ply_data = QS.Data.GetPlayerData(ply)
    local target_data = QS.Data.GetPlayerData(target)
    
    if not ply_data or not target_data then return false end
    
    local ply_rank = QS.Permissions.Ranks[ply_data.rank]
    local target_rank = QS.Permissions.Ranks[target_data.rank]
    
    if not ply_rank or not target_rank then return false end
    
    return ply_rank.immunity >= target_rank.immunity
end

-- Get player rank (with console handling)
function QS.Permissions.GetRank(ply)
    -- Console has maximum rank equivalent
    if QS.Permissions.IsConsole(ply) then
        return "console"
    end
    
    local data = QS.Data.GetPlayerData(ply)
    return data and data.rank or "user"
end

-- Set player rank (console can set any rank)
function QS.Permissions.SetRank(ply, rank)
    if not QS.Permissions.Ranks[rank] then
        return false, "Invalid rank"
    end
    
    local old_rank = QS.Permissions.GetRank(ply)
    QS.Data.SetPlayerData(ply, "rank", rank)
    
    -- Network update to client
    QS.Network.SendRankUpdate(ply, rank)
    
    -- Trigger CAMI hook if available
    hook.Run("QS_RankChanged", ply, old_rank, rank)
    
    return true
end

-- Add permission to player (console bypass)
function QS.Permissions.AddPermission(ply, permission)
    local data = QS.Data.GetPlayerData(ply)
    if not data then return false end
    
    data.permissions = data.permissions or {}
    if not table.HasValue(data.permissions, permission) then
        table.insert(data.permissions, permission)
        QS.Data.SetPlayerData(ply, "permissions", data.permissions)
        return true
    end
    
    return false
end

-- Remove permission from player (console bypass)
function QS.Permissions.RemovePermission(ply, permission)
    local data = QS.Data.GetPlayerData(ply)
    if not data or not data.permissions then return false end
    
    for i, perm in ipairs(data.permissions) do
        if perm == permission then
            table.remove(data.permissions, i)
            QS.Data.SetPlayerData(ply, "permissions", data.permissions)
            return true
        end
    end
    
    return false
end

-- Get all permissions for a player (console has all permissions)
function QS.Permissions.GetPlayerPermissions(ply)
    -- Console has all permissions
    if QS.Permissions.IsConsole(ply) then
        return {"*"}
    end
    
    local data = QS.Data.GetPlayerData(ply)
    if not data then return {} end
    
    local rank = QS.Permissions.Ranks[data.rank]
    local permissions = {}
    
    -- Add rank permissions
    if rank and rank.permissions then
        for _, perm in ipairs(rank.permissions) do
            table.insert(permissions, perm)
        end
    end
    
    -- Add individual permissions
    if data.permissions then
        for _, perm in ipairs(data.permissions) do
            if not table.HasValue(permissions, perm) then
                table.insert(permissions, perm)
            end
        end
    end
    
    return permissions
end

-- Get rank hierarchy for commands
function QS.Permissions.GetRankHierarchy()
    local ranks = {}
    for rank_id, rank_data in pairs(QS.Permissions.Ranks) do
        table.insert(ranks, {
            id = rank_id,
            name = rank_data.name,
            immunity = rank_data.immunity
        })
    end
    
    table.sort(ranks, function(a, b) return a.immunity > b.immunity end)
    return ranks
end

-- Utility function to check if rank exists
function QS.Permissions.RankExists(rank)
    return QS.Permissions.Ranks[rank] ~= nil
end

-- Get immunity level for console/player comparisons
function QS.Permissions.GetImmunity(ply)
    -- Console has maximum immunity
    if QS.Permissions.IsConsole(ply) then
        return math.huge
    end
    
    local data = QS.Data.GetPlayerData(ply)
    if not data then return 0 end
    
    local rank = QS.Permissions.Ranks[data.rank]
    return rank and rank.immunity or 0
end
}

network.lua{
-- QuickSilver Network System
-- Handles client-server communication

local QS = QuickSilver
QS.Network = QS.Network or {}

-- Initialize network system
function QS.Network.Initialize()
    if SERVER then
        -- Add network strings
        util.AddNetworkString("QS_RankUpdate")
        util.AddNetworkString("QS_PermissionUpdate")
        util.AddNetworkString("QS_SystemMessage")
        
        print("[QuickSilver] Network system initialized (server)")
    else
        -- Client-side network handlers
        net.Receive("QS_RankUpdate", QS.Network.ReceiveRankUpdate)
        net.Receive("QS_PermissionUpdate", QS.Network.ReceivePermissionUpdate)
        net.Receive("QS_SystemMessage", QS.Network.ReceiveSystemMessage)
        
        print("[QuickSilver] Network system initialized (client)")
    end
end

if SERVER then
    -- Send rank update to client
    function QS.Network.SendRankUpdate(ply, rank)
        net.Start("QS_RankUpdate")
        net.WriteString(rank)
        net.Send(ply)
    end
    
    -- Send permission update to client
    function QS.Network.SendPermissionUpdate(ply, permissions)
        net.Start("QS_PermissionUpdate")
        net.WriteTable(permissions)
        net.Send(ply)
    end
    
    -- Send system message to client(s)
    function QS.Network.SendSystemMessage(message, target)
        net.Start("QS_SystemMessage")
        net.WriteString(message)
        if target then
            net.Send(target)
        else
            net.Broadcast()
        end
    end
else
    -- Client network receivers
    function QS.Network.ReceiveRankUpdate()
        local rank = net.ReadString()
        -- Handle rank update on client
        print("[QuickSilver] Rank updated to: " .. rank)
    end
    
    function QS.Network.ReceivePermissionUpdate()
        local permissions = net.ReadTable()
        -- Handle permission update on client
        print("[QuickSilver] Permissions updated")
    end
    
    function QS.Network.ReceiveSystemMessage()
        local message = net.ReadString()
        chat.AddText(Color(100, 150, 255), "[QuickSilver] ", Color(255, 255, 255), message)
    end
end
}

example_extension_teleport.lua{
-- QuickSilver Teleport Extension
-- Provides teleportation commands with permission checking

-- Only run on server
if CLIENT then return end

-- Extension info
local EXTENSION_NAME = "Teleport"
local EXTENSION_VERSION = "1.0.0"

-- Print loading message
print("[QuickSilver] Loading " .. EXTENSION_NAME .. " extension v" .. EXTENSION_VERSION)

-- Register teleport command
QS.Commands.Register("tp", {
    permission = "teleport",
    description = "Teleport to player or teleport player to player",
    usage = "!tp <target> OR !tp <player1> <player2> | qs tp <target> OR qs tp <player1> <player2>",
    args_min = 1,
    args_max = 2,
    func = function(ply, args)
        
        if #args == 1 then
            -- Teleport caller to target: !tp <target>
            local target, err = QS.Commands.FindPlayer(ply, args[1])
            if not target then
                QS.Commands.Message(ply, err)
                return
            end
            
            if not IsValid(ply) then
                QS.Commands.Message(ply, "Console cannot teleport")
                return
            end
            
            if ply == target then
                QS.Commands.Message(ply, "Cannot teleport to yourself")
                return
            end
            
            -- Perform teleport
            local pos = target:GetPos()
            local ang = target:GetAngles()
            
            ply:SetPos(pos + Vector(0, 0, 5)) -- Slight offset to avoid getting stuck
            ply:SetAngles(Angle(0, ang.y, 0))
            
            QS.Commands.Message(ply, "Teleported to " .. target:Name())
            
        elseif #args == 2 then
            -- Teleport player1 to player2: !tp <player1> <player2>
            local player1, err1 = QS.Commands.FindPlayer(ply, args[1])
            if not player1 then
                QS.Commands.Message(ply, "Player1: " .. err1)
                return
            end
            
            local player2, err2 = QS.Commands.FindPlayer(ply, args[2])
            if not player2 then
                QS.Commands.Message(ply, "Player2: " .. err2)
                return
            end
            
            if player1 == player2 then
                QS.Commands.Message(ply, "Cannot teleport player to themselves")
                return
            end
            
            -- Check if teleporting someone other than self
            if IsValid(ply) and player1 ~= ply then
                -- Check for teleport others permission
                if not QS.Permissions.HasPermission(ply, "teleport.others") then
                    QS.Commands.Message(ply, "You need 'teleport.others' permission to teleport other players")
                    return
                end
                
                -- Check immunity/rank hierarchy
                if not QS.Permissions.CanTarget(ply, player1) then
                    QS.Commands.Message(ply, "You cannot teleport " .. player1:Name() .. " (insufficient rank)")
                    return
                end
            end
            
            -- Perform teleport
            local pos = player2:GetPos()
            local ang = player2:GetAngles()
            
            player1:SetPos(pos + Vector(0, 0, 5)) -- Slight offset to avoid getting stuck
            player1:SetAngles(Angle(0, ang.y, 0))
            
            -- Send messages
            QS.Commands.Message(ply, "Teleported " .. player1:Name() .. " to " .. player2:Name())
            
            if player1 ~= ply then
                QS.Commands.Message(player1, "You have been teleported to " .. player2:Name() .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
            end
            
            if player2 ~= ply and player2 ~= player1 then
                QS.Commands.Message(player2, player1:Name() .. " has been teleported to you by " .. (IsValid(ply) and ply:Name() or "Console"))
            end
        end
    end
})

-- Register bring command (teleport target to caller)
QS.Commands.Register("bring", {
    permission = "teleport.others",
    description = "Teleport target player to your location",
    usage = "!bring <target> | qs bring <target>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        if not IsValid(ply) then
            QS.Commands.Message(ply, "Console cannot use bring command")
            return
        end
        
        local target, err = QS.Commands.FindPlayer(ply, args[1])
        if not target then
            QS.Commands.Message(ply, err)
            return
        end
        
        if ply == target then
            QS.Commands.Message(ply, "Cannot bring yourself")
            return
        end
        
        -- Check immunity
        if not QS.Permissions.CanTarget(ply, target) then
            QS.Commands.Message(ply, "You cannot bring " .. target:Name() .. " (insufficient rank)")
            return
        end
        
        -- Perform teleport
        local pos = ply:GetPos()
        local ang = ply:GetAngles()
        
        target:SetPos(pos + ply:GetForward() * 100) -- Place in front of caller
        target:SetAngles(Angle(0, ang.y + 180, 0)) -- Face towards caller
        
        QS.Commands.Message(ply, "Brought " .. target:Name() .. " to your location")
        QS.Commands.Message(target, "You have been teleported to " .. ply:Name())
    end
})

-- Register goto command (teleport to coordinates)
QS.Commands.Register("goto", {
    permission = "teleport",
    description = "Teleport to coordinates",
    usage = "!goto <x> <y> <z> | qs goto <x> <y> <z>",
    args_min = 3,
    args_max = 3,
    func = function(ply, args)
        if not IsValid(ply) then
            QS.Commands.Message(ply, "Console cannot teleport")
            return
        end
        
        local x = tonumber(args[1])
        local y = tonumber(args[2])
        local z = tonumber(args[3])
        
        if not x or not y or not z then
            QS.Commands.Message(ply, "Invalid coordinates. Use numbers only.")
            return
        end
        
        local pos = Vector(x, y, z)
        ply:SetPos(pos)
        
        QS.Commands.Message(ply, string.format("Teleported to coordinates: %.0f, %.0f, %.0f", x, y, z))
    end
})

-- Cleanup function (called when extension is unloaded)
function QS_TELEPORT_CLEANUP()
    -- Remove any hooks or timers specific to this extension
    print("[QuickSilver] Teleport extension cleanup completed")
end

print("[QuickSilver] " .. EXTENSION_NAME .. " extension loaded successfully")
}

while my example does not work entirely. that is the type of functionality i am after