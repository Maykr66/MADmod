-- MADmod Hot Reload System
-- Handles hot reloading of extensions and full system restart

MAD.HotReload = MAD.HotReload or {}

-- Initialize hot reload system
function MAD.HotReload.Initialize()
    MAD.HotReload.RegisterCommands()
    MAD.Log.Info("Hot reload system initialized")
end

-- Full system restart
function MAD.HotReload.RestartSystem()
    MAD.Log.Info("=== STARTING FULL SYSTEM RESTART ===")
    
    -- Save all data before restart
    MAD.Data.Save()
    
    -- Cleanup all extensions first
    MAD.HotReload.CleanupAllExtensions()
    
    -- Clear all registered commands except core ones
    MAD.HotReload.ClearNonCoreCommands()
    
    -- Remove all hooks except essential ones
    MAD.HotReload.CleanupHooks()
    
    -- Remove timers
    MAD.HotReload.CleanupTimers()
    
    -- Clear extension data
    MAD.Extensions.Loaded = {}
    MAD.Extensions.RegisteredPermissions = {}
    
    -- Clear command registration tracking
    MAD.Commands.RegisteredCommands = {}
    
    -- Reset logging initialization state
    MAD.Log.Reset()
    
    -- Reinitialize core systems
    MAD.Log.Info("Reinitializing core systems...")
    
    -- Reload core files
    MAD.HotReload.ReloadCoreFiles()
    
    -- Reinitialize systems
    MAD.Data.Initialize()
    MAD.Permissions.Initialize()
    MAD.Commands.Initialize()
    MAD.Network.Initialize()
    MAD.Extensions.Initialize()
    MAD.HotReload.Initialize() -- Reinitialize hot reload commands
    
    -- Reload data
    MAD.Data.Load()
    
    -- Restart auto-save
    MAD.StartAutoSave()
    
    MAD.Log.Info("=== FULL SYSTEM RESTART COMPLETE ===")
    
    -- Notify all players
    for _, ply in ipairs(player.GetAll()) do
        MAD.Commands.Message(ply, "MADmod system has been restarted")
    end
end

-- Reload only extensions
function MAD.HotReload.ReloadExtensions()
    MAD.Log.Info("=== STARTING EXTENSION RELOAD ===")
    
    -- Use existing extension reload functionality
    MAD.Extensions.ReloadAll()
    
    MAD.Log.Info("=== EXTENSION RELOAD COMPLETE ===")
    
    -- Notify all players
    for _, ply in ipairs(player.GetAll()) do
        MAD.Commands.Message(ply, "MADmod extensions have been reloaded")
    end
end

-- Cleanup all extensions
function MAD.HotReload.CleanupAllExtensions()
    MAD.Log.Info("Cleaning up all extensions...")
    
    for name, ext in pairs(MAD.Extensions.Loaded) do
        -- Call cleanup function if it exists
        local cleanup_func = _G["MAD_" .. string.upper(name) .. "_CLEANUP"]
        if cleanup_func and type(cleanup_func) == "function" then
            local success, err = pcall(cleanup_func)
            if not success then
                MAD.Log.Warning("Extension cleanup failed for " .. name .. ": " .. tostring(err))
            end
        end
    end
    
    MAD.Log.Info("Extension cleanup complete")
end

-- Clear non-core commands
function MAD.HotReload.ClearNonCoreCommands()
    MAD.Log.Info("Clearing non-core commands...")
    
    -- List of core commands that should not be removed
    local core_commands = {
        ["help"] = true,
        ["$reload$"] = true,
        ["status"] = true,
    }
    
    -- Remove non-core commands
    for cmd_name, _ in pairs(MAD.Commands.List) do
        if not core_commands[cmd_name] then
            MAD.Commands.List[cmd_name] = nil
            MAD.Commands.RegisteredCommands[cmd_name] = nil
        end
    end
    
    MAD.Log.Info("Non-core commands cleared")
end

-- Cleanup hooks (except essential ones)
function MAD.HotReload.CleanupHooks()
    MAD.Log.Info("Cleaning up hooks...")
    
    -- List of essential hooks that should not be removed
    local essential_hooks = {
        ["Initialize"] = {"MAD_Initialize"},
        ["ShutDown"] = {"MAD_Shutdown"},
        ["PlayerInitialSpawn"] = {"MAD_PlayerConnect"},
        ["PlayerDisconnected"] = {"MAD_PlayerDisconnect"},
        ["PlayerSay"] = {"MAD_ChatCommands"}
    }
    
    -- Remove non-essential hooks
    for event, hooks in pairs(essential_hooks) do
        local all_hooks = hook.GetTable()[event] or {}
        for hook_name, _ in pairs(all_hooks) do
            if not table.HasValue(hooks, hook_name) and string.StartWith(hook_name, "MAD_") then
                hook.Remove(event, hook_name)
                MAD.Log.Debug("Removed hook: " .. event .. " -> " .. hook_name)
            end
        end
    end
    
    MAD.Log.Info("Hook cleanup complete")
end

-- Cleanup timers
function MAD.HotReload.CleanupTimers()
    MAD.Log.Info("Cleaning up timers...")
    
    -- Remove MAD timers except auto-save
    local timers = timer.GetTimers()
    for _, timer_data in ipairs(timers) do
        if string.StartWith(timer_data.name, "MAD_") and timer_data.name ~= "MAD_AutoSave" then
            timer.Remove(timer_data.name)
            MAD.Log.Debug("Removed timer: " .. timer_data.name)
        end
    end
    
    -- Remove auto-save timer (will be recreated)
    timer.Remove("MAD_AutoSave")
    
    MAD.Log.Info("Timer cleanup complete")
end

-- Reload core files
function MAD.HotReload.ReloadCoreFiles()
    MAD.Log.Info("Reloading core files...")
    
    local core_files = {
        "core/mad_data.lua",
        "core/mad_permissions.lua", 
        "core/mad_commands.lua",
        "core/mad_extensions.lua",
        "core/mad_network.lua",
        "core/mad_log.lua"
    }
    
    for _, file in ipairs(core_files) do
        local success, err = pcall(include, file)
        if success then
            MAD.Log.Debug("Reloaded: " .. file)
            if SERVER then
                AddCSLuaFile(file)
            end
        else
            MAD.Log.Error("Failed to reload " .. file .. ": " .. tostring(err))
        end
    end
    
    MAD.Log.Info("Core file reload complete")
end

-- Register hot reload commands
function MAD.HotReload.RegisterCommands()
    -- Extension reload command
    MAD.Commands.Register("$reload$", {
        permission = "manage_extensions",
        description = "Reload all extensions",
        usage = "!$reload$ | mad $reload$",
        args_min = 0,
        args_max = 0,
        func = function(ply, args)
            MAD.Commands.Message(ply, "Reloading extensions...")
            
            -- Delay reload slightly to allow message to be sent
            timer.Simple(0.1, function()
                MAD.HotReload.ReloadExtensions()
            end)
        end
    }, true) -- Allow override
    
    -- Status command to check system state
    MAD.Commands.Register("status", {
        permission = "manage_server",
        description = "Show MADmod system status",
        usage = "!status | mad status",
        args_min = 0,
        args_max = 0,
        func = function(ply, args)
            local ext_status = MAD.Extensions.GetStatus()
            
            MAD.Commands.Message(ply, "=== MADmod System Status ===")
            MAD.Commands.Message(ply, "Version: " .. MAD.Version)
            MAD.Commands.Message(ply, "Extensions: " .. ext_status.loaded .. "/" .. ext_status.total .. " loaded")
            
            if ext_status.failed > 0 then
                MAD.Commands.Message(ply, "Failed extensions: " .. ext_status.failed)
                for _, ext in ipairs(ext_status.extensions) do
                    if not ext.loaded then
                        MAD.Commands.Message(ply, "  " .. ext.name .. ": " .. (ext.error or "Unknown error"))
                    end
                end
            end
            
            MAD.Commands.Message(ply, "Commands registered: " .. table.Count(MAD.Commands.List))
            MAD.Commands.Message(ply, "Players online: " .. #player.GetAll())
        end
    }, true) -- Allow override
end

-- Note: Hot reload system will be initialized by the main MADmod system