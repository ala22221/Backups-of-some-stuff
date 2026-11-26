-- Garante que o jogo já carregou
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer

local currentGui = nil

local function setupSprintGui()
    -- Remove uma GUI antiga caso já exista para evitar duplicatas
    if CoreGui:FindFirstChild("DoorsBottomSprintGui") then
        CoreGui.DoorsBottomSprintGui:Destroy()
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    -- Criando a ScreenGui principal
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "DoorsBottomSprintGui"
    screenGui.IgnoreGuiInset = true
    pcall(function()
        screenGui.Parent = CoreGui
    end)
    if not screenGui.Parent then
        screenGui.Parent = player:WaitForChild("PlayerGui")
    end
    currentGui = screenGui

    -- 1. BOTÃO DE SPRINT COM O QUADRADO BRANCO NO CANTO INFERIOR DIREITO
    local sprintButton = Instance.new("TextButton")
    sprintButton.Name = "SprintSquareButton"
    sprintButton.Size = UDim2.new(0, 95, 0, 70) 
    sprintButton.Position = UDim2.new(1, -115, 1, -85) 
    sprintButton.BackgroundColor3 = Color3.fromRGB(115, 115, 115) 
    sprintButton.BorderSizePixel = 0
    sprintButton.Text = ""
    sprintButton.Parent = screenGui

    -- O quadrado branco estilizado dentro do botão
    local cutSquare = Instance.new("Frame")
    cutSquare.Name = "CutSquareDesign"
    cutSquare.Size = UDim2.new(0, 40, 0, 40)
    cutSquare.AnchorPoint = Vector2.new(0.5, 0.5)
    cutSquare.Position = UDim2.new(0.5, 0, 0.5, 0)
    cutSquare.BackgroundTransparency = 1
    cutSquare.Parent = sprintButton

    local cutStroke = Instance.new("UIStroke")
    cutStroke.Color = Color3.fromRGB(255, 255, 255)
    cutStroke.Thickness = 3
    cutStroke.Parent = cutSquare

    -- 2. BARRA DE SPRINT HORIZONTAL ABAIXO DOS ITENS (Com contorno preto e grossura 4)
    local bottomSprintBarOuter = Instance.new("Frame")
    bottomSprintBarOuter.Name = "BottomSprintOuter"
    bottomSprintBarOuter.Size = UDim2.new(0, 210, 0, 6) 
    bottomSprintBarOuter.AnchorPoint = Vector2.new(0.5, 1)
    bottomSprintBarOuter.Position = UDim2.new(0.5, 0, 1, -8) 
    bottomSprintBarOuter.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    bottomSprintBarOuter.BorderSizePixel = 0
    bottomSprintBarOuter.Parent = screenGui

    -- Adicionando o UIStroke com grossura 4 e cor preta
    local barStroke = Instance.new("UIStroke")
    barStroke.Color = Color3.fromRGB(0, 0, 0) -- Preto
    barStroke.Thickness = 4 -- Grossura 4
    barStroke.Parent = bottomSprintBarOuter

    local bottomSprintFill = Instance.new("Frame")
    bottomSprintFill.Name = "BottomFill"
    bottomSprintFill.Size = UDim2.new(1, 0, 1, 0)
    bottomSprintFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255) 
    bottomSprintFill.BorderSizePixel = 0
    bottomSprintFill.Parent = bottomSprintBarOuter

    -- 3. LÓGICA DO SPRINT, GASTO E RECARGA TOTAL
    local maxStamina = 100
    local currentStamina = 100
    local drainRate = 45   
    local regenRate = 25   
    local normalSpeed = 16
    local sprintSpeed = 23 

    local isSprinting = false
    local exhausted = false

    local function updateVisual()
        local scale = math.clamp(currentStamina / maxStamina, 0, 1)
        bottomSprintFill.Size = UDim2.new(scale, 0, 1, 0) 
    end

    sprintButton.MouseButton1Down:Connect(function()
        if exhausted then return end
        
        isSprinting = not isSprinting
        
        if isSprinting then
            sprintButton.BackgroundColor3 = Color3.fromRGB(170, 170, 170) 
        else
            sprintButton.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = normalSpeed
            end
        end
    end)

    -- Detecta se o player morreu para destruir a GUI imediatamente
    humanoid.Died:Connect(function()
        if screenGui then
            screenGui:Destroy()
        end
    end)

    -- Loop de funcionamento em tempo real
    local connection
    connection = RunService.RenderStepped:Connect(function(dt)
        if not character or not character.Parent or not humanoid or humanoid.Health <= 0 then
            if screenGui then
                screenGui:Destroy()
            end
            connection:Disconnect()
            return
        end

        if isSprinting and not exhausted then
            if humanoid.MoveDirection.Magnitude > 0 then
                currentStamina = currentStamina - (drainRate * dt)
                humanoid.WalkSpeed = sprintSpeed
                
                if currentStamina <= 0 then
                    currentStamina = 0
                    exhausted = true
                    isSprinting = false
                    sprintButton.BackgroundColor3 = Color3.fromRGB(115, 115, 115)
                    humanoid.WalkSpeed = normalSpeed
                end
            else
                humanoid.WalkSpeed = normalSpeed
            end
        else
            if currentStamina < maxStamina then
                currentStamina = currentStamina + (regenRate * dt)
                if currentStamina >= maxStamina then
                    currentStamina = maxStamina
                    exhausted = false 
                end
            end
        end

        updateVisual()
    end)
end

-- Inicializa no carregamento atual
setupSprintGui()

-- Recria a GUI automaticamente quando o player renascer (respawn)
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5) -- Pequeno delay para garantir que o character carregou o humanoid
    setupSprintGui()
end)
