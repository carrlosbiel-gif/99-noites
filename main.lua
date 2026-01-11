--// 99 NIGHTS - XENO TELEPORT FARM (MADEIRA & COMIDA) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local VirtualUser = game:GetService("VirtualUser")

-- CONFIGURAÇÃO
_G.FarmAtivo = true
local alvos = {"Log", "Pig", "Deer", "Chicken", "Cow", "Tree", "Dead Tree"} -- Animais e Madeiras

-- 1. FUNÇÃO DE CLICK REAL (Simula você tocando na tela)
local function simulateClick()
    VirtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    task.wait(0.1)
    VirtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end

-- 2. LOOP DE FARM POR TELEPORTE
task.spawn(function()
    while _G.FarmAtivo do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildWhichIsA("Tool")

        if hrp and tool then
            for _, obj in pairs(workspace:GetDescendants()) do
                -- Verifica se o objeto é um dos nossos alvos
                if table.find(alvos, obj.Name) or obj.Name:find("Tree") then
                    local targetPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                    
                    if targetPart and targetPart.Parent then
                        -- Teleporta você para o lado do item/animal
                        hrp.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
                        
                        -- Bate 5 vezes antes de ir para o próximo
                        for i = 1, 5 do
                            if not _G.FarmAtivo then break end
                            simulateClick()
                            task.wait(0.3)
                        end
                    end
                end
                if not _G.FarmAtivo then break end
            end
        end
        task.wait(1)
    end
end)

-- 3. SEMPRE DIA (Obrigatório para sobreviver)
game:GetService("Lighting").ClockTime = 14
game:GetService("Lighting").Brightness = 2

-- 4. MAGNET DE ITENS (Puxa o que dropou)
task.spawn(function()
    while _G.FarmAtivo do
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, item in pairs(workspace:GetDescendants()) do
                if item.Name == "Meat" or item.Name == "Wood" or item.Name == "Coal" then
                    if item:IsA("BasePart") then
                        item.CFrame = hrp.CFrame
                    end
                end
            end
        end
        task.wait(2)
    end
end)

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "TELEPORT FARM",
    Text = "Segure o MACHADO na mão!",
    Duration = 5
})
