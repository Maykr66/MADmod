MAD.CAMI = MAD.CAMI or {}

-- CAMI Compatibility Layer
local CAMI_USERGROUP = {}
local CAMI_PRIVILEGE = {}

function MAD.CAMI.Initialize()
    -- Override existing CAMI if present
    if CAMI then
        MAD.Log.Info("Overriding existing CAMI implementation")
    end

    CAMI = {
        Version = 20211019
    }

    -- Convert MAD rank to CAMI usergroup
    local function RankToUsergroup(rankName, rankData)
        local inherits = "user"
        if rankData.superadmin then
            inherits = "superadmin"
        elseif rankData.admin then
            inherits = "admin"
        end
        
        return {
            Name = rankName,
            Inherits = inherits,
            CAMI_Source = "MADmod"
        }
    end

    -- Convert MAD privilege to CAMI privilege
    local function PrivilegeToCami(privName, privData)
        return {
            Name = privName,
            MinAccess = "user", -- MAD handles access differently
            Description = privData.description or ""
        }
    end

    function CAMI.RegisterUsergroup(usergroup, source)
        -- MAD doesn't need to register usergroups from external sources
        -- since it manages its own rank system
        hook.Call("CAMI.OnUsergroupRegistered", nil, usergroup, source)
        return usergroup
    end

    function CAMI.UnregisterUsergroup(usergroupName, source)
        hook.Call("CAMI.OnUsergroupUnregistered", nil, {Name = usergroupName}, source)
        return true
    end

    function CAMI.GetUsergroups()
        local usergroups = {}
        
        -- Always include base groups with proper inheritance
        usergroups.user = {Name = "user", Inherits = "user", CAMI_Source = "Garry's Mod"}
        usergroups.admin = {Name = "admin", Inherits = "user", CAMI_Source = "Garry's Mod"}  
        usergroups.superadmin = {Name = "superadmin", Inherits = "admin", CAMI_Source = "Garry's Mod"}
        
        -- Add MAD ranks
        local ranks = MAD.Ranks.GetAll()
        for rankName, rankData in pairs(ranks) do
            usergroups[rankName] = RankToUsergroup(rankName, rankData)
        end
        
        return usergroups
    end

    function CAMI.GetUsergroup(usergroupName)
        local ranks = MAD.Ranks.GetAll()
        if ranks[usergroupName] then
            return RankToUsergroup(usergroupName, ranks[usergroupName])
        end
        
        -- Return base groups
        if usergroupName == "user" then
            return {Name = "user", Inherits = "user", CAMI_Source = "Garry's Mod"}
        elseif usergroupName == "admin" then
            return {Name = "admin", Inherits = "user", CAMI_Source = "Garry's Mod"}
        elseif usergroupName == "superadmin" then
            return {Name = "superadmin", Inherits = "admin", CAMI_Source = "Garry's Mod"}
        end
        
        return nil
    end

    function CAMI.UsergroupInherits(usergroupName, potentialAncestor)
        -- Self-inheritance
        if usergroupName == potentialAncestor then return true end
        
        -- All groups inherit from user
        if potentialAncestor == "user" then return true end
        
        -- Check MAD rank data for admin/superadmin inheritance
        local rankData = MAD.Ranks.Get(usergroupName)
        if rankData then
            -- If checking for admin inheritance and rank has admin or superadmin flag
            if potentialAncestor == "admin" and (rankData.admin or rankData.superadmin) then
                return true
            end
            -- If checking for superadmin inheritance and rank has superadmin flag
            if potentialAncestor == "superadmin" and rankData.superadmin then
                return true
            end
        else
            -- Handle base groups
            if usergroupName == "admin" and potentialAncestor == "user" then return true end
            if usergroupName == "superadmin" and (potentialAncestor == "user" or potentialAncestor == "admin") then return true end
        end
        
        return false
    end

    function CAMI.InheritanceRoot(usergroupName)
        -- Handle base groups
        if usergroupName == "user" then return "user" end
        if usergroupName == "admin" then return "user" end
        if usergroupName == "superadmin" then return "user" end
        
        -- Handle MAD ranks - all ultimately inherit from user
        local rankData = MAD.Ranks.Get(usergroupName)
        if not rankData then return "user" end
        
        -- All MAD ranks are based on user, regardless of admin/superadmin flags
        -- The flags only affect inheritance chain, not the root
        return "user"
    end

    function CAMI.RegisterPrivilege(privilege)
        MAD.Privileges.Register(privilege.Name, privilege.Description)
        hook.Call("CAMI.OnPrivilegeRegistered", nil, privilege)
        return privilege
    end

    function CAMI.UnregisterPrivilege(privilegeName)
        local success = MAD.Privileges.Unregister(privilegeName)
        if success then
            hook.Call("CAMI.OnPrivilegeUnregistered", nil, {Name = privilegeName})
        end
        return success
    end

    function CAMI.GetPrivileges()
        local privileges = {}
        local madPrivileges = MAD.Privileges.GetAll()
        
        for privName, privData in pairs(madPrivileges) do
            privileges[privName] = PrivilegeToCami(privName, privData)
        end
        
        return privileges
    end

    function CAMI.GetPrivilege(privilegeName)
        local privData = MAD.Privileges.Get(privilegeName)
        if privData then
            return PrivilegeToCami(privilegeName, privData)
        end
        return nil
    end

    function CAMI.PlayerHasAccess(actorPly, privilegeName, callback, targetPly, extraInfoTbl)
        local hasAccess = false
        local reason = "Access denied"
        
        -- Console always has access
        if not IsValid(actorPly) then
            hasAccess = true
            reason = "Console access"
        else
            hasAccess = MAD.Privileges.HasAccess(actorPly, privilegeName)
            if hasAccess then
                -- Check targeting restrictions if target is specified
                if IsValid(targetPly) then
                    local canTarget = MAD.Players.CanTarget(actorPly:SteamID64(), targetPly:SteamID64())
                    if not canTarget then
                        hasAccess = false
                        reason = "Cannot target this player"
                    else
                        reason = "Access granted"
                    end
                else
                    reason = "Access granted"
                end
            end
        end
        
        if callback then
            callback(hasAccess, reason)
            return
        end
        
        return hasAccess, reason
    end

    function CAMI.GetPlayersWithAccess(privilegeName, callback, targetPly, extraInfoTbl)
        local allowedPlys = {}
        
        for _, ply in pairs(player.GetAll()) do
            if MAD.Privileges.HasAccess(ply, privilegeName) then
                if not IsValid(targetPly) or MAD.Players.CanTarget(ply:SteamID64(), targetPly:SteamID64()) then
                    table.insert(allowedPlys, ply)
                end
            end
        end
        
        callback(allowedPlys)
    end

    function CAMI.SteamIDHasAccess(actorSteam, privilegeName, callback, targetSteam, extraInfoTbl)
        -- MAD doesn't store offline player privileges, so return false for offline players
        local ply = player.GetBySteamID(actorSteam)
        if IsValid(ply) then
            CAMI.PlayerHasAccess(ply, privilegeName, callback, 
                targetSteam and player.GetBySteamID(targetSteam) or nil, extraInfoTbl)
        else
            callback(false, "Player not online")
        end
    end

    function CAMI.SignalUserGroupChanged(ply, old, new, source)
        hook.Call("CAMI.PlayerUsergroupChanged", nil, ply, old, new, source)
    end

    function CAMI.SignalSteamIDUserGroupChanged(steamId, old, new, source) 
        hook.Call("CAMI.SteamIDUsergroupChanged", nil, steamId, old, new, source)
    end

    -- Hook into MAD's rank change system to signal CAMI
    hook.Add("MAD.OnPlayerRankChanged", "MAD_CAMI_RankChanged", function(steamid64, oldRank, newRank)
        local ply = player.GetBySteamID64(steamid64)
        if IsValid(ply) then
            CAMI.SignalUserGroupChanged(ply, oldRank, newRank, "MADmod")
        else
            CAMI.SignalSteamIDUserGroupChanged(steamid64, oldRank, newRank, "MADmod")
        end
    end)

    MAD.Log.Info("CAMI compatibility layer initialized")
end