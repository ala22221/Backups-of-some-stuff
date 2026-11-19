
-- Services

local Players = game:GetService("Players")
local ReSt = game:GetService("ReplicatedStorage")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local CG = game:GetService("CoreGui")

-- Variables

local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")
local Camera = workspace.CurrentCamera
local legacyhotelmodule = ReSt:FindFirstChild("ClientModules") or ReSt.ModulesClient

local StaticRushSpeed = 60

local FindPartOnRayWithIgnoreList = workspace.FindPartOnRayWithIgnoreList
local WorldToViewportPoint = Camera.WorldToViewportPoint

local SelfModules = {
    DefaultConfig = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/DripCapybara/Test/main/Doors/Backup/DefaultConfig.lua"
    ))(),
}

local ModuleScripts = {
    ModuleEvents = require(legacyhotelmodule.Module_Events),
    MainGame = require(Plr.PlayerGui.MainUI.Initiator.Main_Game),
}

local EntityConnections = {}
local Spawner = {}

-- Safe Destroy

local function safeDestroy(object)
    if object and typeof(object) == "Instance" and object.Parent then
        object:Destroy()
    end
end

-- Character

local function onCharacterAdded(char)
    Char = char
    Hum = char:WaitForChild("Humanoid")
end

local function getPlayerRoot()
    if not Char then
        return nil
    end

    return Char:FindFirstChild("HumanoidRootPart")
        or Char:FindFirstChild("Head")
end

-- Asset Loader

local function LoadCustomAsset(asset)
    if asset == nil then
        return ""
    end

    local assetString = tostring(asset)

    if assetString:find("rbxassetid://")
        or assetString:find("rbxasset://") then
        return assetString
    end

    if tonumber(assetString) then
        return "rbxassetid://" .. assetString
    end

    if assetString:match("^https?://") then
        local fileName = "CustomImage_" ..
            tostring(math.abs(string.byte(assetString, 1) or 1)) .. ".txt"

        local success = pcall(function()
            if not isfile(fileName) then
                writefile(fileName, game:HttpGet(assetString))
            end
        end)

        if success then
            local getAsset = getcustomasset or getsynasset

            if getAsset then
                local ok, result = pcall(getAsset, fileName)

                if ok then
                    return result
                end
            end
        end
    end

    return assetString
end

-- Sound Loader

local function loadSound(soundData)
    local sound = Instance.new("Sound")
    local soundId = tostring(soundData[1])
    local properties = soundData[2] or {}

    for i, v in next, properties do
        if i ~= "SoundId" and i ~= "Parent" then
            pcall(function()
                sound[i] = v
            end)
        end
    end

    if soundId:find("rbxasset://") then
        sound.SoundId = soundId
    else
        sound.SoundId = "rbxassetid://" .. soundId:gsub("%D", "")
    end

    sound.Parent = workspace
    return sound
end

-- Entity Movement
-- Move the entire model with PivotTo instead of tweening only its PrimaryPart.
-- This also works for models whose other parts are not welded to the PrimaryPart.

local function dragEntity(entityModel, pos, speed)
    if not entityModel or not entityModel.Parent or not entityModel.PrimaryPart then
        return false
    end

    speed = tonumber(speed) or 0

    if speed <= 0 then
        warn("Spawner: Invalid movement speed:", speed)
        return false
    end

    local startPivot = entityModel:GetPivot()
    local distance = (startPivot.Position - pos).Magnitude

    if distance <= 0.01 then
        return true
    end

    local rotation = startPivot - startPivot.Position
    local targetPivot = CFrame.new(pos) * rotation
    local duration = math.max(distance / speed, 0.03)

    local pivotValue = Instance.new("CFrameValue")
    pivotValue.Value = startPivot

    local changedConnection = pivotValue:GetPropertyChangedSignal("Value"):Connect(function()
        if entityModel and entityModel.Parent then
            entityModel:PivotTo(pivotValue.Value)
        end
    end)

    local tween = TS:Create(
        pivotValue,
        TweenInfo.new(duration, Enum.EasingStyle.Linear),
        {Value = targetPivot}
    )

    tween:Play()
    local playbackState = tween.Completed:Wait()

    if changedConnection then
        changedConnection:Disconnect()
    end

    tween:Destroy()
    pivotValue:Destroy()

    return playbackState == Enum.PlaybackState.Completed
end

-- Room Sorting

local function sortRooms(rooms)
    table.sort(rooms, function(a, b)
        local na = tonumber(a.Name)
        local nb = tonumber(b.Name)

        if na and nb then
            return na < nb
        elseif na then
            return true
        elseif nb then
            return false
        end

        return a.Name < b.Name
    end)

    return rooms
end

-- Node Sorting

local function sortNodes(nodeList)
    table.sort(nodeList, function(a, b)
        local na = tonumber(a.Name)
        local nb = tonumber(b.Name)

        if na and nb then
            return na < nb
        elseif na then
            return true
        elseif nb then
            return false
        end

        return a:GetFullName() < b:GetFullName()
    end)

    return nodeList
end

-- Collect Nodes From Room

local function collectRoomNodes(room)
    local roomNodes = {}
    local added = {}

    local function add(node)
        if node and node:IsA("BasePart") and not added[node] then
            added[node] = true
            roomNodes[#roomNodes + 1] = node
        end
    end

    -- Current DOORS

    local pathfindNodes = room:FindFirstChild("PathfindNodes")

    if pathfindNodes then
        local found = {}

        for _, node in ipairs(pathfindNodes:GetDescendants()) do
            if node:IsA("BasePart") then
                found[#found + 1] = node
            end
        end

        sortNodes(found)

        for _, node in ipairs(found) do
            add(node)
        end
    end

    -- Hotel - Vision

    if #roomNodes == 0 then
        local hotelNodes = room:FindFirstChild("Nodes")

        if hotelNodes then
            add(room:FindFirstChild("RoomStart"))

            local found = {}

            for _, node in ipairs(hotelNodes:GetDescendants()) do
                if node:IsA("BasePart") and tonumber(node.Name) then
                    found[#found + 1] = node
                end
            end

            sortNodes(found)

            for _, node in ipairs(found) do
                add(node)
            end

            add(room:FindFirstChild("RoomEnd"))
        end
    end

    -- Fallback

    if #roomNodes == 0 then
        add(room:FindFirstChild("RoomStart"))
        add(room:FindFirstChild("RoomEnd"))

        if #roomNodes == 0 then
            add(room:FindFirstChild("RoomExit"))
        end
    end

    return roomNodes
end

-- Build Route

local function collectRoute(currentRooms)
    local route = {}

    local rooms = sortRooms(currentRooms:GetChildren())

    for _, room in ipairs(rooms) do
        local roomNodes = collectRoomNodes(room)

        for _, node in ipairs(roomNodes) do
            if node.Parent and node:IsDescendantOf(currentRooms) then
                route[#route + 1] = node
            end
        end

        if #roomNodes > 0 then
            print(
                "Spawner:",
                room.Name,
                "nodes:",
                #roomNodes
            )
        end
    end

    return route
end

-- Create Entity

Spawner.createEntity = function(config)
    for i, v in next, SelfModules.DefaultConfig do
        if config[i] == nil then
            config[i] = v
        end
    end

    config.Speed = StaticRushSpeed / 100 * config.Speed

    local function GetGitModel(ModelUrl, ModelName)
        if ModelUrl:match("rbxassetid://") then
            local objects = game:GetObjects(ModelUrl)
            return objects and objects[1]
        end

        if not isfile(ModelName .. ".txt") then
            writefile(ModelName .. ".txt", game:HttpGet(ModelUrl))
        end

        local asset = (getcustomasset or getsynasset)(ModelName .. ".txt")
        local objects = game:GetObjects(asset)
        local model = objects and objects[1]

        if model then
            model.Name = ModelName
        end

        return model
    end

    local entityModel = GetGitModel(
        config.Model,
        "CustomModel_" .. tostring(math.random(1, 100000000))
    )

    if entityModel and entityModel:IsA("Model") then
        entityModel.PrimaryPart = entityModel.PrimaryPart
            or entityModel:FindFirstChildWhichIsA("BasePart", true)

        if entityModel.PrimaryPart then
            entityModel.PrimaryPart.Anchored = true

            if config.CustomName then
                entityModel.Name = config.CustomName
            end

            entityModel:SetAttribute("IsCustomEntity", true)
            entityModel:SetAttribute("NoAI", false)

            return {
                Model = entityModel,
                Config = config,

                Debug = {
                    OnEntitySpawned = function() end,
                    OnEntityDespawned = function() end,
                    OnEntityStartMoving = function() end,
                    OnEntityFinishedRebound = function() end,
                    OnEntityEnteredRoom = function() end,
                    OnLookAtEntity = function() end,
                    OnDeath = function() end
                }
            }
        end
    end

    warn("Spawner: Failed to create entity model or PrimaryPart!")
    safeDestroy(entityModel)
    return nil
end

-- Run Entity

Spawner.runEntity = function(entityTable)
    if not entityTable or not entityTable.Model then
        warn("Spawner: Entity or model is nil!")
        return
    end

    local currentRooms = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms then
        warn("Spawner: CurrentRooms missing!")
        return
    end

    local nodes = collectRoute(currentRooms)

    if #nodes == 0 then
        warn("Spawner: No movement nodes found!")
        return
    end

    print("Spawner: Initial route contains", #nodes, "nodes.")

    -- Spawn Model

    local entityModel = entityTable.Model:Clone()

    if not entityModel then
        return
    end

    entityModel.PrimaryPart = entityModel.PrimaryPart
        or entityModel:FindFirstChildWhichIsA("BasePart", true)

    if not entityModel.PrimaryPart then
        safeDestroy(entityModel)
        warn("Spawner: Entity has no PrimaryPart!")
        return
    end

    local backwards = entityTable.Config.BackwardsMovement
    local startIndex = backwards and #nodes or 1
    local startOffset = backwards and -50 or 50

    entityModel:PivotTo(
        nodes[startIndex].CFrame
        * CFrame.new(0, 0, startOffset)
        + Vector3.new(
            0,
            3.5 + (entityTable.Config.HeightOffset or 0),
            0
        )
    )

    entityModel.Parent = workspace

    EntityConnections[entityModel] = {}
    local entityConnections = EntityConnections[entityModel]

    task.spawn(entityTable.Debug.OnEntitySpawned)

    -- Mute on death screen

    local PlayerGui = Plr:FindFirstChildOfClass("PlayerGui")
    local MainUI = PlayerGui and PlayerGui:FindFirstChild("MainUI")
    local Death = MainUI and MainUI:FindFirstChild("Death")
    local HelpfulDialogue = Death and Death:FindFirstChild("HelpfulDialogue")
    local DeathPanelDead = MainUI and MainUI:FindFirstChild("DeathPanelDead")

    local OnDeathScreen = false

    if HelpfulDialogue and HelpfulDialogue:IsA("GuiObject")
        and DeathPanelDead and DeathPanelDead:IsA("GuiObject") then

        OnDeathScreen = HelpfulDialogue.Visible and not DeathPanelDead.Visible
    end

    if CG:FindFirstChild("JumpscareGui") or OnDeathScreen then
        for _, v in ipairs(entityModel:GetDescendants()) do
            if v:IsA("Sound") and v.Playing then
                v:Stop()
            end
        end
    end

    -- Flicker Lights

    if entityTable.Config.FlickerLights
        and entityTable.Config.FlickerLights[1] then

        local gameData = ReSt:FindFirstChild("GameData")
        local latestRoom = gameData and gameData:FindFirstChild("LatestRoom")
        local flickerRoom = latestRoom
            and currentRooms:FindFirstChild(tostring(latestRoom.Value))

        if flickerRoom then
            ModuleScripts.ModuleEvents.flicker(
                flickerRoom,
                entityTable.Config.FlickerLights[2]
            )
        end
    end

    task.wait(entityTable.Config.DelayTime or 0)

    -- Movement Detection

    local enteredRooms = {}

    entityConnections.movementTick = RS.Stepped:Connect(function()
        if not entityModel.Parent or entityModel:GetAttribute("NoAI") then
            return
        end

        local playerRoot = getPlayerRoot()

        if not playerRoot or not entityModel.PrimaryPart then
            return
        end

        local entityPos = entityModel.PrimaryPart.Position
        local rootPos = playerRoot.Position

        local floorRay = FindPartOnRayWithIgnoreList(
            workspace,
            Ray.new(entityPos, Vector3.new(0, -10, 0)),
            {entityModel, Char}
        )

        local playerInSight = FindPartOnRayWithIgnoreList(
            workspace,
            Ray.new(entityPos, rootPos - entityPos),
            {entityModel, Char}
        ) == nil

        if floorRay and floorRay.Name == "Floor" then
            for _, room in ipairs(currentRooms:GetChildren()) do
                if floorRay:IsDescendantOf(room)
                    and not table.find(enteredRooms, room) then

                    enteredRooms[#enteredRooms + 1] = room

                    task.spawn(entityTable.Debug.OnEntityEnteredRoom, room)

                    if entityTable.Config.BreakLights then
                        ModuleScripts.ModuleEvents.shatter(room)
                    end

                    break
                end
            end
        end

        -- Camera Shake

        local shakeConfig = entityTable.Config.CamShake
        local shakeMag = (
            playerRoot.Position - entityModel.PrimaryPart.Position
        ).Magnitude

        if shakeConfig and shakeConfig[1]
            and shakeMag <= shakeConfig[3] then

            local shakeRep = {}

            for i, v in next, shakeConfig[2] do
                shakeRep[i] = v
            end

            shakeRep[1] = shakeConfig[2][1] / shakeConfig[3]
                * (shakeConfig[3] - shakeMag)

            ModuleScripts.MainGame.camShaker.ShakeOnce(
                ModuleScripts.MainGame.camShaker,
                table.unpack(shakeRep)
            )
        end

        -- Player Detection

        if playerInSight then
            local _, onScreen = WorldToViewportPoint(
                Camera,
                entityModel.PrimaryPart.Position
            )

            if onScreen then
                task.spawn(entityTable.Debug.OnLookAtEntity)
            end

            -- Kill Player

            if entityTable.Config.CanKill
                and not Char:GetAttribute("IsDead")
                and not Char:GetAttribute("Hiding")
                and (playerRoot.Position - entityModel.PrimaryPart.Position).Magnitude
                    <= entityTable.Config.KillRange then

                task.spawn(function()
                    local floorReplicated = ReSt:FindFirstChild("FloorReplicated")
                    local seekMusic = floorReplicated
                        and floorReplicated:FindFirstChild("SeekMusic")

                    if workspace:FindFirstChild("SeekMovingNewClone")
                        or (seekMusic and seekMusic:IsA("Sound") and seekMusic.Playing)
                        or workspace:FindFirstChild("Blink")
                        or workspace:FindFirstChild("Atumalaca") then
                        return
                    end

                    if not Char or not Char.Parent then
                        return
                    end

                    Char:SetAttribute("IsDead", true)

                    for _, v in ipairs(entityModel:GetDescendants()) do
                        if v:IsA("Sound") and v.Playing then
                            v:Stop()
                        end
                    end

                    if entityTable.Config.Jumpscare
                        and entityTable.Config.Jumpscare[1] then

                        Spawner.runJumpscare(entityTable.Config.Jumpscare[2])
                    end

                    task.spawn(entityTable.Debug.OnDeath)

                    if Hum and Hum.Parent then
                        Hum.Health = 0
                    end

                    local gameStats = ReSt:FindFirstChild("GameStats")
                    local playerStats = gameStats
                        and gameStats:FindFirstChild("Player_" .. Plr.Name)

                    local total = playerStats and playerStats:FindFirstChild("Total")
                    local deathCause = total and total:FindFirstChild("DeathCause")

                    if deathCause then
                        deathCause.Value = entityModel.Name
                    end

                    if #entityTable.Config.CustomDialog > 0 then
                        local entityInfo = ReSt:FindFirstChild("EntityInfo")
                        local deathHint = entityInfo
                            and entityInfo:FindFirstChild("DeathHint")

                        if deathHint then
                            firesignal(
                                deathHint.OnClientEvent,
                                entityTable.Config.CustomDialog,
                                "Blue"
                            )
                        end
                    end

                    task.spawn(function()
                        local playerGui = Plr:WaitForChild("PlayerGui")
                        local mainUI = playerGui:WaitForChild("MainUI")
                        local deathPanel = mainUI:WaitForChild("DeathPanelDead")

                        repeat
                            task.wait()
                        until deathPanel.Visible or not entityModel.Parent

                        if not entityModel.Parent then
                            return
                        end

                        for _, v in ipairs(entityModel:GetDescendants()) do
                            if v:IsA("Sound") then
                                local oldVolume = v.Volume
                                v.Volume = 0
                                v:Play()

                                TS:Create(
                                    v,
                                    TweenInfo.new(2),
                                    {Volume = oldVolume}
                                ):Play()
                            end
                        end
                    end)
                end)
            end
        end
    end)

    task.spawn(entityTable.Debug.OnEntityStartMoving)

    -- Route Movement
    -- Rebuild the route while moving so newly loaded rooms are included.

    local cyclesConfig = entityTable.Config.Cycles or {
        Min = 1,
        Max = 1,
        WaitTime = 0
    }

    local minCycles = math.max(1, tonumber(cyclesConfig.Min) or 1)
    local maxCycles = math.max(minCycles, tonumber(cyclesConfig.Max) or minCycles)
    local totalCycles = math.random(minCycles, maxCycles)
    local direction = backwards and -1 or 1
    local heightOffset = 3.5 + (entityTable.Config.HeightOffset or 0)

    for cycle = 1, totalCycles do
        if not entityModel.Parent then
            break
        end

        local visited = {}
        local lastRouteChange = os.clock()
        local previousRoute = nil

        while entityModel.Parent do
            local updatedNodes = collectRoute(currentRooms)

            if #updatedNodes == 0 then
                task.wait(0.2)
                if os.clock() - lastRouteChange > 8 then
                    warn("Spawner: No route nodes became available; ending movement.")
                    break
                end
                continue
            end

            local routeChanged = previousRoute == nil or #previousRoute ~= #updatedNodes

            if not routeChanged then
                for i = 1, #updatedNodes do
                    if previousRoute[i] ~= updatedNodes[i] then
                        routeChanged = true
                        break
                    end
                end
            end

            if routeChanged then
                previousRoute = table.clone(updatedNodes)
                lastRouteChange = os.clock()
            end

            nodes = updatedNodes

            -- Pick the next node that this cycle has not visited yet.
            local nextNode = nil

            if direction == 1 then
                for i = 1, #nodes do
                    local candidate = nodes[i]
                    if candidate and candidate.Parent and not visited[candidate] then
                        nextNode = candidate
                        break
                    end
                end
            else
                for i = #nodes, 1, -1 do
                    local candidate = nodes[i]
                    if candidate and candidate.Parent and not visited[candidate] then
                        nextNode = candidate
                        break
                    end
                end
            end

            if nextNode then
                visited[nextNode] = true
                lastRouteChange = os.clock()

                print("Spawner: Moving to node", nextNode:GetFullName())

                local moved = dragEntity(
                    entityModel,
                    nextNode.Position + Vector3.new(0, heightOffset, 0),
                    entityTable.Config.Speed
                )

                if not moved and entityModel.Parent then
                    task.wait(0.1)
                end
            else
                -- All currently loaded nodes have been visited. Give the game
                -- a moment to stream in the next room before ending this pass.
                task.wait(0.2)

                if os.clock() - lastRouteChange >= 3 then
                    break
                end
            end
        end

        if not entityModel.Parent then
            break
        end

        -- Rebound return trip. Use the latest route, in reverse order.
        if cyclesConfig.Max > 1 and cycle < totalCycles then
            local returnNodes = collectRoute(currentRooms)

            for i = #returnNodes, 1, -1 do
                if not entityModel.Parent then
                    break
                end

                local node = returnNodes[i]
                if node and node.Parent then
                    dragEntity(
                        entityModel,
                        node.Position + Vector3.new(0, heightOffset, 0),
                        entityTable.Config.Speed
                    )
                end
            end
        end

        task.spawn(entityTable.Debug.OnEntityFinishedRebound)

        if cycle < totalCycles then
            task.wait(tonumber(cyclesConfig.WaitTime) or 0)
        end
    end

    -- Cleanup

    if entityModel:GetAttribute("NoAI") then
        return
    end

    for _, connection in next, entityConnections do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end

    task.spawn(entityTable.Debug.OnEntityDespawned)

    if entityModel.PrimaryPart then
        entityModel.PrimaryPart.Anchored = false
        entityModel.PrimaryPart.CanCollide = false
    end

    task.wait(6)

    safeDestroy(entityModel)
    EntityConnections[entityModel] = nil
end

-- Jumpscare

Spawner.runJumpscare = function(config)
    local image1 = LoadCustomAsset(config.Image1)
    local image2 = LoadCustomAsset(config.Image2)

    local sound1, sound2 = nil, nil

    if config.Sound1 then
        sound1 = loadSound(config.Sound1)
    end

    if config.Sound2 then
        sound2 = loadSound(config.Sound2)
    end

    local JumpscareGui = Instance.new("ScreenGui")
    local Background = Instance.new("Frame")
    local Face = Instance.new("ImageLabel")

    JumpscareGui.Name = "JumpscareGui"
    JumpscareGui.IgnoreGuiInset = true
    JumpscareGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    Background.Name = "Background"
    Background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Background.BorderSizePixel = 0
    Background.Size = UDim2.new(1, 0, 1, 0)
    Background.ZIndex = 999

    Face.Name = "Face"
    Face.AnchorPoint = Vector2.new(0.5, 0.5)
    Face.BackgroundTransparency = 1
    Face.Position = UDim2.new(0.5, 0, 0.5, 0)
    Face.ResampleMode = Enum.ResamplerMode.Pixelated
    Face.Size = UDim2.new(0, 150, 0, 150)
    Face.Image = image1

    Face.Parent = Background
    Background.Parent = JumpscareGui
    JumpscareGui.Parent = CG

    -- Tease

    local teaseConfig = config.Tease
    local absHeight = JumpscareGui.AbsoluteSize.Y
    local minTeaseSize = absHeight / 5
    local maxTeaseSize = absHeight / 2.5

    if teaseConfig[1] then
        local teaseAmount = math.random(teaseConfig.Min, teaseConfig.Max)

        if sound1 then
            sound1:Play()
        end

        for _ = teaseConfig.Min, teaseAmount do
            task.wait(math.random(100, 200) / 100)

            local growFactor = (maxTeaseSize - minTeaseSize) / teaseAmount

            Face.Size = UDim2.new(
                0,
                Face.AbsoluteSize.X + growFactor,
                0,
                Face.AbsoluteSize.Y + growFactor
            )
        end

        task.wait(math.random(100, 200) / 100)
    end

    -- Flashing

    if config.Flashing[1] then
        task.spawn(function()
            while JumpscareGui.Parent do
                Background.BackgroundColor3 = config.Flashing[2]
                task.wait(math.random(25, 100) / 1000)

                if not Background.Parent then
                    break
                end

                Background.BackgroundColor3 = Color3.new(0, 0, 0)
                task.wait(math.random(25, 100) / 1000)
            end
        end)
    end

    -- Shaking

    if config.Shake then
        task.spawn(function()
            local origin = Face.Position

            while JumpscareGui.Parent do
                Face.Position = origin + UDim2.new(
                    0,
                    math.random(-10, 10),
                    0,
                    math.random(-10, 10)
                )

                Face.Rotation = math.random(-5, 5)
                task.wait()
            end
        end)
    end

    -- Jumpscare

    Face.Image = image2
    Face.Size = UDim2.new(0, maxTeaseSize, 0, maxTeaseSize)

    if sound2 then
        sound2:Play()
    end

    TS:Create(
        Face,
        TweenInfo.new(0.75),
        {
            Size = UDim2.new(0, absHeight * 3, 0, absHeight * 3),
            ImageTransparency = 0.5
        }
    ):Play()

    task.wait(0.75)

    safeDestroy(JumpscareGui)
    safeDestroy(sound1)
    safeDestroy(sound2)
end

-- Setup

Plr.CharacterAdded:Connect(onCharacterAdded)

local executorEnv = getgenv and getgenv() or _G

if not executorEnv.SpawnerSetup then
    executorEnv.SpawnerSetup = true

    workspace.DescendantRemoving:Connect(function(des)
        if des.Name == "PathfindNodes" then
            local parent = des.Parent

            if parent then
                local clone = des:Clone()
                clone.Parent = parent
            end
        end
    end)
end

return Spawner
