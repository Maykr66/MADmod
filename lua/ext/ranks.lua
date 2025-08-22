-- MADmod Rank Management Extension
-- Provides comprehensive rank management commands

-- Only run on server
if CLIENT then return end

-- Default template rank for creating new ranks
local DEFAULT_TEMPLATE = {
    display_name = "New Rank",
    immunity = 0,
    order = 0,
    color = Color(150, 150, 150),
    permissions = {},
    derived_from = "user"
}

-- Protected ranks that cannot be deleted
local PROTECTED_RANKS = {
    ["user"] = true,
    ["admin"] = true,
    ["superadmin"] = true
}

-- Register addrank command
MAD.Commands.Register("addrank", {
    permission = "manage_ranks",
    description = "Create a new rank from template",
    usage = "!addrank <name> | mad addrank <name>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        
        -- Validate rank name
        if not rank_name:match("^[a-zA-Z0-9_]+$") then
            MAD.Message(ply, "Rank name can only contain letters, numbers, and underscores")
            return
        end
        
        if string.len(rank_name) > 32 then
            MAD.Message(ply, "Rank name too long (max 32 characters)")
            return
        end
        
        -- Check if rank already exists
        if MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. rank_name .. "' already exists")
            return
        end
        
        -- Create new rank from template
        MAD.Data.Ranks[rank_name] = table.Copy(DEFAULT_TEMPLATE)
        MAD.Data.Ranks[rank_name].display_name = args[1] -- Preserve original case for display
        MAD.Data.SaveRanks()
        
        MAD.Message(ply, "Created rank: " .. args[1])
        MAD.Log.Info(string.format("%s created rank: %s", IsValid(ply) and ply:Name() or "Console", args[1]))
    end
})

-- Register delrank command
MAD.Commands.Register("delrank", {
    permission = "manage_ranks",
    description = "Delete a rank",
    usage = "!delrank <name> | mad delrank <name>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        -- Check if rank is protected
        if PROTECTED_RANKS[rank_name] then
            MAD.Message(ply, "Cannot delete protected rank: " .. args[1])
            return
        end
        
        -- Check if any players currently have this rank
        local players_with_rank = {}
        for steamid, data in pairs(MAD.Data.PlayerData) do
            if data.rank == rank_name then
                table.insert(players_with_rank, data.last_name or data.name or steamid)
            end
        end
        
        if #players_with_rank > 0 then
            MAD.Message(ply, "Cannot delete rank - " .. #players_with_rank .. " players still have this rank:")
            MAD.Message(ply, table.concat(players_with_rank, ", "))
            return
        end
        
        -- Delete the rank
        MAD.Data.Ranks[rank_name] = nil
        MAD.Data.SaveRanks()
        
        MAD.Message(ply, "Deleted rank: " .. args[1])
        MAD.Log.Info(string.format("%s deleted rank: %s", IsValid(ply) and ply:Name() or "Console", args[1]))
    end
})

-- Register setrank command
MAD.Commands.Register("setrank", {
    permission = "manage_ranks",
    description = "Set a player's rank",
    usage = "!setrank <player> <rank> | mad setrank <player> <rank>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local target, err = MAD.FindPlayer(ply, args[1])
        if not target then
            MAD.Message(ply, err)
            return
        end
        
        local rank_name = string.lower(args[2])
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[2] .. "' does not exist")
            return
        end
        
        -- Check immunity (only if not console and not targeting self)
        if IsValid(ply) and ply ~= target then
            if not MAD.Permissions.CanTarget(ply, target) then
                MAD.Message(ply, "You cannot change " .. target:Name() .. "'s rank (insufficient immunity)")
                return
            end
            
            -- Check if trying to set rank higher than own
            local caller_immunity = MAD.Permissions.GetImmunity(ply)
            local target_rank_immunity = MAD.Data.Ranks[rank_name].immunity
            
            if target_rank_immunity >= caller_immunity then
                MAD.Message(ply, "Cannot set rank higher than or equal to your own")
                return
            end
        end
        
        local old_rank = MAD.Permissions.GetRank(target)
        local success, error_msg = MAD.Permissions.SetRank(target, rank_name)
        
        if success then
            MAD.Message(ply, string.format("Set %s's rank to %s (was %s)", target:Name(), args[2], old_rank))
            MAD.Message(target, string.format("Your rank has been set to %s by %s", args[2], IsValid(ply) and ply:Name() or "Console"))
            MAD.Log.Info(string.format("%s set %s's rank to %s (was %s)", IsValid(ply) and ply:Name() or "Console", target:Name(), args[2], old_rank))
        else
            MAD.Message(ply, "Failed to set rank: " .. error_msg)
        end
    end
})

-- Register copyrank command
MAD.Commands.Register("copyrank", {
    permission = "manage_ranks",
    description = "Copy one rank to another",
    usage = "!copyrank <source> <target> | mad copyrank <source> <target>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local source_name = string.lower(args[1])
        local target_name = string.lower(args[2])
        
        -- Check if source rank exists
        if not MAD.Data.Ranks[source_name] then
            MAD.Message(ply, "Source rank '" .. args[1] .. "' does not exist")
            return
        end
        
        -- Check if target rank exists
        if not MAD.Data.Ranks[target_name] then
            MAD.Message(ply, "Target rank '" .. args[2] .. "' does not exist")
            return
        end
        
        -- Check if target rank is protected
        if PROTECTED_RANKS[target_name] then
            MAD.Message(ply, "Cannot overwrite protected rank: " .. args[2])
            return
        end
        
        -- Copy the rank
        local source_rank = MAD.Data.Ranks[source_name]
        MAD.Data.Ranks[target_name] = table.Copy(source_rank)
        MAD.Data.Ranks[target_name].display_name = args[2] -- Preserve target's display name
        MAD.Data.SaveRanks()
        
        MAD.Message(ply, string.format("Copied rank %s to %s", args[1], args[2]))
        MAD.Log.Info(string.format("%s copied rank %s to %s", IsValid(ply) and ply:Name() or "Console", args[1], args[2]))
    end
})

-- Register addperm command
MAD.Commands.Register("addperm", {
    permission = "manage_ranks",
    description = "Add permission to a rank",
    usage = "!addperm <rank> <permission> | mad addperm <rank> <permission>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        local permission = args[2]
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        local rank_data = MAD.Data.Ranks[rank_name]
        
        -- Check if permission already exists
        if table.HasValue(rank_data.permissions, permission) then
            MAD.Message(ply, "Permission '" .. permission .. "' already exists in rank " .. args[1])
            return
        end
        
        -- Add permission
        table.insert(rank_data.permissions, permission)
        MAD.Data.SaveRanks()
        
        MAD.Message(ply, string.format("Added permission '%s' to rank %s", permission, args[1]))
        MAD.Log.Info(string.format("%s added permission '%s' to rank %s", IsValid(ply) and ply:Name() or "Console", permission, args[1]))
    end
})

-- Register delperm command
MAD.Commands.Register("delperm", {
    permission = "manage_ranks",
    description = "Remove permission from a rank",
    usage = "!delperm <rank> <permission> | mad delperm <rank> <permission>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        local permission = args[2]
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        local rank_data = MAD.Data.Ranks[rank_name]
        
        -- Find and remove permission
        for i, perm in ipairs(rank_data.permissions) do
            if perm == permission then
                table.remove(rank_data.permissions, i)
                MAD.Data.SaveRanks()
                
                MAD.Message(ply, string.format("Removed permission '%s' from rank %s", permission, args[1]))
                MAD.Log.Info(string.format("%s removed permission '%s' from rank %s", IsValid(ply) and ply:Name() or "Console", permission, args[1]))
                return
            end
        end
        
        MAD.Message(ply, "Permission '" .. permission .. "' not found in rank " .. args[1])
    end
})

-- Register listranks command
MAD.Commands.Register("listranks", {
    permission = "manage_ranks",
    description = "List all available ranks",
    usage = "!listranks | mad listranks",
    args_min = 0,
    args_max = 0,
    func = function(ply, args)
        local ranks = {}
        
        for rank_name, rank_data in pairs(MAD.Data.Ranks) do
            table.insert(ranks, {
                name = rank_name,
                display = rank_data.display_name,
                immunity = rank_data.immunity,
                order = rank_data.order
            })
        end
        
        -- Sort by order, then by immunity
        table.sort(ranks, function(a, b)
            if a.order == b.order then
                return a.immunity > b.immunity
            end
            return a.order > b.order
        end)
        
        MAD.Message(ply, "Available ranks:")
        for _, rank in ipairs(ranks) do
            MAD.Message(ply, string.format("  %s (immunity: %d, order: %d)", rank.display, rank.immunity, rank.order))
        end
    end
})

-- Register rankinfo command
MAD.Commands.Register("rankinfo", {
    permission = "manage_ranks",
    description = "Show detailed information about a rank",
    usage = "!rankinfo <rank> | mad rankinfo <rank>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        local rank_data = MAD.Data.Ranks[rank_name]
        
        MAD.Message(ply, "Rank Information: " .. rank_data.display_name)
        MAD.Message(ply, "  Immunity: " .. rank_data.immunity)
        MAD.Message(ply, "  Order: " .. rank_data.order)
        MAD.Message(ply, "  Color: " .. rank_data.color.r .. ", " .. rank_data.color.g .. ", " .. rank_data.color.b)
        MAD.Message(ply, "  Derived from: " .. rank_data.derived_from)
        
        if #rank_data.permissions > 0 then
            MAD.Message(ply, "  Permissions: " .. table.concat(rank_data.permissions, ", "))
        else
            MAD.Message(ply, "  Permissions: None")
        end
        
        -- Count players with this rank
        local count = 0
        for _, data in pairs(MAD.Data.PlayerData) do
            if data.rank == rank_name then
                count = count + 1
            end
        end
        MAD.Message(ply, "  Players with rank: " .. count)
    end
})

-- Register whois command
MAD.Commands.Register("whois", {
    permission = "manage_ranks",
    description = "List players with specified rank",
    usage = "!whois <rank> | mad whois <rank>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        local online_players = {}
        local offline_players = {}
        
        -- Check online players
        for _, target in ipairs(player.GetAll()) do
            if MAD.Permissions.GetRank(target) == rank_name then
                table.insert(online_players, target:Name())
            end
        end
        
        -- Check offline players
        for steamid, data in pairs(MAD.Data.PlayerData) do
            if data.rank == rank_name then
                local is_online = false
                for _, target in ipairs(player.GetAll()) do
                    if target:SteamID64() == steamid then
                        is_online = true
                        break
                    end
                end
                if not is_online then
                    table.insert(offline_players, data.last_name or data.name or steamid)
                end
            end
        end
        
        MAD.Message(ply, "Players with rank '" .. args[1] .. "':")
        
        if #online_players > 0 then
            MAD.Message(ply, "  Online: " .. table.concat(online_players, ", "))
        end
        
        if #offline_players > 0 then
            MAD.Message(ply, "  Offline: " .. table.concat(offline_players, ", "))
        end
        
        if #online_players == 0 and #offline_players == 0 then
            MAD.Message(ply, "  No players found with this rank")
        end
    end
})

-- Register setimmunity command
MAD.Commands.Register("setimmunity", {
    permission = "manage_ranks",
    description = "Set immunity level for a rank",
    usage = "!setimmunity <rank> <level> | mad setimmunity <rank> <level>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local rank_name = string.lower(args[1])
        local immunity = tonumber(args[2])
        
        if not immunity then
            MAD.Message(ply, "Invalid immunity level - must be a number")
            return
        end
        
        -- Check if rank exists
        if not MAD.Data.Ranks[rank_name] then
            MAD.Message(ply, "Rank '" .. args[1] .. "' does not exist")
            return
        end
        
        -- Bounds checking
        if immunity < 0 then immunity = 0 end
        if immunity > 999 then immunity = 999 end
        
        local old_immunity = MAD.Data.Ranks[rank_name].immunity
        MAD.Data.Ranks[rank_name].immunity = immunity
        MAD.Data.SaveRanks()
        
        MAD.Message(ply, string.format("Set immunity for rank %s to %d (was %d)", args[1], immunity, old_immunity))
        MAD.Log.Info(string.format("%s set immunity for rank %s to %d (was %d)", IsValid(ply) and ply:Name() or "Console", args[1], immunity, old_immunity))
    end
})

-- Cleanup function (called when extension is unloaded)
function MAD_RANKMANAGEMENT_CLEANUP()
end