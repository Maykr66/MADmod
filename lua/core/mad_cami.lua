--[[
DataTypes, Function List, Hook List
DO NOT register the admin mod's privileges (registering privileges is for third party mods, not for sharing privileges between admin mods)

-- DataTypes:

CAMI_USERGROUP -- Defines the characteristics of a usergroup
@field "usergroup name" :: string (The name of the usergroup)
@field "Inherits usergroup" ::string (usergroup this usergroup inherits from)
@field "CAMI_Source" :: string (The source specified by the admin mod which registered this usergroup) -- if any, converted to a string)
@example
    { // Example Usergroup
            Name = "cool user",
            Inherits = "user",
            CAMI_Source = "MADmod",
    }

CAMI_PRIVILEGE -- defines the characteristics of a privilege
@field "Name" :: string (The name of the privilege)
@field "MinAccess" :: string (Default group that should have this privilege) -- "user" | "admin" | "superadmin"
@field "Description" :: string or nil (Optional text describing the purpose of the privilege)
@example
    {
        name = "canDie",
        MinAccess = "user",
        Description = "Check if the user is allowed to die" -- or nil
    }

-- Functions:
CAMI.RegisterUsergroup(usergroup, source)
CAMI.UnregisterUsergroup(usergroupName, source)
CAMI.GetUsergroups()
CAMI.GetUsergroup(usergroupName)
CAMI.UsergroupInherits(usergroupName, potentialAncestor)
CAMI.InheritanceRoot(usergroupName)
CAMI.RegisterPrivilege(privilege)
CAMI.UnregisterPrivilege(privilegeName)
CAMI.GetPrivileges()
CAMI.GetPrivilege(privilegeName)
CAMI.PlayerHasAccess(actorPly, privilegeName, callback, targetPly, extraInfoTbl)
CAMI.GetPlayersWithAccess(privilegeName, callback, targetPly, extraInfoTbl)
CAMI.SteamIDHasAccess(actorSteam, privilegeName, callback, targetSteam, extraInfoTbl)
CAMI.SignalUserGroupChanged(ply, old, new, source)
CAMI.SignalSteamIDUserGroupChanged(steamId, old, new, source)
-- Optional Functions
CAMI_PRIVILEGE:HasAccess(actor, target)

-- Hooks(to implement)
CAMI.OnUsergroupRegistered(CAMI_USERGROUP)
CAMI.OnUsergroupUnregistered(CAMI_USERGROUP)
CAMI.OnPrivilegeRegistered(CAMI_PRIVILEGE)
CAMI.OnPrivilegeUnregistered(CAMI_PRIVILEGE)
CAMI.PlayerHasAccess(actor :: Player, privilege :: string, callback :: function(bool, string), target :: Player, extraInfo :: table) :: bool/nil
CAMI.SteamIDHasAccess(actor :: SteamID, privilege :: string, callback :: function(bool, string), target :: Player, extraInfo :: table) :: bool/nil
CAMI.PlayerUsergroupChanged(ply :: Player, from :: string, to :: string, source :: any)
CAMI.SteamIDUsergroupChanged(steamId :: string, from :: string, to :: string, source :: any)
]]--[[
CAMI - Common Admin Mod Interface.
Copyright 2020 CAMI Contributors

Makes admin mods intercompatible and provides an abstract privilege interface for third party addons.

Follows the specification on this page: https://github.com/glua/CAMI/blob/master/README.md

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

--[[
MADmod Remarks:
MADmod implements a flexible rank system where all ranks have a derived_from field that corresponds to CAMI inheritance.
This CAMI implementation bridges MADmod's permission system with CAMI-compatible addons.
]]

-- Version number in YearMonthDay format.
local version = 20211019

if CAMI and CAMI.Version >= version then 
    MAD.Log.Info("CAMI already loaded (hot reload)")
    return 
end

CAMI = CAMI or {}
CAMI.Version = version

local CAMI_PRIVILEGE = {}
--- Optional function to check if a player has access to this privilege (and optionally execute it on another player)
--- **Warning**: This function may not be called by all admin mods
--- @param actor GPlayer @The player
--- @param target GPlayer | nil @Optional - the target
--- @return boolean @If they can or not
--- @return string | nil @Optional reason
function CAMI_PRIVILEGE:HasAccess(actor, target)
end

--- Contains the registered CAMI_USERGROUP usergroup structures.
--- Indexed by usergroup name.
--- @type CAMI_USERGROUP[]
local usergroups = {}

--- Contains the registered CAMI_PRIVILEGE privilege structures.
--- Indexed by privilege name.
--- @type CAMI_PRIVILEGE[]
local privileges = CAMI.GetPrivileges and CAMI.GetPrivileges() or {}

-- MADmod CAMI Integration Functions
local function SyncMADRanksToCAMI()
    -- Clear existing usergroups
    usergroups = {}
    
    -- Convert MADmod ranks to CAMI usergroups
    for rank_name, rank_data in pairs(MAD.Data.Ranks) do
        usergroups[rank_name] = {
            Name = rank_name,
            Inherits = rank_data.derived_from,
            CAMI_Source = "MADmod",
        }
    end
    
    MAD.Log.Debug("Synced " .. table.Count(usergroups) .. " MADmod ranks to CAMI usergroups")
end

-- Initialize CAMI usergroups from MADmod ranks
local function InitializeCAMI()
    if MAD and MAD.Data and MAD.Data.Ranks then
        SyncMADRanksToCAMI()
    else
        -- Fallback to default usergroups if MADmod not ready
        usergroups = {
            user = {
                Name = "user",
                Inherits = "user",
                CAMI_Source = "MADmod",
            },
            admin = {
                Name = "admin",
                Inherits = "user",
                CAMI_Source = "MADmod",
            },
            superadmin = {
                Name = "superadmin",
                Inherits = "admin",
                CAMI_Source = "MADmod",
            }
        }
        MAD.Log.Warning("MADmod not ready, using fallback CAMI usergroups")
    end
end

--- Registers a usergroup with CAMI.
--- Use the source parameter to make sure CAMI.RegisterUsergroup function and
--- the CAMI.OnUsergroupRegistered hook don't cause an infinite loop
--- @param usergroup CAMI_USERGROUP @The structure for the usergroup you want to register
--- @param source any @Identifier for your own admin mod. Can be anything.
--- @return CAMI_USERGROUP @The usergroup given as an argument
function CAMI.RegisterUsergroup(usergroup, source)
    if source then
        usergroup.CAMI_Source = tostring(source)
    end
    
    -- If this is from MADmod, don't add to CAMI table (it's already synced)
    if source ~= "MADmod" then
        usergroups[usergroup.Name] = usergroup
    end

    hook.Call("CAMI.OnUsergroupRegistered", nil, usergroup, source)
    return usergroup
end

--[[ CAMI.UnregisterUsergroup
Unregisters a usergroup from CAMI. This will call a hook that will notify all other admin mods of the removal.
**Warning**: Call only when the usergroup is to be permanently removed.
Use the source parameter to make sure CAMI.UnregisterUsergroup function and
the CAMI.OnUsergroupUnregistered hook don't cause an infinite loop
@param usergroupName string @The name of the usergroup.
@param source any @Identifier for your own admin mod. Can be anything.
@return boolean @Whether the unregistering succeeded.
]]--
function CAMI.UnregisterUsergroup(usergroupName, source)
    if not usergroups[usergroupName] then return false end

    local usergroup = usergroups[usergroupName]
    
    -- Don't allow external removal of MADmod ranks
    if usergroup.CAMI_Source == "MADmod" and source ~= "MADmod" then
        MAD.Log.Warning("External attempt to unregister MADmod usergroup: " .. usergroupName)
        return false
    end
    
    usergroups[usergroupName] = nil
    hook.Call("CAMI.OnUsergroupUnregistered", nil, usergroup, source)
    return true
end

--- Retrieves all registered usergroups.
--- @return CAMI_USERGROUP[] @Usergroups indexed by their names.
function CAMI.GetUsergroups()
    -- Ensure usergroups are synced with MADmod
    if MAD and MAD.Data and MAD.Data.Ranks then
        SyncMADRanksToCAMI()
    end
    return usergroups
end

--- Receives information about a usergroup.
--- @param usergroupName string
--- @return CAMI_USERGROUP | nil @Returns nil when the usergroup does not exist.
function CAMI.GetUsergroup(usergroupName)
    -- Ensure usergroups are synced with MADmod
    if MAD and MAD.Data and MAD.Data.Ranks then
        SyncMADRanksToCAMI()
    end
    return usergroups[usergroupName]
end

--- Checks to see if potentialAncestor is an ancestor of usergroupName.
--- All usergroups are ancestors of themselves.
--- Examples:
--- * `user` is an ancestor of `admin` and also `superadmin`
--- * `admin` is an ancestor of `superadmin`, but not `user`
--- @param usergroupName string @The usergroup to query
--- @param potentialAncestor string @The ancestor to query
--- @return boolean @Whether usergroupName inherits potentialAncestor.
function CAMI.UsergroupInherits(usergroupName, potentialAncestor)
    -- Use MADmod's rank data if available for more accurate inheritance
    if MAD and MAD.Data and MAD.Data.Ranks then
        SyncMADRanksToCAMI()
    end
    
    repeat
        if usergroupName == potentialAncestor then return true end

        usergroupName = usergroups[usergroupName] and
                         usergroups[usergroupName].Inherits or
                         usergroupName
    until not usergroups[usergroupName] or
          usergroups[usergroupName].Inherits == usergroupName

    -- One can only be sure the usergroup inherits from user if the
    -- usergroup isn't registered.
    return usergroupName == potentialAncestor or potentialAncestor == "user"
end

--- Find the base group a usergroup inherits from.
---
--- This function traverses down the inheritence chain, so for example if you have
--- `user` -> `group1` -> `group2`
--- this function will return `user` if you pass it `group2`.
---
--- ℹ **NOTE**: All usergroups must eventually inherit either user, admin or superadmin.
--- @param usergroupName string @The name of the usergroup
--- @return "'user'" | "'admin'" | "'superadmin'" @The name of the root usergroup
function CAMI.InheritanceRoot(usergroupName)
    if not usergroups[usergroupName] then return end

    local inherits = usergroups[usergroupName].Inherits
    while inherits ~= usergroups[usergroupName].Inherits do
        usergroupName = usergroups[usergroupName].Inherits
    end

    return usergroupName
end

--- Registers an addon privilege with CAMI.
---
--- ⚠ **Warning**: This should only be used by addons. Admin mods must *NOT*
---  register their privileges using this function.
--- @param privilege CAMI_PRIVILEGE
--- @return CAMI_PRIVILEGE @The privilege given as argument.
function CAMI.RegisterPrivilege(privilege)
    privileges[privilege.Name] = privilege
    hook.Call("CAMI.OnPrivilegeRegistered", nil, privilege)
    return privilege
end

--- Unregisters a privilege from CAMI.
--- This will call a hook that will notify any admin mods of the removal.
---
--- ⚠ **Warning**: Call only when the privilege is to be permanently removed.
--- @param privilegeName string @The name of the privilege.
--- @return boolean @Whether the unregistering succeeded.
function CAMI.UnregisterPrivilege(privilegeName)
    if not privileges[privilegeName] then return false end

    local privilege = privileges[privilegeName]
    privileges[privilegeName] = nil

    hook.Call("CAMI.OnPrivilegeUnregistered", nil, privilege)
    return true
end

--- Retrieves all registered privileges.
--- @return CAMI_PRIVILEGE[] @All privileges indexed by their names.
function CAMI.GetPrivileges()
    return privileges
end

--- Receives information about a privilege.
--- @param privilegeName string
--- @return CAMI_PRIVILEGE | nil
function CAMI.GetPrivilege(privilegeName)
    return privileges[privilegeName]
end

-- MADmod access handler that responds to CAMI hooks
local madmodAccessHandler = {["CAMI.PlayerHasAccess"] =
    function(_, actorPly, privilegeName, callback, targetPly, extraInfoTbl)
        -- The server always has access
        if not IsValid(actorPly) then return callback(true, "MADmod: Console access") end

        -- Use MADmod's permission system if available
        if MAD and MAD.Permissions and MAD.Permissions.HasPermission then
            local hasAccess = MAD.Permissions.HasPermission(actorPly, privilegeName)
            if hasAccess then
                return callback(true, "MADmod: Permission granted")
            end
        end

        -- Fallback to privilege-based checking
        local priv = privileges[privilegeName]
        
        local fallback = extraInfoTbl and (
            not extraInfoTbl.Fallback and actorPly:IsAdmin() or
            extraInfoTbl.Fallback == "user" and true or
            extraInfoTbl.Fallback == "admin" and actorPly:IsAdmin() or
            extraInfoTbl.Fallback == "superadmin" and actorPly:IsSuperAdmin())

        if not priv then return callback(fallback, "MADmod: Fallback") end

        local hasAccess =
            priv.MinAccess == "user" or
            priv.MinAccess == "admin" and actorPly:IsAdmin() or
            priv.MinAccess == "superadmin" and actorPly:IsSuperAdmin()

        if hasAccess and priv.HasAccess then
            hasAccess = priv:HasAccess(actorPly, targetPly)
        end

        callback(hasAccess, "MADmod: Privilege check")
    end,
    ["CAMI.SteamIDHasAccess"] =
    function(_, actorSteam, privilegeName, callback, targetSteam, extraInfoTbl)
        -- Use MADmod's offline player data if available
        if MAD and MAD.Data and MAD.Data.PlayerData and actorSteam then
            local playerData = MAD.Data.PlayerData[actorSteam]
            if playerData and playerData.rank then
                local rankData = MAD.Data.GetRankData(playerData.rank)
                if rankData then
                    -- Check if rank has the permission
                    local hasAccess = table.HasValue(rankData.permissions, privilegeName) or 
                                    table.HasValue(rankData.permissions, "*") or
                                    rankData.derived_from == "superadmin"
                    return callback(hasAccess, "MADmod: Offline player check")
                end
            end
        end
        
        callback(false, "MADmod: No offline data available")
    end
}

--- @class CAMI_ACCESS_EXTRA_INFO
--- @field Fallback "'user'" | "'admin'" | "'superadmin'" @Fallback status for if the privilege doesn't exist. Defaults to `admin`.
--- @field IgnoreImmunity boolean @Ignore any immunity mechanisms an admin mod might have.
--- @field CommandArguments table @Extra arguments that were given to the privilege command.

--- Checks if a player has access to a privilege
--- (and optionally can execute it on targetPly)
---
--- This function is designed to be asynchronous but will be invoked
---  synchronously if no callback is passed.
---
--- ⚠ **Warning**: If the currently installed admin mod does not support
---                 synchronous queries, this function will throw an error!
--- @param actorPly GPlayer @The player to query
--- @param privilegeName string @The privilege to query
--- @param callback fun(hasAccess: boolean, reason: string|nil) @Callback to receive the answer, or nil for synchronous
--- @param targetPly GPlayer | nil @Optional - target for if the privilege effects another player (eg kick/ban)
--- @param extraInfoTbl CAMI_ACCESS_EXTRA_INFO | nil @Table of extra information for the admin mod
--- @return boolean | nil @Synchronous only - if the player has the privilege
--- @return string | nil @Synchronous only - optional reason from admin mod
function CAMI.PlayerHasAccess(actorPly, privilegeName, callback, targetPly, extraInfoTbl)
    local hasAccess, reason = nil, nil
    local callback_ = callback or function(hA, r) hasAccess, reason = hA, r end

    hook.Call("CAMI.PlayerHasAccess", madmodAccessHandler, actorPly,
        privilegeName, callback_, targetPly, extraInfoTbl)

    if callback ~= nil then return end

    if hasAccess == nil then
        local err = [[The function CAMI.PlayerHasAccess was used to find out
        whether Player %s has privilege "%s", but an admin mod did not give an
        immediate answer!]]
        error(string.format(err,
            actorPly:IsPlayer() and actorPly:Nick() or tostring(actorPly),
            privilegeName))
    end

    return hasAccess, reason
end

--- Get all the players on the server with a certain privilege
--- (and optionally who can execute it on targetPly)
---
--- ℹ **NOTE**: This is an asynchronous function!
--- @param privilegeName string @The privilege to query
--- @param callback fun(players: GPlayer[]) @Callback to receive the answer
--- @param targetPly GPlayer | nil @Optional - target for if the privilege effects another player (eg kick/ban)
--- @param extraInfoTbl CAMI_ACCESS_EXTRA_INFO | nil @Table of extra information for the admin mod
function CAMI.GetPlayersWithAccess(privilegeName, callback, targetPly, extraInfoTbl)
    local allowedPlys = {}
    local allPlys = player.GetAll()
    local countdown = #allPlys

    local function onResult(ply, hasAccess, _)
        countdown = countdown - 1

        if hasAccess then table.insert(allowedPlys, ply) end
        if countdown == 0 then callback(allowedPlys) end
    end

    for _, ply in ipairs(allPlys) do
        CAMI.PlayerHasAccess(ply, privilegeName,
            function(...) onResult(ply, ...) end,
            targetPly, extraInfoTbl)
    end
end

--- @class CAMI_STEAM_ACCESS_EXTRA_INFO
--- @field IgnoreImmunity boolean @Ignore any immunity mechanisms an admin mod might have.
--- @field CommandArguments table @Extra arguments that were given to the privilege command.

--- Checks if a (potentially offline) SteamID has access to a privilege
--- (and optionally if they can execute it on a target SteamID)
---
--- ℹ **NOTE**: This is an asynchronous function!
--- @param actorSteam string | nil @The SteamID to query
--- @param privilegeName string @The privilege to query
--- @param callback fun(hasAccess: boolean, reason: string|nil) @Callback to receive  the answer
--- @param targetSteam string | nil @Optional - target SteamID for if the privilege effects another player (eg kick/ban)
--- @param extraInfoTbl CAMI_STEAM_ACCESS_EXTRA_INFO | nil @Table of extra information for the admin mod
function CAMI.SteamIDHasAccess(actorSteam, privilegeName, callback, targetSteam, extraInfoTbl)
    hook.Call("CAMI.SteamIDHasAccess", madmodAccessHandler, actorSteam,
        privilegeName, callback, targetSteam, extraInfoTbl)
end

--- Signify that your admin mod has changed the usergroup of a player. This
--- function communicates to other admin mods what it thinks the usergroup
--- of a player should be.
---
--- Listen to the hook to receive the usergroup changes of other admin mods.
--- @param ply GPlayer @The player for which the usergroup is changed
--- @param old string @The previous usergroup of the player.
--- @param new string @The new usergroup of the player.
--- @param source any @Identifier for your own admin mod. Can be anything.
function CAMI.SignalUserGroupChanged(ply, old, new, source)
    hook.Call("CAMI.PlayerUsergroupChanged", nil, ply, old, new, source)
end

--- Signify that your admin mod has changed the usergroup of a disconnected
--- player. This communicates to other admin mods what it thinks the usergroup
--- of a player should be.
---
--- Listen to the hook to receive the usergroup changes of other admin mods.
--- @param steamId string @The steam ID of the player for which the usergroup is changed
--- @param old string @The previous usergroup of the player.
--- @param new string @The new usergroup of the player.
--- @param source any @Identifier for your own admin mod. Can be anything.
function CAMI.SignalSteamIDUserGroupChanged(steamId, old, new, source)
    hook.Call("CAMI.SteamIDUsergroupChanged", nil, steamId, old, new, source)
end

-- MADmod Integration Hooks
hook.Add("MAD_RankChanged", "CAMI_Integration", function(ply, oldRank, newRank)
    -- Signal CAMI that usergroup changed
    CAMI.SignalUserGroupChanged(ply, oldRank, newRank, "MADmod")
end)

-- Hook to sync usergroups when MADmod ranks change
hook.Add("MAD_RanksUpdated", "CAMI_Integration", function()
    SyncMADRanksToCAMI()
end)

-- Initialize when script loads
timer.Simple(0.1, function()
    InitializeCAMI()
    MAD.Log.Info("CAMI integration initialized with MADmod")
end)