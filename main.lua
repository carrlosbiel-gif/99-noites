--// 99 Nights - HARD GOD MODE & UNIVERSAL MAGNET //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. HARD GOD MODE & STATUS FIX
task.spawn(function()
    while task.wait() do -- Loop ultra rápido
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                -- Tenta encontrar qualquer valor de Vida/Fome/Stamina no personagem ou no Player
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        if v.Name:find("Health") or v.Name:find("Vida") or v.Name:find("HP") then
                            v.Value = 999999
                        elseif v.Name:find("Hunger") or v.Name:find("Food") or v.Name:find("Fome") then
                            v.Value = 100
                        elseif v.Name:find("Stamina") or v.Name:find("Energy") then
                            v.Value = 100
                        end
                    end
                end
                
                -- God Mode no Humanoid padrão também
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = hum.MaxHealth
                end
            end
        end)
    end
end)

-- 2. MUNIÇÃO INFINITA (LASER)
task.spawn(function()
    while task.wait(0.5) do
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
        if tool then
            for _, v in pairs(tool:GetDescendants()) do
                if v:IsA("NumberValue") or v:IsA("IntValue") then
                    if v.Name:find("Ammo") or v.Name:find("Energy") or v.Name:find("Charge") then
                        v.Value = 999
                    end
                end
            end
        end
    end
end)

-- 3. MAGNET MELHORADO (RAIO 5KM)
local function runMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                if (hrp.Position - handle.Position).Magnitude <= 5000 then
                    -- Teleporta o item para a sua frente
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame * CFrame.new(0, 2, -5)) 
                    else 
                        obj.CFrame = hrp.CFrame * CFrame.new(0, 2, -5)
                    end
                    -- Força o clique de pegar
                    if firetouchinterest then
                        firetouchinterest(hrp, handle, 0)
                        firetouchinterest(hrp, handle, 1)
                    end
                end
            end
        end
    end
end

-- 4. CONTROLE (DPAD DOWN) E TECLADO (SETABAIXO)
UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
        runMagnet()
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "ULTRA GOD MODE",
    Text = "Varrendo Status... Seta Baixo = Magnet",
    Duration = 5
})
