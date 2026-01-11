--// 99 NIGHTS - LIGHT VERSION (NOCLIP NO R3) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

_G.Noclip = false

-- 1. FULL BRIGHT (SEMPRE DIA)
Lighting.Brightness = 2
Lighting.ClockTime = 14
Lighting.FogEnd = 100000
Lighting.GlobalShadows = false

-- 2. FUNÇÃO NOCLIP
RunService.Stepped:Connect(function()
    if _G.Noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in pairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

-- 3. ATIVAÇÃO NO R3 (ANALÓGICO DIREITO)
UserInputService.InputBegan:Connect(function(input)
    -- ButtonR3 é o clique do analógico direito do controle
    if input.KeyCode == Enum.KeyCode.ButtonR3 or input.KeyCode == Enum.KeyCode.N then
        _G.Noclip = not _G.Noclip
        
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Noclip Status",
            Text = _G.Noclip and "ATIVADO (R3)" or "DESATIVADO",
            Duration = 2
        })
    end
end)

-- 4. MAGNET DE ITENS (OTIMIZADO)
task.spawn(function()
    local items = {"Log", "Meat", "Wood", "Coal"}
    while task.wait(2) do
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, obj in pairs(workspace:GetChildren()) do
                if table.find(items, obj.Name) then
                    local dist = (hrp.Position - obj:GetPivot().Position).Magnitude
                    if dist < 40 then
                        obj:PivotTo(hrp.CFrame)
                    end
                end
            end
        end
    end
end)

print("Noclip no R3 carregado com sucesso!")
