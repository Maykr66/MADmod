-- MADmod Rank Manager Extension v2.0.0 - Advanced Commands Only

local EXTENSION_NAME = "Advanced Rank Manager"
local EXTENSION_VERSION = "2.0.0"

MAD.Log.Info("Loading " .. EXTENSION_NAME .. " v" .. EXTENSION_VERSION)

-- Advanced rank management commands (not available in core)

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


MAD.Log.Success(EXTENSION_NAME .. " v" .. EXTENSION_VERSION .. " loaded successfully!")