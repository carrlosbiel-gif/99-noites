--// 99 Nights - BYPASS GOD MODE (XENO SAFE) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- 1. BYPASS DE DANO E FOME (Imortalidade Real)
task.spawn(function()
    while task.wait(0.1) do
        local char = LocalPlayer.Character
        if char then
            -- Deleta o script de dano por fome se ele existir no seu personagem
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("Script") or v:IsA("LocalScript") then
                    if v.Name:find("Hunger") or v.Name:find("Damage") or v.Name:find("Health") then
                        v.Disabled = true -- Desativa o script que tira sua vida
                    end
                end
            end
            
            -- Deixa o corpo "Inquebrável"
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) -- Impede de entrar no estado de morto
                hum.Health = 100 -- Tenta manter em 100
            end
        end
    end
end)

-- 2. MUNIÇÃO E STAMINA (Loop Direto)
task.spawn(function()
    while task.wait(0.3) do
        local char = LocalPlayer.Character
        if char then
            -- Stamina
            local s = char:FindFirstChild("Stamina") or LocalPlayer:FindFirstChild("Stamina")
            if s then s.Value = 100 end
            
            -- Laser/Armas
            local tool = char:FindFirstChildWhichIsA("Tool")
            if tool then
                local e = tool:FindFirstChild("Energy") or tool:FindFirstChild("Ammo") or tool:FindFirstChild("Charge")
                if e then e.Value = 999 end
            end
        end
    end
end)

-- 3. MAGNET UNIVERSAL (RAIO 5KM)
local function runMagnet()
    local itemsToGrab = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if table.find(itemsToGrab, obj.Name) then
            local handle = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
            if handle then
                if (hrp.Position - handle.Position).Magnitude <= 5000 then
                    -- Traz o item para a sua frente
                    if obj:IsA("Model") then 
                        obj:PivotTo(hrp.CFrame * CFrame.new(0, 3, -4)) 
                    else 
                        obj.CFrame = hrp.CFrame * CFrame.new(0, 3, -4)
                    end
                    -- Força o toque
                    if firetouchinterest then
                        firetouchinterest(hrp, handle, 0)
                        firetouchinterest(hrp, handle, 1)
                    end
                end
            end
        end
    end
end

-- 4. COMANDO DE ATIVAÇÃO (CONTROLE E TECLADO)
UserInputService.InputBegan:Connect(function(input)
    -- DPAD DOWN (Controle) ou SETA BAIXO (Teclado)
    if input.KeyCode == Enum.KeyCode.Down or input.KeyCode == Enum.KeyCode.ButtonDpadDown then
        runMagnet()
    end
end)

-- Notificação de Sucesso
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "BYPASS ATIVO",
    Text = "God Mode & Fome Desativados. Seta Baixo = Magnet",
    Duration = 5
})
