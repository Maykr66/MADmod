MAD.Privileges = MAD.Privileges or {}

local privileges = {}

function MAD.Privileges.Initialize()
    -- Register the hardcoded root privilege
    privileges["*root"] = {
        name = "*root",
        description = "Root access - bypasses all privilege checks"
    }
    MAD.Log.Info("Registered hardcoded privilege: *root")
    
    -- Listen for command registrations to auto-register privileges
    hook.Add("MAD.OnCommandRegistered", "MAD_AutoRegisterPrivileges", function(commandName, commandData)
        local privilege = commandData.privilege
        
        -- Only auto-register if privilege is specified, doesn't exist, and isn't the root privilege
        if privilege and privilege ~= "" and privilege ~= "*root" and not MAD.Privileges.Exists(privilege) then
            local description = "Auto-generated privilege for command: " .. commandName
            MAD.Privileges.Register(privilege, description)
            MAD.Log.Info("Auto-registered privilege '" .. privilege .. "' for command '" .. commandName .. "'")
        end
    end)
    
    MAD.Log.Info("Privileges system initialized")
end

function MAD.Privileges.Register(name, description)
    if privileges[name] then
        MAD.Log.Warning("Privilege '" .. name .. "' already registered, overwriting")
    end
    
    privileges[name] = {
        name = name,
        description = description or ""
    }
    
    MAD.Log.Info("Registered privilege: " .. name)
end

function MAD.Privileges.Unregister(name)
    if not privileges[name] then return false end
    
    privileges[name] = nil
    MAD.Log.Info("Unregistered privilege: " .. name)
    return true
end

function MAD.Privileges.Exists(name)
    return privileges[name] ~= nil
end

function MAD.Privileges.GetAll()
    return table.Copy(privileges)
end

function MAD.Privileges.Get(name)
    return privileges[name] and table.Copy(privileges[name]) or nil
end

function MAD.Privileges.HasAccess(player, privilegeName)
    if not IsValid(player) then return true end -- Console always has access
    
    local rank = MAD.Players.GetRank(player:SteamID64())
    if not rank then return false end
    
    local rankData = MAD.Ranks.Get(rank)
    if not rankData then return false end
    
    -- Check for root privilege first (bypasses all other checks)
    for _, priv in ipairs(rankData.privileges or {}) do
        if priv == "*root" then
            return true
        end
    end
    
    -- Check if specific privilege is in rank's privileges list
    for _, priv in ipairs(rankData.privileges or {}) do
        if priv == privilegeName then
            return true
        end
    end
    
    return false
end