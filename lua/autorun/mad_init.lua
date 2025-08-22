-- MADmod initialization file
if SERVER then
    AddCSLuaFile("madmod.lua")
    include("madmod.lua")
elseif CLIENT then
    include("madmod.lua")
end