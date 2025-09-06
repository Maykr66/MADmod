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
    -- Register core rank management commands
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

    -- Advanced rank management commands (formerly from extension)
    MAD.Commands.Register({
        name = "addrank",
        privilege = "manage_ranks",
        description = "Create a new rank",
        syntax = "addrank <index> <title>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: addrank <index> <title>"
            end
            
            local rankName = args[1]
            if MAD.Ranks.Exists(rankName) then
                return "Rank '" .. rankName .. "' already exists"
            end
            
            local title = args[2]
            
            local rankData = table.Copy(MAD.Ranks.DefaultTemplate)
            rankData.title = title
            
            local success = MAD.Ranks.Create(rankName, rankData)
            if success then
                return string.format("Created rank '%s' with title '%s'", rankName, title)
            else
                return "Failed to create rank"
            end
        end
    })

    MAD.Commands.Register({
        name = "delrank",
        privilege = "manage_ranks",
        description = "Delete a rank",
        syntax = "delrank <rank>",
        callback = function(caller, args, silent)
            if #args < 1 then
                return "Usage: delrank <rank>"
            end
            
            local rankName = args[1]
            local success, error = MAD.Ranks.Delete(rankName)
            
            if success then
                return "Deleted rank '" .. rankName .. "'"
            else
                return "Failed to delete rank: " .. (error or "Unknown error")
            end
        end
    })

    MAD.Commands.Register({
        name = "copyrank",
        privilege = "manage_ranks",
        description = "Copy a rank to create a new one",
        syntax = "copyrank <source> <destination>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: copyrank <source> <destination>"
            end
            
            local sourceRank = args[1]
            local destRank = args[2]
            
            local success, error = MAD.Ranks.Copy(sourceRank, destRank)
            
            if success then
                return string.format("Copied rank '%s' to '%s'", sourceRank, destRank)
            else
                return "Failed to copy rank: " .. (error or "Unknown error")
            end
        end
    })

    MAD.Commands.Register({
        name = "addpriv",
        privilege = "manage_privileges",
        description = "Add a privilege to a rank",
        syntax = "addpriv <rank> <privilege>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: addpriv <rank> <privilege>"
            end
            
            local rankName = args[1]
            local privilege = args[2]
            
            if not MAD.Ranks.Exists(rankName) then
                return "Rank '" .. rankName .. "' does not exist"
            end
            
            local success = MAD.Ranks.AddPrivilege(rankName, privilege)
            
            if success then
                return string.format("Added privilege '%s' to rank '%s'", privilege, rankName)
            else
                return "Failed to add privilege"
            end
        end
    })

    MAD.Commands.Register({
        name = "removepriv",
        privilege = "manage_privileges",
        description = "Remove a privilege from a rank",
        syntax = "removepriv <rank> <privilege>",
        callback = function(caller, args, silent)
            if #args < 2 then
                return "Usage: removepriv <rank> <privilege>"
            end
            
            local rankName = args[1]
            local privilege = args[2]
            
            if not MAD.Ranks.Exists(rankName) then
                return "Rank '" .. rankName .. "' does not exist"
            end
            
            local success = MAD.Ranks.RemovePrivilege(rankName, privilege)
            
            if success then
                return string.format("Removed privilege '%s' from rank '%s'", privilege, rankName)
            else
                return "Failed to remove privilege"
            end
        end
    })

    MAD.Commands.Register({
        name = "listprivs",
        privilege = "view_ranks",
        description = "List all registered privileges",
        syntax = "listprivs",
        callback = function(caller, args, silent)
            local privileges = MAD.Privileges.GetAll()
            
            if table.IsEmpty(privileges) then
                return "No privileges registered"
            end
            
            local privList = {}
            for privName, privData in pairs(privileges) do
                local desc = privData.description
                if desc and desc ~= "" then
                    table.insert(privList, "  " .. privName .. " - " .. desc)
                else
                    table.insert(privList, "  " .. privName)
                end
            end
            
            table.sort(privList)
            
            local result = "Registered privileges (" .. table.Count(privileges) .. "):\n" .. table.concat(privList, "\n")
            return result
        end
    })

    MAD.Commands.Register({
        name = "rankprivs",
        privilege = "view_ranks",
        description = "Show privileges assigned to a rank",
        syntax = "rankprivs <rank>",
        callback = function(caller, args, silent)
            if #args < 1 then
                return "Usage: rankprivs <rank>"
            end
            
            local rankName = args[1]
            local rankData = MAD.Ranks.Get(rankName)
            
            if not rankData then
                return "Rank '" .. rankName .. "' not found"
            end
            
            local privileges = rankData.privileges or {}
            
            if #privileges == 0 then
                return "Rank '" .. rankName .. "' has no privileges assigned"
            end
            
            table.sort(privileges)
            local result = "Privileges for rank '" .. rankName .. "' (" .. #privileges .. "):\n"
            
            for _, priv in ipairs(privileges) do
                local privData = MAD.Privileges.Get(priv)
                if privData and privData.description ~= "" then
                    result = result .. "  " .. priv .. " - " .. privData.description .. "\n"
                else
                    result = result .. "  " .. priv .. "\n"
                end
            end
            
            return result:sub(1, -2)
        end
    })

    MAD.Commands.Register({
        name = "editrank",
        privilege = "manage_ranks",
        description = "Edit rank properties",
        syntax = "editrank <rank> <property> <value>",
        callback = function(caller, args, silent)
            if #args < 3 then
                return "Usage: editrank <rank> <property> <value>\nProperties: title, immunity, admin, superadmin, only_target_self"
            end
            
            local rankName = args[1]
            local property = string.lower(args[2])
            local value = args[3]
            
            if not MAD.Ranks.Exists(rankName) then
                return "Rank '" .. rankName .. "' does not exist"
            end
            
            local updateData = {}
            
            if property == "title" then
                updateData.title = value
            elseif property == "immunity" then
                local numValue = tonumber(value)
                if not numValue then
                    return "Immunity must be a number"
                end
                updateData.immunity = numValue
            elseif property == "admin" then
                updateData.admin = (string.lower(value) == "true" or value == "1")
            elseif property == "superadmin" then
                updateData.superadmin = (string.lower(value) == "true" or value == "1")
            elseif property == "only_target_self" then
                updateData.only_target_self = (string.lower(value) == "true" or value == "1")
            else
                return "Invalid property. Valid properties: title, immunity, admin, superadmin, only_target_self"
            end
            
            local success = MAD.Ranks.Update(rankName, updateData)
            
            if success then
                return string.format("Updated rank '%s': %s = %s", rankName, property, tostring(updateData[property]))
            else
                return "Failed to update rank"
            end
        end
    })
    
    MAD.Log.Info("Ranks system initialized with advanced management commands")
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