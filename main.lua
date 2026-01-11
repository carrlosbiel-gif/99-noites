--// 99 NIGHTS - PASSIVE SURVIVAL (AFK FARM) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Lighting = game:GetService("Lighting")

-- 1. MODO SEMPRE DIA (Para você monitorar melhor)
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.FogEnd = 100000
Lighting.GlobalShadows = false

-- 2. ANTI-AFK (Impede que o Roblox te expulse por ficar parado)
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- 3. AUTO-REGEN & ANTI-FOME (Para sobreviver sozinho)
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                -- Tenta manter a fome cheia para não perder vida
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("ValueBase") and (v.Name:lower():find("hunger") or v.Name:lower():find("food")) then
                        v.Value = 100
                    end
                end
                -- Cura automática se algo te bater
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health < hum.MaxHealth then
                    hum.Health = hum.MaxHealth
                end
            end
        end)
    end
end)

-- 4. ESP DO MONSTRO (Para você ver se ele está perto enquanto descansa)
task.spawn(function()
    while task.wait(5) do
        for _, v in pairs(workspace:GetChildren()) do
            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(v) then
                if not v:FindFirstChild("Highlight") then
                    local h = Instance.new("Highlight", v)
                    h.FillColor = Color3.fromRGB(255, 0, 0)
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                end
            end
        end
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "AFK FARM ATIVO",
    Text = "O script tentará te manter vivo. Boa sorte nas 99 noites!",
    Duration = 10
})
