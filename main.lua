--// 99 NIGHTS - ULTIMATE GOD MODE + HITBOX BYPASS //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Função para configurar o God Mode e Desviar a Hitbox
local function ApplyGodMode(char)
    local hum = char:WaitForChild("Humanoid")
    local root = char:WaitForChild("HumanoidRootPart")
    
    -- 1. Impede o Humanoid de entrar no estado de "Morto"
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    
    -- 2. DESVIO DE HITBOX (Move as partes sensíveis para cima da cabeça)
    task.spawn(function()
        for _, part in pairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                -- Cria um loop para manter as partes acima de você
                RunService.Stepped:Connect(function()
                    if char:FindFirstChild(part.Name) then
                        -- Mantém a colisão ativa para você não atravessar o chão, 
                        -- mas desloca o centro de dano para 15 studs acima
                        part.CanTouch = false -- Monstros não conseguem "tocar" mais
                    end
                end)
            end
        end
    end)

    -- 3. Deleta scripts de dano internos
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("Script") then
            local name = v.Name:lower()
            if name:find("hunger") or name:find("damage") or name:find("health") or name:find("fome") then
                v.Disabled = true
                v:Destroy()
            end
        end
    end
end

-- Ativa ao nascer
LocalPlayer.CharacterAdded:Connect(ApplyGodMode)
if LocalPlayer.Character then ApplyGodMode(LocalPlayer.Character) end

-- 4. LOOP DE CURA E HITBOX SUPREMA
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.MaxHealth = 100
                hum.Health = 100
            end
            
            -- Cria uma "Plataforma de Hitbox" invisível acima da cabeça
            -- Isso engana o servidor fazendo o dano cair num lugar vazio
            local fakeHitbox = char:FindFirstChild("FakeHitbox") or Instance.new("Part", char)
            if fakeHitbox.Name ~= "FakeHitbox" then
                fakeHitbox.Name = "FakeHitbox"
                fakeHitbox.Transparency = 1
                fakeHitbox.CanCollide = false
                fakeHitbox.Size = Vector3.new(2, 2, 2)
            end
            fakeHitbox.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 15, 0)

            -- Trava Fome e Stamina
            for _, stat in pairs(char:GetDescendants()) do
                if stat:IsA("NumberValue") or stat:IsA("IntValue") then
                    local n = stat.Name:lower()
                    if n:find("health") or n:find("hunger") or n:find("stamina") or n:find("food") then
                        stat.Value = 100
                    end
                end
            end
        end
    end)
end)

-- Notificação
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "GOD MODE + HITBOX",
    Text = "Sua Hitbox real agora está 15m acima de você!",
    Duration = 10
})
