-- MADmod Player Manipulation Extension
-- Essential player control commands for administrators

-- Only run on server
if CLIENT then return end

-- Track frozen players and their restrictions
local frozenPlayers = {}

-- Helper function to check if player can be targeted
local function CanTargetPlayer(admin, target)
    if not IsValid(admin) then return true end -- Console can target anyone
    if not IsValid(target) then return false end
    if admin == target then return true end -- Can target self
    return MAD.Permissions.CanTarget(admin, target)
end

-- God Mode Commands
MAD.Commands.Register("god", {
    permission = "player_manage",
    description = "Give player god mode",
    usage = "!god [player] | mad god [player]",
    args_min = 0,
    args_max = 1,
    func = function(ply, args)
        local target = ply
        
        if args[1] then
            local found_target, err = MAD.FindPlayer(ply, args[1])
            if not found_target then
                MAD.Commands.Message(ply, err)
                return
            end
            target = found_target
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        target:GodEnable()
        MAD.Message(ply, "Enabled god mode for " .. target:Name())
        if target ~= ply then
            MAD.Message(target, "God mode enabled by " .. (IsValid(ply) and ply:Name() or "Console"))
        end
        
        MAD.Log.Info(string.format("%s enabled god mode for %s", 
            IsValid(ply) and ply:Name() or "Console", target:Name()), "admin_actions")
    end
})

MAD.Commands.Register("ungod", {
    permission = "player_manage",
    description = "Remove player god mode",
    usage = "!ungod [player] | mad ungod [player]",
    args_min = 0,
    args_max = 1,
    func = function(ply, args)
        local target = ply
        
        if args[1] then
            local found_target, err = MAD.Commands.FindPlayer(ply, args[1])
            if not found_target then
                MAD.Commands.Message(ply, err)
                return
            end
            target = found_target
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        target:GodDisable()
        MAD.Commands.Message(ply, "Disabled god mode for " .. target:Name())
        if target ~= ply then
            MAD.Commands.Message(target, "God mode disabled by " .. (IsValid(ply) and ply:Name() or "Console"))
        end
        
        MAD.Log.Info(string.format("%s disabled god mode for %s", 
            IsValid(ply) and ply:Name() or "Console", target:Name()), "admin_actions")
    end
})

-- Health Commands
MAD.Commands.Register("hp", {
    permission = "player_manage",
    description = "Set player health",
    usage = "!hp <player> <amount> | mad hp <player> <amount>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local target, err = MAD.FindPlayer(ply, args[1])
        if not target then
            MAD.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        local amount = tonumber(args[2])
        if not amount or amount < 0 then
            MAD.Message(ply, "Invalid health amount")
            return
        end
        
        target:SetHealth(amount)
        MAD.Message(ply, "Set " .. target:Name() .. "'s health to " .. amount)
        MAD.Message(target, "Your health was set to " .. amount .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s set %s's health to %d", 
            IsValid(ply) and ply:Name() or "Console", target:Name(), amount), "admin_actions")
    end
})

-- Armor Commands  
MAD.Commands.Register("armor", {
    permission = "player_manage",
    description = "Set player armor",
    usage = "!armor <player> <amount> | mad armor <player> <amount>",
    args_min = 2,
    args_max = 2,
    func = function(ply, args)
        local target, err = MAD.Commands.FindPlayer(ply, args[1])
        if not target then
            MAD.Commands.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        local amount = tonumber(args[2])
        if not amount or amount < 0 then
            MAD.Commands.Message(ply, "Invalid armor amount")
            return
        end
        
        target:SetArmor(amount)
        MAD.Commands.Message(ply, "Set " .. target:Name() .. "'s armor to " .. amount)
        MAD.Commands.Message(target, "Your armor was set to " .. amount .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s set %s's armor to %d", 
            IsValid(ply) and ply:Name() or "Console", target:Name(), amount), "admin_actions")
    end
})

-- Speed Commands
MAD.Commands.Register("speed", {
    permission = "player_manage", 
    description = "Set player speed",
    usage = "!speed <player> <walk> [run] | mad speed <player> <walk> [run]",
    args_min = 2,
    args_max = 3,
    func = function(ply, args)
        local target, err = MAD.Commands.FindPlayer(ply, args[1])
        if not target then
            MAD.Commands.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        local walk_speed = tonumber(args[2])
        if not walk_speed or walk_speed < 0 then
            MAD.Commands.Message(ply, "Invalid walk speed")
            return
        end
        
        local run_speed = walk_speed * 2 -- Default run speed
        if args[3] then
            run_speed = tonumber(args[3])
            if not run_speed or run_speed < 0 then
                MAD.Commands.Message(ply, "Invalid run speed")
                return
            end
        end
        
        target:SetWalkSpeed(walk_speed)
        target:SetRunSpeed(run_speed)
        
        MAD.Commands.Message(ply, string.format("Set %s's speed to %d/%d (walk/run)", 
            target:Name(), walk_speed, run_speed))
        MAD.Commands.Message(target, string.format("Your speed was set to %d/%d by %s", 
            walk_speed, run_speed, IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s set %s's speed to %d/%d", 
            IsValid(ply) and ply:Name() or "Console", target:Name(), walk_speed, run_speed), "admin_actions")
    end
})

-- Freeze Commands
MAD.Commands.Register("freeze", {
    permission = "player_manage",
    description = "Freeze a player (blocks movement, tools, and spawning)",
    usage = "!freeze <player> | mad freeze <player>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local target, err = MAD.Commands.FindPlayer(ply, args[1])
        if not target then
            MAD.Commands.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        target:Freeze(true)
        frozenPlayers[target:SteamID64()] = true
        
        MAD.Commands.Message(ply, "Froze " .. target:Name())
        MAD.Commands.Message(target, "You have been frozen by " .. (IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s froze %s", 
            IsValid(ply) and ply:Name() or "Console", target:Name()), "admin_actions")
    end
})

MAD.Commands.Register("unfreeze", {
    permission = "player_manage",
    description = "Unfreeze a player",
    usage = "!unfreeze <player> | mad unfreeze <player>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local target, err = MAD.Commands.FindPlayer(ply, args[1])
        if not target then
            MAD.Commands.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        target:Freeze(false)
        frozenPlayers[target:SteamID64()] = nil
        
        MAD.Commands.Message(ply, "Unfroze " .. target:Name())
        MAD.Commands.Message(target, "You have been unfrozen by " .. (IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s unfroze %s", 
            IsValid(ply) and ply:Name() or "Console", target:Name()), "admin_actions")
    end
})

-- Noclip Commands
MAD.Commands.Register("noclip", {
    permission = "player_manage",
    description = "Toggle player noclip",
    usage = "!noclip [player] | mad noclip [player]",
    args_min = 0,
    args_max = 1,
    func = function(ply, args)
        local target = ply
        
        if args[1] then
            local found_target, err = MAD.Commands.FindPlayer(ply, args[1])
            if not found_target then
                MAD.Commands.Message(ply, err)
                return
            end
            target = found_target
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        local current_movetype = target:GetMoveType()
        local new_movetype = (current_movetype == MOVETYPE_NOCLIP) and MOVETYPE_WALK or MOVETYPE_NOCLIP
        local status = (new_movetype == MOVETYPE_NOCLIP) and "enabled" or "disabled"
        
        target:SetMoveType(new_movetype)
        
        MAD.Commands.Message(ply, "Noclip " .. status .. " for " .. target:Name())
        if target ~= ply then
            MAD.Commands.Message(target, "Noclip " .. status .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
        end
        
        MAD.Log.Info(string.format("%s %s noclip for %s", 
            IsValid(ply) and ply:Name() or "Console", status, target:Name()), "admin_actions")
    end
})

-- Respawn Command
MAD.Commands.Register("respawn", {
    permission = "player_manage",
    description = "Respawn a player",
    usage = "!respawn <player> | mad respawn <player>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        local target, err = MAD.Commands.FindPlayer(ply, args[1])
        if not target then
            MAD.Commands.Message(ply, err)
            return
        end
        
        if not CanTargetPlayer(ply, target) then
            MAD.Commands.Message(ply, "You cannot target " .. target:Name())
            return
        end
        
        target:Spawn()
        
        MAD.Commands.Message(ply, "Respawned " .. target:Name())
        MAD.Commands.Message(target, "You were respawned by " .. (IsValid(ply) and ply:Name() or "Console"))
        
        MAD.Log.Info(string.format("%s respawned %s", 
            IsValid(ply) and ply:Name() or "Console", target:Name()), "admin_actions")
    end
})

-- Hook to block tool/prop spawning for frozen players
hook.Add("PlayerSpawnProp", "MAD_FreezeRestriction", function(ply)
    if frozenPlayers[ply:SteamID64()] then
        return false
    end
end)

hook.Add("CanTool", "MAD_FreezeRestriction", function(ply, tr, tool)
    if frozenPlayers[ply:SteamID64()] then
        return false
    end
end)

-- Clean up frozen players on disconnect
hook.Add("PlayerDisconnected", "MAD_FreezeCleanup", function(ply)
    frozenPlayers[ply:SteamID64()] = nil
end)

-- Cleanup function (called when extension is unloaded)
function MAD_PLAYER_CLEANUP()
    -- Clear frozen players table
    frozenPlayers = {}
end