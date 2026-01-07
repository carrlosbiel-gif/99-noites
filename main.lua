--// 99 Nights in the Forest [LITE & OPTIMIZED] //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services & Cache
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local US = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights | Lite",
    LoadingTitle = "Modo Performance",
    LoadingSubtitle = "Otimizado para FPS",
    KeySystem = false,
})

-- State Variables
local Config = {
    ItemESP = false,
    NPCESP = false,
    AutoTree = false,
    Aimbot = false,
    Fly = false,
    FlySpeed = 60
}

local teleportTargets = {"Alien", "Chest", "Raygun", "Revolver", "Medkit", "Apple", "Wolf", "Log"}
local AimbotTargets = {"Alien", "Wolf", "Cultist", "Bear"}

-- Optimized Click
local function fastClick()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- Optimization: ESP Pool (Evita criar milhares de objetos)
local function applyESP(obj, text)
    if not obj:FindFirstChild("LITE_ESP") then
        local bg = Instance.new("BillboardGui", obj)
        bg.Name = "LITE_ESP"
        bg.AlwaysOnTop = true
        bg.Size = UDim2.new(0, 50, 0, 20)
        bg.StudsOffset = Vector3.new(0, 2, 0)
        
        local l = Instance.new("TextLabel", bg)
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 1, 0)
        l.Text = text
        l.TextColor3 = Color3.new(1, 1, 1)
        l.TextScaled = true
        
        local h = Instance.new("Highlight", obj)
        h.FillTransparency = 0.5
        h.OutlineColor = Color3.new(1, 0.5, 0)
    end
end

-- Home Tab
local Home = Window:CreateTab("🏠 Principal")

Home:CreateToggle({
    Name = "ESP de Itens (Proximidade)",
    CurrentValue = false,
    Callback = function(v) Config.ItemESP = v end
})

Home:CreateToggle({
    Name = "Auto Tree Farm (Perto)",
    CurrentValue = false,
    Callback = function(v) Config.AutoTree = v end
})

-- Otimização: Loop Único para Checks de Proximidade
task.spawn(function()
    while task.wait(0.5) do
        if not LP.Character then continue end
        local root = LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        for _, obj in ipairs(workspace:GetChildren()) do
            -- Auto Farm Otimizado (Só ativa se estiver perto para evitar teleporte flag)
            if Config.AutoTree and obj.Name == "Small Tree" then
                local trunk = obj:FindFirstChild("Trunk")
                if trunk and (trunk.Position - root.Position).Magnitude < 15 then
                    fastClick()
                end
            end
            
            -- ESP Otimizado (Apenas no que está na hierarquia principal)
            if Config.ItemESP and table.find(teleportTargets, obj.Name) then
                applyESP(obj, obj.Name)
            end
        end
    end
end)

-- Aimbot Tab
local Combat = Window:CreateTab("⚔️ Combate")

Combat:CreateToggle({
    Name = "Aimbot Assist (Right Click)",
    CurrentValue = false,
    Callback = function(v) Config.Aimbot = v end
})

RS.RenderStepped:Connect(function()
    if Config.Aimbot and US:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = nil
        local dist = 200
        
        for _, npc in ipairs(workspace:GetChildren()) do
            if table.find(AimbotTargets, npc.Name) and npc:FindFirstChild("Head") then
                local pos, onScreen = Camera:WorldToViewportPoint(npc.Head.Position)
                if onScreen then
                    local mDist = (Vector2.new(pos.X, pos.Y) - US:GetMouseLocation()).Magnitude
                    if mDist < dist then
                        dist = mDist
                        target = npc.Head
                    end
                end
            end
        end
        
        if target then
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target.Position), 0.2)
        end
    end
end)

-- Teleport Tab (Otimizado: Não busca em tudo, apenas no Workspace direto)
local Teleport = Window:CreateTab("🌀 Teleporte")

for _, name in ipairs(teleportTargets) do
    Teleport:CreateButton({
        Name = "Ir para: " .. name,
        Callback = function()
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name:find(name) then
                    LP.Character:PivotTo(obj:GetPivot() * CFrame.new(0, 5, 0))
                    break
                end
            end
        end
    })
end

Rayfield:Notify({Title = "Lite Loaded", Content = "Script otimizado para FPS.", Duration = 3})
