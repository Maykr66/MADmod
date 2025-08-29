-- MADmod Admin System - Lightweight server administration with hot-reloadable extensions

MAD = MAD or {}
MAD.Version = "3.2.0"
MAD.Extensions = MAD.Extensions or {}
MAD.Config = MAD.Config or {}

-- Load core modules
if SERVER then
    include("mad_utils.lua")
    include("core/mad_log.lua")
    include("core/mad_data.lua")
    include("core/mad_privileges.lua")
    include("core/mad_commands.lua")
    include("core/mad_ranks.lua")
    include("core/mad_players.lua")
    include("core/mad_network.lua")
    include("core/mad_extensions.lua")
else
    include("mad_utils.lua")
    include("core/mad_network.lua")
end

-- Init MADmod
function MAD.Initialize()
    if SERVER then
        MAD.Log.Initialize()
        MAD.Log.Info("Initializing MADmod v" .. MAD.Version .. " server-side...")
        
        MAD.Data.Initialize()
        MAD.Privileges.Initialize()
        MAD.Commands.Initialize()
        MAD.Ranks.Initialize()
        MAD.Ranks.LoadAll()

        MAD.Players.Initialize()
        MAD.Network.Initialize()
        MAD.Extensions.Initialize()
        

        MAD.StartAutoSave()
        
        MAD.Log.Success("Server initialization complete!")
    else
        print("[MADmod] Initializing client-side...")
        MAD.Network.Initialize()
        print("[MADmod] Client initialization complete!")
    end
end

-- Auto-save functionality
function MAD.StartAutoSave()
    if SERVER then
        local config = MAD.Data.GetConfig()
        local interval = config.autosave_interval or 300
        
        timer.Create("MAD_AutoSave", interval, 0, function()
            MAD.Data.SaveConfig()
            MAD.Data.SaveAllRanks()
            MAD.Data.SaveAllPlayers()
        end)
        
        MAD.Log.Info("Auto-save started (" .. interval .. " second intervals)")
    end
end

-- Shutdown cleanup
function MAD.Shutdown()
    if SERVER then
        MAD.Log.Info("Shutting down MADmod...")
        
        MAD.Data.SaveConfig()
        MAD.Data.SaveAllRanks()
        MAD.Data.SaveAllPlayers()
        
        if MAD.Extensions and MAD.Extensions.CleanupAll then
            MAD.Extensions.CleanupAll()
        end
        
        MAD.Log.Info("Shutdown complete")
    end
end

hook.Add("Initialize", "MAD_Initialize", MAD.Initialize)
hook.Add("ShutDown", "MAD_Shutdown", MAD.Shutdown)