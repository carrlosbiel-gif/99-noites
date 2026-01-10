--// 99 Nights in the Forest - GHOST SCRIPT (XENO SAFE) //--
--// SEM INTERFACE - MAIS RÁPIDO E ESTÁVEL //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

print("Script Carregado! Pule para usar o Magnet.")

-- 1. CONFIGURAÇÃO DE STAMINA E LASER INFINITO
task.spawn(function()
    while task.wait(0.3) do
        -- Stamina Infinita
        local char = LocalPlayer.Character
        if char then
            if char:FindFirstChild("Stamina") then char.Stamina.Value = 100 end
            if LocalPlayer:FindFirstChild("Stamina") then LocalPlayer.Stamina.Value = 100 end
        end
        
        -- Canhão/Armas Infinitas
        local tool = char and char:FindFirstChildWhichIsA("Tool")
        if tool then
            if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
            if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
            if tool:FindFirstChild("Charge") then tool.Charge.Value = 100 end
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
                    -- Teleporta o item
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame + Vector3.new(0, 3, 0)) 
                    else 
                        obj.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
                    end
                    
                    -- Firetouch para conseguir usar/pegar
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
    print("Magnet: " .. count .. " itens trazidos!")
end

-- 3. ATIVAR MAGNET AO PULAR (Facilita no Mobile/Xeno)
UserInputService.JumpRequest:Connect(function()
    runMagnet()
end)

-- Aviso Sonoro/Visual Simples
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Ghost Script",
    Text = "Stamina/Laser ON. Pule para Magnet!",
    Duration = 5
})
