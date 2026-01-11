--// 99 NIGHTS - SURVIVAL SCRIPT (NOCLIP ON DPAD DOWN) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- CONFIGURAÇÕES
_G.Noclip = false
_G.GodMode = true

-- 1. NOCLIP (ATIVADO PELA SETA PARA BAIXO)
RunService.Stepped:Connect(function()
    if _G.Noclip then
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then 
                    part.CanCollide = false 
                end
            end
        end
    end
end)

-- 2. DETECÇÃO DO CONTROLE (SETA BAIXO)
UserInputService.InputBegan:Connect(function(input)
    -- Ativa/Desativa Noclip na Seta para Baixo (DpadDown) ou Tecla N no PC
    if input.KeyCode == Enum.KeyCode.ButtonDpadDown or input.KeyCode == Enum.KeyCode.N then
        _G.Noclip = not _G.Noclip
        
        -- Aviso na tela para você saber se ligou ou desligou
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Noclip Status",
            Text = _G.Noclip and "ATIVADO (Atravessando)" or "DESATIVADO",
            Duration = 2
        })
    end
end)

-- 3. SOBREVIVÊNCIA (AUTO-REGEN & RECURSOS)
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                -- Trava Fome e Stamina
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("ValueBase") then
                        if v.Name:lower():find("hunger") or v.Name:lower():find("stamina") then
                            v.Value = 100
                        end
                    end
                end
                -- Cura automática
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and _G.GodMode and hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end
        end)
    end
end)

-- 4. ESP DO MONSTRO (WALL HACK VERMELHO)
task.spawn(function()
    while task.wait(2) do
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") then
                if not Players:GetPlayerFromCharacter(v) and not v:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", v)
                    h.FillColor = Color3.fromRGB(255, 0, 0)
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            end
        end
    end
end)

-- 5. NOITE CLARA (FULL BRIGHT)
task.spawn(function()
    local lighting = game:GetService("Lighting")
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = false
end)

-- 6. DEFESA AUTOMÁTICA (AUTO-ATTACK)
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        if tool and char:FindFirstChild("HumanoidRootPart") then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and not Players:GetPlayerFromCharacter(v) then
                    local dist = (char.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
                    if dist < 18 then
                        tool:Activate()
                    end
                end
            end
        end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "SCRIPT CARREGADO",
    Text = "Seta Baixo = Noclip | Defesa Auto Ativa",
    Duration = 5
})
