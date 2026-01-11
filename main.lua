--// 99 NIGHTS - LIGHT VERSION (ANTI-LAG) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

_G.Noclip = false

-- 1. NOITE CLARA (FULL BRIGHT) - Executa apenas uma vez para não travar
local function ForceDay()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
end
ForceDay()

-- 2. NOCLIP OTIMIZADO (SETABAIXO / DPADDOWN)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonDpadDown or input.KeyCode == Enum.KeyCode.N then
        _G.Noclip = not _G.Noclip
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Noclip",
            Text = _G.Noclip and "ATIVADO" or "DESATIVADO",
            Duration = 2
        })
    end
end)

RunService.Stepped:Connect(function()
    if _G.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- 3. ESP DO MONSTRO (SIMPLIFICADO)
-- Procura o monstro a cada 5 segundos (mais lento para não dar lag)
task.spawn(function()
    while task.wait(5) do
        for _, v in pairs(workspace:GetChildren()) do
            -- Se for um modelo, não for jogador e tiver vida (provável monstro)
            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(v) then
                if not v:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", v)
                    h.FillColor = Color3.fromRGB(255, 0, 0)
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            end
        end
    end
end)

print("Script Leve Carregado!")
