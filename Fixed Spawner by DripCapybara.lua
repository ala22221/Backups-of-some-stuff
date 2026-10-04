```lua
--// Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

--// Player
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local StaticRushSpeed = 60

--// Modules
local SelfModules = {
    DefaultConfig = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/DripCapybara/Test/main/Doors/Backup/DefaultConfig.lua"
    ))()
}

local ModuleScripts = {
    ModuleEvents = require(ReplicatedStorage.ClientModules.Module_Events),
}

local EntityConnections = {}
local Spawner = {}

--==================================================
-- CHARACTER
--==================================================

local function onCharacterAdded(char)
    Character = char
    Humanoid = char:WaitForChild("Humanoid")
end

local function getPlayerRoot()
    if not Character then
        return nil
    end

    return Character:FindFirstChild("HumanoidRootPart")
        or Character:FindFirstChild("Head")
end

--==================================================
-- CAMERA FIX
--==================================================
-- Does NOT force CameraType.
-- Does NOT use Main_Game.camShaker.
-- Only restores CameraSubject when it is actually invalid.

local function fixCamera()
    local Camera = workspace.CurrentCamera

    if not Camera then
        return
    end

    if not Humanoid or not Humanoid.Parent then
        return
    end

    local subject = Camera.CameraSubject

    if subject == nil or not subject.Parent then
        pcall(function()
            Camera.CameraSubject = Humanoid
        end)
        return
    end

    -- If the camera somehow got assigned to something
    -- completely unrelated to the player's character.
    if subject ~= Humanoid
        and not subject:IsDescendantOf(Character) then

        pcall(function()
            Camera.CameraSubject = Humanoid
        end)
    end
end

task.spawn(function()
    while task.wait(0.5) do
        -- Don't interfere with normal cutscenes.
        if not Character:GetAttribute("IsDead") then
            fixCamera()
        end
    end
end)

--==================================================
-- SOUND
--==================================================

local function loadSound(soundData)
    if not soundData then
        return nil
    end

    local sound = Instance.new("Sound")

    local soundId = tostring(soundData[1])
    local properties = soundData[2] or {}

    for property, value in next, properties do
        if property ~= "SoundId"
            and property ~= "Parent" then

            pcall(function()
                sound[property] = value
            end)
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

--==================================================
-- IMAGE ASSET
--==================================================

local function LoadCustomAsset(asset)
    if asset == nil then
        return ""
    end

    local value = tostring(asset)

    if value:match("^rbxassetid://") then
        return value
    end

    if value:match("^%d+$") then
        return "rbxassetid://" .. value
    end

    return value
end

--==================================================
-- ENTITY MOVEMENT
--==================================================

local function dragEntity(entityModel, position, speed)
    if not entityModel
        or not entityModel.Parent
        or not entityModel.PrimaryPart then
        return
    end

    local distance =
        (entityModel.PrimaryPart.Position - position).Magnitude

    local travelTime =
        distance / math.max(speed, 0.01)

    local tween = TweenService:Create(
        entityModel.PrimaryPart,
        TweenInfo.new(
            travelTime,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            Position = position
        }
    )

    tween:Play()
    tween.Completed:Wait()
end

--==================================================
-- MODEL LOADER
--==================================================

local function GetGitModel(modelUrl, modelName)

    -- RBX asset ID
    if modelUrl:match("^rbxassetid://") then

        local success, objects = pcall(function()
            return game:GetObjects(modelUrl)
        end)

        if not success then
            warn("GetObjects failed:", objects)
            return nil
        end

        return objects and objects[1]
    end

    local getAsset =
        getcustomasset
        or getsynasset

    if not getAsset then
        warn("getcustomasset/getsynasset is unavailable")
        return nil
    end

    local fileName = modelName .. ".rbxm"

    -- Download model
    if not isfile(fileName) then

        local success, data = pcall(function()
            return game:HttpGet(modelUrl)
        end)

        if not success then
            warn("Failed to download model:", data)
            return nil
        end

        if not data or #data == 0 then
            warn("Downloaded model is empty")
            return nil
        end

        local writeSuccess, writeError = pcall(function()
            writefile(fileName, data)
        end)

        if not writeSuccess then
            warn("Failed to save model:", writeError)
            return nil
        end
    end

    -- Convert local file into Roblox asset
    local customAsset

    local assetSuccess, assetError = pcall(function()
        customAsset = getAsset(fileName)
    end)

    if not assetSuccess then
        warn("getcustomasset failed:", assetError)
        return nil
    end

    if not customAsset then
        warn("getcustomasset returned nil")
        return nil
    end

    -- Load RBXM
    local objectSuccess, objects = pcall(function()
        return game:GetObjects(customAsset)
    end)

    if not objectSuccess then
        warn("Failed to load RBXM:", objects)
        return nil
    end

    if not objects or not objects[1] then
        warn("RBXM contained no object")
        return nil
    end

    local object = objects[1]
    object.Name = modelName

    return object
end

--==================================================
-- CREATE ENTITY
--==================================================

Spawner.createEntity = function(config)

    config = config or {}

    -- Fill missing config options
    for i, value in next, SelfModules.DefaultConfig do
        if config[i] == nil then
            config[i] = value
        end
    end

    config.Speed =
        StaticRushSpeed / 100 * config.Speed

    -- Load model
    local entityModel = GetGitModel(
        config.Model,
        "CustomModel_" .. tostring(math.random(1, 100000000))
    )

    if not entityModel then
        warn("FAILED TO CREATE ENTITY MODEL")
        warn("Model:", config.Model)
        return nil
    end

    if entityModel.ClassName ~= "Model" then
        warn(
            "Entity is not a Model:",
            entityModel.ClassName
        )

        pcall(function()
            entityModel:Destroy()
        end)

        return nil
    end

    entityModel.PrimaryPart =
        entityModel.PrimaryPart
        or entityModel:FindFirstChildWhichIsA("BasePart")

    if not entityModel.PrimaryPart then
        warn("Entity has no PrimaryPart/BasePart")

        pcall(function()
            entityModel:Destroy()
        end)

        return nil
    end

    entityModel.PrimaryPart.Anchored = true

    if config.CustomName then
        entityModel.Name = config.CustomName
    end

    entityModel:SetAttribute(
        "IsCustomEntity",
        true
    )

    entityModel:SetAttribute(
        "NoAI",
        false
    )

    -- ALWAYS create Debug table
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

--==================================================
-- RUN ENTITY
--==================================================

Spawner.runEntity = function(entityTable)

    if not entityTable then
        warn("runEntity: entityTable is nil")
        return
    end

    if not entityTable.Model then
        warn("runEntity: entityTable.Model is nil")
        return
    end

    if not entityTable.Debug then
        warn("runEntity: entityTable.Debug is nil")
        return
    end

    local nodes = {}

    --==================================================
    -- FIND NODES
    --==================================================

    for _, room in next, workspace.CurrentRooms:GetChildren() do

        local pathfindNodes =
            room:FindFirstChild("PathfindNodes")

        if pathfindNodes then
            pathfindNodes =
                pathfindNodes:GetChildren()
        else
            local fakeNode =
                Instance.new("Part")

            fakeNode.Name = "1"

            fakeNode.CFrame =
                room:WaitForChild("RoomExit").CFrame
                - Vector3.new(
                    0,
                    room.RoomExit.Size.Y / 2,
                    0
                )

            pathfindNodes = {
                fakeNode
            }
        end

        table.sort(
            pathfindNodes,
            function(a, b)
                return tonumber(a.Name)
                    < tonumber(b.Name)
            end
        )

        for _, node in next, pathfindNodes do
            nodes[#nodes + 1] = node
        end
    end

    if #nodes == 0 then
        warn("No pathfind nodes found")
        return
    end

    --==================================================
    -- SPAWN
    --==================================================

    local entityModel =
        entityTable.Model:Clone()

    local startNodeIndex =
        entityTable.Config.BackwardsMovement
        and #nodes
        or 1

    local startNodeOffset =
        entityTable.Config.BackwardsMovement
        and -50
        or 50

    EntityConnections[entityModel] = {}

    local entityConnections =
        EntityConnections[entityModel]

    entityModel:PivotTo(
        nodes[startNodeIndex].CFrame
        * CFrame.new(
            0,
            0,
            startNodeOffset
        )
        + Vector3.new(
            0,
            3.5 + entityTable.Config.HeightOffset,
            0
        )
    )

    entityModel.Parent = workspace

    task.spawn(
        entityTable.Debug.OnEntitySpawned
    )

    --==================================================
    -- FLICKER
    --==================================================

    if entityTable.Config.FlickerLights[1] then

        local latestRoom =
            workspace.CurrentRooms[
                ReplicatedStorage.GameData.LatestRoom.Value
            ]

        if latestRoom then
            pcall(function()
                ModuleScripts.ModuleEvents.flicker(
                    latestRoom,
                    entityTable.Config.FlickerLights[2]
                )
            end)
        end
    end

    --==================================================
    -- DELAY
    --==================================================

    task.wait(
        entityTable.Config.DelayTime
    )

    --==================================================
    -- MOVEMENT
    --==================================================

    local enteredRooms = {}

    entityConnections.movementTick =
        RunService.Stepped:Connect(function()

            if not entityModel.Parent
                or not entityModel.PrimaryPart
                or entityModel:GetAttribute("NoAI") then
                return
            end

            local playerRoot =
                getPlayerRoot()

            if not playerRoot then
                return
            end

            local entityPos =
                entityModel.PrimaryPart.Position

            local rootPos =
                playerRoot.Position

            local floorRay =
                workspace:FindPartOnRayWithIgnoreList(
                    Ray.new(
                        entityPos,
                        Vector3.new(0, -10, 0)
                    ),
                    {
                        entityModel,
                        Character
                    }
                )

            local playerInSight =
                workspace:FindPartOnRayWithIgnoreList(
                    Ray.new(
                        entityPos,
                        rootPos - entityPos
                    ),
                    {
                        entityModel,
                        Character
                    }
                ) == nil

            -- Room detection
            if floorRay
                and floorRay.Name == "Floor" then

                for _, room in next,
                    workspace.CurrentRooms:GetChildren() do

                    if floorRay:IsDescendantOf(room)
                        and not table.find(
                            enteredRooms,
                            room
                        ) then

                        enteredRooms[#enteredRooms + 1] =
                            room

                        task.spawn(
                            entityTable.Debug.OnEntityEnteredRoom,
                            room
                        )

                        if entityTable.Config.BreakLights then
                            pcall(function()
                                ModuleScripts.ModuleEvents.shatter(room)
                            end)
                        end

                        break
                    end
                end
            end

            --==================================================
            -- CAMERA SHAKE
            --==================================================
            -- INTENTIONALLY DISABLED.
            --
            -- The old code called:
            -- MainGame.camShaker:ShakeOnce(...)
            --
            -- That is the part most likely to conflict
            -- with the current DOORS camera controller.

            --==================================================
            -- PLAYER DETECTION
            --==================================================

            if playerInSight then

                local Camera =
                    workspace.CurrentCamera

                if Camera then

                    local _, onScreen =
                        Camera:WorldToViewportPoint(
                            entityModel.PrimaryPart.Position
                        )

                    if onScreen then
                        task.spawn(
                            entityTable.Debug.OnLookAtEntity
                        )
                    end
                end

                --==================================================
                -- KILL
                --==================================================

                if entityTable.Config.CanKill
                    and not Character:GetAttribute("IsDead")
                    and not Character:GetAttribute("Hiding")
                    and (
                        playerRoot.Position
                        - entityModel.PrimaryPart.Position
                    ).Magnitude
                    <= entityTable.Config.KillRange then

                    task.spawn(function()

                        if workspace.Ambience_FigureEnd.Playing
                            or workspace.Ambience_FigureStart.Playing
                            or workspace.Ambience_Figure.Playing
                            or workspace.Ambience_Seek.Playing
                            or workspace:FindFirstChild("Blink")
                            or workspace:FindFirstChild("SeekMoving")
                            or workspace:FindFirstChild("Atumalaca") then
                            return
                        end

                        Character:SetAttribute(
                            "IsDead",
                            true
                        )

                        -- Mute entity
                        for _, v in next,
                            entityModel:GetDescendants() do

                            if v.ClassName == "Sound"
                                and v.Playing then
                                v:Stop()
                            end
                        end

                        -- Jumpscare
                        if entityTable.Config.Jumpscare[1] then
                            Spawner.runJumpscare(
                                entityTable.Config.Jumpscare[2]
                            )
                        end

                        task.spawn(
                            entityTable.Debug.OnDeath
                        )

                        Humanoid.Health = 0

                        local playerStats =
                            ReplicatedStorage.GameStats:FindFirstChild(
                                "Player_" .. Player.Name
                            )

                        if playerStats
                            and playerStats:FindFirstChild("Total")
                            and playerStats.Total:FindFirstChild("DeathCause") then

                            playerStats.Total.DeathCause.Value =
                                entityModel.Name
                        end

                        if #entityTable.Config.CustomDialog > 0 then
                            pcall(function()
                                firesignal(
                                    ReplicatedStorage.EntityInfo.DeathHint.OnClientEvent,
                                    entityTable.Config.CustomDialog,
                                    "Blue"
                                )
                            end)
                        end
                    end)
                end
            end
        end)

    task.spawn(
        entityTable.Debug.OnEntityStartMoving
    )

    --==================================================
    -- CYCLES
    --==================================================

    local cyclesConfig =
        entityTable.Config.Cycles

    if entityTable.Config.BackwardsMovement then

        local inverseNodes = {}

        for i = #nodes, 1, -1 do
            inverseNodes[#inverseNodes + 1] =
                nodes[i]
        end

        nodes = inverseNodes
    end

    local cycleAmount =
        math.max(
            math.random(
                cyclesConfig.Min,
                cyclesConfig.Max
            ),
            1
        )

    for cycle = 1, cycleAmount do

        -- Forward
        for nodeIdx = 1, #nodes do

            dragEntity(
                entityModel,

                nodes[nodeIdx].Position
                    + Vector3.new(
                        0,
                        3.5
                            + entityTable.Config.HeightOffset,
                        0
                    ),

                entityTable.Config.Speed
            )
        end

        -- Reverse
        if cyclesConfig.Max > 1 then

            for nodeIdx = #nodes, 1, -1 do

                dragEntity(
                    entityModel,

                    nodes[nodeIdx].Position
                        + Vector3.new(
                            0,
                            3.5
                                + entityTable.Config.HeightOffset,
                            0
                        ),

                    entityTable.Config.Speed
                )
            end
        end

        task.spawn(
            entityTable.Debug.OnEntityFinishedRebound
        )

        if cycle < cycleAmount then
            task.wait(
                cyclesConfig.WaitTime
            )
        end
    end

    --==================================================
    -- DESPAWN
    --==================================================

    for _, connection in next,
        entityConnections do

        pcall(function()
            connection:Disconnect()
        end)
    end

    task.spawn(
        entityTable.Debug.OnEntityDespawned
    )

    if entityModel.PrimaryPart then
        entityModel.PrimaryPart.Anchored = false
        entityModel.PrimaryPart.CanCollide = false
    end

    task.wait(6)

    if entityModel then
        entityModel:Destroy()
    end

    EntityConnections[entityModel] = nil

    -- Repair camera AFTER entity is gone
    if not Character:GetAttribute("IsDead") then
        fixCamera()
    end
end

--==================================================
-- JUMPSCARE
--==================================================

Spawner.runJumpscare = function(config)

    config = config or {}

    local image1 =
        LoadCustomAsset(config.Image1)

    local image2 =
        LoadCustomAsset(config.Image2)

    local sound1 =
        config.Sound1
        and loadSound(config.Sound1)

    local sound2 =
        config.Sound2
        and loadSound(config.Sound2)

    -- UI
    local JumpscareGui =
        Instance.new("ScreenGui")

    local Background =
        Instance.new("Frame")

    local Face =
        Instance.new("ImageLabel")

    JumpscareGui.Name =
        "JumpscareGui"

    JumpscareGui.IgnoreGuiInset =
        true

    JumpscareGui.ZIndexBehavior =
        Enum.ZIndexBehavior.Sibling

    Background.Name =
        "Background"

    Background.BackgroundColor3 =
        Color3.new(0, 0, 0)

    Background.BorderSizePixel = 0

    Background.Size =
        UDim2.new(1, 0, 1, 0)

    Background.ZIndex = 999

    Face.Name = "Face"

    Face.AnchorPoint =
        Vector2.new(0.5, 0.5)

    Face.BackgroundTransparency = 1

    Face.Position =
        UDim2.new(0.5, 0, 0.5, 0)

    Face.Size =
        UDim2.new(0, 150, 0, 150)

    Face.Image = image1

    Face.ZIndex = 1000

    Face.Parent = Background
    Background.Parent = JumpscareGui
    JumpscareGui.Parent = CoreGui

    --==================================================
    -- TEASE
    --==================================================

    local tease =
        config.Tease
        or {
            false,
            Min = 1,
            Max = 1
        }

    local height =
        JumpscareGui.AbsoluteSize.Y

    if height <= 0 then
        height =
            workspace.CurrentCamera.ViewportSize.Y
    end

    local minSize =
        height / 5

    local maxSize =
        height / 2.5

    if tease[1] then

        local amount =
            math.random(
                tease.Min,
                tease.Max
            )

        if sound1 then
            sound1:Play()
        end

        for _ = 1, amount do

            task.wait(
                math.random(100, 200) / 100
            )

            local grow =
                (maxSize - minSize)
                / amount

            Face.Size =
                UDim2.new(
                    0,
                    Face.AbsoluteSize.X + grow,
                    0,
                    Face.AbsoluteSize.Y + grow
                )
        end

        task.wait(
            math.random(100, 200) / 100
        )
    end

    --==================================================
    -- FLASHING
    --==================================================

    local flashing =
        config.Flashing
        or {false}

    if flashing[1] then

        task.spawn(function()

            while JumpscareGui.Parent do

                Background.BackgroundColor3 =
                    flashing[2]
                    or Color3.new(1, 1, 1)

                task.wait(
                    math.random(25, 100) / 1000
                )

                if not JumpscareGui.Parent then
                    break
                end

                Background.BackgroundColor3 =
                    Color3.new(0, 0, 0)

                task.wait(
                    math.random(25, 100) / 1000
                )
            end
        end)
    end

    --==================================================
    -- SHAKE
    --==================================================

    if config.Shake then

        task.spawn(function()

            local originalPosition =
                Face.Position

            while JumpscareGui.Parent do

                Face.Position =
                    originalPosition
                    + UDim2.new(
                        0,
                        math.random(-10, 10),
                        0,
                        math.random(-10, 10)
                    )

                Face.Rotation =
                    math.random(-5, 5)

                task.wait()
            end
        end)
    end

    --==================================================
    -- FINAL JUMPSCARE
    --==================================================

    Face.Image = image2

    Face.Size =
        UDim2.new(
            0,
            maxSize,
            0,
            maxSize
        )

    if sound2 then
        sound2:Play()
    end

    TweenService:Create(
        Face,
        TweenInfo.new(0.75),
        {
            Size =
                UDim2.new(
                    0,
                    height * 3,
                    0,
                    height * 3
                ),

            ImageTransparency = 0.5
        }
    ):Play()

    task.wait(0.75)

    if JumpscareGui then
        JumpscareGui:Destroy()
    end

    if sound1 then
        sound1:Destroy()
    end

    if sound2 then
        sound2:Destroy()
    end

    -- Only repair if the player isn't dead
    if not Character:GetAttribute("IsDead") then
        fixCamera()
    end
end

--==================================================
-- CHARACTER CONNECTION
--==================================================

Player.CharacterAdded:Connect(
    onCharacterAdded
)

--==================================================
-- PATHFIND NODE PROTECTION
--==================================================

if not SpawnerSetup then

    getgenv().SpawnerSetup = true

    workspace.DescendantRemoving:Connect(
        function(descendant)

            if descendant.Name == "PathfindNodes" then

                pcall(function()
                    descendant:Clone().Parent =
                        descendant.Parent
                end)
            end
        end
    )
end

--==================================================
-- RETURN
--==================================================

return Spawner
