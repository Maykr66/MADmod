MAD.Extensions = MAD.Extensions or {}

-- Extension storage
MAD.Extensions.Loaded = MAD.Extensions.Loaded or {}
MAD.Extensions.Path = "ext/"
MAD.Extensions.RegisteredPermissions = MAD.Extensions.RegisteredPermissions or {}

-- Initialize extension system
function MAD.Extensions.Initialize()
    MAD.Log.Info("Extensions system initialized")
    
    -- Register reload command
    MAD.Commands.Register({
        name = "reload",
        privilege = "reload_extensions", 
        description = "Hot-reload all extensions or a specific extension",
        syntax = "reload [extension_name]",
        callback = function(caller, args, silent)
            -- Save all data before any reload operation
            MAD.Data.SaveConfig()
            MAD.Data.SaveAllRanks()
            MAD.Data.SaveAllPlayers()
            
            if #args > 0 then
                -- Reload specific extension
                local extName = args[1]
                local success, error = MAD.Extensions.ReloadExtension(extName)
                
                if success then
                    return string.format("Successfully reloaded extension: %s", extName)
                else
                    return string.format("Failed to reload extension '%s': %s", extName, error or "Unknown error")
                end
            else
                -- Reload all extensions
                local results = MAD.Extensions.ReloadAll()
                
                local loaded = results.loaded or 0
                local failed = results.failed or 0
                local total = loaded + failed
                
                local message = string.format("Extension reload completed: %d/%d loaded successfully", loaded, total)
                
                if failed > 0 then
                    message = message .. string.format(" (%d failed)", failed)
                end
                
                return message
            end
        end
    })
    
    -- Register extension status command
    MAD.Commands.Register({
        name = "extstatus",
        privilege = "reload_extensions",
        description = "Show current loaded extensions status", 
        syntax = "extstatus",
        callback = function(caller, args, silent)
            local status = MAD.Extensions.GetStatus()
            
            if status.total == 0 then
                return "No extensions found in " .. MAD.Extensions.Path
            end
            
            local result = string.format("Extensions Status (%d total):\n", status.total)
            result = result .. string.format("  Loaded: %d\n", status.loaded)
            result = result .. string.format("  Failed: %d\n", status.failed)
            
            if #status.extensions > 0 then
                result = result .. "\nExtension Details:\n"
                
                for _, ext in ipairs(status.extensions) do
                    local statusText = ext.loaded and "LOADED" or "FAILED"
                    result = result .. string.format("  %s - %s", ext.name, statusText)
                    
                    if ext.error then
                        result = result .. " (Error: " .. ext.error .. ")"
                    end
                    
                    result = result .. "\n"
                end
            end
            
            return result:sub(1, -2) -- Remove trailing newline
        end
    })
    
    -- Load all extensions on startup
    MAD.Extensions.LoadAll()
end

-- Load all extensions
function MAD.Extensions.LoadAll()
    local files, _ = file.Find(MAD.Extensions.Path .. "*.lua", "LUA")
    
    if not files or #files == 0 then
        MAD.Log.Info("No extensions found in " .. MAD.Extensions.Path)
        return
    end
    
    local loaded = 0
    local failed = 0
    
    for _, fileName in pairs(files) do
        local extName = string.StripExtension(fileName)
        local success, error = MAD.Extensions.LoadExtension(extName)
        
        if success then
            loaded = loaded + 1
        else
            failed = failed + 1
            MAD.Log.Error("Failed to load extension '" .. extName .. "': " .. (error or "Unknown error"))
        end
    end
    
    MAD.Log.Info(string.format("Extension loading completed: %d loaded, %d failed", loaded, failed))
end

-- Load a specific extension
function MAD.Extensions.LoadExtension(extName)
    local filePath = MAD.Extensions.Path .. extName .. ".lua"
    
    if not file.Exists(filePath, "LUA") then
        return false, "Extension file not found"
    end
    
    local success, error = pcall(include, filePath)
    
    if success then
        MAD.Extensions.Loaded[extName] = {
            name = extName,
            file = filePath,
            loaded = true,
            load_time = os.time(),
            error = nil
        }
        
        MAD.Log.Success("Loaded extension: " .. extName)
        return true
    else
        MAD.Extensions.Loaded[extName] = {
            name = extName,
            file = filePath,
            loaded = false,
            load_time = os.time(),
            error = tostring(error)
        }
        
        return false, tostring(error)
    end
end

-- Reload all extensions
function MAD.Extensions.ReloadAll()
    MAD.Log.Info("Starting extension hot-reload...")
    
    MAD.Extensions.CleanupAll()
    
    MAD.Extensions.Loaded = {}
    
    -- Reload all extensions
    local files, _ = file.Find(MAD.Extensions.Path .. "*.lua", "LUA")
    local loaded = 0
    local failed = 0
    
    if files then
        for _, fileName in pairs(files) do
            local extName = string.StripExtension(fileName)
            local success, error = MAD.Extensions.LoadExtension(extName)
            
            if success then
                loaded = loaded + 1
            else
                failed = failed + 1
            end
        end
    end
    
    return {
        loaded = loaded,
        failed = failed,
        total = loaded + failed
    }
end

-- Reload a specific extension
function MAD.Extensions.ReloadExtension(extName)
    MAD.Log.Info("Reloading extension: " .. extName)
    
    MAD.Extensions.CleanupExtension(extName)
    
    MAD.Extensions.Loaded[extName] = nil
    
    -- Reload the extension
    return MAD.Extensions.LoadExtension(extName)
end

-- Get extension status
function MAD.Extensions.GetStatus()
    local status = {
        total = 0,
        loaded = 0,
        failed = 0,
        extensions = {}
    }
    
    -- Get all extension files
    local files, _ = file.Find(MAD.Extensions.Path .. "*.lua", "LUA")
    
    if files then
        status.total = #files
        
        for _, fileName in pairs(files) do
            local extName = string.StripExtension(fileName)
            local extData = MAD.Extensions.Loaded[extName]
            
            if extData then
                table.insert(status.extensions, {
                    name = extName,
                    loaded = extData.loaded,
                    error = extData.error,
                    load_time = extData.load_time
                })
                
                if extData.loaded then
                    status.loaded = status.loaded + 1
                else
                    status.failed = status.failed + 1
                end
            else
                -- Extension exists but not loaded
                table.insert(status.extensions, {
                    name = extName,
                    loaded = false,
                    error = "Not loaded"
                })
                status.failed = status.failed + 1
            end
        end
    end
    
    return status
end

-- Cleanup all extensions
function MAD.Extensions.CleanupAll()
    MAD.Log.Info("Cleaning up all extensions...")
    
    -- Call cleanup functions for loaded extensions
    for extName, extData in pairs(MAD.Extensions.Loaded) do
        if extData.loaded then
            MAD.Extensions.CleanupExtension(extName)
        end
    end
    
    -- core commands that should never be removed
    local coreCommands = {
        "help", "reload", "extstatus", "config", "setconfig", 
        "save", "backup", "version", "setrank", "listranks", "rankinfo",
        "kick", "ban", "unban", "banlist"
    }
    
    -- Cleanup all non-core commands
    local allCommands = MAD.Commands.GetAll()
    for cmdName, cmdData in pairs(allCommands) do
        if not table.HasValue(coreCommands, cmdName) then
            MAD.Commands.Deregister(cmdName)
        end
    end
    
    MAD.Log.Info("Extension cleanup completed")
end

-- Cleanup a specific extension
function MAD.Extensions.CleanupExtension(extName)
    -- Look for extension-specific cleanup function
    local cleanupFuncName = string.upper(extName) .. "_CLEANUP"
    cleanupFuncName = string.gsub(cleanupFuncName, "[^A-Z0-9_]", "_")
    cleanupFuncName = "MAD_" .. cleanupFuncName
    
    if _G[cleanupFuncName] and type(_G[cleanupFuncName]) == "function" then
        local success, error = pcall(_G[cleanupFuncName])
        if success then
            MAD.Log.Info("Called cleanup function for extension: " .. extName)
        else
            MAD.Log.Error("Extension cleanup function failed for " .. extName .. ": " .. tostring(error))
        end
        
        -- Remove the cleanup function
        _G[cleanupFuncName] = nil
    end
end