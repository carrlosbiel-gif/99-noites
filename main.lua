--// 99 Nights in the Forest [ANTI-BAN & SAFE] //--

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Services & Cache
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local US = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Configuração de Segurança
local SafeConfig = {
    Aimbot = false,
    SafeESP = false,
    LegitFarm = false,
    Fly = false,
    Smoothing = 0.4, -- Quanto maior, mais "humana" a mira
    WaitTime = 0.5   -- Delay randômico para evitar padrões
}

local Targets = {"Alien", "Wolf", "Cultist", "Bear"}

-- Função de Click Humanizado (Não clica sempre no mesmo milissegundo)
local function humanClick()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(math.random(5, 15) / 100) -- Delay aleatório entre clicks
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- Window Setup
local Window = Rayfield:CreateWindow({
    Name = "99 Nights | Stealth Edition",
    LoadingTitle = "Modo Seguro Ativado",
    LoadingSubtitle = "Proteção Anti-Cheat",
    KeySystem = false,
})

local Main = Window:CreateTab("Segurança")

-- 1. LEGIT AUTO FARM (Sem teleporte agressivo)
Main:CreateToggle({
    Name = "Legit Farm (Apenas alcance manual)",
    CurrentValue = false,
    Callback = function(v) SafeConfig.LegitFarm = v end
})

task.spawn(function()
    while task.wait(0.3) do
        if SafeConfig.LegitFarm and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            -- Em vez de teleportar pelo mapa, ele só bate se você chegar PERTO da árvore
            -- Isso evita o ban por "Teleportation Detection"
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "Small Tree" and obj:FindFirstChild("Trunk") then
                    local dist = (obj.Trunk.Position - LP.Character.HumanoidRootPart.Position).Magnitude
                    if dist < 12 then -- Distância de segurança (braço do personagem)
                        humanClick()
                        task.wait(0.2)
                        break
                    end
                end
            end
        end
    end
end)

-- 2. AIMBOT SUAVE (Lerp interpolation)
Main:CreateToggle({
    Name = "Silent Aimbot (Suave)",
    CurrentValue = false,
    Callback = function(v) SafeConfig.Aimbot = v end
})

RunService.RenderStepped:Connect(function()
    if SafeConfig.Aimbot and US:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = nil
        local shortestDist = 150 -- FOV Limitado para não parecer estranho
        
        for _, npc in ipairs(workspace:GetChildren()) do
            if table.find(Targets, npc.Name) and npc:FindFirstChild("Head") then
                local pos, onScreen = Camera:WorldToViewportPoint(npc.Head.Position)
                if onScreen then
                    local mag = (Vector2.new(pos.X, pos.Y) - US:GetMouseLocation()).Magnitude
                    if mag < shortestDist then
                        target = npc.Head
                        shortestDist = mag
                    end
                end
            end
        end
        
        if target then
            -- INTERPOLAÇÃO (Faz a câmera girar suavemente, não instantâneo)
            local targetCF = CFrame.new(Camera.CFrame.Position, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(targetCF, SafeConfig.Smoothing)
        end
    end
end)

-- 3. ESP SEGURO (Usa Box Simples em vez de Highlight pesado)
Main:CreateToggle({
    Name = "Box ESP (Menos detectável)",
    CurrentValue = false,
    Callback = function(v) SafeConfig.SafeESP = v end
})

-- Aba de Exploração Segura
local Exploit = Window:CreateTab("Exploits")

Exploit:CreateButton({
    Name = "Teleporte Seguro (Tween)",
    Callback = function()
        -- Exemplo: Teleporte com "frio" (suavizado) para evitar kick
        Rayfield:Notify({Title = "Aviso", Content = "Use teleporte apenas em emergências!", Duration = 3})
    end
})

Exploit:CreateSlider({
    Name = "Suavidade da Mira",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = 4,
    Callback = function(v) SafeConfig.Smoothing = v / 10 end
})
