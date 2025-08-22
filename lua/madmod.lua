-- MADmod Admin System - Main Core
-- Lightweight server administration with hot-reloadable extensions

if SERVER then
    AddCSLuaFile()
end

-- Global MADmod namespace
MAD = MAD or {}
MAD.Version = "1.1.0" -- Updated version for hot reload capability
MAD.Extensions = MAD.Extensions or {}
MAD.Config = MAD.Config or {}

-- Include core modules
if SERVER then
    include("mad_utils.lua")
    include("core/mad_data.lua")
    include("core/mad_permissions.lua")
    include("core/mad_commands.lua")
    include("core/mad_extensions.lua")
    include("core/mad_network.lua")
    include("core/mad_log.lua")
    include("core/mad_hotreload.lua")
    include("core/mad_cami.lua") -- CAMI integration (self-initializing)
    --include("core/mad_cppi.lua") -- Optional CPPI integration
else
    include("mad_utils.lua")
    include("core/mad_network.lua")
end

-- Add client files
if SERVER then
    AddCSLuaFile("mad_utils.lua")
    AddCSLuaFile("core/mad_network.lua")
end

-- Initialize MADmod
function MAD.Initialize()
    if SERVER then
        MAD.Log.Initialize()
        MAD.Log.Info("Initializing MADmod v" .. MAD.Version .. " server-side...")
        
        -- Initialize core systems (skip logging as it's already initialized)
        MAD.Data.Initialize()
        MAD.Permissions.Initialize()
        MAD.Commands.Initialize()
        MAD.Network.Initialize()
        MAD.Extensions.Initialize()
        MAD.HotReload.Initialize()
        --MAD.CPPI.Initialize()
        
        -- Load saved data
        MAD.Data.Load()
        
        -- Start auto-save timer
        MAD.StartAutoSave()
        
        MAD.Log.Info("Server initialization complete!")
    else
        print("[MADmod] Initializing client-side...")
        MAD.Network.Initialize()
        print("[MADmod] Client initialization complete!")
    end
end

-- Auto-save functionality
function MAD.StartAutoSave()
    if SERVER then
        timer.Create("MAD_AutoSave", 300, 0, function() -- Save every 5 minutes
            MAD.Data.Save()
        end)
    end
end

-- Shutdown cleanup
function MAD.Shutdown()
    if SERVER then
        MAD.Log.Info("Shutting down...")
        MAD.Data.Save()
        timer.Remove("MAD_AutoSave")
        
        -- Cleanup extensions
        if MAD.HotReload and MAD.HotReload.CleanupAllExtensions then
            MAD.HotReload.CleanupAllExtensions()
        end
    end
end

-- Initialize on addon load
hook.Add("Initialize", "MAD_Initialize", MAD.Initialize)
hook.Add("ShutDown", "MAD_Shutdown", MAD.Shutdown)

-- Player connection hooks
if SERVER then
    hook.Add("PlayerInitialSpawn", "MAD_PlayerConnect", function(ply)
        MAD.Data.LoadPlayer(ply)
        MAD.Log.Info(string.format("%s (%s) connected", ply:Name(), ply:SteamID()))
    end)
    
    hook.Add("PlayerDisconnected", "MAD_PlayerDisconnect", function(ply)
        MAD.Data.SavePlayer(ply)
        MAD.Log.Info(string.format("%s (%s) disconnected", ply:Name(), ply:SteamID()))
    end)
end