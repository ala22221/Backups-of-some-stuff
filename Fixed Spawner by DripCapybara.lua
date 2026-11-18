
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
    DefaultConfig = loadstring(game:HttpGet("https://raw.githubusercontent.com/DripCapybara/Test/main/Doors/Backup/DefaultConfig.lua"))(),
}

local ModuleScripts = {
    ModuleEvents = require(legacyhotelmodule.Module_Events),
    MainGame = require(Plr.PlayerGui.MainUI.Initiator.Main_Game),
}

local EntityConnections = {}

local Spawner = {}

-- Misc Functions

function onCharacterAdded(char)
    Char, Hum = char, char:WaitForChild("Humanoid")
end

function getPlayerRoot()
    return Char:FindFirstChild("HumanoidRootPart") or Char:FindFirstChild("Head")
end

function loadSound(soundData)
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

function dragEntity(entityModel, pos, speed)
    if not entityModel or not entityModel.PrimaryPart then
        return
    end

    local Distance = (entityModel.PrimaryPart.Position - pos).Magnitude
    speed = tonumber(speed) or 0

    if speed <= 0 then
        warn("Spawner: Entity speed must be greater than zero!")
        return
    end

    local Time = Distance / speed

    local Tween = TS:Create(
        entityModel.PrimaryPart,
        TweenInfo.new(Time, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        {Position = pos}
    )

    Tween:Play()
    Tween.Completed:Wait()
end

-- Create Entity

Spawner.createEntity = function(config)
    for i, v in next, SelfModules.DefaultConfig do
        if config[i] == nil then
            config[i] = v
        end
    end

    config.Speed = StaticRushSpeed / 100 * config.Speed

    -- Model

    local function GetGitModel(ModelUrl, ModelName)
        if ModelUrl:match("rbxassetid://") then
            return game:GetObjects(ModelUrl)[1]
        else
            if not isfile(ModelName .. ".txt") then
                writefile(ModelName .. ".txt", game:HttpGet(ModelUrl))
            end

            local a = game:GetObjects((getcustomasset or getsynasset)(ModelName .. ".txt"))[1]
            a.Name = ModelName

            return a
        end
    end

    local entityModel = GetGitModel(
        config.Model,
        "CustomModel_" .. tostring(math.random(1, 100000000))
    )

    if typeof(entityModel) == "Instance" and entityModel.ClassName == "Model" then
        entityModel.PrimaryPart = entityModel.PrimaryPart or entityModel:FindFirstChildWhichIsA("BasePart")

        if entityModel.PrimaryPart then
            entityModel.PrimaryPart.Anchored = true

            if config.CustomName then
                entityModel.Name = config.CustomName
            end

            entityModel:SetAttribute("IsCustomEntity", true)
            entityModel:SetAttribute("NoAI", false)

            -- Entity Table

            local entityTable = {
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

            return entityTable
        end
    end

    warn("Spawner: Failed to create entity model or find a PrimaryPart!")
    return nil
end

-- Run Entity

Spawner.runEntity = function(entityTable)
    if not entityTable or not entityTable.Model then
        warn("Spawner: Entity table or model is nil!")
        return
    end

    -- Nodes (Current DOORS + The Hotel - Vision)

    local nodes = {}
    local currentRooms = workspace:FindFirstChild("CurrentRooms")

    if not currentRooms then
        warn("Spawner: Workspace.CurrentRooms was not found!")
        return
    end

    -- Sort rooms numerically

    local rooms = currentRooms:GetChildren()

    table.sort(rooms, function(a, b)
        local numberA = tonumber(a.Name)
        local numberB = tonumber(b.Name)

        if numberA and numberB then
            return numberA < numberB
        elseif numberA then
            return true
        elseif numberB then
            return false
        end

        return a.Name < b.Name
    end)

    for _, room in ipairs(rooms) do
        local pathfindNodes = room:FindFirstChild("PathfindNodes")
        local hotelNodes = room:FindFirstChild("Nodes")
        local roomNodes = {}

        if pathfindNodes then
            -- Current DOORS

            for _, node in ipairs(pathfindNodes:GetChildren()) do
                if node:IsA("BasePart") then
                    roomNodes[#roomNodes + 1] = node
                end
            end

        elseif hotelNodes then
            -- The Hotel - Vision

            local roomStart = room:FindFirstChild("RoomStart")
            local roomEnd = room:FindFirstChild("RoomEnd")

            if roomStart and roomStart:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomStart
            end

            local numberedNodes = {}

            for _, node in ipairs(hotelNodes:GetChildren()) do
                if node:IsA("BasePart") then
                    numberedNodes[#numberedNodes + 1] = node
                end
            end

            table.sort(numberedNodes, function(a, b)
                local na, nb = tonumber(a.Name), tonumber(b.Name)

                if na and nb then return na < nb end
                if na then return true end
                if nb then return false end

                return a.Name < b.Name
            end)

            for _, node in ipairs(numberedNodes) do
                roomNodes[#roomNodes + 1] = node
            end

            if roomEnd and roomEnd:IsA("BasePart") then
                roomNodes[#roomNodes + 1] = roomEnd
            end

        else
            -- Fallback

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

    -- Spawn

    local entityModel = entityTable.Model:Clone()

    if not entityModel.PrimaryPart then
        entityModel.PrimaryPart = entityModel:FindFirstChildWhichIsA("BasePart")
    end

    if not entityModel.PrimaryPart then
        warn("Spawner: Spawned entity has no PrimaryPart!")
        entityModel:Destroy()
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
    -- HelpfulDialogue is optional; missing UI elements won't cause an error.

    local PlayerGui = Plr:FindFirstChildOfClass("PlayerGui")
    local MainUI = PlayerGui and PlayerGui:FindFirstChild("MainUI")
    local Death = MainUI and MainUI:FindFirstChild("Death")
    local HelpfulDialogue = Death and Death:FindFirstChild("HelpfulDialogue")
    local DeathPanelDead = MainUI and MainUI:FindFirstChild("DeathPanelDead")

    local OnDeathScreen = false

    if HelpfulDialogue and HelpfulDialogue:IsA("GuiObject") then
        if DeathPanelDead and DeathPanelDead:IsA("GuiObject") then
            OnDeathScreen = HelpfulDialogue.Visible and not DeathPanelDead.Visible
        end
    end

    if CG:FindFirstChild("JumpscareGui") or OnDeathScreen then
        warn("On death screen, mute entity")

        for _, v in ipairs(entityModel:GetDescendants()) do
            if v:IsA("Sound") and v.Playing then
                v:Stop()
            end
        end
    end

    -- Flickering

    if entityTable.Config.FlickerLights[1] then
        local latestRoom = ReSt:FindFirstChild("GameData")
            and ReSt.GameData:FindFirstChild("LatestRoom")

        local flickerRoom = latestRoom
            and currentRooms:FindFirstChild(tostring(latestRoom.Value))

        if flickerRoom then
            ModuleScripts.ModuleEvents.flicker(
                flickerRoom,
                entityTable.Config.FlickerLights[2]
            )
        end
    end

    -- Movement

    task.wait(entityTable.Config.DelayTime)

    local enteredRooms = {}

    entityConnections.movementTick = RS.Stepped:Connect(function()
        if entityModel.Parent and not entityModel:GetAttribute("NoAI") then
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

            if floorRay ~= nil and floorRay.Name == "Floor" then
                for _, room in ipairs(currentRooms:GetChildren()) do
                    if floorRay:IsDescendantOf(room) and not table.find(enteredRooms, room) then
                        enteredRooms[#enteredRooms + 1] = room

                        task.spawn(entityTable.Debug.OnEntityEnteredRoom, room)

                        -- Break lights

                        if entityTable.Config.BreakLights then
                            ModuleScripts.ModuleEvents.shatter(room)
                        end

                        break
                    end
                end
            end

            -- Camera shaking

            local shakeConfig = entityTable.Config.CamShake
            local shakeMag = (playerRoot.Position - entityModel.PrimaryPart.Position).Magnitude

            if shakeConfig[1] and shakeMag <= shakeConfig[3] then
                local shakeRep = {}

                for i, v in next, shakeConfig[2] do
                    shakeRep[i] = v
                end

                shakeRep[1] = shakeConfig[2][1] / shakeConfig[3] * (shakeConfig[3] - shakeMag)

                ModuleScripts.MainGame.camShaker.ShakeOnce(
                    ModuleScripts.MainGame.camShaker,
                    table.unpack(shakeRep)
                )
            end

            -- Player in sight

            if playerInSight then
                -- Look at entity

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
                    and (playerRoot.Position - entityModel.PrimaryPart.Position).Magnitude <= entityTable.Config.KillRange then

                    task.spawn(function()
                        -- Prevent cutscene death

                        if workspace:FindFirstChild("Ambience_FigureEnd")
                            and workspace.Ambience_FigureEnd.Playing then
                            return
                        end

                        if workspace:FindFirstChild("Ambience_FigureStart")
                            and workspace.Ambience_FigureStart.Playing then
                            return
                        end

                        if workspace:FindFirstChild("Ambience_Figure")
                            and workspace.Ambience_Figure.Playing then
                            return
                        end

                        if workspace:FindFirstChild("Ambience_Seek")
                            and workspace.Ambience_Seek.Playing then
                            return
                        end

                        if workspace:FindFirstChild("Blink")
                            or workspace:FindFirstChild("SeekMovingNewClone")
                            or workspace:FindFirstChild("Atumalaca") then
                            return
                        end

                        Char:SetAttribute("IsDead", true)

                        -- Mute entity

                        warn("Mute entity")

                        for _, v in ipairs(entityModel:GetDescendants()) do
                            if v:IsA("Sound") and v.Playing then
                                v:Stop()
                            end
                        end

                        -- Jumpscare

                        if entityTable.Config.Jumpscare[1] then
                            Spawner.runJumpscare(entityTable.Config.Jumpscare[2])
                        end

                        -- Death handling

                        task.spawn(entityTable.Debug.OnDeath)

                        Hum.Health = 0

                        local gameStats = ReSt:FindFirstChild("GameStats")
                        local playerStats = gameStats and gameStats:FindFirstChild("Player_" .. Plr.Name)
                        local total = playerStats and playerStats:FindFirstChild("Total")
                        local deathCause = total and total:FindFirstChild("DeathCause")

                        if deathCause then
                            deathCause.Value = entityModel.Name
                        end

                        if #entityTable.Config.CustomDialog > 0 then
                            firesignal(
                                ReSt.EntityInfo.DeathHint.OnClientEvent,
                                entityTable.Config.CustomDialog,
                                "Blue"
                            )
                        end

                        -- Unmute entity

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

                            warn("Unmute entity:", entityModel)

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

    for cycle = 1, math.max(math.random(cyclesConfig.Min, cyclesConfig.Max), 1) do
        for nodeIdx = 1, #nodes do
            dragEntity(
                entityModel,
                nodes[nodeIdx].Position + Vector3.new(0, 3.5 + entityTable.Config.HeightOffset, 0),
                entityTable.Config.Speed
            )
        end

        if cyclesConfig.Max > 1 then
            for nodeIdx = #nodes, 1, -1 do
                dragEntity(
                    entityModel,
                    nodes[nodeIdx].Position + Vector3.new(0, 3.5 + entityTable.Config.HeightOffset, 0),
                    entityTable.Config.Speed
                )
            end
        end

        -- Rebound finished

        task.spawn(entityTable.Debug.OnEntityFinishedRebound)

        if cycle < cyclesConfig.Max then
            task.wait(cyclesConfig.WaitTime)
        end
    end

    -- Destroy

    if not entityModel:GetAttribute("NoAI") then
        for _, v in next, entityConnections do
            v:Disconnect()
        end

        task.spawn(entityTable.Debug.OnEntityDespawned)

        if entityModel.PrimaryPart then
            entityModel.PrimaryPart.Anchored = false
            entityModel.PrimaryPart.CanCollide = false
        end

        task.wait(6)

        if entityModel then
            entityModel:Destroy()
        end
    end
end

-- Jumpscare

Spawner.runJumpscare = function(config)
    -- Variables

    local image1 = LoadCustomAsset(config.Image1)
    local image2 = LoadCustomAsset(config.Image2)

    local sound1, sound2 = nil, nil

    if config.Sound1 then
        sound1 = loadSound(config.Sound1)
    end

    if config.Sound2 then
        sound2 = loadSound(config.Sound2)
    end

    -- UI Construction

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

        -- Only play if Sound1 exists

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

    -- Only play if Sound2 exists

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

    JumpscareGui:Destroy()

    if sound1 then
        sound1:Destroy()
    end

    if sound2 then
        sound2:Destroy()
    end
end

-- Scripts

Plr.CharacterAdded:Connect(onCharacterAdded)

if not SpawnerSetup then
    getgenv().SpawnerSetup = true

    workspace.DescendantRemoving:Connect(function(des)
        if des.Name == "PathfindNodes" then
            local parent = des.Parent

            if parent then
                des:Clone().Parent = parent
            end
        end
    end)
end

return Spawner
