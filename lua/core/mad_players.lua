MAD.Players = MAD.Players or {}

local playerData = {}
local playTime = {}

local defaultPlayerData = {
    rank = "default",
    ban = {
        active = false,
        time_remaining = 0,
        permanent = false,
        reason = ""
    },
    time_played = 0,
    last_joined = "",
    steam_name = ""
}

function MAD.Players.Initialize()
    -- Register player management commands
    MAD.Commands.Register({
        name = "kick",
        privilege = "kick_players",
        description = "Kick a player from the server",
        syntax = "kick <player> [reason]",
        callback = function(caller, args, silent)
            if #args < 1 then
                return "Usage: kick <player> [reason]"
            end
            
            local targetPlayer = MAD.Utils.FindPlayer(args[1])
            if not targetPlayer then
                return "Player '" .. args[1] .. "' not found"
            end
            
            -- Check targeting permissions
            if IsValid(caller) then
                local canTarget = MAD.Players.CanTarget(caller:SteamID64(), targetPlayer:SteamID64())
                if not canTarget then
                    return "You cannot target this player"
                end
            end
            
            local reason = #args > 1 and table.concat(args, " ", 2) or "No reason specified"
            local callerName = IsValid(caller) and caller:Nick() or "Console"
            
            MAD.Log.Info(string.format("%s kicked %s (%s) - Reason: %s", 
                callerName, targetPlayer:Nick(), targetPlayer:SteamID(), reason))
            
            targetPlayer:Kick("Kicked by " .. callerName .. " - " .. reason)
            
            return string.format("Kicked %s - Reason: %s", targetPlayer:Nick(), reason)
        end
    })
    
    MAD.Commands.Register({
        name = "ban",
        privilege = "ban_players",
        description = "Ban a player (time in minutes, 0 for permanent)",
        syntax = "ban <player> <time_minutes> <reason>",
        callback = function(caller, args, silent)
            if #args < 3 then
                return "Usage: ban <player> <time_minutes> <reason>"
            end
            
            local targetPlayer = MAD.Utils.FindPlayer(args[1])
            if not targetPlayer then
                return "Player '" .. args[1] .. "' not found"
            end
            
            -- Check targeting permissions
            if IsValid(caller) then
                local canTarget = MAD.Players.CanTarget(caller:SteamID64(), targetPlayer:SteamID64())
                if not canTarget then
                    return "You cannot target this player"
                end
            end
            
            local timeMinutes = tonumber(args[2])
            if not timeMinutes or timeMinutes < 0 then
                return "Invalid time. Use 0 for permanent ban or positive number for minutes"
            end
            
            local reason = table.concat(args, " ", 3)
            local callerName = IsValid(caller) and caller:Nick() or "Console"
            
            local success, message = MAD.Players.BanPlayer(targetPlayer:SteamID64(), timeMinutes, reason, callerName)
            
            if success then
                targetPlayer:Kick("Banned by " .. callerName .. " - " .. reason)
                return message
            else
                return "Failed to ban player: " .. message
            end
        end
    })
    
    MAD.Commands.Register({
        name = "unban",
        privilege = "ban_players",
        description = "Unban a player by SteamID64",
        syntax = "unban <steamid64>",
        callback = function(caller, args, silent)
            if #args < 1 then
                return "Usage: unban <steamid64>"
            end
            
            local steamid64 = args[1]
            if not string.match(steamid64, "^%d+$") or string.len(steamid64) ~= 17 then
                return "Invalid SteamID64 format"
            end
            
            local callerName = IsValid(caller) and caller:Nick() or "Console"
            local success, message = MAD.Players.UnbanPlayer(steamid64, callerName)
            
            if success then
                return message
            else
                return "Failed to unban player: " .. message
            end
        end
    })
    
    MAD.Commands.Register({
        name = "banlist",
        privilege = "ban_players",
        description = "Show list of banned players",
        syntax = "banlist",
        callback = function(caller, args, silent)
            local bannedPlayers = MAD.Players.GetBannedPlayers()
            
            if #bannedPlayers == 0 then
                return "No banned players"
            end
            
            local result = "Banned players (" .. #bannedPlayers .. "):\n"
            
            for _, ban in ipairs(bannedPlayers) do
                local timeStr = ban.permanent and "Permanent" or 
                    string.format("%.1f minutes remaining", ban.time_remaining / 60)
                result = result .. string.format("  %s (%s) - %s - %s\n", 
                    ban.steam_name or "Unknown", ban.steamid64, timeStr, ban.reason or "No reason")
            end
            
            return result:sub(1, -2)
        end
    })
    
    MAD.Log.Info("Players system initialized")
end

function MAD.Players.GetData(steamid64)
    if not playerData[steamid64] then
        -- Try to load from file using data layer
        local data = MAD.Data.LoadPlayer(steamid64)
        if data then
            playerData[steamid64] = data
        else
            -- Create new player data
            playerData[steamid64] = table.Copy(defaultPlayerData)
            playerData[steamid64].last_joined = MAD.Utils.GetDateString()
        end
    end
    
    return table.Copy(playerData[steamid64])
end

function MAD.Players.SetData(steamid64, data)
    playerData[steamid64] = table.Merge(MAD.Players.GetData(steamid64), data)
    -- Use data layer for saving
    MAD.Data.SavePlayer(steamid64, playerData[steamid64])
end

function MAD.Players.GetAllLoaded()
    return table.Copy(playerData)
end

function MAD.Players.GetRank(steamid64)
    local data = MAD.Players.GetData(steamid64)
    return data.rank
end

function MAD.Players.SetRank(steamid64, rank, caller)
    if not MAD.Ranks.Exists(rank) then
        return false, "Rank does not exist"
    end
    
    local oldRank = MAD.Players.GetRank(steamid64)
    local data = MAD.Players.GetData(steamid64)
    data.rank = rank
    MAD.Players.SetData(steamid64, data)
    
    local ply = player.GetBySteamID64(steamid64)
    if IsValid(ply) then
        -- Update Garry's Mod usergroup
        local rankData = MAD.Ranks.Get(rank)
        if rankData then
            if rankData.superadmin then
                ply:SetUserGroup("superadmin")
            elseif rankData.admin then
                ply:SetUserGroup("admin")
            else
                ply:SetUserGroup("user")
            end
        end
    end
    
    MAD.Log.Info(string.format("Player %s rank changed from '%s' to '%s'%s", 
        steamid64, oldRank, rank, caller and (" by " .. caller) or ""))
    
    return true
end

function MAD.Players.CanTarget(actorSteamID64, targetSteamID64)
    if actorSteamID64 == targetSteamID64 then return true end -- Self-targeting always allowed
    
    local actorRank = MAD.Players.GetRank(actorSteamID64)
    local targetRank = MAD.Players.GetRank(targetSteamID64)
    
    local actorRankData = MAD.Ranks.Get(actorRank)
    local targetRankData = MAD.Ranks.Get(targetRank)
    
    if not actorRankData or not targetRankData then return false end
    
    -- Check only_target_self restriction
    if actorRankData.only_target_self then return false end
    
    -- Check immunity levels
    return actorRankData.immunity > targetRankData.immunity
end

-- Ban system functions
function MAD.Players.BanPlayer(steamid64, timeMinutes, reason, bannerName)
    local data = MAD.Players.GetData(steamid64)
    
    local isPermanent = (timeMinutes == 0)
    local timeSeconds = isPermanent and 0 or (timeMinutes * 60)
    
    data.ban = {
        active = true,
        time_remaining = timeSeconds,
        permanent = isPermanent,
        reason = reason or "No reason specified"
    }
    
    MAD.Players.SetData(steamid64, data)
    
    local timeStr = isPermanent and "permanently" or ("for " .. timeMinutes .. " minutes")
    MAD.Log.Info(string.format("%s banned %s %s - Reason: %s", 
        bannerName or "Console", steamid64, timeStr, reason or "No reason"))
    
    local message = string.format("Banned %s %s - Reason: %s", 
        data.steam_name or steamid64, timeStr, reason or "No reason")
    
    return true, message
end

function MAD.Players.UnbanPlayer(steamid64, unbannerName)
    local data = MAD.Players.GetData(steamid64)
    
    if not data.ban.active then
        return false, "Player is not banned"
    end
    
    data.ban = {
        active = false,
        time_remaining = 0,
        permanent = false,
        reason = ""
    }
    
    MAD.Players.SetData(steamid64, data)
    
    MAD.Log.Info(string.format("%s unbanned %s", unbannerName or "Console", steamid64))
    
    local message = string.format("Unbanned %s", data.steam_name or steamid64)
    return true, message
end

function MAD.Players.IsBanned(steamid64)
    local data = MAD.Players.GetData(steamid64)
    
    if not data.ban.active then
        return false, nil
    end
    
    -- Check if temporary ban has expired
    if not data.ban.permanent then
        if data.ban.time_remaining <= 0 then
            -- Ban expired, remove it
            data.ban.active = false
            data.ban.time_remaining = 0
            data.ban.reason = ""
            MAD.Players.SetData(steamid64, data)
            return false, nil
        end
    end
    
    return true, data.ban
end

function MAD.Players.GetBannedPlayers()
    local bannedPlayers = {}
    local files, _ = file.Find("madmod/Players/*.txt", "DATA")
    
    for _, fileName in pairs(files or {}) do
        local steamid64 = string.StripExtension(fileName)
        local isBanned, banData = MAD.Players.IsBanned(steamid64)
        
        if isBanned then
            local data = MAD.Players.GetData(steamid64)
            table.insert(bannedPlayers, {
                steamid64 = steamid64,
                steam_name = data.steam_name,
                permanent = banData.permanent,
                time_remaining = banData.time_remaining,
                reason = banData.reason
            })
        end
    end
    
    return bannedPlayers
end

-- Update ban times for online players
function MAD.Players.UpdateBanTimes()
    for steamid64, _ in pairs(playerData) do
        local data = playerData[steamid64]
        
        if data and data.ban and data.ban.active and not data.ban.permanent then
            if data.ban.time_remaining > 0 then
                data.ban.time_remaining = data.ban.time_remaining - 1
                
                if data.ban.time_remaining <= 0 then
                    -- Ban expired
                    data.ban.active = false
                    data.ban.time_remaining = 0
                    data.ban.reason = ""
                    
                    MAD.Log.Info("Ban expired for player: " .. steamid64)
                end
            end
        end
    end
end

function MAD.Players.LoadPlayer(ply)
    if not IsValid(ply) then return end
    
    local steamid64 = ply:SteamID64()
    
    -- Check if player is banned before allowing connection
    local isBanned, banData = MAD.Players.IsBanned(steamid64)
    if isBanned then
        local kickMsg = "You are banned from this server"
        
        if banData.permanent then
            kickMsg = kickMsg .. " permanently"
        else
            local minutesLeft = math.ceil(banData.time_remaining / 60)
            kickMsg = kickMsg .. " for " .. minutesLeft .. " more minutes"
        end
        
        if banData.reason and banData.reason ~= "" then
            kickMsg = kickMsg .. " - Reason: " .. banData.reason
        end
        
        ply:Kick(kickMsg)
        MAD.Log.Info(string.format("Banned player %s (%s) attempted to connect", ply:Nick(), steamid64))
        return
    end
    
    -- Load/create player data
    local data = MAD.Players.GetData(steamid64)
    data.steam_name = ply:Nick()
    data.last_joined = MAD.Utils.GetDateString()
    MAD.Players.SetData(steamid64, data)
    
    -- Set usergroup based on rank
    local rankData = MAD.Ranks.Get(data.rank)
    if rankData then
        if rankData.superadmin then
            ply:SetUserGroup("superadmin")
        elseif rankData.admin then
            ply:SetUserGroup("admin")
        else
            ply:SetUserGroup("user")
        end
    end
    
    -- Start time tracking
    playTime[steamid64] = CurTime()
    
    -- Log connection
    MAD.Log.Player("connect", ply, "from " .. (ply:IPAddress() or "unknown"))
    MAD.Log.Info(string.format("%s (%s) connected", ply:Name(), ply:SteamID()))
end

function MAD.Players.SavePlayer(ply)
    if not IsValid(ply) then return end
    
    local steamid64 = ply:SteamID64()
    
    -- Update play time
    if playTime[steamid64] then
        local sessionTime = CurTime() - playTime[steamid64]
        local data = MAD.Players.GetData(steamid64)
        data.time_played = (data.time_played or 0) + sessionTime
        MAD.Players.SetData(steamid64, data)
        playTime[steamid64] = nil
    end
    
    -- Log disconnection
    MAD.Log.Player("disconnect", ply)
    MAD.Log.Info(string.format("%s (%s) disconnected", ply:Name(), ply:SteamID()))
    
    -- Unload player data from memory after saving
    if playerData[steamid64] then
        playerData[steamid64] = nil
        MAD.Log.Info("Unloaded player data for: " .. steamid64)
    end
end

-- Player event hooks
if SERVER then
    hook.Add("PlayerInitialSpawn", "MAD_PlayerConnect", function(ply)
        MAD.Players.LoadPlayer(ply)
    end)
    
    hook.Add("PlayerDisconnected", "MAD_PlayerDisconnect", function(ply)
        MAD.Players.SavePlayer(ply)
    end)
    
    hook.Add("PlayerDeath", "MAD_LogPlayerDeath", function(victim, inflictor, attacker)
        MAD.Log.Player("death", victim, "killed by " .. (IsValid(attacker) and attacker:Nick() or "world"))
    end)

    hook.Add("PlayerSpawn", "MAD_LogPlayerSpawn", function(ply)
        MAD.Log.Player("spawn", ply)
    end)
    
    -- Timer to update ban times every second
    timer.Create("MAD_BanTimeUpdater", 1, 0, function()
        MAD.Players.UpdateBanTimes()
    end)
end