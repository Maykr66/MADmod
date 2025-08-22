-- MADmod Utility Functions
-- Shared utility functions for both client and server

-- Format time in seconds to human-readable string
function MAD.FormatTime(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    
    if seconds <= 0 then
        return "0 seconds"
    end
    
    local units = {
        { value = 60 * 60 * 24 * 7, name = "week" },
        { value = 60 * 60 * 24, name = "day" },
        { value = 60 * 60, name = "hour" },
        { value = 60, name = "minute" },
        { value = 1, name = "second" }
    }
    
    local parts = {}
    
    for _, unit in ipairs(units) do
        if seconds >= unit.value then
            local count = math.floor(seconds / unit.value)
            seconds = seconds % unit.value
            
            table.insert(parts, 
                string.format("%d %s%s", count, unit.name, count ~= 1 and "s" or ""))
        end
    end
    
    return table.concat(parts, ", ")
end

-- Parse command arguments with quotes support
function MAD.ParseArgs(text)
    local args = {}
    local current_arg = ""
    local in_quotes = false
    local i = 1
    
    while i <= string.len(text) do
        local char = string.sub(text, i, i)
        
        if char == '"' then
            in_quotes = not in_quotes
        elseif char == " " and not in_quotes then
            if current_arg ~= "" then
                table.insert(args, current_arg)
                current_arg = ""
            end
        else
            current_arg = current_arg .. char
        end
        
        i = i + 1
    end
    
    if current_arg ~= "" then
        table.insert(args, current_arg)
    end
    
    return args
end

-- Send message to player with chunking for long messages
function MAD.Message(ply, msg)
    if IsValid(ply) then
        -- Split long messages to avoid character limit
        local max_length = 200 -- Safe limit under 255 bytes
        if string.len(msg) > max_length then
            local chunks = {}
            local current_pos = 1
            
            while current_pos <= string.len(msg) do
                local chunk = string.sub(msg, current_pos, current_pos + max_length - 1)
                table.insert(chunks, chunk)
                current_pos = current_pos + max_length
            end
            
            for _, chunk in ipairs(chunks) do
                ply:ChatPrint("[MADmod] " .. chunk)
            end
        else
            ply:ChatPrint("[MADmod] " .. msg)
        end
    else
        print("[MADmod] " .. msg)
    end
end

-- Find player by partial name with improved matching
function MAD.FindPlayer(caller, target_name)
    if not target_name or target_name == "" then
        return nil, "No target specified"
    end
    
    -- Self reference
    if target_name == "^" or target_name == "self" then
        return caller, nil
    end
    
    local targets = {}
    target_name = string.lower(target_name)
    
    -- First pass: exact name match
    for _, p in ipairs(player.GetAll()) do
        local name = string.lower(p:Name())
        if name == target_name then
            return p, nil -- Exact match, return immediately
        end
    end
    
    -- Second pass: partial name match
    for _, p in ipairs(player.GetAll()) do
        local name = string.lower(p:Name())
        if string.find(name, target_name, 1, true) then
            table.insert(targets, p)
        end
    end
    
    if #targets == 0 then
        return nil, "Player not found"
    elseif #targets > 1 then
        local names = {}
        for _, p in ipairs(targets) do
            table.insert(names, p:Name())
        end
        return nil, "Multiple matches: " .. table.concat(names, ", ")
    end
    
    return targets[1], nil
end

-- Format player info string
function MAD.FormatPlayerInfo(ply)
    if not IsValid(ply) then return "Invalid Player" end
    
    return string.format("%s (%s)", ply:Name(), ply:SteamID())
end

-- Validate and sanitize input
function MAD.SanitizeString(str, max_length)
    if not str then return "" end
    
    max_length = max_length or 100
    str = string.Trim(str)
    
    if string.len(str) > max_length then
        str = string.sub(str, 1, max_length)
    end
    
    return str
end

-- Check if string is valid name (alphanumeric + underscore)
function MAD.IsValidName(name)
    if not name or name == "" then return false end
    return string.match(name, "^[a-zA-Z0-9_]+$") ~= nil
end

-- Format table as readable string
function MAD.TableToString(tbl, max_items)
    if not tbl or type(tbl) ~= "table" then return "nil" end
    
    max_items = max_items or 10
    local items = {}
    local count = 0
    
    for k, v in pairs(tbl) do
        if count >= max_items then
            table.insert(items, "...")
            break
        end
        
        table.insert(items, tostring(k) .. "=" .. tostring(v))
        count = count + 1
    end
    
    return "{" .. table.concat(items, ", ") .. "}"
end

-- Color utility functions
MAD.Colors = {
    PRIMARY = Color(100, 200, 255),
    SUCCESS = Color(100, 255, 100),
    WARNING = Color(255, 255, 100),
    ERROR = Color(255, 100, 100),
    INFO = Color(200, 200, 200)
}

-- Get color by name
function MAD.GetColor(name)
    return MAD.Colors[string.upper(name)] or MAD.Colors.INFO
end