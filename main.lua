--// 99 Nights - BRUTE FORCE ADMIN (HIT KILL & INF ITEMS) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 1. HIT KILL REAL (DESTRUIÇÃO DE HUMANOID)
-- Este código mata qualquer coisa que não seja tu num raio de 20 studs ao atacar
local function applyHitKill()
    local char = LocalPlayer.Character
    if not char then return end
    
    for _, monster in pairs(workspace:GetDescendants()) do
        if monster:IsA("Model") and monster:FindFirstChildOfClass("Humanoid") then
            if monster.Name ~= LocalPlayer.Name then
                local mHrp = monster:FindFirstChild("HumanoidRootPart") or monster:FindFirstChild("Head")
                local myHrp = char:FindFirstChild("HumanoidRootPart")
                
                if mHrp and myHrp then
                    if (myHrp.Position - mHrp.Position).Magnitude <= 20 then
                        monster:FindFirstChildOfClass("Humanoid").Health = 0
                    end
                end
            end
        end
    end
end

-- Ativa o Hit Kill sempre que clicares com uma ferramenta na mão
LocalPlayer.Character.ChildAdded:Connect(function(tool)
    if tool:IsA("Tool") then
        tool.Activated:Connect(function()
            applyHitKill()
        end)
    end
end)

-- 2. TENTATIVA DE ITENS INFINITOS (BYPASS DE CONSUMO)
-- Bloqueia o jogo de diminuir valores de munição ou itens
local mt = getrawmetatable(game)
local oldIndex = mt.__index
local oldNewIndex = mt.__newindex
setreadonly(mt, false)

mt.__newindex = newcclosure(function(t, k, v)
    if checkcaller() then return oldNewIndex(t, k, v) end
    
    -- Se o jogo tentar baixar a munição ou comida, o script ignora
    if k == "Value" and (t.Name:find("Ammo") or t.Name:find("Energy") or t.Name:find("Quantity")) then
        if v < t.Value then
            return oldNewIndex(t, k, t.Value) -- Mantém o valor antigo (não gasta)
        end
    end
    return oldNewIndex(t, k, v)
end)
setreadonly(mt, true)

-- 3. AUTO MAGNET (MUITO RÁPIDO)
task.spawn(function()
    local list = {"Coal", "Log", "Broken Fan", "Radio", "Tire", "Old Tire", "Washing Machine", "Old Car Engine"}
    while task.wait(0.5) do
        pcall(function()
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    if table.find(list, obj.Name) then
                        local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                        if part and (hrp.Position - part.Position).Magnitude <= 1000 then
                            obj:PivotTo(hrp.CFrame * CFrame.new(0, 3, -5))
                        end
                    end
                end
            end
        end)
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "BRUTE FORCE LOADED",
    Text = "HitKill: Clique para matar | Itens: Anti-Gasto",
    Duration = 5
})
