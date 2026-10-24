local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Ă¥Â¸Â¸Ă©â€¡Â
local WHITE = Color3.fromRGB(255, 255, 255)
local BROWN = Color3.fromRGB(56, 46, 39)
local BEIGE = Color3.fromRGB(213, 185, 158)
local TRANSPARENT = 1

-- Ă¥Ë†â€ºĂ¥Â»Âº GUI Ă¥â€¦Æ’Ă§Â´ Ă§Ââ€Ă¥â€¡Â½Ă¦â€¢Â°
local function createGuiElement(className, properties)
    local element = Instance.new(className)
    for property, value in pairs(properties) do
        element[property] = value
    end
    return element
end

-- Ă¥Ë†â€ºĂ¥Â»Âº GUI Ă¥â€¦Æ’Ă§Â´ 
local StaminaGui = createGuiElement("ScreenGui", {Name = "StaminaGui", Parent = Parent, Enabled = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local Sprint = createGuiElement("Frame", {Name = "Sprint", Parent = StaminaGui, AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = WHITE, BackgroundTransparency = TRANSPARENT, Position = UDim2.new(0.93, 0, 0.5, 0), Size = UDim2.new(0.056, 0, 0.076, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = 1005})
local ImageLabel = createGuiElement("ImageLabel", {Parent = Sprint, BackgroundColor3 = BEIGE, Size = UDim2.new(1, 0, 1, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY, Visible = false})
local Bar = createGuiElement("Frame", {Name = "Bar", Parent = Sprint, AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = BROWN, BackgroundTransparency = 0.7, Position = UDim2.new(-2.726, 0, 0.5, 0), Size = UDim2.new(5, 0, 0.3, 0), ZIndex = 0})
local Fill = createGuiElement("Frame", {Name = "Fill", Parent = Bar, AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = BEIGE, Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), ZIndex = 2})

-- Ă¦Â·Â»Ă¥Â Ă¥Â¥â€Ă¨Â·â€˜Ă¦Å’â€°Ă©â€™Â®
local RunButton = createGuiElement("TextButton", {
    Parent = StaminaGui,
    Text = "Sprint",
    Size = UDim2.new(0.1, 0, 0.1, 0),
    Position = UDim2.new(0.9, 0, 0.5, 0), -- Ă¦â€Â¾Ă¥Å“Â¨Ă¥Â±ÂĂ¥Â¹â€¢Ă¥ÂÂ³Ă¨Â¾Â¹
    BackgroundColor3 = BEIGE,
    TextColor3 = BROWN,
    Font = Enum.Font.SourceSans,
    TextScaled = true
})
local RunButtonCorner = createGuiElement("UICorner", {CornerRadius = UDim.new(0.25, 0), Parent = RunButton})

-- Ă¥ÂËœĂ©â€¡Â
local Plr = Players.LocalPlayer
local Char = Plr.Character or Plr.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")

local stamina, staminaMax = 100, 100
local cooldown = false
local isSprinting = false

local ModuleScripts = {
    MainGame = require(Plr.PlayerGui.MainUI.Initiator.Main_Game),
}

-- Hook metamethod
local nIdx; nIdx = hookmetamethod(game, "__newindex", newcclosure(function(t, k, v)
    if k == "WalkSpeed" then
        if ModuleScripts.MainGame.chase then
            v = ModuleScripts.MainGame.crouching and 15 or 22
        elseif ModuleScripts.MainGame.crouching then
            v = 8
        else
            v = isSprinting and 22 or 12
        end
    end
    return nIdx(t, k, v)
end))

local zerostamtween = TweenService:Create(ImageLabel, TweenInfo.new(12), {ImageTransparency = 0})

local function toggleSprint()
    if cooldown then return end -- Ă¥Â¦â€Ă¦ÂÅ“Ă¥Å“Â¨Ă¥â€ Â·Ă¥ÂÂ´Ă§ÂÂ¶Ă¦â‚¬ÂĂ¯Â¼Å’Ă§â€ºÂ´Ă¦ÂÂ¥Ă¨Â¿â€Ă¥â€ºÂ

    if isSprinting then
        -- Ă¥ÂÅ“Ă¦Â­Â¢Ă¥Â¥â€Ă¨Â·â€˜
        isSprinting = false
        Hum:SetAttribute("SpeedBoost", 0)
        Hum.WalkSpeed = 12
        TweenService:Create(ImageLabel, TweenInfo.new(1), {ImageTransparency = 1}):Play()
    else
        -- Ă¥Â¼â‚¬Ă¥Â§â€¹Ă¥Â¥â€Ă¨Â·â€˜
        isSprinting = true
        Hum:SetAttribute("SpeedBoost", 4)
        zerostamtween:Play()
        while isSprinting and stamina > 0 do
            Hum.WalkSpeed = 22
            stamina = math.max(stamina - 1, 0)
            Fill.Size = UDim2.new(1 * stamina / staminaMax, 1, 1, 0)
            task.wait(0.1)
        end
        zerostamtween:Pause()
        isSprinting = false
        Hum:SetAttribute("SpeedBoost", 0)
        Hum.WalkSpeed = 12
        TweenService:Create(ImageLabel, TweenInfo.new(1), {ImageTransparency = 1}):Play()

        if stamina == 0 then
            -- Ă¥â€ Â·Ă¥ÂÂ´
            ModuleScripts.MainGame.caption("You are tired...", true)
            local noStaminaSound = Instance.new("Sound", workspace)
            noStaminaSound.SoundId = "rbxassetid://8258601891"
            noStaminaSound.Volume = 0.8
            noStaminaSound.PlayOnRemove = true
            noStaminaSound:Destroy()
            cooldown = true
            TweenService:Create(ImageLabel, TweenInfo.new(0.3), {ImageTransparency = 0}):Play()
            wait(0.3)
            TweenService:Create(ImageLabel, TweenInfo.new(10), {ImageTransparency = 1}):Play()
            for i = 1, staminaMax, 1 do
                stamina = i
                Fill.Size = UDim2.new(1 * stamina / staminaMax, 1, 1, 0)
                task.wait(0.14)
            end
            cooldown = false
        else
            -- Ă¨Â¡Â¥Ă¥â€¦â€¦
            cooldown = false
            TweenService:Create(ImageLabel, TweenInfo.new(1), {ImageTransparency = 1}):Play()
            while not isSprinting do
                stamina = math.min(stamina + 1, staminaMax)
                Fill.Size = UDim2.new(1 * stamina / staminaMax, 1, 1, 0)
                task.wait(0.14)
            end
        end        
    end
end

-- Ă§Â»â€˜Ă¥Â®ÂĂ¦Å’â€°Ă©â€™Â®Ă§â€Â¹Ă¥â€¡Â»Ă¤Âºâ€¹Ă¤Â»Â¶
RunButton.MouseButton1Click:Connect(toggleSprint)

Hum:SetAttribute("SpeedBoost", 0)
Hum.WalkSpeed = 12
