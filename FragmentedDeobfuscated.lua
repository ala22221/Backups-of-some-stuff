
local function isFigureActive()local success,result=
pcall(function()
if workspace:FindFirstChild("Figure")then return true end local gameData=game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
if gameData then local latestRoom=gameData:FindFirstChild("LatestRoom")
if latestRoom then local currentRooms=workspace:FindFirstChild("CurrentRooms")
if currentRooms then local currentRoom=currentRooms:FindFirstChild(tostring(latestRoom.Value))
if currentRoom then 
if currentRoom:FindFirstChild("Figure")or currentRoom.Name:lower():find("figure")then return true 
end end 
end end end return false 
end)return success and result end 
local function isInRoom35To49()local success,_i=
pcall(function()local latestRoomValue=game:GetService("ReplicatedStorage"):WaitForChild("GameData"):WaitForChild("LatestRoom")return(latestRoomValue.Value>=35 and latestRoomValue.Value<50)
end)return success and _i end 
task.spawn(function()task.wait(0.5)
pcall(function()local unusedFlag=false 
local function _l(room)
local function processObject(object)
if object.Name=="LightStand"then local lightFixture=object:WaitForChild("LightFixture",5)
if lightFixture then 
if lightFixture:FindFirstChild("BulbZap")then lightFixture:FindFirstChild("BulbZap").SoundId="rbxassetid://4398878054"end lightFixture.ChildAdded:Connect(function(sound)
if sound.Name=="BulbZap"then sound.SoundId="rbxassetid://4398878054"end 
end)
end end 
if object.Name=="Chandelier"then 
if object:FindFirstChild("Stand")and object:FindFirstChild("Stand"):FindFirstChild("BulbZap")then object:FindFirstChild("Stand"):FindFirstChild("BulbZap").SoundId="rbxassetid://4398878054"end 
if object:FindFirstChild("Stand")then object:FindFirstChild("Stand").ChildAdded:Connect(function(sound)
if sound.Name=="BulbZap"then sound.SoundId="rbxassetid://4398878054"end 
end)
end end end for index,descendant in pairs(room:GetDescendants())do processObject(descendant)end room.DescendantAdded:Connect(processObject)end for index,room in pairs(workspace.CurrentRooms:GetChildren())do _l(room)end workspace.CurrentRooms.ChildAdded:Connect(function(room)_l(room)
end)
end)
end)
local function isSeekOrFigureActive()local success,result=
pcall(function()
if workspace:FindFirstChild("Seek")or workspace:FindFirstChild("Figure")then return true end local gameData=game:GetService("ReplicatedStorage"):FindFirstChild("GameData")
if gameData then local latestRoom=gameData:FindFirstChild("LatestRoom")
if latestRoom then local currentRooms=workspace:FindFirstChild("CurrentRooms")
if currentRooms then local currentRoom=currentRooms:FindFirstChild(tostring(latestRoom.Value))
if currentRoom then 
if currentRoom:FindFirstChild("Seek")or currentRoom:FindFirstChild("Figure")or currentRoom.Name:lower():find("seek")or currentRoom.Name:lower():find("figure")then return true 
end end 
end end end return false 
end)return success and result end 
local function reloadOnRoomChange(scriptUrl,normalInterval,specialInterval)
task.spawn(function()local latestRoomValue while not latestRoomValue do 
pcall(function()latestRoomValue=game:GetService("ReplicatedStorage"):WaitForChild("GameData",2):WaitForChild("LatestRoom",2)
end)
if not latestRoomValue then task.wait(1)
end end 
while true do local interval=normalInterval 
if isInRoom35To49()then interval=specialInterval end task.wait(interval)while isFigureActive()do task.wait(1)end local previousRoom=latestRoomValue.Value while latestRoomValue.Value==previousRoom do task.wait(0.5)end 
if not isFigureActive()then 
pcall(function()loadstring(game:HttpGet(scriptUrl))()
end)
end end 
end)end 
local function reloadOnRoomChangeAfterDelay(scriptUrl,interval)
task.spawn(function()local latestRoomValue while not latestRoomValue do 
pcall(function()latestRoomValue=game:GetService("ReplicatedStorage"):WaitForChild("GameData",2):WaitForChild("LatestRoom",2)
end)
if not latestRoomValue then task.wait(1)
end end 
while true do task.wait(interval)while isFigureActive()do task.wait(1)end local previousRoom=latestRoomValue.Value while latestRoomValue.Value==previousRoom do task.wait(0.5)end 
if not isFigureActive()then 
pcall(function()loadstring(game:HttpGet(scriptUrl))()
end)
end end 
end)end 
local function reloadAfterRoom51(scriptUrl,interval)
task.spawn(function()local latestRoomValue while not latestRoomValue do 
pcall(function()latestRoomValue=game:GetService("ReplicatedStorage"):WaitForChild("GameData",2):WaitForChild("LatestRoom",2)
end)
if not latestRoomValue then task.wait(1)
end end while latestRoomValue.Value<51 do task.wait(0.5)end 
while true do task.wait(interval)while isFigureActive()do task.wait(1)end local previousRoom=latestRoomValue.Value while latestRoomValue.Value==previousRoom do task.wait(0.5)end 
if not isFigureActive()then 
pcall(function()loadstring(game:HttpGet(scriptUrl))()
end)
end end 
end)end 
task.spawn(function()
while true do task.wait(35)
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Daze"))()
end)end 
end)
task.spawn(function()
while true do task.wait(450)while isFigureActive()do task.wait(1)end 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Torment"))()
end)end 
end)
task.spawn(function()
while true do task.wait(520)while isFigureActive()do task.wait(1)end 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Noise"))()
end)end 
end)
task.spawn(function()
while true do task.wait(330)task.wait(6)
if not isSeekOrFigureActive()then 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Revoker"))()
end)
end end 
end)
task.spawn(function()
while true do task.wait(360)while isFigureActive()do task.wait(1)end 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Fluster"))()
end)end 
end)
task.spawn(function()
while true do task.wait(630)while isFigureActive()do task.wait(1)end 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Daunt"))()
end)end 
end)
task.spawn(function()
while true do task.wait(300)while isFigureActive()do task.wait(1)end 
pcall(function()loadstring(game:HttpGet("https://github.com/junin724/V4/raw/refs/heads/main/Sprint"))()
end)end 
end)reloadOnRoomChange("https://github.com/junin724/V4/raw/refs/heads/main/Disturbance",200,200)reloadOnRoomChange("https://github.com/junin724/V4/raw/refs/heads/main/Rebound",350,350)reloadOnRoomChangeAfterDelay("https://github.com/junin724/V4/raw/refs/heads/main/Hungered",420)reloadAfterRoom51("https://github.com/junin724/V4/raw/refs/heads/main/Hustle",150)reloadAfterRoom51("https://github.com/junin724/V4/raw/refs/heads/main/Fallacy",160)
