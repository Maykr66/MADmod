MAD.Utils = MAD.Utils or {}

-- Color table for console output
MAD.Utils.Colors = {
    PRIMARY = Color(100, 149, 237),
    SUCCESS = Color(50, 205, 50),
    WARNING = Color(255, 165, 0), 
    ERROR = Color(255, 69, 69),
    INFO = Color(135, 206, 235)
}

-- file IO wrapper
if SERVER then
    function MAD.Utils.FileExists(path)
        return file.Exists(path, "DATA")
    end

    function MAD.Utils.ReadFile(path)
        if not MAD.Utils.FileExists(path) then return nil end
        return file.Read(path, "DATA")
    end

    function MAD.Utils.WriteFile(path, content)
        local dir = string.GetPathFromFilename(path)
        if dir and dir ~= "" then
            file.CreateDir(dir)
        end
        file.Write(path, content)
    end

    function MAD.Utils.DeleteFile(path)
        if MAD.Utils.FileExists(path) then
            file.Delete(path)
        end
    end

    function MAD.Utils.TableToJSON(tbl)
        return util.TableToJSON(tbl, true)
    end

    function MAD.Utils.JSONToTable(json)
        local success, result = pcall(util.JSONToTable, json)
        if success and result then
            return result
        end
        return nil
    end
end

-- Player helpers
function MAD.Utils.FindPlayer(identifier)
    if not identifier or identifier == "" then return nil end
    
    -- full SteamID
    if string.match(identifier, "STEAM_[0-5]:[01]:%d+") then
        return player.GetBySteamID(identifier)
    end
    
    -- SteamID64
    if string.match(identifier, "^%d+$") and string.len(identifier) == 17 then
        return player.GetBySteamID64(identifier)
    end
    
    -- partial name matching
    local matches = {}
    local lowerIdent = string.lower(identifier)
    
    for _, ply in pairs(player.GetAll()) do
        local lowerName = string.lower(ply:Nick())
        if lowerName == lowerIdent then
            return ply -- Exact match
        elseif string.find(lowerName, lowerIdent, 1, true) then
            table.insert(matches, ply)
        end
    end
    
    return #matches == 1 and matches[1] or nil
end

-- Strings
function MAD.Utils.Trim(str)
    return string.match(str, "^%s*(.-)%s*$")
end

function MAD.Utils.Split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- Time
function MAD.Utils.GetTimeString()
    return os.date("%Y-%m-%d %H:%M:%S")
end

function MAD.Utils.GetDateString()
    return os.date("%Y-%m-%d")
end