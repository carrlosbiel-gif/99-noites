--// 99 NIGHTS - ULTIMATE GOD MODE (BYPASS) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Função para limpar scripts de dano e travar a vida
local function ApplyGodMode(char)
    local hum = char:WaitForChild("Humanoid")
    
    -- 1. Impede o Humanoid de entrar no estado de "Morto"
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    
    -- 2. Tenta deletar ou desativar scripts de Fome, Sede e Dano
    for _, v in pairs(char:GetDescendants()) do
        if v:IsA("LocalScript") or v:IsA("Script") then
            local name = v.Name:lower()
            if name:find("hunger") or name:find("damage") or name:find("health") or name:find("fome") or name:find("take") then
                v.Disabled = true
                v:Destroy() -- Deleta o script de dano do seu corpo
            end
        end
    end
end

-- Ativa sempre que o personagem nasce ou reseta
LocalPlayer.CharacterAdded:Connect(ApplyGodMode)
if LocalPlayer.Character then ApplyGodMode(LocalPlayer.Character) end

-- 3. LOOP DE CURA FORÇADA (REGEN ULTRA RÁPIDA)
RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                -- Trava a vida no máximo
                hum.MaxHealth = 100
                hum.Health = 100
            end
            
            -- Procura por valores de Vida/Fome/Stamina e trava tudo no 100
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
    Title = "GOD MODE ATIVADO",
    Text = "Scripts de dano removidos. Imortalidade ON.",
    Duration = 10
})
