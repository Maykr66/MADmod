-- ============================================================================
-- File: autorun/mad_init.lua
-- ============================================================================

-- MADmod initialization file
if SERVER then
    AddCSLuaFile("madmod.lua")
    AddCSLuaFile("mad_utils.lua")
    AddCSLuaFile("core/mad_network.lua")
end
include("madmod.lua")