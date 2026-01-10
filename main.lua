--// 99 Nights - GOD MODE V3 & CONTROLE MAGNET //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. LOOP DE SOBREVIVÊNCIA EXTREMA (Vida, Fome, Stamina, Laser)
task.spawn(function()
    while task.wait(0.1) do -- Loop mais rápido para a Vida não cair
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            
            -- GOD MODE (VIDA INFINITA)
            if hum then
                hum.MaxHealth = 999999
                hum.Health = 999999
                -- Tenta impedir que o script de dano do jogo te mate
                if char:FindFirstChild("ForceField") == nil then
                    local ff = Instance.new("ForceField", char)
                    ff.Visible = false -- Fica imune mas sem o brilho azul
                end
            end

            -- SEM FOME (HUNGER)
            local hungerPaths = {
                char:FindFirstChild("Hunger"),
                char:FindFirstChild("Food"),
                LocalPlayer:FindFirstChild("Hunger"),
                LocalPlayer:FindFirstChild("Stats") and LocalPlayer.Stats:FindFirstChild("Hunger")
            }
            for _, path in pairs(hungerPaths) do
                if path then path.Value = 100 end
            end

            -- STAMINA INFINITA
            if char:FindFirstChild("Stamina") then char.Stamina.Value = 100 end
            if LocalPlayer:FindFirstChild("Stamina") then LocalPlayer.Stamina.Value = 100 end
            
            -- CANHÃO LASER / ARMAS INFINITAS
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
                if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
                if tool:FindFirstChild("Charge") then tool.Charge.Value = 100 end
            end
        end
    end
end)

-- 2. FUNÇÃO MAGNET (PUXAR ITENS - RAIO 5KM)
local function runMagnet()
    local itemsToGrab = {
        "Coal", "Log", "Broken Fan", "Radio", "Tire", 
        "Old Tire", "Washing Machine", "Old Car Engine"
    }
    
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                local dist = (hrp.Position - handle.Position).Magnitude
                if dist <= 5000 then
                    -- Teleporta o item 5 metros acima de ti para não bugar
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame * CFrame.new(0, 5, -2)) 
                    else 
                        obj.CFrame = hrp.CFrame * CFrame.new(0, 5, -2)
                    end
                    
                    -- Simula o toque para interagir
                    if firetouchinterest then
                        firetouchinterest(hrp, handle, 0)
                        firetouchinterest(hrp, handle, 1)
                    end
                end
            end
        end
    end
end

-- 3. ATIVAR MAGNET (CONTROLE: SETA BAIXO / TECLADO: SETA BAIXO)
UserInputService.InputBegan:Connect(function(input, processed)
    -- Removido o 'processed' para garantir que o controle funcione sempre
    if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
        runMagnet()
    end
end)

-- Aviso de Início
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "GOD MODE ATIVO",
    Text = "Vida, Fome e Laser OK! Seta Baixo no Controle = Magnet",
    Duration = 10
})
