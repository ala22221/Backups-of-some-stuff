
--// Services
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer

--// Utilities
loadstring(game:HttpGet(
    ""
))()

--// Assets
local ROOT = "https://github.com/RegularVynixu/DOORS-Crucifix-Everything/raw/main/Assets/"

local Assets = {
    Repentance = LoadCustomInstance(ROOT.."Repentance.rbxm")
}

local Source = {}

--// Helpers
local function Tween(obj, time, props, style, direction)
    TweenService:Create(obj, TweenInfo.new(
        time,
        style or Enum.EasingStyle.Sine,
        direction or Enum.EasingDirection.InOut
    ), props):Play()
end

local function WaitSound(sound, time)
    repeat
        RunService.RenderStepped:Wait()
    until not sound.Parent or sound.TimePosition >= time
end

local function FadeOut(pentagram)
    for _, v in ipairs(pentagram:GetChildren()) do
        if v.Name == "BeamFlat" then
            task.delay(v:GetAttribute("Delay") or 0, function()
                if v.Parent then
                    Tween(v, 1.5, {Brightness = 0},
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.In)
                end
            end)
        elseif v.Name == "BeamChain" then
            Tween(v, 1.5, {Brightness = 0},
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.In)
        end
    end
end

--// Main Animation
function Source:Play(Config)
    Config = Config or {}

    local Entity = Config.Entity
    local Resist = Config.Resist == true
    local Type = Config.Type or "Guiding"

    if not Entity or not Entity:IsA("Model") then
        warn("Crucifix: Invalid entity")
        return
    end

    local Character = Player.Character or Player.CharacterAdded:Wait()
    local entityPivot = Entity:GetPivot()

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character, Entity}

    local result = workspace:Raycast(
        entityPivot.Position,
        Vector3.new(0, -1000, 0),
        params
    )

    if not result then return end

    Entity:SetAttribute("BeingBanished", true)

    local MainGame = require(Player.PlayerGui.MainUI.Initiator.Main_Game)
    local CamShaker = MainGame.camShaker
    local Shake = CamShaker:StartShake(5, 20, 2, Vector3.zero)

    local Model = Assets.Repentance:Clone()
    local Crucifix = Model.Crucifix
    local Handle = Crucifix.Handle
    local Pentagram = Model.Pentagram
    local EntityPart = Model.Entity
    local Sound = Handle[Resist and "SoundFail" or "Sound"]

    Model:PivotTo(CFrame.new(result.Position))
    Crucifix:PivotTo(Character:GetPivot())
    EntityPart.CFrame = entityPivot
    Model.Parent = workspace

    Sound:Play()

    --// Colors
    local Colors = {
        Guiding = Color3.fromRGB(137, 207, 255),
        Curious = Color3.fromRGB(255, 227, 137)
    }

    local Color = Config.CustomColor or Colors[Type] or Colors.Guiding

    for _, v in ipairs(Model:GetDescendants()) do
        if v.Name == "GiveMeColor" then
            if v:IsA("Light") or v:IsA("BasePart") then
                v.Color = Color
            elseif v:IsA("ParticleEmitter") or v:IsA("Beam") then
                v.Color = ColorSequence.new(Color)
            end
        end
    end

    --// Entity movement
    if not Resist then
        task.spawn(function()
            while EntityPart.Parent do
                if Entity.Parent then
                    Entity:PivotTo(EntityPart.CFrame)
                end
                RunService.RenderStepped:Wait()
            end

            if Entity.Parent then
                Entity:Destroy()
            end
        end)
    end

    --// Pentagram
    Tween(Pentagram.Circle, 2, {
        CFrame = Pentagram.Circle.CFrame - Vector3.new(0, 25, 0)
    }, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

    task.delay(2, function()
        if Pentagram.Circle.Parent then
            Pentagram.Circle:Destroy()
        end
    end)

    --// Floating Crucifix
    Handle.BodyPosition.Position =
        (Character:GetPivot() * CFrame.new(1, 4, -6)).Position

    Tween(Handle.BodyAngularVelocity, 4, {
        AngularVelocity = Vector3.new(0, 40, 0)
    }, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)

    --// Shards
    task.delay(3, function()
        if not Handle.Parent then return end

        for _, shard in ipairs(Handle.Shards:GetChildren()) do
            shard.CollisionGroup = "NoPlayer"
            shard.CanCollide = true

            if shard:FindFirstChild("Weld") then
                shard.Weld:Destroy()
            end

            shard.AssemblyAngularVelocity = Vector3.zero
        end
    end)

    --// Raise entity
    if not Resist then
        Tween(EntityPart, 3, {
            CFrame = EntityPart.CFrame + Vector3.new(0, 2, 0)
        }, Enum.EasingStyle.Elastic, Enum.EasingDirection.In)
    end

    --// Light animation
    task.spawn(function()
        WaitSound(Sound, 2.625)

        if not Model.Parent then return end

        Tween(Pentagram.Base.LightAttach.LightBright, 1.5, {
            Brightness = 5,
            Range = 40
        }, Enum.EasingStyle.Circular)

        Tween(Handle.Light, 1.5, {
            Brightness = 11.25,
            Range = 30
        }, Enum.EasingStyle.Circular)

        task.wait(1.5)

        Tween(Pentagram.Base.LightAttach.LightBright, 1.5, {
            Brightness = 0,
            Range = 0
        }, Enum.EasingStyle.Circular)

        Tween(Handle.Light, 1.5, {
            Brightness = 0,
            Range = 0
        }, Enum.EasingStyle.Circular)

        if not Resist then
            task.wait(1.5)

            Tween(Handle.Light, 1, {
                Brightness = 15,
                Range = 40
            }, Enum.EasingStyle.Circular)

            Shake:StartFadeOut(3)
            FadeOut(Pentagram)

            Tween(Handle.BodyAngularVelocity, 3, {
                AngularVelocity = Vector3.zero
            }, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        end
    end)

    --// Successful banishment
    if not Resist then
        WaitSound(Sound, 2.5)

        Tween(EntityPart, 3, {
            CFrame = EntityPart.CFrame - Vector3.new(0, 50, 0)
        }, Enum.EasingStyle.Back, Enum.EasingDirection.In)

        for _, s in ipairs(Entity:GetDescendants()) do
            if s:IsA("Sound") and not s:GetAttribute("VolumeIgnore") then
                Tween(s, 3, {Volume = 0},
                    Enum.EasingStyle.Back,
                    Enum.EasingDirection.In)
            end
        end

        WaitSound(Sound, 6.75)

    --// Resisted banishment
    else
        WaitSound(Sound, 4)

        Tween(Handle.BodyAngularVelocity, 3, {
            AngularVelocity = Vector3.zero
        })

        local Red = Color3.fromRGB(255, 116, 130)

        Tween(Pentagram.Base.LightAttach.LightBright, 1.5, {
            Brightness = 0,
            Range = 0,
            Color = Red
        })

        Tween(Handle.Light, 1.5, {
            Brightness = 0,
            Range = 0,
            Color = Red
        })

        Shake:StartFadeOut(3)

        local ColorValue = Instance.new("Color3Value")
        ColorValue.Value = Color3.fromRGB(137, 207, 255)

        local ColorTween = TweenService:Create(
            ColorValue,
            TweenInfo.new(0.5, Enum.EasingStyle.Sine),
            {Value = Red}
        )

        ColorTween:Play()

        task.spawn(function()
            while ColorTween.PlaybackState == Enum.PlaybackState.Playing do
                for _, d in ipairs(Model:GetDescendants()) do
                    if d:IsA("Beam") then
                        d.Color = ColorSequence.new(ColorValue.Value)
                    elseif d.Name == "Glow" and d:IsA("BasePart") then
                        d.Color = ColorValue.Value
                    end
                end
                task.wait()
            end

            ColorValue:Destroy()
        end)

        WaitSound(Sound, 9.625)
    end

    --// Final explosion
    Tween(Handle.Glow, 1, {
        Size = Handle.Glow.Size * 3,
        Transparency = 1
    })

    Tween(Pentagram.Base.LightAttach.LightBright, 1, {
        Brightness = 0,
        Range = 0
    })

    Tween(Handle.Light, 1, {
        Brightness = 0,
        Range = 0
    })

    if not Resist then
        Handle.ExplodeParticle:Emit(math.random(20, 30))
        CamShaker:ShakeOnce(7.5, 7.5, 0.25, 1.5)
    else
        Entity:SetAttribute("BeingBanished", false)
        Entity:SetAttribute("Paused", false)
        FadeOut(Pentagram)
    end

    task.delay(5, function()
        if Model.Parent then
            Model:Destroy()
        end
    end)
end

return Source
