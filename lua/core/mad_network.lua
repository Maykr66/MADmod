-- MADmod Network System
-- Handles client-server communication

MAD.Network = MAD.Network or {}

-- Initialize network system
function MAD.Network.Initialize()
    if SERVER then
        -- Add network strings
        util.AddNetworkString("MAD_RankUpdate")
        util.AddNetworkString("MAD_PermissionUpdate")
        util.AddNetworkString("MAD_SystemMessage")
        
        MAD.Log.Info("Network system initialized (server)")
    else
        -- Client-side network handlers
        net.Receive("MAD_RankUpdate", MAD.Network.ReceiveRankUpdate)
        net.Receive("MAD_PermissionUpdate", MAD.Network.ReceivePermissionUpdate)
        net.Receive("MAD_SystemMessage", MAD.Network.ReceiveSystemMessage)
        
        print("[MADmod] Network system initialized (client)")
    end
end

if SERVER then
    -- Send rank update to client
    function MAD.Network.SendRankUpdate(ply, rank)
        net.Start("MAD_RankUpdate")
        net.WriteString(rank)
        net.Send(ply)
    end
    
    -- Send permission update to client
    function MAD.Network.SendPermissionUpdate(ply, permissions)
        net.Start("MAD_PermissionUpdate")
        net.WriteTable(permissions)
        net.Send(ply)
    end
    
    -- Send system message to client(s)
    function MAD.Network.SendSystemMessage(message, target)
        net.Start("MAD_SystemMessage")
        net.WriteString(message)
        if target then
            net.Send(target)
        else
            net.Broadcast()
        end
    end
else
    -- Client network receivers
    function MAD.Network.ReceiveRankUpdate()
        local rank = net.ReadString()
        -- Handle rank update on client
        print("[MADmod] Rank updated to: " .. rank)
    end
    
    function MAD.Network.ReceivePermissionUpdate()
        local permissions = net.ReadTable()
        -- Handle permission update on client
        print("[MADmod] Permissions updated")
    end
    
    function MAD.Network.ReceiveSystemMessage()
        local message = net.ReadString()
        chat.AddText(Color(255, 100, 100), "[MADmod] ", Color(255, 255, 255), message)
    end
end