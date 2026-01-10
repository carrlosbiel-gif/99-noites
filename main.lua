--// 99 Nights - REMOTE SPAMMER EDITION (XENO) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- 1. HIT KILL (MATA TUDO QUE ESTÁ PERTO QUANDO VOCÊ CLICA)
local function KillNearby()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChild("Humanoid") and v.Name ~= LocalPlayer.Name then
            local monsterHrp = v:FindFirstChild("HumanoidRootPart")
            if monsterHrp and (hrp.Position - monsterHrp.Position).Magnitude <= 25 then
                -- Tenta matar zerando a vida localmente (pra bugar o servidor)
                v.Humanoid.Health = 0
                
                -- Tenta forçar o dano via toque (falso hit)
                local tool = character:FindFirstChildWhichIsA("Tool")
                if tool and tool:FindFirstChild("Handle") then
                    firetouchinterest(monsterHrp, tool.Handle, 0)
                    firetouchinterest(monsterHrp, tool.Handle, 1)
                end
            end
        end
    end
end

-- Ativa o Hit Kill no clique
LocalPlayer:GetMouse().Button1Down:Connect(KillNearby)

-- 2. TENTATIVA DE ITENS INFINITOS (BLOQUEIA O CONSUMO)
-- Esse método tenta deletar o comando de 'tirar item' do inventário
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local tool = character:FindFirstChildWhichIsA("Tool")
            if tool then
                -- Se o jogo usa 'Ammo' ou 'Durability' em NumberValues
                for _, val in pairs(tool:GetDescendants()) do
                    if val:IsA("IntValue") or val:IsA("NumberValue") then
                        val.Value = 999 
                    end
                end
            end
        end)
    end
end)

-- 3. MEGA MAGNET (AUTOMÁTICO - 5KM)
task.spawn(function()
    local items = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    while task.wait(1) do
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in pairs(workspace:GetDescendants()) do
                if table.find(items, obj.Name) then
                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    if part then
                        local dist = (hrp.Position - part.Position).Magnitude
                        if dist <= 5000 then
                            obj:PivotTo(hrp.CFrame * CFrame.new(0, 5, -2))
                        end
                    end
                end
            end
        end
    end
end)

-- 4. STAMINA E FOME (VIA REMOTES)
task.spawn(function()
    while task.wait(0.5) do
        -- Tenta resetar os valores de fome e stamina direto no player
        local s = character:FindFirstChild("Stamina") or LocalPlayer:FindFirstChild("Stamina")
        if s then s.Value = 100 end
        
        local f = character:FindFirstChild("Hunger") or LocalPlayer:FindFirstChild("Hunger")
        if f then f.Value = 100 end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "REMOTE BYPASS",
    Text = "HitKill no Clique | Magnet Auto",
    Duration = 5
})
