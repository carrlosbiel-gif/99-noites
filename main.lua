--// 99 Nights - CONTROLE & TECLADO EDITION (VIDA, FOME, STAMINA, LASER) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. LOOP DE ATRIBUTOS (VIDA, FOME, STAMINA, LASER)
task.spawn(function()
    while task.wait(0.2) do
        local char = LocalPlayer.Character
        if char then
            -- VIDA INFINITA (God Mode Simples)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.MaxHealth = 999999
                hum.Health = 999999
            end

            -- SEM FOME (Tentando todos os nomes possíveis no jogo)
            local hungerNames = {"Hunger", "Food", "HungerLevel", "Fome"}
            for _, name in pairs(hungerNames) do
                if char:FindFirstChild(name) then char[name].Value = 100 end
                if LocalPlayer:FindFirstChild(name) then LocalPlayer[name].Value = 100 end
            end

            -- STAMINA INFINITA
            if char:FindFirstChild("Stamina") then char.Stamina.Value = 100 end
            if LocalPlayer:FindFirstChild("Stamina") then LocalPlayer.Stamina.Value = 100 end
            
            -- LASER / MUNIÇÃO INFINITA
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                if tool:FindFirstChild("Ammo") then tool.Ammo.Value = 999 end
                if tool:FindFirstChild("Energy") then tool.Energy.Value = 100 end
                if tool:FindFirstChild("Charge") then tool.Charge.Value = 100 end
            end
        end
    end
end)

-- 2. FUNÇÃO MAGNET (PUXAR ITENS)
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
                -- Teleporta o item
                if obj:IsA("Model") then 
                    obj:PivotTo(hrp.CFrame + Vector3.new(0, 4, 0)) 
                else 
                    obj.CFrame = hrp.CFrame + Vector3.new(0, 4, 0)
                end
                
                -- Simula o toque para habilitar a interação
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

-- 3. DETECTAR SETA PARA BAIXO (TECLADO E CONTROLE)
UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        -- Teclado (Seta Baixo) ou Controle (D-Pad Baixo)
        if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
            runMagnet()
        end
    end
end)

-- Notificação Visual
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Ultra Script Ativo",
    Text = "Vida, Fome, Stamina ON! Seta Baixo (Controle/Teclado) = Magnet",
    Duration = 7
})
