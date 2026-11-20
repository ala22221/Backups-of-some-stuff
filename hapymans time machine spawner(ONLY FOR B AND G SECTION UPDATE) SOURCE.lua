
local EntitySource = {}

--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

--// CONFIGURATION
EntitySource.Config = {
    EntityID = "rbxassetid://132639218330721",

    Speed = 100,
    KillDistance = 15,

    CheckLockers = true,
    CheckTables = true,

    HidingSpotIndex = 3,
    CheckDelay = 0.5,
    TweenToHidingSpots = true,

    CheckSafe = true,
    SafeValueName = "safe",

    RoomPause = 0.5,

    Debug = true,
}

--// VARIABLES
local Running = false
local Entity = nil

local function Debug(...)
    if EntitySource.Config.Debug then
        print("[EntitySource]", ...)
    end
end

--// SAFE CHECK
function EntitySource:IsSafe()
    if not self.Config.CheckSafe then
        return false
    end

    local Larper = workspace:FindFirstChild(Player.Name)
    local Safe = Larper and Larper:FindFirstChild(self.Config.SafeValueName)

    if Safe and Safe:IsA("BoolValue") then
        return Safe.Value
    end

    return false
end

--// ENTITY POSITION
local function GetPivot(Object)
    if Object:IsA("Model") then
        return Object:GetPivot()
    elseif Object:IsA("BasePart") then
        return Object.CFrame
    end
end

local function SetPivot(Object, CF)
    if Object:IsA("Model") then
        Object:PivotTo(CF)
    elseif Object:IsA("BasePart") then
        Object.CFrame = CF
    end
end

--// STOP
function EntitySource:Stop()
    Running = false

    if Entity then
        Entity:Destroy()
        Entity = nil
    end

    Debug("Stopped")
end

--// KILL PLAYER
function EntitySource:KillPlayer()
    if self:IsSafe() then
        Debug("Player is safe!")
        return
    end

    local Character = Player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

    if Humanoid and Humanoid.Health > 0 then
        Debug("Player caught!")
        Humanoid.Health = 0
    end
end

--// MOVEMENT
function EntitySource:MoveTo(Target)
    if not Running or not Entity or not Entity.Parent then
        return
    end

    local Start = GetPivot(Entity)
    local Distance = (Target.Position - Start.Position).Magnitude

    local Duration = math.max(
        Distance / math.max(self.Config.Speed, 1),
        0.01
    )

    local Value = Instance.new("CFrameValue")
    Value.Value = Start

    local Connection = Value:GetPropertyChangedSignal("Value"):Connect(function()
        if Entity and Entity.Parent then
            SetPivot(Entity, Value.Value)
        end
    end)

    local Tween = TweenService:Create(
        Value,
        TweenInfo.new(Duration, Enum.EasingStyle.Linear),
        {Value = Target}
    )

    Tween:Play()
    Tween.Completed:Wait()

    Connection:Disconnect()
    Value:Destroy()
end

--// FIND CHECK BINDABLE
local function FindCheck(Spot)
    for _, Object in ipairs(Spot:GetDescendants()) do
        if Object.Name:lower() == "check" then
            if Object:IsA("BindableEvent")
            or Object:IsA("BindableFunction") then
                return Object
            end
        end
    end

    for _, Object in ipairs(Spot:GetChildren()) do
        if Object.Name:lower() == "check" then
            if Object:IsA("BindableEvent")
            or Object:IsA("BindableFunction") then
                return Object
            end
        end
    end

    return nil
end

--// HIDING SPOT CHECK
function EntitySource:CheckSpot(Spot)
    if not Running then return end

    local Target

    if Spot:IsA("BasePart") then
        Target = Spot.CFrame
    elseif Spot:IsA("Model") then
        Target = Spot:GetPivot()
    else
        local Part = Spot:FindFirstChildWhichIsA("BasePart", true)
        Target = Part and Part.CFrame
    end

    -- Move to hiding spot
    if Target and self.Config.TweenToHidingSpots then
        Debug("Moving to hiding spot:", Spot.Name)
        self:MoveTo(Target)
    end

    if not Running then return end

    -- Check whether player is safe
    local WasSafe = self:IsSafe()

    -- Activate hiding spot check
    local Check = FindCheck(Spot)

    if Check then
        Debug("Activating check:", Spot:GetFullName())

        if Check:IsA("BindableEvent") then
            pcall(function()
                Check:Fire()
            end)
        elseif Check:IsA("BindableFunction") then
            task.spawn(function()
                pcall(function()
                    Check:Invoke()
                end)
            end)
        end
    else
        Debug("No Check Bindable found:", Spot.Name)
    end

    task.wait(self.Config.CheckDelay)

    if not Running then return end

    -- Recheck safety AFTER the hiding spot check
    local IsSafeNow = self:IsSafe()

    if not IsSafeNow then
        Debug("Player is vulnerable at hiding spot!")
        self:KillPlayer()
    else
        Debug("Player is protected")
    end
end

--// CHECK FOLDER
function EntitySource:CheckFolder(Room, FolderName)
    local Folder = Room:FindFirstChild(FolderName)

    if not Folder then return end

    local Children = Folder:GetChildren()
    local Spot = Children[self.Config.HidingSpotIndex]

    if Spot then
        self:CheckSpot(Spot)
    end
end

--// CHECK ROOM
function EntitySource:CheckRoom(Room)
    Debug("Checking room:", Room.Name)

    if self.Config.CheckTables then
        self:CheckFolder(Room, "Tables")
    end

    if self.Config.CheckLockers then
        self:CheckFolder(Room, "Lockers")
    end

    task.wait(self.Config.RoomPause)
end

--// KILL DETECTION LOOP
local function StartKillLoop(Source)
    task.spawn(function()
        while Running and Entity and Entity.Parent do
            if not Source:IsSafe() then
                local Character = Player.Character
                local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
                local Root = Character and Character:FindFirstChild("HumanoidRootPart")

                if Humanoid and Root and Humanoid.Health > 0 then
                    local EntityPosition = GetPivot(Entity).Position

                    local Distance = (Root.Position - EntityPosition).Magnitude

                    if Distance <= Source.Config.KillDistance then
                        Source:KillPlayer()
                    end
                end
            end

            task.wait(0.1)
        end
    end)
end

--// LOAD ENTITY
local function LoadEntity(ID)
    local Success, Result = pcall(function()
        return game:GetObjects(ID)[1]
    end)

    if not Success then
        warn("[EntitySource] Loading failed:", Result)
        return nil
    end

    return Result
end

--// START ENTITY
function EntitySource:Start(SpawnCFrame, EndCFrame)
    if Running then
        warn("Entity already running!")
        return
    end

    Running = true

    -- Load model
    Entity = LoadEntity(self.Config.EntityID)

    if not Entity then
        Running = false
        return
    end

    if not Entity:IsA("Model") and not Entity:IsA("BasePart") then
        warn("Invalid entity model")
        self:Stop()
        return
    end

    Entity.Parent = workspace

    -- Anchor
    for _, Object in ipairs(Entity:GetDescendants()) do
        if Object:IsA("BasePart") then
            Object.Anchored = true
        end
    end

    if Entity:IsA("BasePart") then
        Entity.Anchored = true
    end

    -- Spawn
    SetPivot(Entity, SpawnCFrame)

    Debug("Entity spawned")

    StartKillLoop(self)

    -- Rooms
    local Rooms = workspace:WaitForChild("CurrentRooms")
    local LatestRoom = ReplicatedStorage
        :WaitForChild("GameData")
        :WaitForChild("LatestRoom")

    local Checked = {}

    while Running do
        local Latest = LatestRoom.Value

        -- Process loaded rooms in numerical order
        local RoomList = {}

        for _, Room in ipairs(Rooms:GetChildren()) do
            local Number = tonumber(Room.Name)

            if Number and Number <= Latest and not Checked[Number] then
                table.insert(RoomList, {
                    Number = Number,
                    Instance = Room
                })
            end
        end

        table.sort(RoomList, function(A, B)
            return A.Number < B.Number
        end)

        for _, Data in ipairs(RoomList) do
            if not Running then break end

            local Room = Data.Instance

            if Room and Room.Parent then
                Checked[Data.Number] = true

                self:MoveTo(Room:GetPivot())

                if Running then
                    self:CheckRoom(Room)
                end
            end
        end

        -- Stop when the entity has reached the latest room
        if Checked[Latest] then
            break
        end

        task.wait(0.1)
    end

    -- Final destination
    if Running then
        Debug("Moving to front")
        self:MoveTo(EndCFrame)
    end

    self:Stop()
    Debug("Entity finished")
end

return EntitySource
