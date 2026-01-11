--// 99 NIGHTS - ULTIMATE SURVIVAL SCRIPT //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- CONFIGURAÇÕES
_G.AutoEat = true
_G.GodMode = true
_G.Noclip = false

-- 1. SOBREVIVÊNCIA (VIDA, FOME E STAMINA)
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                -- Trava Fome e Stamina (Recursos Essenciais)
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("ValueBase") then
                        local n = v.Name:lower()
                        if n:find("hunger") or n:find("food") or n:find("stamina") or n:find("energy") then
                            v.Value = 100
                        end
                    end
                end
                
                -- Cura Forçada se tomar dano do monstro
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and _G.GodMode then
                    if hum.Health < hum.MaxHealth then
                        hum.Health = hum.MaxHealth
                    end
                end
            end
        end)
    end
end)

-- 2. ESP DO MONSTRO (WALL HACK)
-- Faz o monstro brilhar em vermelho através das paredes para você saber onde ele está
local function applyMonsterESP(obj)
    if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
        if not Players:GetPlayerFromCharacter(obj) and not obj:FindFirstChild("MonsterHighlight") then
            local h = Instance.new("Highlight", obj)
            h.Name = "MonsterHighlight"
            h.FillColor = Color3.fromRGB(255, 0, 0)
            h.OutlineColor = Color3.fromRGB(255, 255, 255)
            h.FillAlpha = 0.5
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        end
    end
end

task.spawn(function()
    while task.wait(2) do
        for _, v in pairs(workspace:GetDescendants()) do
            applyMonsterESP(v)
        end
    end
end)

-- 3. DEFESA AUTOMÁTICA (AUTO-ATTACK)
-- Se o monstro chegar perto, o script ataca automaticamente com o que estiver na mão
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in pairs(workspace:GetDescendants()) do
                if v:IsA("Model") and v:FindFirstChild("HumanoidRootPart") and not Players:GetPlayerFromCharacter(v) then
                    local dist = (char.HumanoidRootPart.Position - v.HumanoidRootPart.Position).Magnitude
                    if dist < 15 then -- Ataca se estiver a menos de 15 studs
                        tool:Activate()
                        -- Força o dano por toque
                        if firetouchinterest then
                            firetouchinterest(char.HumanoidRootPart, v.HumanoidRootPart, 0)
                            firetouchinterest(char.HumanoidRootPart, v.HumanoidRootPart, 1)
                        end
                    end
                end
            end
        end
    end
end)

-- 4. NOCLIP (PARA FUGIR PELAS PAREDES)
RunService.Stepped:Connect(function()
    if _G.Noclip then
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- CONTROLES
UserInputService.InputBegan:Connect(function(input)
    -- Tecla N ou L3 para atravessar paredes (Fuga de emergência)
    if input.KeyCode == Enum.KeyCode.N or input.KeyCode == Enum.KeyCode.ButtonL3 then
        _G.Noclip = not _G.Noclip
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Noclip",
            Text = _G.Noclip and "ATIVADO" or "DESATIVADO",
            Duration = 2
        })
    end
end)

-- 5. ILUMINAÇÃO (FULL BRIGHT)
-- Para enxergar o monstro no escuro da noite
game:GetService("Lighting").Brightness = 2
game:GetService("Lighting").ClockTime = 14
game:GetService("Lighting").FogEnd = 100000
game:GetService("Lighting").GlobalShadows = false

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "99 NOITES BYPASS",
    Text = "GodMode, Auto-Eat e ESP Ativos!",
    Duration = 5
})
