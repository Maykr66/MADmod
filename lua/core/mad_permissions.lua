-- MADmod Permission System
-- Handles player permissions and access control

MAD.Permissions = MAD.Permissions or {}

-- Initialize permissions system
function MAD.Permissions.Initialize()
    MAD.Log.Info("Permission system initialized")
end

-- Check if player has permission (with console bypass)
function MAD.Permissions.HasPermission(ply, permission)
    -- Console always has all permissions
    if not IsValid(ply) then return true end
    
    local data = MAD.Data.GetPlayerData(ply)
    if not data then return false end
    
    local rank_data = MAD.Data.GetRankData(data.rank)
    if not rank_data then return false end
    
    -- Superadmin has all permissions
    if rank_data.derived_from == "superadmin" then return true end
    
    -- Check for wildcard permission
    if table.HasValue(rank_data.permissions, "*") then
        return true
    end
    
    -- Check specific permission
    return table.HasValue(rank_data.permissions, permission)
end

-- Check if player can target another player (immunity check)
function MAD.Permissions.CanTarget(ply, target)
    -- Console can target anyone
    if not IsValid(ply) then return true end
    
    if not IsValid(target) then return false end
    if ply == target then return true end
    
    local ply_data = MAD.Data.GetPlayerData(ply)
    local target_data = MAD.Data.GetPlayerData(target)
    
    if not ply_data or not target_data then return false end
    
    local ply_rank = MAD.Data.GetRankData(ply_data.rank)
    local target_rank = MAD.Data.GetRankData(target_data.rank)
    
    if not ply_rank or not target_rank then return false end
    
    return ply_rank.immunity > target_rank.immunity
end

-- Get player rank
function MAD.Permissions.GetRank(ply)
    if not IsValid(ply) then return "console" end
    
    local data = MAD.Data.GetPlayerData(ply)
    return data and data.rank or "user"
end

-- Set player rank
function MAD.Permissions.SetRank(ply, rank)
    if not MAD.Data.Ranks[rank] then
        return false, "Invalid rank"
    end
    
    local old_rank = MAD.Permissions.GetRank(ply)
    local steamid = ply:SteamID64()
    
    if MAD.Data.PlayerData[steamid] then
        MAD.Data.PlayerData[steamid].rank = rank
        
        -- Network update to client
        MAD.Network.SendRankUpdate(ply, rank)
        
        -- Trigger CAMI hook if available
        hook.Run("MAD_RankChanged", ply, old_rank, rank)
        
        return true
    end
    
    return false, "Player data not found"
end

-- Get player immunity level
function MAD.Permissions.GetImmunity(ply)
    if not IsValid(ply) then return math.huge end
    
    local data = MAD.Data.GetPlayerData(ply)
    if not data then return 0 end
    
    local rank = MAD.Data.GetRankData(data.rank)
    return rank and rank.immunity or 0
end