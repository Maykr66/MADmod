-- MADmod Extension System
-- Handles loading, hot-reloading, and management of extensions

MAD.Extensions = MAD.Extensions or {}

-- Extension storage
MAD.Extensions.Loaded = MAD.Extensions.Loaded or {}
MAD.Extensions.Path = "ext/"
MAD.Extensions.RegisteredPermissions = MAD.Extensions.RegisteredPermissions or {}

-- Initialize extension system
function MAD.Extensions.Initialize()
    MAD.Extensions.LoadAll()
    MAD.Log.Info("Extension system initialized")
end

-- Load all extensions from ext directory
function MAD.Extensions.LoadAll()
    local files, dirs = file.Find(MAD.Extensions.Path .. "*.lua", "LUA")
    
    MAD.Log.Info("Loading extensions...")
    
    for _, filename in ipairs(files) do
        MAD.Extensions.LoadExtension(filename)
    end
    
    MAD.Log.Info(string.format("Loaded %d extensions", #files))
end

-- Load a single extension
function MAD.Extensions.LoadExtension(filename)
    local filepath = MAD.Extensions.Path .. filename
    local name = string.StripExtension(filename)
    
    -- Check if file exists
    if not file.Exists(filepath, "LUA") then
        MAD.Log.Warning("Extension file not found: " .. filepath)
        return false
    end
    
    -- Unload existing extension
    if MAD.Extensions.Loaded[name] then
        MAD.Extensions.UnloadExtension(name)
    end
    
    -- Create extension environment
    local ext = {
        name = name,
        filename = filename,
        filepath = filepath,
        loaded = false,
        error = nil,
        permissions = {} -- Track permissions used by this extension
    }
    
    -- Store original command registration to intercept permission checks
    local original_register = MAD.Commands.Register
    local temp_permissions = {}
    
    -- Override command registration temporarily to collect permissions
    MAD.Commands.Register = function(cmd_name, cmd_data)
        if cmd_data.permission and cmd_data.permission ~= "user" then
            table.insert(temp_permissions, cmd_data.permission)
        end
        return original_register(cmd_name, cmd_data)
    end
    
    -- Load and execute extension
    local success, err = pcall(function()
        -- Include the extension file
        include(filepath)
        
        -- Add to client if needed
        if SERVER then
            AddCSLuaFile(filepath)
        end
        
        ext.loaded = true
        MAD.Log.Info("Loaded extension: " .. name)
    end)
    
    -- Restore original command registration
    MAD.Commands.Register = original_register
    
    if not success then
        ext.error = err
        MAD.Log.Error("Failed to load extension '" .. name .. "': " .. tostring(err))
        MAD.Extensions.Loaded[name] = ext
        return false
    end
    
    -- Check for permission conflicts
    local conflicts = MAD.Extensions.CheckPermissionConflicts(name, temp_permissions)
    if #conflicts > 0 then
        ext.loaded = false
        ext.error = "Permission conflicts detected: " .. table.concat(conflicts, ", ")
        MAD.Log.Error("PERMISSION CONFLICT - Extension '" .. name .. "' failed to load:")
        MAD.Log.Error("Conflicting permissions: " .. table.concat(conflicts, ", "))
        for _, perm in ipairs(conflicts) do
            local owner = MAD.Extensions.RegisteredPermissions[perm]
            MAD.Log.Error("Permission '" .. perm .. "' is already used by extension: " .. owner)
        end
        MAD.Extensions.Loaded[name] = ext
        return false
    end
    
    -- Register permissions for this extension
    ext.permissions = temp_permissions
    for _, perm in ipairs(temp_permissions) do
        MAD.Extensions.RegisteredPermissions[perm] = name
    end
    
    MAD.Extensions.Loaded[name] = ext
    return success
end

-- Unload an extension
function MAD.Extensions.UnloadExtension(name)
    local ext = MAD.Extensions.Loaded[name]
    if not ext then
        return false
    end
    
    -- Call cleanup function if it exists
    local cleanup_func = _G["MAD_" .. string.upper(name) .. "_CLEANUP"]
    if cleanup_func and type(cleanup_func) == "function" then
        pcall(cleanup_func)
    end
    
    -- Remove registered permissions
    if ext.permissions then
        for _, perm in ipairs(ext.permissions) do
            MAD.Extensions.RegisteredPermissions[perm] = nil
        end
    end
    
    MAD.Log.Info("Unloaded extension: " .. name)
    return true
end

-- Reload a specific extension
function MAD.Extensions.ReloadExtension(name)
    local ext = MAD.Extensions.Loaded[name]
    if not ext then
        MAD.Log.Warning("Extension not found: " .. name)
        return false
    end
    
    MAD.Log.Info("Reloading extension: " .. name)
    return MAD.Extensions.LoadExtension(ext.filename)
end

-- Reload all extensions
function MAD.Extensions.ReloadAll()
    MAD.Log.Info("Reloading all extensions...")
    
    -- Store current extension list
    local current_extensions = {}
    for name, ext in pairs(MAD.Extensions.Loaded) do
        current_extensions[name] = ext.filename
    end
    
    -- Unload all current extensions
    for name, _ in pairs(current_extensions) do
        MAD.Extensions.UnloadExtension(name)
    end
    
    -- Clear loaded extensions and permissions
    MAD.Extensions.Loaded = {}
    MAD.Extensions.RegisteredPermissions = {}
    
    -- Load all extensions fresh
    MAD.Extensions.LoadAll()
    
    MAD.Log.Info("Extension reload complete")
end

-- Check for permission conflicts
function MAD.Extensions.CheckPermissionConflicts(extension_name, permissions)
    local conflicts = {}
    
    for _, perm in ipairs(permissions) do
        if MAD.Extensions.RegisteredPermissions[perm] then
            local owner = MAD.Extensions.RegisteredPermissions[perm]
            if owner ~= extension_name then
                table.insert(conflicts, perm .. " (used by: " .. owner .. ")")
            end
        end
    end
    
    return conflicts
end

-- Get extension status
function MAD.Extensions.GetStatus()
    local status = {
        total = 0,
        loaded = 0,
        failed = 0,
        extensions = {}
    }
    
    for name, ext in pairs(MAD.Extensions.Loaded) do
        status.total = status.total + 1
        
        local ext_status = {
            name = name,
            loaded = ext.loaded,
            error = ext.error
        }
        
        if ext.loaded then
            status.loaded = status.loaded + 1
        else
            status.failed = status.failed + 1
        end
        
        table.insert(status.extensions, ext_status)
    end
    
    return status
end