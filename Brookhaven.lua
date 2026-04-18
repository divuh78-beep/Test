-- [[ CARREGAMENTO DAS BIBLIOTECAS ]] --
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- [[ SERVIÇOS ]] --
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- [[ VARIÁVEIS GLOBAIS ]] --
local State = {
    Target = nil,
    VehicleTarget = nil,
    BrutalFling = false,
    VehicleFlingActive = false,
    WalkSpeed = 16,
    RainbowActive = true,
    LagServer = false,
    HiddenFling = false,
    GhostMode = false,
    ESP_Enabled = false,
    RainbowName = true,
    GlitchActive = false,
    PlayerESP_Enabled = false,
    DisruptActive = false
}

-- [[ FUNÇÕES UTILITÁRIAS ]] --
local function GetPlayerList()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    table.sort(list)
    return list
end

local function GetAliveHRP(player)
    if not player or not player.Character then return nil end
    return player.Character:FindFirstChild("HumanoidRootPart")
end

local function StopViewing()
    if LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then Camera.CameraSubject = hum end
    end
    Fluent:Notify({Title = "", Content = "", Duration = 2})
end

-- [[ JANELA PRINCIPAL ]] --
local Window = Fluent:CreateWindow({
    Title = "Brookhaven Hub",
    SubTitle = "V2.0",
    TabWidth = 140,
    Size = UDim2.fromOffset(300, 300),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- [[ DEFINIÇÃO DAS TABS ]] --
local Tabs = {
    Ghost = Window:AddTab({ Title = "Avatar", Icon = "user" }),
    Visuals = Window:AddTab({ Title = "Visuals [BETA]", Icon = "eye" }),
    CarControl = Window:AddTab({ Title = "Car [BETA]", Icon = "car" }),
    Fling = Window:AddTab({ Title = "Fling Player", Icon = "user" }),
    Vehicle = Window:AddTab({ Title = "Fling Vehicle", Icon = "car" }),
    Tools = Window:AddTab({ Title = "Tools", Icon = "wrench" }),
    Lag = Window:AddTab({ Title = "Lag [BETA]", Icon = "monitor" }),
    Settings = Window:AddTab({ Title = "Config", Icon = "settings" })
}

-- ABA: AVATAR --
do
    Tabs.Ghost:AddToggle("RainbowName", {
        Title = "Rainbow Name",
        Default = true,
        Callback = function(Value) State.RainbowName = Value end
    })

    Tabs.Ghost:AddToggle("GhostMode", {
        Title = "Tiny Mode",
        Default = false,
        Callback = function(Value) 
            State.GhostMode = Value
            if Value then
                pcall(function()
                    local char = LocalPlayer.Character
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    ReplicatedStorage.Remotes.SetAvatarEditorContext:FireServer("Body")
                    ReplicatedStorage.RE["1Flyin1g"]:FireServer("PCollisionPatch")
                    for _, v in pairs(char:GetDescendants()) do
                        if v:IsA("Accessory") or v:IsA("Shirt") or v:IsA("Pants") then v:Destroy() end
                    end
                    local targetSize = 0.1
                    local scales = {"BodyDepthScale","BodyHeightScale","BodyWidthScale","HeadScale","ProportionScale","BodyTypeScale"}
                    for _, name in pairs(scales) do
                        local s = hum:FindFirstChild(name)
                        if s then s.Value = targetSize end
                    end
                    hum.HipHeight = -3
                end)
            else
                if LocalPlayer.Character then LocalPlayer.Character.Humanoid.Health = 0 end
            end
        end 
    })

    Tabs.Ghost:AddToggle("HiddenFling", {
        Title = "Fling Invisible",
        Default = false,
        Callback = function(Value) State.HiddenFling = Value end
    })
end

-- [[ ABA: VISUALS (ESP PLAYER) ]] --
local PlayerESPFolder = Instance.new("Folder", game.CoreGui)
PlayerESPFolder.Name = "PlayerESP_Cyberz"

local function ClearPlayerESP() PlayerESPFolder:ClearAllChildren() end

local function CreatePlayerESP(p)
    if p == LocalPlayer or not p.Character or not p.Character:FindFirstChild("HumanoidRootPart") then return end
    local h = Instance.new("Highlight", PlayerESPFolder)
    h.Adornee = p.Character
    h.FillColor = Color3.fromRGB(0, 255, 127)
    
    local b = Instance.new("BillboardGui", PlayerESPFolder)
    b.Size = UDim2.new(0,100,0,50); b.AlwaysOnTop = true; b.Adornee = p.Character.HumanoidRootPart; b.ExtentsOffset = Vector3.new(0,3,0)
    local t = Instance.new("TextLabel", b)
    t.Size = UDim2.new(1,0,1,0); t.BackgroundTransparency = 1; t.TextColor3 = Color3.new(1,1,1); t.Text = p.Name; t.Font = "GothamBold"; t.TextSize = 12
end

Tabs.Visuals:AddToggle("PlayerESP", { 
    Title = "ESP Players", 
    Default = false, 
    Callback = function(V) 
        State.PlayerESP_Enabled = V 
        if not V then ClearPlayerESP() end 
    end 
})

Tabs.CarControl:AddSection("")

-- ABA: CAR CONTROL / ESP --
local ESPFolder = Instance.new("Folder", game.CoreGui)
ESPFolder.Name = "CarESP_Filtered"

local function ClearESP()
    ESPFolder:ClearAllChildren()
    for _, v in pairs(workspace:GetDescendants()) do
        if v.Name == "CAR_ESP_TAG" then v:Destroy() end
    end
end

local function CreateESP(vehicle)
    if vehicle:FindFirstChild("CAR_ESP_TAG") then return end
    
    -- FILTRO: Só cria se o modelo tiver um nome que parece carro ou se tiver rodas
    -- No Brookhaven, balanços geralmente não estão em modelos complexos como os carros
    local seat = vehicle:FindFirstChildWhichIsA("VehicleSeat")
    if not seat then return end

    -- Se o pai do assento for o workspace direto ou uma pasta de móveis, ignoramos
    if vehicle.Parent == workspace or vehicle:FindFirstChild("Prop") then return end

    local tag = Instance.new("BoolValue", vehicle)
    tag.Name = "CAR_ESP_TAG"

    local highlight = Instance.new("Highlight", ESPFolder)
    highlight.Adornee = vehicle
    highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Vermelho para carros de players
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)

    local billboard = Instance.new("BillboardGui", ESPFolder)
    billboard.Size = UDim2.new(0, 80, 0, 30)
    billboard.AlwaysOnTop = true
    billboard.Adornee = seat

    local text = Instance.new("TextLabel", billboard)
    text.Size = UDim2.new(1, 0, 1, 0)
    text.BackgroundTransparency = 1
    text.TextColor3 = Color3.new(1, 1, 1)
    text.Text = ""
end

Tabs.CarControl:AddToggle("VehicleESP", {
    Title = "ESP Car",
    Default = false,
    Callback = function(Value)
        State.ESP_Enabled = Value
        if not Value then ClearESP() end
    end
})

Tabs.CarControl:AddSection("")

local StealCarActive = false

Tabs.CarControl:AddToggle("CarPhysicsGlitch", {
    Title = "Auto Steal Random Car",
    Default = false,
    Callback = function(Value)
        StealCarActive = Value
        if Value then
        end
    end
})

-- Script de lógica do Glitch (Coloque no seu Heartbeat ou em um task.spawn separado)
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if GlitchActive then
            pcall(function()
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local seat = hum and hum.SeatPart
                
                if seat and seat:IsA("VehicleSeat") then
                    -- O "Pulo do Gato": Aplica força em todas as partes do carro
                    local car = seat.Parent
                    for _, part in pairs(car:GetDescendants()) do
                        if part:IsA("BasePart") then
                            -- Aplica uma velocidade minúscula para "reivindicar" a física
                            part.Velocity = Vector3.new(0, 0.05, 0) 
                            -- Torna a parte "instável" para o servidor ceder o ownership
                            part.CanCollide = true 
                        end
                    end
                    
                    -- Aumenta o torque local para você vencer a trava do dono
                    seat.MaxSpeed = 200
                    seat.SteerFloat = seat.SteerFloat
                    seat.ThrottleFloat = seat.ThrottleFloat
                end
            end)
        end
    end)
end)

local DisruptActive = false
Tabs.CarControl:AddToggle("VehicleDisrupter", {
    Title = "Disrupt Vehicle",
    Default = false,
    Callback = function(Value)
        DisruptActive = Value
        if Value then
            Fluent:Notify({Title = "", Content = "", Duration = 3})
        end
    end
})

-- Lógica de Interrupção
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if DisruptActive then
            pcall(function()
                local hum = LocalPlayer.Character.Humanoid
                local seat = hum.SeatPart
                
                if seat and seat:IsA("VehicleSeat") then
                    local car = seat.Parent
                    for _, part in pairs(car:GetDescendants()) do
                        if part:IsA("BasePart") then
                            -- O segredo: Força a velocidade a ser ZERO constantemente
                            part.Velocity = Vector3.new(0, 0, 0)
                            part.RotVelocity = Vector3.new(0, 0, 0)
                            -- Opcional: faz o carro tremer lateralmente para irritar mais
                            part.CFrame = part.CFrame * CFrame.new(math.random(-1,1)/100, 0, 0)
                        end
                    end
                end
            end)
        end
    end)
end)

-- ABA: FLING PLAYER --
do
    local PlayerDropdown = Tabs.Fling:AddDropdown("FlingTarget", {
        Title = "Select Player",
        Values = GetPlayerList(),
        Callback = function(Value) State.Target = Players:FindFirstChild(Value) end
    })

    Tabs.Fling:AddButton({ Title = "update List", Callback = function() PlayerDropdown:SetValues(GetPlayerList()) end })
    
    Tabs.Fling:AddButton({ 
        Title = "View", 
        Callback = function() 
            if State.Target and State.Target.Character then 
                Camera.CameraSubject = State.Target.Character:FindFirstChildOfClass("Humanoid") 
            end 
        end 
    })
    
    Tabs.Fling:AddButton({ Title = "Unview", Callback = StopViewing })

    Tabs.Fling:AddToggle("BrutalFling", {
        Title = "Enable Fling",
        Default = false,
        Callback = function(Value) State.BrutalFling = Value end
    })
end

-- ABA: FLING VEHICLE --
do
    local VehicleDropdown = Tabs.Vehicle:AddDropdown("VehicleTarget", {
        Title = "Select Player",
        Values = GetPlayerList(),
        Callback = function(Value) State.VehicleTarget = Players:FindFirstChild(Value) end
    })

    Tabs.Vehicle:AddButton({ Title = "Update List", Callback = function() VehicleDropdown:SetValues(GetPlayerList()) end })

    Tabs.Vehicle:AddButton({ 
        Title = "View", 
        Callback = function() 
            if State.VehicleTarget and State.VehicleTarget.Character then 
                Camera.CameraSubject = State.VehicleTarget.Character:FindFirstChildOfClass("Humanoid") 
            end 
        end 
    })

    Tabs.Vehicle:AddButton({ Title = "Unview", Callback = StopViewing })

    Tabs.Vehicle:AddButton({
        Title = "Spawn bus",
        Callback = function()
            pcall(function()
                ReplicatedStorage.RE["1Ca1r"]:FireServer("DeleteAllVehicles")
                task.wait(0.3)
                ReplicatedStorage.RE["1Ca1r"]:FireServer("PickingCar", "SchoolBus")
            end)
        end
    })

    Tabs.Vehicle:AddToggle("VehicleFling", {
        Title = "Enable Fling Vehicle",
        Default = false,
        Callback = function(Value) State.VehicleFlingActive = Value end
    })
end

-- ABA: TOOLS --
do
    Tabs.Tools:AddSlider("WalkSpeed", { 
        Title = "Speed", Default = 16, Min = 16, Max = 700, Rounding = 0, 
        Callback = function(V) 
            if LocalPlayer.Character then LocalPlayer.Character.Humanoid.WalkSpeed = V end
        end 
    })

    Tabs.Tools:AddButton({ 
        Title = "Gravity Gun", 
        Callback = function() 
            loadstring(game:HttpGet("https://raw.githubusercontent.com/BocusLuke/Scripts/main/GravityGun.lua"))()
        end 
    })

    Tabs.Tools:AddButton({ Title = "FE DOORS", Callback = function() loadstring(game:HttpGet("https://pastebin.com/raw/6wEFwr3t"))() end })
end

-- Adicione isso dentro do bloco 'do' da -- Botão de Teleporte para o Avião
do
    Tabs.Tools:AddButton({
        Title = "Teleport Airplane",
        Callback = function()
            local hrp = GetAliveHRP(LocalPlayer)
            if hrp then 
    hrp.CFrame = CFrame.new(457.004, -9.979, 141.320)
    Fluent:Notify({Title = "", Content = "", Duration = 3})
end

-- ABA: LAG ALL --
do
    Tabs.Lag:AddToggle("LagServer", { Title = "Lag [BETA]", Default = false, Callback = function(V) State.LagServer = V end })
    Tabs.Lag:AddSlider("LagPower", { Title = "Attack Power", Default = 10, Min = 1, Max = 99999, Rounding = 0, Callback = function(V) State.LagPower = V end })
end

Tabs.Lag:AddToggle("LagToggle", {
    Title = "Enable Lag Server [BETA]",
    Default = false,
    Callback = function(Value)
        State.LagServer = Value
        if Value then
            Fluent:Notify({Title = "", Content = "", Duration = 3})
        end
    end
})

Tabs.Lag:AddSlider("LagPower", {
    Title = "Intensity Lag",
    Default = 10,
    Min = 1,
    Max = 100, -- 100 pacotes extras a cada 0.1s já é insano e seguro para você
    Rounding = 0,
    Callback = function(V) State.LagPower = V end
})
                    ReplicatedStorage.RE["1Size1r"]:FireServer("PickingSize", 0.3)
                    ReplicatedStorage.RE["1RPNam1eColo1r"]:FireServer("PickingRPNameColor", Color3.fromHSV(math.random(), 1, 1))
                end
            end)
        end
        task.wait(0.1) -- Respiro vital para o seu cliente
    end
end)

-- ABA: CONFIG --
do
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    Tabs.Settings:AddButton({ Title = "Rejoin Server", Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end })
end

        -- LOOP PRINCIPAL (Heartbeat)
RunService.Heartbeat:Connect(function()
    pcall(function()

        local hrp = GetAliveHRP(LocalPlayer)
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        -- ESP
        if State.ESP_Enabled then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChildOfClass("VehicleSeat") then
                    CreateESP(v)
                end
            end
        else
            ClearESP()
        end

        -- FLING PLAYER
        if State.BrutalFling and State.Target then
            local tHRP = GetAliveHRP(State.Target)
            if tHRP then
                hum.PlatformStand = true
                hrp.CFrame = tHRP.CFrame * CFrame.Angles(0, math.rad(tick()*1500), 0)
                hrp.Velocity = Vector3.new(9e7, 9e7, 9e7)
                hrp.RotVelocity = Vector3.new(9e7, 9e7, 9e7)
            end
        else
            hum.PlatformStand = false
        end

        -- HIDDEN FLING
        if State.HiddenFling and not State.BrutalFling then
            hrp.Velocity = Vector3.new(9e7, 9e7, 9e7)
        end

        -- VEHICLE FLING
        if State.VehicleFlingActive and hum.SeatPart and State.VehicleTarget then
            local tHRP = GetAliveHRP(State.VehicleTarget)
            if tHRP then
                hum.SeatPart.CFrame = tHRP.CFrame
            end
        end

    end)
end)

-- RAINBOW NAME
task.spawn(function()
    pcall(function()
        local initialName = "BROOKHAVEN HUB"
        ReplicatedStorage.RE["1RPNam1eText"]:FireServer("PickingRPName", initialName)
    end)

    while task.wait(0.1) do
        if State.RainbowName then
            local hue = (tick() % 3) / 3
            local color = Color3.fromHSV(hue, 1, 1)
            ReplicatedStorage.RE["1RPNam1eColo1r"]:FireServer("PickingRPNameColor", color)
        end
    end
end)

-- [[ SISTEMA DE LAG SERVER - BETA ]] --
task.spawn(function()
    while task.wait(0.1) do
        if State.LagServer then
            pcall(function()
                for i = 1, State.LagPower do
                    ReplicatedStorage.RE["1Size1r"]:FireServer("PickingSize", 0.3)
                    ReplicatedStorage.RE["1RPNam1eColo1r"]:FireServer("PickingRPNameColor", Color3.fromHSV(math.random(), 1, 1))
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if StealCarActive then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                
                -- Se já estiver sentado em um carro, aproveita e aumenta a velocidade
                if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
                    hum.SeatPart.MaxSpeed = 250
                    hum.SeatPart.Torque = 50000
                    return -- Sai do loop para você poder dirigir o carro roubado
                end

                if hrp and hum then
                    local vehicles = {}
                    
                    -- Mapeia todos os assentos de veículos no mapa
                    for _, v in pairs(workspace:GetDescendants()) do
                        if v:IsA("VehicleSeat") and not v.Occupant and v.Parent ~= workspace then
                            table.insert(vehicles, v)
                        end
                    end
                    
                    -- Se achar um carro vazio, tenta o Hijack
                    if #vehicles > 0 then
                        local randomSeat = vehicles[math.random(1, #vehicles)]
                        
                        -- Teleporta um pouco acima do banco para não bugar no chão
                        hrp.CFrame = randomSeat.CFrame * CFrame.new(0, 1.5, 0)
                        task.wait(0.1)
                        
                        -- Força o Humanoid a sentar
                        randomSeat:Sit(hum)
                    end
                end
            end)
        end
    end
end)

-- Se achar um carro vazio, tenta o Hijack
                    if #vehicles > 0 then
                        local randomSeat = vehicles[math.random(1, #vehicles)]
                        
                        -- Teleporta um pouco acima do banco para não bugar no chão
                        hrp.CFrame = randomSeat.CFrame * CFrame.new(0, 1.5, 0)
                        task.wait(0.1)
                        
                        -- Força o Humanoid a sentar
                        randomSeat:Sit(hum)
                    end
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(1) do
        if State.PlayerESP_Enabled then
            ClearPlayerESP()
            for _, p in pairs(Players:GetPlayers()) do CreatePlayerESP(p) end
        end
    end
end)

-- FINAL
Window:SelectTab(1)
Fluent:Notify({Title = "BROOKHAVEN HUB V2.0", Content = "Script Focado em Fling Aproveite!", Duration = 5})
