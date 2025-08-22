-- MADmod Teleport Extension
-- Provides teleportation commands with permission checking

-- Only run on server
if CLIENT then return end

-- Register teleport command
MAD.Commands.Register("tp", {
    permission = "teleport",
    description = "Teleport to player or teleport player to player",
    usage = "!tp <target> OR !tp <player1> <player2> | mad tp <target> OR mad tp <player1> <player2>",
    args_min = 1,
    args_max = 2,
    func = function(ply, args)
        
        if #args == 1 then
            -- Teleport caller to target: !tp <target>
            local target, err = MAD.FindPlayer(ply, args[1])
            if not target then
                MAD.Message(ply, err)
                return
            end
            
            if not IsValid(ply) then
                MAD.Message(ply, "Console cannot teleport")
                return
            end
            
            if ply == target then
                MAD.Message(ply, "Cannot teleport to yourself")
                return
            end
            
            -- Perform teleport
            local pos = target:GetPos()
            local ang = target:GetAngles()
            
            ply:SetPos(pos + Vector(0, 0, 5)) -- Slight offset to avoid getting stuck
            ply:SetAngles(Angle(0, ang.y, 0))
            
            MAD.Message(ply, "Teleported to " .. target:Name())
            
        elseif #args == 2 then
            -- Teleport player1 to player2: !tp <player1> <player2>
            local player1, err1 = MAD.FindPlayer(ply, args[1])
            if not player1 then
                MAD.Message(ply, "Player1: " .. err1)
                return
            end
            
            local player2, err2 = MAD.FindPlayer(ply, args[2])
            if not player2 then
                MAD.Message(ply, "Player2: " .. err2)
                return
            end
            
            if player1 == player2 then
                MAD.Message(ply, "Cannot teleport player to themselves")
                return
            end
            
            -- Check if teleporting someone other than self
            if IsValid(ply) and player1 ~= ply then
                -- Check for teleport others permission
                if not MAD.Permissions.HasPermission(ply, "teleport.others") then
                    MAD.Message(ply, "You need 'teleport.others' permission to teleport other players")
                    return
                end
                
                -- Check immunity/rank hierarchy
                if not MAD.Permissions.CanTarget(ply, player1) then
                    MAD.Message(ply, "You cannot teleport " .. player1:Name() .. " (insufficient rank)")
                    return
                end
            end
            
            -- Perform teleport
            local pos = player2:GetPos()
            local ang = player2:GetAngles()
            
            player1:SetPos(pos + Vector(0, 0, 5)) -- Slight offset to avoid getting stuck
            player1:SetAngles(Angle(0, ang.y, 0))
            
            -- Send messages
            MAD.Message(ply, "Teleported " .. player1:Name() .. " to " .. player2:Name())
            
            if player1 ~= ply then
                MAD.Message(player1, "You have been teleported to " .. player2:Name() .. " by " .. (IsValid(ply) and ply:Name() or "Console"))
            end
            
            if player2 ~= ply and player2 ~= player1 then
                MAD.Message(player2, player1:Name() .. " has been teleported to you by " .. (IsValid(ply) and ply:Name() or "Console"))
            end
        end
    end
})

-- Register bring command (teleport target to caller)
MAD.Commands.Register("bring", {
    permission = "teleport.others",
    description = "Teleport target player to your location",
    usage = "!bring <target> | mad bring <target>",
    args_min = 1,
    args_max = 1,
    func = function(ply, args)
        if not IsValid(ply) then
            MAD.Message(ply, "Console cannot use bring command")
            return
        end
        
        local target, err = MAD.FindPlayer(ply, args[1])
        if not target then
            MAD.Message(ply, err)
            return
        end
        
        if ply == target then
            MAD.Message(ply, "Cannot bring yourself")
            return
        end
        
        -- Check immunity
        if not MAD.Permissions.CanTarget(ply, target) then
            MAD.Message(ply, "You cannot bring " .. target:Name() .. " (insufficient rank)")
            return
        end
        
        -- Perform teleport
        local pos = ply:GetPos()
        local ang = ply:GetAngles()
        
        target:SetPos(pos + ply:GetForward() * 100) -- Place in front of caller
        target:SetAngles(Angle(0, ang.y + 180, 0)) -- Face towards caller
        
        MAD.Message(ply, "Brought " .. target:Name() .. " to your location")
        MAD.Message(target, "You have been teleported to " .. ply:Name())
    end
})

-- Register goto command (teleport to coordinates)
MAD.Commands.Register("goto", {
    permission = "teleport",
    description = "Teleport to coordinates",
    usage = "!goto <x> <y> <z> | mad goto <x> <y> <z>",
    args_min = 3,
    args_max = 3,
    func = function(ply, args)
        if not IsValid(ply) then
            MAD.Message(ply, "Console cannot teleport")
            return
        end
        
        local x = tonumber(args[1])
        local y = tonumber(args[2])
        local z = tonumber(args[3])
        
        if not x or not y or not z then
            MAD.Message(ply, "Invalid coordinates. Use numbers only.")
            return
        end
        
        local pos = Vector(x, y, z)
        ply:SetPos(pos)
        
        MAD.Message(ply, string.format("Teleported to coordinates: %.0f, %.0f, %.0f", x, y, z))
    end
})

-- Cleanup function (called when extension is unloaded)
function MAD_TELEPORT_CLEANUP()
    -- Remove any hooks or timers specific to this extension
end