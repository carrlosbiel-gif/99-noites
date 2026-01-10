--// 99 Nights - INFINITE ITEMS & ADMIN AXE (HIT KILL) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- 1. TUDO INFINITO (Munição, Comida, Recursos na Mão)
task.spawn(function()
    while task.wait(0.1) do
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
        if tool then
            -- Procura qualquer valor numérico dentro da Tool (Ammo, Quantity, Amount, Energy)
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    v.Value = 999
                end
            end
        end
    end
end)

-- 2. MACHADO ADM / HIT KILL (Aumenta o Dano e Velocidade)
RunService.Stepped:Connect(function()
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
    
    -- Verifica se é o Machado (Axe) ou qualquer arma de combate
    if tool and (tool.Name:find("Axe") or tool.Name:find("Machado") or tool.Name:find("Sword")) then
        
        -- HIT KILL: Aumenta o dano se o valor existir
        if tool:FindFirstChild("Damage") then tool.Damage.Value = 999999 end
        if tool:FindFirstChild("HitDamage") then tool.HitDamage.Value = 999999 end
        
        -- SEM COOLDOWN: Bate super rápido
        if tool:FindFirstChild("Cooldown") then tool.Cooldown.Value = 0 end
        if tool:FindFirstChild("AttackSpeed") then tool.AttackSpeed.Value = 0 end
        if tool:FindFirstChild("Delay") then tool.Delay.Value = 0 end
        
        -- ALCANCE LONGO (Bate de longe)
        if tool:FindFirstChild("Handle") then
            tool.Handle.Size = Vector3.new(10, 10, 10) -- Aumenta a área de corte
            tool.Handle.CanCollide = false
        end
    end
end)

-- 3. MAGNET SIMPLIFICADO (Ativa Automático ao Equipar Machado)
task.spawn(function()
    while task.wait(1) do
        local items = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if hrp and LocalPlayer.Character:FindFirstChildWhichIsA("Tool") then
            for _, obj in pairs(workspace:GetDescendants()) do
                if table.find(items, obj.Name) then
                    local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if handle and (hrp.Position - handle.Position).Magnitude <= 500 then
                        obj:PivotTo(hrp.CFrame * CFrame.new(0, 3, -3))
                    end
                end
            end
        end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "ADMIN AXE ON",
    Text = "Machado com Hit Kill e Itens Infinitos!",
    Duration = 5
})
