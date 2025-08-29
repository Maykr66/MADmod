MAD.Ranks = MAD.Ranks or {}

local ranks = {}
MAD.Ranks.DefaultTemplate = {
    order = 1.0,
    color = {
        r = 128,
        g = 128,
        b = 128,
        a = 255
    },
    superadmin = false,
    only_target_self = true,
    restrictions = {
        Weaps = {},
        Tools = {},
        Sents = {}
    },
    privileges = {},
    title = "Default",
    admin = false,
    immunity = 1.0
}

function MAD.Ranks.Initialize()
    -- Register rank management commands
    MAD.Commands.Register({
        name = "setrank",
        privilege = "setrank_players",
        description = "Set a player's rank",
        syntax = "setrank <player> <rank>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: setrank <player> <rank>"
            end
            
            local targetPlayer = MAD.Utils.FindPlayer(args[1])
            if not targetPlayer then
                return "Player '" .. args[1] .. "' not found"
            end
            
            local newRank = args[2]
            if not MAD.Ranks.Exists(newRank) then
                return "Rank '" .. newRank .. "' does not exist"
            end
            
            -- Check targeting permissions
            if IsValid(caller) then
                local canTarget = MAD.Players.CanTarget(caller:SteamID64(), targetPlayer:SteamID64())
                if not canTarget then
                    return "You cannot target this player"
                end
            end
            
            local callerName = IsValid(caller) and caller:Nick() or "Console"
            local success, error = MAD.Players.SetRank(targetPlayer:SteamID64(), newRank, callerName)
            
            if success then
                return string.format("Set %s's rank to '%s'", targetPlayer:Nick(), newRank)
            else
                return "Failed to set rank: " .. (error or "Unknown error")
            end
        end
    })
    
    MAD.Commands.Register({
        name = "listranks",
        privilege = "view_ranks",
        description = "List all ranks with player counts",
        syntax = "listranks",
        callback = function(caller, args, silent)
            local allRanks = MAD.Ranks.GetAll()
            if table.IsEmpty(allRanks) then
                return "No ranks found"
            end
            
            local rankList = {}
            for rankName, rankData in pairs(allRanks) do
                local playerCount = MAD.Ranks.CountPlayersWithRank(rankName)
                local immunityStr = string.format("%.1f", rankData.immunity or 1.0)
                local flags = {}
                
                if rankData.admin then table.insert(flags, "Admin") end
                if rankData.superadmin then table.insert(flags, "SuperAdmin") end
                if rankData.only_target_self then table.insert(flags, "SelfOnly") end
                
                local flagStr = #flags > 0 and (" [" .. table.concat(flags, ", ") .. "]") or ""
                
                table.insert(rankList, string.format("  %s: %s (%d players, immunity: %s)%s", 
                    rankName, rankData.title or rankName, playerCount, immunityStr, flagStr))
            end
            
            table.sort(rankList)
            return "Available ranks (" .. table.Count(allRanks) .. "):\n" .. table.concat(rankList, "\n")
        end
    })
    
    MAD.Commands.Register({
        name = "rankinfo",
        privilege = "view_ranks", 
        description = "Show detailed information about a rank",
        syntax = "rankinfo <rank>",
        callback = function(caller, args, silent)
            if #args < 1 then
                return "Usage: rankinfo <rank>"
            end
            
            local rankName = args[1]
            local rankData = MAD.Ranks.Get(rankName)
            
            if not rankData then
                return "Rank '" .. rankName .. "' not found"
            end
            
            local info = {}
            table.insert(info, "Rank: " .. rankName)
            table.insert(info, "Title: " .. (rankData.title or rankName))
            table.insert(info, "Immunity: " .. string.format("%.1f", rankData.immunity or 1.0))
            table.insert(info, "Admin: " .. (rankData.admin and "Yes" or "No"))
            table.insert(info, "SuperAdmin: " .. (rankData.superadmin and "Yes" or "No"))
            table.insert(info, "Only Target Self: " .. (rankData.only_target_self and "Yes" or "No"))
            table.insert(info, "Player Count: " .. MAD.Ranks.CountPlayersWithRank(rankName))
            
            -- Show privileges
            local privileges = rankData.privileges or {}
            if #privileges > 0 then
                table.insert(info, "Privileges (" .. #privileges .. "):")
                for _, priv in ipairs(privileges) do
                    table.insert(info, "  - " .. priv)
                end
            else
                table.insert(info, "Privileges: None")
            end
            
            return table.concat(info, "\n")
        end
    })
    
    MAD.Log.Info("Ranks system initialized")
end

function MAD.Ranks.Create(name, data)
    if ranks[name] then
        MAD.Log.Warning("Rank '" .. name .. "' already exists, overwriting")
    end
    
    local rankData = table.Merge(table.Copy(MAD.Ranks.DefaultTemplate), data or {})
    ranks[name] = rankData
    
    MAD.Data.SaveRank(name, rankData)
    MAD.Log.Info("Created rank: " .. name)
    
    return true
end

function MAD.Ranks.Delete(name)
    if name == "default" then
        return false, "Cannot delete default rank"
    end
    
    if not ranks[name] then
        return false, "Rank does not exist"
    end
    
    ranks[name] = nil
    MAD.Data.DeleteRank(name)
    MAD.Log.Info("Deleted rank: " .. name)
    
    return true
end

function MAD.Ranks.Get(name)
    return ranks[name] and table.Copy(ranks[name]) or nil
end

function MAD.Ranks.GetAll()
    return table.Copy(ranks)
end

function MAD.Ranks.Exists(name)
    return ranks[name] ~= nil
end

function MAD.Ranks.Update(name, data)
    if not ranks[name] then return false end
    
    table.Merge(ranks[name], data)
    MAD.Data.SaveRank(name, ranks[name])
    MAD.Log.Info("Updated rank: " .. name)
    
    return true
end

function MAD.Ranks.Copy(fromRank, toRank)
    if not ranks[fromRank] then return false, "Source rank does not exist" end
    if ranks[toRank] then return false, "Target rank already exists" end
    
    local newRankData = table.Copy(ranks[fromRank])
    newRankData.title = toRank
    
    return MAD.Ranks.Create(toRank, newRankData)
end

function MAD.Ranks.AddPrivilege(rankName, privilege)
    if not ranks[rankName] then return false end
    
    local privileges = ranks[rankName].privileges or {}
    if not table.HasValue(privileges, privilege) then
        table.insert(privileges, privilege)
        ranks[rankName].privileges = privileges
        MAD.Data.SaveRank(rankName, ranks[rankName])
        MAD.Log.Info("Added privilege '" .. privilege .. "' to rank '" .. rankName .. "'")
    end
    
    return true
end

function MAD.Ranks.RemovePrivilege(rankName, privilege)
    if not ranks[rankName] then return false end
    
    local privileges = ranks[rankName].privileges or {}
    local index = table.KeyFromValue(privileges, privilege)
    if index then
        table.remove(privileges, index)
        ranks[rankName].privileges = privileges
        MAD.Data.SaveRank(rankName, ranks[rankName])
        MAD.Log.Info("Removed privilege '" .. privilege .. "' from rank '" .. rankName .. "'")
    end
    
    return true
end

function MAD.Ranks.LoadAll()
    -- Use data layer to load all ranks
    local files, _ = file.Find("madmod/Ranks/*.txt", "DATA")
    
    for _, fileName in pairs(files or {}) do
        local rankName = string.StripExtension(fileName)
        local rankData = MAD.Data.LoadRank(rankName)
        if rankData then
            ranks[rankName] = rankData
            MAD.Log.Info("Loaded rank: " .. rankName)
        end
    end
    
    -- Ensure default rank exists (create if not)
    if not ranks.default then
        if not MAD.Utils.FileExists("madmod/Ranks/default.txt") then
            -- Create default rank file and load it
            MAD.Ranks.Create("default", MAD.Ranks.DefaultTemplate)
            MAD.Log.Info("Created default rank from template")
        else
            -- File exists but failed to load, try loading it directly
            local defaultData = MAD.Data.LoadRank("default")
            if defaultData then
                ranks.default = defaultData
                MAD.Log.Info("Loaded existing default rank")
            else
                MAD.Log.Error("Failed to load default.txt, creating new default rank")
                MAD.Ranks.Create("default", MAD.Ranks.DefaultTemplate)
            end
        end
    else
        MAD.Log.Info("Default rank already loaded")
    end
    
    MAD.Log.Info("Ranks system loaded with " .. table.Count(ranks) .. " ranks")
end

-- players with specific rank count
function MAD.Ranks.CountPlayersWithRank(rankName)
    local count = 0
    local files, _ = file.Find("madmod/Players/*.txt", "DATA")
    
    for _, fileName in pairs(files or {}) do
        local steamid64 = string.StripExtension(fileName)
        local playerData = MAD.Data.LoadPlayer(steamid64)
        if playerData and playerData.rank == rankName then
            count = count + 1
        end
    end
    
    -- online players count
    for _, ply in pairs(player.GetAll()) do
        local playerRank = MAD.Players.GetRank(ply:SteamID64())
        if playerRank == rankName then
            count = count + 1
        end
    end
    
    return count
end