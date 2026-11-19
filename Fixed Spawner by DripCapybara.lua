
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

-- Misc Functions

local function onCharacterAdded(char)
    Char = char
    Hum = char:WaitForChild("Humanoid")
end

local function getPlayerRoot()
    return Char:FindFirstChild("HumanoidRootPart")
        or Char:FindFirstChild("Head")
end

local function loadSound(soundData)
    local sound = Instance.new("Sound")
    local soundId = tostring(soundData[1])
    local properties = soundData[2]

    for i, v in next, properties do
        if i ~= "SoundId" and i ~= "Parent" then
            sound[i] = v
        end
    end

    if soundId:find("rbxasset://") then
        sound.SoundId = soundId
    else
        local numberId = soundId:gsub("%D", "")
        sound.SoundId = "rbxassetid://" .. numberId
    end

    sound.Parent = workspace
    return sound
end

local function dragEntity(entityModel, pos, speed)
    if not entityModel or not entityModel.Parent or not entityModel.PrimaryPart then
        return
    end

    local primaryPart = entityModel.PrimaryPart
    local distance = (primaryPart.Position - pos).Magnitude

    speed = tonumber(speed) or 0

    if speed <= 0 then
        warn("Spawner: Entity speed must be greater than zero!")
        return
    end

    if distance <= 0.001 then
        return
    end

    local tween = TS:Create(
        primaryPart,
        TweenInfo.new(distance / speed, Enum.EasingStyle.Linear),
        {Position = pos}
    )

    tween:Play()
    tween.Completed:Wait()
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
        else
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

    warn("Spawner: Failed to create entity model or find a PrimaryPart!")
    safeDestroy(entityModel)
    return nil
end

-- Run Entity

Spawner.runEntity = function(entityTable)
    if not entityTable or not entityTable.Model then
        warn("Spawner: Entity table or model is nil!")
        return
    end

    local nodes = {}
    local currentRooms = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms then
        warn("Spawner: Workspace.CurrentRooms was not found!")
        return
    end

    -- Sort rooms numerically

    local rooms = currentRooms:GetChildren()

    table.sort(rooms, function(a, b)
        local na, nb = tonumber(a.Name), tonumber(b.Name)

        if na and nb then
            return na < nb
        elseif na then
            return true
        elseif nb then
            return false
        end

        return a.Name < b.Name
    end)

    -- Collect nodes from every room

    for _, room in ipairs(rooms) do
        local pathfindNodes = room:FindFirstChild("PathfindNodes")
        local hotelNodes = room:FindFirstChild("Nodes")
        local roomNodes = {}

        -- Current DOORS nodes

        if pathfindNodes then
            for _, node in ipairs(pathfindNodes:GetDescendants()) do
                if node:IsA("BasePart") then
                    roomNodes[#roomNodes + 1] = node
                end
            end
        end

        -- The Hotel - Vision nodes
        -- Recursively search nested folders.

        if #roomNodes == 0 and hotelNodes then
            local roomStart = room:FindFirstChild("RoomStart")
            local roomEnd = room:FindFirstChild("RoomEnd")

            if roomStart and roomStart:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomStart
            end

            local numberedNodes = {}

            for _, node in ipairs(hotelNodes:GetDescendants()) do
                if node:IsA("BasePart") then
                    numberedNodes[#numberedNodes + 1] = node
                end
            end

            -- Sort numbered nodes

            table.sort(numberedNodes, function(a, b)
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

            for _, node in ipairs(numberedNodes) do
                roomNodes[#roomNodes + 1] = node
            end

            if roomEnd and roomEnd:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomEnd
            end
        end

        -- Fallback

        if #roomNodes == 0 then
            local roomStart = room:FindFirstChild("RoomStart")
            local roomEnd = room:FindFirstChild("RoomEnd")
            local roomExit = room:FindFirstChild("RoomExit")

            if roomStart and roomStart:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomStart
            end

            if roomEnd and roomEnd:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomEnd
            end

            if #roomNodes == 0 and roomExit and roomExit:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomExit
            end
        end

        for _, node in ipairs(roomNodes) do
            nodes[#nodes + 1] = node
        end
    end

    if #nodes == 0 then
        warn("Spawner: No valid pathfinding nodes found in CurrentRooms!")
        return
    end

    print("Spawner: Collected", #nodes, "movement nodes.")

    -- Spawn

    local entityModel = entityTable.Model:Clone()

    if not entityModel then
        warn("Spawner: Failed to clone entity model!")
        return
    end

    if not entityModel.PrimaryPart then
        entityModel.PrimaryPart = entityModel:FindFirstChildWhichIsA("BasePart", true)
    end

    if not entityModel.PrimaryPart then
        warn("Spawner: Spawned entity has no PrimaryPart!")
        safeDestroy(entityModel)
        return
    end

    local startNodeIndex = entityTable.Config.BackwardsMovement and #nodes or 1
    local startNodeOffset = entityTable.Config.BackwardsMovement and -50 or 50

    EntityConnections[entityModel] = {}
    local entityConnections = EntityConnections[entityModel]

    entityModel:PivotTo(
        nodes[startNodeIndex].CFrame
        * CFrame.new(0, 0, startNodeOffset)
        + Vector3.new(0, 3.5 + entityTable.Config.HeightOffset, 0)
    )

    entityModel.Parent = workspace

    task.spawn(entityTable.Debug.OnEntitySpawned)

    -- Mute entity on spawn

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

    -- Flickering

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

    -- Movement detection

    task.wait(entityTable.Config.DelayTime)

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

        -- Entered room

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

        -- Camera shaking

        local shakeConfig = entityTable.Config.CamShake
        local shakeMag = (
            playerRoot.Position - entityModel.PrimaryPart.Position
        ).Magnitude

        if shakeConfig[1] and shakeMag <= shakeConfig[3] then
            local shakeRep = {}

            for i, v in next, shakeConfig[2] do
                shakeRep[i] = v
            end

            shakeRep[1] = shakeConfig[2][1] / shakeConfig[3]
                * (shakeConfig[3] - shakeMag)

            ModuleScripts.MainGame.camShaker:ShakeOnce(
                table.unpack(shakeRep)
            )
        end

        -- Player in sight

        if playerInSight then
            local _, onScreen = WorldToViewportPoint(
                Camera,
                entityModel.PrimaryPart.Position
            )

            if onScreen then
                task.spawn(entityTable.Debug.OnLookAtEntity)
            end

            -- Kill player

            if entityTable.Config.CanKill
                and not Char:GetAttribute("IsDead")
                and not Char:GetAttribute("Hiding")
                and (playerRoot.Position - entityModel.PrimaryPart.Position).Magnitude
                    <= entityTable.Config.KillRange then

                task.spawn(function()
                    -- Prevent death during current Seek sequence

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

                    -- Unmute entity after death panel appears

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

    -- Cycles

    local cyclesConfig = entityTable.Config.Cycles

    if entityTable.Config.BackwardsMovement then
        local inverseNodes = {}

        for nodeIdx = #nodes, 1, -1 do
            inverseNodes[#inverseNodes + 1] = nodes[nodeIdx]
        end

        nodes = inverseNodes
    end

    local totalCycles = math.max(
        math.random(cyclesConfig.Min, cyclesConfig.Max),
        1
    )

    for cycle = 1, totalCycles do
        for nodeIdx = 1, #nodes do
            if not entityModel.Parent then
                break
            end

            dragEntity(
                entityModel,
                nodes[nodeIdx].Position
                    + Vector3.new(0, 3.5 + entityTable.Config.HeightOffset, 0),
                entityTable.Config.Speed
            )
        end

        if cyclesConfig.Max > 1 then
            for nodeIdx = #nodes, 1, -1 do
                if not entityModel.Parent then
                    break
                end

                dragEntity(
                    entityModel,
                    nodes[nodeIdx].Position
                        + Vector3.new(0, 3.5 + entityTable.Config.HeightOffset, 0),
                    entityTable.Config.Speed
                )
            end
        end

        task.spawn(entityTable.Debug.OnEntityFinishedRebound)

        if cycle < totalCycles then
            task.wait(cyclesConfig.WaitTime)
        end
    end

    -- Destroy

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

-- Scripts

Plr.CharacterAdded:Connect(onCharacterAdded)

if not getgenv().SpawnerSetup then
    getgenv().SpawnerSetup = true

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
