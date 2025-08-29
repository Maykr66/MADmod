MAD.Network = MAD.Network or {}

function MAD.Network.Initialize()
    if SERVER then
        -- Network strings for future client communication
        local networkStrings = {
            "mad_rank_update",
            "mad_player_update", 
            "mad_config_update"
        }

        for _, str in ipairs(networkStrings) do
            util.AddNetworkString(str)
        end
        
        MAD.Log.Info("Network system initialized (server)")
    else
        print("[MADmod] Network system initialized (client)")
    end
end

if SERVER then
    function MAD.Network.SendRankUpdate(ply, rankData)
        if not IsValid(ply) then return end
        
        net.Start("mad_rank_update")
        net.WriteTable(rankData or {})
        net.Send(ply)
    end

    function MAD.Network.SendPlayerUpdate(ply, playerData)
        if not IsValid(ply) then return end
        
        net.Start("mad_player_update") 
        net.WriteTable(playerData or {})
        net.Send(ply)
    end

    function MAD.Network.BroadcastConfigUpdate(config)
        net.Start("mad_config_update")
        net.WriteTable(config or {})
        net.Broadcast()
    end
end