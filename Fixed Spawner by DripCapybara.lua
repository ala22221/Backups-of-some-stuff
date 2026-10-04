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

local StaticRushSpeed = 60

local FindPartOnRayWithIgnoreList = workspace.FindPartOnRayWithIgnoreList

local SelfModules = {
    DefaultConfig = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/DripCapybara/Test/main/Doors/Backup/DefaultConfig.lua"
    ))(),
}

local ModuleScripts = {
    ModuleEvents = require(ReSt.ClientModules.Module_Events),
    MainGame = require(Plr.PlayerGui.MainUI.Initiator.Main_Game),
}

local EntityConnections = {}

local Spawner = {}

-- =========================================
-- CHARACTER
-- =========================================

local function onCharacterAdded(char)
    Char = char
    Hum = char:WaitForChild("Humanoid")

    task.defer(function()
        Camera = workspace.CurrentCamera

        if Camera and Hum then
            pcall(function()
                if not Camera.CameraSubject
                    or not Camera.CameraSubject:IsDescendantOf(Char) then
                    Camera.CameraSubject = Hum
                end
            end)
        end
    end)
end

local function getPlayerRoot()
    if not Char then
        return nil
    end

    return Char:FindFirstChild("HumanoidRootPart")
        or Char:FindFirstChild("Head")
end

-- =========================================
-- CAMERA SAFETY
-- =========================================
-- Does NOT force CameraType.
-- Only repairs CameraSubject if it becomes invalid.

local function repairCamera()
    local currentCamera = workspace.CurrentCamera

    if not currentCamera or not Hum or not Hum.Parent then
        return
    end

    local subject = currentCamera.CameraSubject

    if not subject
        or not subject.Parent
        or (
            subject ~= Hum
            and not subject:IsDescendantOf(Char)
        ) then

        pcall(function()
            currentCamera.CameraSubject = Hum
        end)
    end
end

task.spawn(function()
    while task.wait(0.25) do
        repairCamera()
    end
end)

-- =========================================
-- SOUND
-- =========================================

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
        local numberId = soundId:gsub("%D", "")
        sound.SoundId = "rbxassetid://" .. numberId
    end

    sound.Parent = workspace

    return sound
end

-- =========================================
-- ASSET LOADER
-- =========================================

local function LoadCustomAsset(asset)
    if asset == nil then
        return ""
    end

    local assetString = tostring(asset)

    if assetString:match("^rbxassetid://")
        or assetString:match("^rbxasset://")
        or assetString:match("^http://")
        or assetString:match("^https://") then

        return assetString
    end

    if assetString:match("^%d+$") then
        return "rbxassetid://" .. assetString
    end

    return assetString
end

-- =========================================
-- ENTITY MOVEMENT
-- =========================================

local function dragEntity(entityModel, pos, speed)
    if not entityModel
        or not entityModel.Parent
        or not entityModel.PrimaryPart then
        return
    end

    local distance =
        (entityModel.PrimaryPart.Position - pos).Magnitude

    local time =
        distance / math.max(speed, 0.01)

    local tween = TS:Create(
        entityModel.PrimaryPart,
        TweenInfo.new(
            time,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.Out
        ),
        {
            Position = pos
        }
    )

    tween:Play()
    tween.Completed:Wait()
end

-- =========================================
-- CREATE ENTITY
-- =========================================

Spawner.createEntity = function(config)
    config = config or {}

    for i, v in next, SelfModules.DefaultConfig do
        if config[i] == nil then
            config[i] = v
        end
    end

    config.Speed =
        StaticRushSpeed / 100 * config.Speed

    -- =====================================
    -- MODEL LOADER
    -- =====================================

    local function GetGitModel(ModelUrl, ModelName)
        if ModelUrl:match("rbxassetid://") then
            return game:GetObjects(ModelUrl)[1]
        end

        if not isfile(ModelName .. ".txt") then
            writefile(
                ModelName .. ".txt",
                game:HttpGet(ModelUrl)
            )
        end

        local getAsset =
            getcustomasset
            or getsynasset

        if not getAsset then
            error(
                "Your executor does not support getcustomasset or getsynasset"
            )
        end

        local assetObject = game:GetObjects(
            getAsset(ModelName .. ".txt")
        )[1]

        if assetObject then
            assetObject.Name = ModelName
        end

        return assetObject
    end

    -- FIXED MISSING ")"
    local entityModel = GetGitModel(
        config.Model,
        "CustomModel_" .. tostring(math.random(1, 100000000))
    )

    if typeof(entityModel) == "Instance"
        and entityModel.ClassName == "Model" then

        entityModel.PrimaryPart =
            entityModel.PrimaryPart
            or entityModel:FindFirstChildWhichIsA("BasePart")

        if entityModel.PrimaryPart then
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

    warn(
        "Failed to create entity model:",
        config.Model
    )

    return nil
end

-- =========================================
-- RUN ENTITY
-- =========================================

Spawner.runEntity = function(entityTable)
    if not entityTable
        or not entityTable.Model
        or not entityTable.Config then

        warn("Invalid entityTable")
        return
    end

    local nodes = {}

    -- =====================================
    -- FIND NODES
    -- =====================================

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

    -- =====================================
    -- SPAWN
    -- =====================================

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
            3.5
                + entityTable.Config.HeightOffset,
            0
        )
    )

    entityModel.Parent = workspace

    task.spawn(
        entityTable.Debug.OnEntitySpawned
    )

    -- =====================================
    -- MUTE ON DEATH SCREEN
    -- =====================================

    if CG:FindFirstChild("JumpscareGui")
        or (
            Plr.PlayerGui.MainUI.Death.HelpfulDialogue.Visible
            and not Plr.PlayerGui.MainUI.DeathPanelDead.Visible
        ) then

        for _, v in next,
            entityModel:GetDescendants() do

            if v.ClassName == "Sound"
                and v.Playing then

                v:Stop()
            end
        end
    end

    -- =====================================
    -- FLICKER
    -- =====================================

    if entityTable.Config.FlickerLights[1] then
        local latestRoom =
            workspace.CurrentRooms[
                ReSt.GameData.LatestRoom.Value
            ]

        if latestRoom then
            ModuleScripts.ModuleEvents.flicker(
                latestRoom,
                entityTable.Config.FlickerLights[2]
            )
        end
    end

    -- =====================================
    -- DELAY
    -- =====================================

    task.wait(
        entityTable.Config.DelayTime
    )

    -- =====================================
    -- MOVEMENT CONNECTION
    -- =====================================

    local enteredRooms = {}

    entityConnections.movementTick =
        RS.Stepped:Connect(function()

            if not entityModel.Parent
                or entityModel:GetAttribute("NoAI")
                or not entityModel.PrimaryPart then
                return
            end

            local entityPos =
                entityModel.PrimaryPart.Position

            local playerRoot =
                getPlayerRoot()

            if not playerRoot then
                return
            end

            local rootPos =
                playerRoot.Position

            local floorRay =
                FindPartOnRayWithIgnoreList(
                    workspace,
                    Ray.new(
                        entityPos,
                        Vector3.new(0, -10, 0)
                    ),
                    {
                        entityModel,
                        Char
                    }
                )

            local playerInSight =
                FindPartOnRayWithIgnoreList(
                    workspace,
                    Ray.new(
                        entityPos,
                        rootPos - entityPos
                    ),
                    {
                        entityModel,
                        Char
                    }
                ) == nil

            -- =================================
            -- ROOM DETECTION
            -- =================================

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
                            ModuleScripts.ModuleEvents.shatter(
                                room
                            )
                        end

                        break
                    end
                end
            end

            -- =================================
            -- CAMERA SHAKE
            -- =================================

            local shakeConfig =
                entityTable.Config.CamShake

            local shakeDistance =
                (
                    playerRoot.Position
                    - entityModel.PrimaryPart.Position
                ).Magnitude

            if shakeConfig[1]
                and shakeDistance <= shakeConfig[3] then

                local shakeRep = {}

                for i, v in next,
                    shakeConfig[2] do
                    shakeRep[i] = v
                end

                shakeRep[1] =
                    shakeConfig[2][1]
                    / shakeConfig[3]
                    * (
                        shakeConfig[3]
                        - shakeDistance
                    )

                pcall(function()
                    ModuleScripts.MainGame.camShaker:ShakeOnce(
                        table.unpack(shakeRep)
                    )
                end)
            end

            -- =================================
            -- PLAYER DETECTION
            -- =================================

            if playerInSight then

                local currentCamera =
                    workspace.CurrentCamera

                if currentCamera then
                    local _, onScreen =
                        currentCamera:WorldToViewportPoint(
                            entityModel.PrimaryPart.Position
                        )

                    if onScreen then
                        task.spawn(
                            entityTable.Debug.OnLookAtEntity
                        )
                    end
                end

                -- =================================
                -- KILL
                -- =================================

                if entityTable.Config.CanKill
                    and not Char:GetAttribute("IsDead")
                    and not Char:GetAttribute("Hiding")
                    and (
                        playerRoot.Position
                        - entityModel.PrimaryPart.Position
                    ).Magnitude
                    <= entityTable.Config.KillRange then

                    task.spawn(function()

                        -- Prevent cutscene deaths

                        if workspace.Ambience_FigureEnd.Playing
                            or workspace.Ambience_FigureStart.Playing
                            or workspace.Ambience_Figure.Playing
                            or workspace.Ambience_Seek.Playing
                            or workspace:FindFirstChild("Blink")
                            or workspace:FindFirstChild("SeekMoving")
                            or workspace:FindFirstChild("Atumalaca") then

                            return
                        end

                        Char:SetAttribute(
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

                        -- =================================
                        -- JUMPSCARE
                        -- =================================

                        if entityTable.Config.Jumpscare[1] then
                            Spawner.runJumpscare(
                                entityTable.Config.Jumpscare[2]
                            )
                        end

                        -- =================================
                        -- DEATH
                        -- =================================

                        task.spawn(
                            entityTable.Debug.OnDeath
                        )

                        Hum.Health = 0

                        local playerStats =
                            ReSt.GameStats:FindFirstChild(
                                "Player_" .. Plr.Name
                            )

                        if playerStats
                            and playerStats:FindFirstChild("Total")
                            and playerStats.Total:FindFirstChild("DeathCause") then

                            playerStats.Total.DeathCause.Value =
                                entityModel.Name
                        end

                        if #entityTable.Config.CustomDialog > 0 then
                            firesignal(
                                ReSt.EntityInfo.DeathHint.OnClientEvent,
                                entityTable.Config.CustomDialog,
                                "Blue"
                            )
                        end
                    end)
                end
            end
        end)

    task.spawn(
        entityTable.Debug.OnEntityStartMoving
    )

    -- =========================================
    -- CYCLES
    -- =========================================

    local cyclesConfig =
        entityTable.Config.Cycles

    if entityTable.Config.BackwardsMovement then
        local inverseNodes = {}

        for nodeIdx = #nodes, 1, -1 do
            inverseNodes[#inverseNodes + 1] =
                nodes[nodeIdx]
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

    -- =========================================
    -- DESTROY
    -- =========================================

    if entityModel
        and not entityModel:GetAttribute("NoAI") then

        for _, connection in next,
            entityConnections do

            if connection then
                pcall(function()
                    connection:Disconnect()
                end)
            end
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
    end
end

-- =========================================
-- JUMPSCARE
-- =========================================

Spawner.runJumpscare = function(config)
    config = config or {}

    local image1 =
        LoadCustomAsset(config.Image1)

    local image2 =
        LoadCustomAsset(config.Image2)

    local sound1 = nil
    local sound2 = nil

    if config.Sound1 then
        sound1 =
            loadSound(config.Sound1)
    end

    if config.Sound2 then
        sound2 =
            loadSound(config.Sound2)
    end

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
        Color3.fromRGB(0, 0, 0)

    Background.BorderSizePixel =
        0

    Background.Size =
        UDim2.new(1, 0, 1, 0)

    Background.ZIndex = 999

    Face.Name = "Face"

    Face.AnchorPoint =
        Vector2.new(0.5, 0.5)

    Face.BackgroundTransparency = 1

    Face.Position =
        UDim2.new(0.5, 0, 0.5, 0)

    Face.ResampleMode =
        Enum.ResamplerMode.Pixelated

    Face.Size =
        UDim2.new(0, 150, 0, 150)

    Face.Image = image1

    Face.ZIndex = 1000

    Face.Parent = Background
    Background.Parent = JumpscareGui
    JumpscareGui.Parent = CG

    -- =========================================
    -- TEASE
    -- =========================================

    local teaseConfig =
        config.Tease or {
            false,
            Min = 1,
            Max = 1
        }

    local absHeight =
        JumpscareGui.AbsoluteSize.Y

    if absHeight <= 0 then
        absHeight =
            workspace.CurrentCamera.ViewportSize.Y
    end

    local minTeaseSize =
        absHeight / 5

    local maxTeaseSize =
        absHeight / 2.5

    if teaseConfig[1] then

        local teaseAmount =
            math.random(
                teaseConfig.Min,
                teaseConfig.Max
            )

        if sound1 then
            sound1:Play()
        end

        for _ = 1, teaseAmount do

            task.wait(
                math.random(100, 200) / 100
            )

            local growFactor =
                (
                    maxTeaseSize
                    - minTeaseSize
                )
                / teaseAmount

            Face.Size =
                UDim2.new(
                    0,
                    Face.AbsoluteSize.X
                        + growFactor,
                    0,
                    Face.AbsoluteSize.Y
                        + growFactor
                )
        end

        task.wait(
            math.random(100, 200) / 100
        )
    end

    -- =========================================
    -- FLASHING
    -- =========================================

    local flashingConfig =
        config.Flashing or {
            false
        }

    if flashingConfig[1] then

        task.spawn(function()

            while JumpscareGui.Parent do

                Background.BackgroundColor3 =
                    flashingConfig[2]
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

    -- =========================================
    -- SHAKE
    -- =========================================

    if config.Shake then

        task.spawn(function()

            local origin =
                Face.Position

            while JumpscareGui.Parent do

                Face.Position =
                    origin
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

    -- =========================================
    -- FINAL JUMPSCARE
    -- =========================================

    Face.Image =
        image2

    Face.Size =
        UDim2.new(
            0,
            maxTeaseSize,
            0,
            maxTeaseSize
        )

    if sound2 then
        sound2:Play()
    end

    TS:Create(
        Face,
        TweenInfo.new(0.75),
        {
            Size =
                UDim2.new(
                    0,
                    absHeight * 3,
                    0,
                    absHeight * 3
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

    -- Make sure camera hasn't lost the character
    repairCamera()
end

-- =========================================
-- CONNECTIONS
-- =========================================

Plr.CharacterAdded:Connect(
    onCharacterAdded
)



if not SpawnerSetup then

    getgenv().SpawnerSetup = true

    workspace.DescendantRemoving:Connect(
        function(des)

            if des.Name == "PathfindNodes" then

                pcall(function()
                    des:Clone().Parent =
                        des.Parent
                end)
            end
        end
    )
end

-- =========================================
-- RETURN
-- =========================================

return Spawner
