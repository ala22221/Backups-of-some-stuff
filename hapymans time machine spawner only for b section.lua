
--// ENTITY SPAWNER

local Players = game:GetService("Players")
local Player = Players.LocalPlayer

--// ENDPOINTS
local Things = workspace:WaitForChild("Things")

local Back = Things:WaitForChild("back")
local Front = Things:WaitForChild("front")

--// SOURCE URL
local SourceURL = "https://raw.githubusercontent.com/ala22221/Backups-of-some-stuff/refs/heads/main/hapymans%20time%20machine%20spawner(ONLY%20FOR%20B%20AND%20G%20SECTION%20UPDATE)%20SOURCE.lua"

print("[Spawner] Downloading source...")

local Success, EntitySource = pcall(function()
    local Code = game:HttpGet(SourceURL)
    local Function = loadstring(Code)

    if not Function then
        error("Could not compile source")
    end

    return Function()
end)

if not Success then
    warn("[Spawner] Source error:", EntitySource)
    return
end

if type(EntitySource) ~= "table" then
    warn("[Spawner] Source did not return a table")
    return
end

if type(EntitySource.Start) ~= "function"
    or type(EntitySource.Config) ~= "table" then
    warn("[Spawner] Source is missing required functions or config")
    return
end

--// CONFIGURATION
local Config = EntitySource.Config

Config.EntityID = "rbxassetid://132639218330721"

Config.Speed = 100
Config.KillDistance = 15

-- SPAWN
Config.SpawnFromFront = true -- true = front, false = back

-- REBOUND
Config.Rebound = true
Config.ReboundDelay = 1
Config.ReboundCount = 0

-- HIDING SPOTS
Config.CheckTables = true
Config.CheckLockers = true
Config.HidingSpotIndex = 3

Config.CheckDelay = 0.5
Config.TweenToHidingSpots = true

-- SAFETY
Config.CheckSafe = true
Config.SafeValueName = "safe"

Config.RoomPause = 0.2
Config.Debug = true

--// START
print("[Spawner] Starting entity...")

EntitySource:Start(
    Back.CFrame,
    Front.CFrame
)

print("[Spawner] Entity stopped")
