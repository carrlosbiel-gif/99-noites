--// 99 Noites na Floresta - Versão Performance & Safe //--
-- Baseado no código de carrlosbiel-gif

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Configurações de Segurança (Anti-Detecção)
local Settings = {
    FarmSpeed = 0.3,
    Smoothing = 0.25, -- Mira suave para evitar ban
    FlySpeed = 50,
    PanicKey = Enum.KeyCode.P -- Tecla P fecha tudo
}

local Window = Rayfield:CreateWindow({
    Name = "99 Noites | Pro Edition",
    LoadingTitle = "Carregando Otimizações...",
    LoadingSubtitle = "by Gemini Safe-Mode",
    KeySystem = false,
})

-- Cache de Serviços para Performance
local LP = game:GetService("Players").LocalPlayer
local RS = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

-- Função de Click Seguro
local function safeClick()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(math.random(2, 5) / 100)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- Aba Principal
local Main = Window:CreateTab("Automação", 4483362458)

local AutoFarm = false
Main:CreateToggle({
    Name = "Farm de Árvores (Legit Mode)",
    CurrentValue = false,
    Callback = function(v) 
        AutoFarm = v 
        if v then
            Rayfield:Notify({Title = "Segurança", Content = "Apenas bata nas árvores, o script cuidará do click.", Duration = 3})
        end
    end
})

-- Loop de Farm Otimizado (Gasta menos CPU)
task.spawn(function()
    while task.wait(Settings.FarmSpeed) do
        if AutoFarm and LP.Character then
            local root = LP.Character:FindFirstChild("HumanoidRootPart")
            for _, obj in ipairs(workspace:GetChildren()) do
                if obj.Name == "Small Tree" and obj:FindFirstChild("Trunk") then
                    if (obj.Trunk.Position - root.Position).Magnitude < 15 then
                        safeClick()
                        break
                    end
                end
            end
        end
    end
end)

-- Aba de Combate
local Combat = Window:CreateTab("Combate", 4483362458)

local AimbotActive = false
Combat:CreateToggle({
    Name = "Aimbot Suave (Botão Direito)",
    CurrentValue = false,
    Callback = function(v) AimbotActive = v end
})

-- Sistema de Mira com Interpolação (Não puxa instantâneo)
RS.RenderStepped:Connect(function()
    if AimbotActive and game:GetService("UserInputService"):IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        local target = nil
        local dist = 200
        
        for _, npc in ipairs(workspace:GetChildren()) do
            if (npc.Name == "Wolf" or npc.Name == "Alien") and npc:FindFirstChild("Head") then
                local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(npc.Head.Position)
                if onScreen then
                    local mDist = (Vector2.new(screenPos.X, screenPos.Y) - game:GetService("UserInputService"):GetMouseLocation()).Magnitude
                    if mDist < dist then
                        dist = mDist
                        target = npc.Head
                    end
                end
            end
        end
        
        if target then
            local lookAt = CFrame.new(workspace.CurrentCamera.CFrame.Position, target.Position)
            workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(lookAt, Settings.Smoothing)
        end
    end
end)

-- Botão de Pânico (Fecha o Script se um Admin aparecer)
game:GetService("UserInputService").InputBegan:Connect(function(input)
    if input.KeyCode == Settings.PanicKey then
        Rayfield:Destroy()
    end
end)

Rayfield:Notify({Title = "Sucesso", Content = "Script carregado com base no GitHub oficial.", Duration = 5})
