--// 99 NIGHTS - AUTO FARM (MADEIRA & COMIDA) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- CONFIGURAÇÕES
_G.AutoFarm = true
local range = 20 -- Distância para bater

-- 1. FUNÇÃO DE ATAQUE AUTOMÁTICO
task.spawn(function()
    while task.wait(0.2) do
        if not _G.AutoFarm then break end
        
        local char = LocalPlayer.Character
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        
        if tool and hrp then
            -- Procura Animais e Árvores
            for _, v in pairs(workspace:GetChildren()) do
                -- Alvos: Modelos que tenham vida (Animais) ou partes de Madeira (Logs/Trees)
                if v:IsA("Model") and v.Name ~= LocalPlayer.Name then
                    local targetHrp = v:FindFirstChild("HumanoidRootPart") or v:FindFirstChildWhichIsA("BasePart")
                    
                    if targetHrp then
                        local dist = (hrp.Position - targetHrp.Position).Magnitude
                        if dist <= range then
                            -- Ataca
                            tool:Activate()
                            
                            -- Força o dano (Kill rápido)
                            if firetouchinterest then
                                firetouchinterest(targetHrp, tool.Handle, 0)
                                firetouchinterest(targetHrp, tool.Handle, 1)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- 2. MAGNET DE ITENS (PEGA TUDO QUE CAIR NO CHÃO)
task.spawn(function()
    local items = {"Coal", "Log", "Meat", "Food", "Apple", "Berry"}
    while task.wait(1) do
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in pairs(workspace:GetDescendants()) do
                if table.find(items, obj.Name) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part and (hrp.Position - part.Position).Magnitude <= 50 then
                        obj:PivotTo(hrp.CFrame)
                    end
                end
            end
        end
    end
end)

-- 3. ANTI-FOME E SEMPRE DIA
task.spawn(function()
    while task.wait(2) do
        -- Mantém Claro
        game:GetService("Lighting").ClockTime = 14
        
        -- Tenta travar status de fome se encontrar o valor
        local char = LocalPlayer.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("ValueBase") and (v.Name:lower():find("hunger") or v.Name:lower():find("stamina")) then
                    v.Value = 100
                end
            end
        end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "AUTO-FARM ATIVO",
    Text = "Pegando Madeira e Matando Animais...",
    Duration = 5
})
