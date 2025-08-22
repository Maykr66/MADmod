-- MADmod Data Management System
MAD.Data = MAD.Data or {}

-- Data storage
MAD.Data.PlayerData = MAD.Data.PlayerData or {}
MAD.Data.Ranks = MAD.Data.Ranks or {}

-- File paths 
local DATA_PATH = "madmod/"
local PLAYER_DATA_PATH = DATA_PATH .. "players/"
local RANKS_DATA_PATH = DATA_PATH .. "ranks/"

-- Initialize data system
function MAD.Data.Initialize()
    -- Ensure directories exist
    if not file.Exists(DATA_PATH, "DATA") then
        file.CreateDir(DATA_PATH)
    end
    if not file.Exists(PLAYER_DATA_PATH, "DATA") then
        file.CreateDir(PLAYER_DATA_PATH)
    end
    if not file.Exists(RANKS_DATA_PATH, "DATA") then
        file.CreateDir(RANKS_DATA_PATH)
    end
    
    -- Load default ranks if none exist
    if not MAD.Data.LoadRanks() then
        MAD.Data.CreateDefaultRanks()
    end
    
    MAD.Log.Info("Data system initialized")
end

-- Load all data
function MAD.Data.Load()
    MAD.Data.LoadRanks()
    MAD.Data.LoadPlayers()
    MAD.Log.Info("All data loaded")
end

-- Save all data
function MAD.Data.Save()
    MAD.Data.SaveRanks()
    MAD.Data.SavePlayers()
    MAD.Log.Info("All data saved")
end

-- Load all players' data
function MAD.Data.LoadPlayers()
    for _, ply in ipairs(player.GetAll()) do
        MAD.Data.LoadPlayer(ply)
    end
end

-- Save all players' data
function MAD.Data.SavePlayers()
    for _, ply in ipairs(player.GetAll()) do
        MAD.Data.SavePlayer(ply)
    end
end

-- Load a single player's data
function MAD.Data.LoadPlayer(ply)
    if not IsValid(ply) then return nil end
    
    local steamid = ply:SteamID64()
    local filepath = PLAYER_DATA_PATH .. steamid .. ".txt"
    
    if file.Exists(filepath, "DATA") then
        local data = file.Read(filepath, "DATA")
        if data then
            local success, decoded = pcall(util.JSONToTable, data)
            if success and decoded then
                MAD.Data.PlayerData[steamid] = decoded
                -- Update last seen info
                MAD.Data.PlayerData[steamid].last_seen = os.time()
                MAD.Data.PlayerData[steamid].last_name = ply:Name()
                MAD.Log.Debug("Loaded player data for: " .. ply:Name())
                return decoded
            else
                MAD.Log.Warning("Failed to decode player data for: " .. ply:Name())
            end
        end
    end
    
    -- Create new player data
    MAD.Data.PlayerData[steamid] = MAD.Data.CreateNewPlayerData(ply)
    MAD.Log.Debug("Created new player data for: " .. ply:Name())
    return MAD.Data.PlayerData[steamid]
end

-- Save a single player's data
function MAD.Data.SavePlayer(ply)
    if not IsValid(ply) then return false end
    
    local steamid = ply:SteamID64()
    if MAD.Data.PlayerData[steamid] then
        -- Update session time
        local data = MAD.Data.PlayerData[steamid]
        data.last_seen = os.time()
        data.play_time = (data.play_time or 0) + (os.time() - (data.session_start or os.time()))
        data.session_start = os.time()
        data.last_name = ply:Name()
        
        local filepath = PLAYER_DATA_PATH .. steamid .. ".txt"
        local content = util.TableToJSON(data, true)
        
        local success = file.Write(filepath, content)
        if success then
            MAD.Log.Debug("Saved player data for: " .. ply:Name())
            return true
        else
            MAD.Log.Error("Failed to save player data for: " .. ply:Name())
            return false
        end
    end
    return false
end

-- Create new player data structure
function MAD.Data.CreateNewPlayerData(ply)
    return {
        steamid = ply:SteamID64(),
        name = ply:Name(),
        rank = "user",
        play_time = 0,
        session_start = os.time(),
        last_seen = os.time(),
        banned = false,
        ban_reason = "",
        ban_time = 0,
        ban_admin = "",
        first_join = os.time()
    }
end

-- Load ranks from files
function MAD.Data.LoadRanks()
    local files = file.Find(RANKS_DATA_PATH .. "*.txt", "DATA")
    if #files == 0 then 
        MAD.Log.Debug("No rank files found")
        return false 
    end
    
    MAD.Data.Ranks = {}
    local loaded_count = 0
    
    for _, filename in ipairs(files) do
        local rank_name = string.StripExtension(filename)
        local content = file.Read(RANKS_DATA_PATH .. filename, "DATA")
        
        if content then
            local success, rank_data = pcall(util.JSONToTable, content)
            if success and rank_data then
                MAD.Data.Ranks[rank_name] = rank_data
                loaded_count = loaded_count + 1
            else
                MAD.Log.Warning("Failed to load rank file: " .. filename)
            end
        end
    end
    
    MAD.Log.Info("Loaded " .. loaded_count .. " ranks from files")
    return true
end

-- Save ranks to files
function MAD.Data.SaveRanks()
    local saved_count = 0
    
    for rank_name, rank_data in pairs(MAD.Data.Ranks) do
        local content = util.TableToJSON(rank_data, true)
        local success = file.Write(RANKS_DATA_PATH .. rank_name .. ".txt", content)
        if success then
            saved_count = saved_count + 1
        else
            MAD.Log.Error("Failed to save rank: " .. rank_name)
        end
    end
    
    MAD.Log.Debug("Saved " .. saved_count .. " ranks to files")
end

-- Create default ranks
function MAD.Data.CreateDefaultRanks()
    MAD.Data.Ranks = {
        ["user"] = {
            display_name = "User",
            immunity = 0,
            order = 0,
            color = Color(150, 150, 150),
            permissions = {},
            derived_from = "user"
        },
        ["admin"] = {
            display_name = "Admin",
            immunity = 50,
            order = 1,
            color = Color(0, 150, 255),
            permissions = {"kick", "ban", "teleport", "manage_extensions"},
            derived_from = "admin"
        },
        ["superadmin"] = {
            display_name = "Super Admin",
            immunity = 100,
            order = 2,
            color = Color(255, 50, 50),
            permissions = {"*"},
            derived_from = "superadmin"
        }
    }
    
    MAD.Data.SaveRanks()
    MAD.Log.Info("Created default ranks")
end

-- Get player data by player object
function MAD.Data.GetPlayerData(ply)
    if not IsValid(ply) then return nil end
    local steamid = ply:SteamID64()
    return MAD.Data.PlayerData[steamid]
end

-- Get player data by SteamID64
function MAD.Data.GetPlayerDataBySteamID(steamid)
    return MAD.Data.PlayerData[steamid]
end

-- Get rank data by rank name
function MAD.Data.GetRankData(rank_name)
    return MAD.Data.Ranks[rank_name]
end

-- Check if rank exists
function MAD.Data.RankExists(rank_name)
    return MAD.Data.Ranks[rank_name] ~= nil
end

-- Get all players with a specific rank
function MAD.Data.GetPlayersWithRank(rank_name)
    local players = {}
    
    for steamid, data in pairs(MAD.Data.PlayerData) do
        if data.rank == rank_name then
            -- Try to find online player
            local ply = nil
            for _, p in ipairs(player.GetAll()) do
                if p:SteamID64() == steamid then
                    ply = p
                    break
                end
            end
            
            table.insert(players, {
                steamid = steamid,
                name = data.last_name or data.name,
                online = ply ~= nil,
                player = ply
            })
        end
    end
    
    return players
end

-- Clean up old player data (optional maintenance function)
function MAD.Data.CleanupOldPlayers(max_age_days)
    max_age_days = max_age_days or 90 -- Default 90 days
    local cutoff_time = os.time() - (max_age_days * 24 * 60 * 60)
    local cleaned = 0
    
    for steamid, data in pairs(MAD.Data.PlayerData) do
        if (data.last_seen or 0) < cutoff_time then
            -- Remove from memory
            MAD.Data.PlayerData[steamid] = nil
            
            -- Remove file
            local filepath = PLAYER_DATA_PATH .. steamid .. ".txt"
            if file.Exists(filepath, "DATA") then
                file.Delete(filepath)
            end
            
            cleaned = cleaned + 1
        end
    end
    
    if cleaned > 0 then
        MAD.Log.Info("Cleaned up " .. cleaned .. " old player records")
    end
    
    return cleaned
end