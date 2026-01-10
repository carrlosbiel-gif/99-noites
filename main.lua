--// 99 Nights in the Forest - GHOST (SETA BAIXO) - STAMINA, LASER & SEM FOME //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. LOOP DE ATRIBUTOS INFINITOS (Stamina, Laser e Sem Fome)
task.spawn(function()
    while task.wait(0.3) do
        local char = LocalPlayer.Character
        if char then
            -- --- SEM FOME (HUNGER) ---
            if char:FindFirstChild("Hunger") then char.Hunger.Value = 100 end
            if char:FindFirstChild("Food") then char.Food.Value = 100 end
            -- Verifica também nas estatísticas do jogador
            local stats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:FindFirstChild("Stats")
            if stats then
                if stats:FindFirstChild("Hunger") then stats.Hunger.Value = 100 end
                if stats:FindFirstChild("Food") then stats.Food.Value = 100 end
            end

            -- --- STAMINA INFINITA ---
            if char:FindFirstChild("Stamina") then char.Stamina.Value = 100 end
            if LocalPlayer:FindFirstChild("Stamina") then LocalPlayer.Stamina.Value = 100 end
            
            -- --- CANHÃO LASER / ARMAS INFINITAS ---
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
                if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
                if tool:FindFirstChild("Charge") then tool.Charge.Value = 100 end
            end
        end
    end
end)

-- 2. FUNÇÃO MAGNET (RAIO 5KM)
local function runMagnet()
    local itemsToGrab = {
        "Coal", "Log", "Broken Fan", "Radio", "Tire", 
        "Old Tire", "Washing Machine", "Old Car Engine"
    }
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local count = 0
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                local distance = (hrp.Position - handle.Position).Magnitude
                if distance <= 5000 then
                    -- Teleporta o item para cima do jogador
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame + Vector3.new(0, 3, 0)) 
                    else 
                        obj.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
                    end
                    
                    -- Simula o toque para o botão de 'Usar' aparecer
                    if firetouchinterest then
                        firetouchinterest(hrp, handle, 0)
                        task.wait(0.01)
                        firetouchinterest(hrp, handle, 1)
                    end
                    count = count + 1
                end
            end
        end
    end
end

-- 3. ATIVAR MAGNET AO PREMIR A SETA PARA BAIXO
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        if input.KeyCode == Enum.KeyCode.Down then
            runMagnet()
        end
    end
end)

-- Notificação de inicialização
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Ghost Script Ativo",
    Text = "Stamina, Laser e Fome Ativos! Seta Baixo = Magnet",
    Duration = 5
})
