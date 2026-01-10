--// 99 NIGHTS - GHOST MODE (HITBOX BYPASS) //--
-- Se a vida não muda, o segredo é NÃO levar o dano.

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- 1. REMOVER HITBOX DE DANO (GHOST MODE)
-- Isso faz com que ataques de monstros passem por dentro de você sem acertar
task.spawn(function()
    while task.wait(0.5) do
        local character = LocalPlayer.Character
        if character then
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    -- Mantém você sólido para o chão, mas invisível para colisões de dano
                    if part.Name ~= "HumanoidRootPart" then 
                        part.CanTouch = false 
                    end
                end
            end
        end
    end
end)

-- 2. DESATIVAR ESTADO DE MORTE (ULTRA RESISTÊNCIA)
-- Impede o jogo de processar que você morreu se a vida chegar a 0
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
end

-- 3. AUTO-REGEN FORÇADA (TENTATIVA FINAL)
-- Tenta spammar o sinal de cura para o servidor
task.spawn(function()
    while task.wait() do
        local h = char:FindFirstChildOfClass("Humanoid")
        if h and h.Health < h.MaxHealth then
            h.Health = h.Health + 1
        end
    end
end)

-- Notificação
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "GHOST MODE ATIVO",
    Text = "Hitbox desativada. Monstros não devem te acertar!",
    Duration = 10
})
