--// 99 NIGHTS - SUPER REGEN & FAST RECOVERY //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- 1. SUPER REGEN (Aumenta a velocidade de cura drasticamente)
RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            -- Se a vida estiver abaixo do máximo, ele cura instantaneamente
            if hum.Health < hum.MaxHealth then
                hum.Health = hum.Health + 5 -- Adiciona +5 de vida a cada milissegundo
            end
        end
        
        -- Procura por scripts de 'Regen' originais do jogo e tenta acelerá-los
        for _, v in pairs(char:GetDescendants()) do
            if v:IsA("NumberValue") and (v.Name:lower():find("regen") or v.Name:lower():find("recovery")) then
                v.Value = 999 -- Aumenta a taxa de cura do próprio jogo
            end
        end
    end
end)

-- 2. ANTI-KNOCKBACK (Para você não ser jogado longe ao levar dano)
task.spawn(function()
    while task.wait() do
        local char = LocalPlayer.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.Velocity = Vector3.new(0,0,0)
                    v.RotVelocity = Vector3.new(0,0,0)
                end
            end
        end
    end
end)

-- 3. SEM FOME (FORÇADO)
-- Muitas vezes a vida não regenera porque você está com fome. 
-- Este loop garante que a fome nunca impeça a cura.
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, stat in pairs(char:GetDescendants()) do
                    if stat:IsA("NumberValue") or stat:IsA("IntValue") then
                        if stat.Name:lower():find("hunger") or stat.Name:lower():find("food") then
                            stat.Value = 100
                        end
                    end
                end
            end
        end)
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "REGEN ATIVADA",
    Text = "Recuperação de Vida Acelerada!",
    Duration = 5
})
