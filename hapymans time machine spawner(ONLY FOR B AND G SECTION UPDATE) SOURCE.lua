
--// ENTITY SOURCE

local EntitySource = {}

--// SERVICES
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer

--// CONFIGURATION
EntitySource.Config = {
    EntityID = "rbxassetid://132639218330721",

    Speed = 100,
    KillDistance = 15,

    -- SPAWNING
    SpawnFromFront = false,

    -- REBOUND
    Rebound = true,
    ReboundDelay = 1,
    ReboundCount = 0, -- 0 = infinite

    -- HIDING SPOTS
    CheckLockers = true,
    CheckTables = true,
    HidingSpotIndex = 3,
    CheckDelay = 0.5,
    TweenToHidingSpots = true,

    -- SAFETY
    CheckSafe = true,
    SafeValueName = "safe",

    RoomPause = 0.2,
    Debug = true,
}

--// STATE
local Running = false
local Entity = nil
local ActiveTween = nil

local function Debug(...)
    if EntitySource.Config.Debug then
        print("[EntitySource]", ...)
    end
end

--// LATEST ROOM
local function GetLatestRoom(Rooms)
    local Latest = 0

    for _, Room in ipairs(Rooms:GetChildren()) do
        local Number = tonumber(Room.Name)

        if Number and Number > Latest then
            Latest = Number
        end
    end

    return Latest
end

--// SAFETY
function EntitySource:IsSafe()
    if not self.Config.CheckSafe then
        return false
    end

    local Character = workspace:FindFirstChild(Player.Name)
    local Safe = Character and Character:FindFirstChild(
        self.Config.SafeValueName
    )

    if Safe and Safe:IsA("BoolValue") then
        return Safe.Value
    end

    -- Unknown safety state: do not kill
    return true
end

--// ENTITY PIVOT
local function GetPivot(Object)
    if not Object then
        return nil
    end

    if Object:IsA("Model") then
        return Object:GetPivot()
    elseif Object:IsA("BasePart") then
        return Object.CFrame
    end

    return nil
end

local function SetPivot(Object, CF)
    if not Object or not Object.Parent then
        return
    end

    if Object:IsA("Model") then
        Object:PivotTo(CF)
    elseif Object:IsA("BasePart") then
        Object.CFrame = CF
    end
end

--// STOP
function EntitySource:Stop()
    Running = false

    if ActiveTween then
        pcall(function()
            ActiveTween:Cancel()
        end)

        ActiveTween = nil
    end

    if Entity then
        Entity:Destroy()
        Entity = nil
    end

    Debug("Stopped")
end

--// KILL PLAYER
function EntitySource:KillPlayer()
    if self:IsSafe() then
        return
    end

    local Character = Player.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")

    if Humanoid and Humanoid.Health > 0 then
        Debug("Player caught")
        Humanoid.Health = 0
    end
end

--// MOVEMENT
function EntitySource:MoveTo(Target)
    if not Running or not Entity or not Entity.Parent then
        return false
    end

    local Start = GetPivot(Entity)

    if not Start or not Target then
        return false
    end

    local Distance = (Target.Position - Start.Position).Magnitude
    local Duration = math.max(
        Distance / math.max(self.Config.Speed, 1),
        0.01
    )

    Debug("Moving:", math.floor(Distance), "studs")

    local Value = Instance.new("CFrameValue")
    Value.Value = Start

    local Connection = Value:GetPropertyChangedSignal("Value"):Connect(function()
        if Running and Entity and Entity.Parent then
            SetPivot(Entity, Value.Value)
        end
    end)

    local Tween = TweenService:Create(
        Value,
        TweenInfo.new(Duration, Enum.EasingStyle.Linear),
        {Value = Target}
    )

    ActiveTween = Tween
    Tween:Play()

    local State = Tween.Completed:Wait()

    if ActiveTween == Tween then
        ActiveTween = nil
    end

    Connection:Disconnect()
    Value:Destroy()

    return Running and State == Enum.PlaybackState.Completed
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

--// HIDING SPOT POSITION
local function GetSpotCFrame(Spot)
    if Spot:IsA("BasePart") then
        return Spot.CFrame
    elseif Spot:IsA("Model") then
        return Spot:GetPivot()
    end

    local Part = Spot:FindFirstChildWhichIsA("BasePart", true)

    return Part and Part.CFrame
end

--// CHECK HIDING SPOT
function EntitySource:CheckSpot(Spot)
    if not Running then
        return
    end

    Debug("Approaching:", Spot:GetFullName())

    local Target = GetSpotCFrame(Spot)

    if Target and self.Config.TweenToHidingSpots then
        if not self:MoveTo(Target) then
            return
        end
    end

    if not Running then
        return
    end

    local Check = FindCheck(Spot)

    if Check then
        Debug("Activating:", Check:GetFullName())

        if Check:IsA("BindableEvent") then
            local Success, Error = pcall(function()
                Check:Fire()
            end)

            if not Success then
                warn("[EntitySource] Bindable error:", Error)
            end

        elseif Check:IsA("BindableFunction") then
            task.spawn(function()
                pcall(function()
                    Check:Invoke()
                end)
            end)
        end
    else
        Debug("No check Bindable found")
    end

    task.wait(self.Config.CheckDelay)

    if not Running then
        return
    end

    if self:IsSafe() then
        Debug("Player is safe")
    else
        self:KillPlayer()
    end
end

--// CHECK FOLDER
function EntitySource:CheckFolder(Room, FolderName)
    local Folder = Room:FindFirstChild(FolderName)

    if not Folder then
        Debug("Missing folder:", FolderName)
        return
    end

    local Children = Folder:GetChildren()
    local Spot = Children[self.Config.HidingSpotIndex]

    if Spot then
        self:CheckSpot(Spot)
    else
        Debug("No spot at index:", self.Config.HidingSpotIndex)
    end
end

--// CHECK ONLY LATEST ROOM
function EntitySource:CheckLatestRoom(Rooms)
    if not Running then
        return
    end

    local LatestNumber = GetLatestRoom(Rooms)

    if LatestNumber <= 0 then
        Debug("No latest room found")
        return
    end

    local LatestRoom = Rooms:FindFirstChild(tostring(LatestNumber))

    if not LatestRoom then
        Debug("Latest room disappeared")
        return
    end

    Debug("Checking ONLY latest room:", LatestNumber)

    if self.Config.CheckTables then
        self:CheckFolder(LatestRoom, "Tables")
    end

    if not Running then
        return
    end

    if self.Config.CheckLockers then
        self:CheckFolder(LatestRoom, "Lockers")
    end

    task.wait(self.Config.RoomPause)
end

--// KILL LOOP
local function StartKillLoop(Source)
    task.spawn(function()
        while Running and Entity and Entity.Parent do
            if not Source:IsSafe() then
                local Character = Player.Character
                local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
                local Root = Character and Character:FindFirstChild("HumanoidRootPart")
                local EntityPivot = GetPivot(Entity)

                if Humanoid and Root and EntityPivot and Humanoid.Health > 0 then
                    local Distance = (Root.Position - EntityPivot.Position).Magnitude

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
    local Success, Objects = pcall(function()
        return game:GetObjects(ID)
    end)

    if not Success or not Objects or not Objects[1] then
        warn("[EntitySource] Failed to load entity:", Objects)
        return nil
    end

    return Objects[1]
end

--// GET ROOM LIST
local function GetRoomList(Rooms, Latest)
    local Result = {}

    for _, Room in ipairs(Rooms:GetChildren()) do
        local Number = tonumber(Room.Name)

        if Number and Number <= Latest then
            table.insert(Result, {
                Number = Number,
                Instance = Room
            })
        end
    end

    return Result
end

--// TRAVEL THROUGH ROOMS
function EntitySource:RunPass(Rooms, Direction)
    local Latest = GetLatestRoom(Rooms)

    if Latest <= 0 then
        Debug("No numbered rooms found")
        return false
    end

    local RoomList = GetRoomList(Rooms, Latest)

    table.sort(RoomList, function(A, B)
        if Direction == 1 then
            return A.Number < B.Number
        else
            return A.Number > B.Number
        end
    end)

    Debug("Starting pass. Direction:", Direction)

    for _, Data in ipairs(RoomList) do
        if not Running then
            return false
        end

        local Room = Data.Instance

        if Room and Room.Parent then
            Debug("Moving through room:", Data.Number)

            if not self:MoveTo(Room:GetPivot()) then
                return false
            end
        end
    end

    -- Check tables and lockers ONLY in the latest room
    if not Running then
        return false
    end

    self:CheckLatestRoom(Rooms)

    return Running
end

--// START
function EntitySource:Start(BackCFrame, FrontCFrame)
    if Running then
        warn("[EntitySource] Already running")
        return
    end

    if typeof(BackCFrame) ~= "CFrame"
        or typeof(FrontCFrame) ~= "CFrame" then
        warn("[EntitySource] Invalid endpoint CFrames")
        return
    end

    Running = true

    local SpawnFromFront = self.Config.SpawnFromFront == true

    local StartCFrame
    local FinishCFrame
    local InitialDirection

    if SpawnFromFront then
        StartCFrame = FrontCFrame
        FinishCFrame = BackCFrame
        InitialDirection = -1
    else
        StartCFrame = BackCFrame
        FinishCFrame = FrontCFrame
        InitialDirection = 1
    end

    Debug("Loading entity")

    Entity = LoadEntity(self.Config.EntityID)

    if not Entity then
        Running = false
        return
    end

    if not Entity:IsA("Model") and not Entity:IsA("BasePart") then
        warn("[EntitySource] Entity must be a Model or BasePart")
        self:Stop()
        return
    end

    Entity.Parent = workspace

    for _, Object in ipairs(Entity:GetDescendants()) do
        if Object:IsA("BasePart") then
            Object.Anchored = true
            Object.CanCollide = false
        end
    end

    if Entity:IsA("BasePart") then
        Entity.Anchored = true
        Entity.CanCollide = false
    end

    SetPivot(Entity, StartCFrame)

    Debug("Spawned at:", SpawnFromFront and "front" or "back")

    StartKillLoop(self)

    local Rooms = workspace:WaitForChild("CurrentRooms")

    local Direction = InitialDirection
    local CompletedRebounds = 0

    while Running do
        Debug("Moving direction:", Direction)

        if not self:RunPass(Rooms, Direction) then
            break
        end

        if not self:MoveTo(FinishCFrame) then
            break
        end

        Debug("Reached endpoint")

        if not self.Config.Rebound then
            break
        end

        -- Swap endpoints and reverse direction
        local PreviousStart = StartCFrame
        StartCFrame = FinishCFrame
        FinishCFrame = PreviousStart

        Direction = -Direction

        -- A complete cycle means the entity has returned
        -- to the endpoint it originally spawned at.
        if Direction == InitialDirection then
            CompletedRebounds += 1
            Debug("Completed rebound cycles:", CompletedRebounds)
        end

        if self.Config.ReboundCount > 0
            and CompletedRebounds >= self.Config.ReboundCount then
            Debug("Rebound limit reached")
            break
        end

        task.wait(self.Config.ReboundDelay)
    end

    self:Stop()
    Debug("Finished")
end

return EntitySource
