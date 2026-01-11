--// 99 NIGHTS - EXCLUSIVE MAGNET (FOGO, MACHADO, CURA) //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Variáveis de Controle
_G.Noclip = false
_G.MagnetOP = false
_G.AutoFarm = false

-- Interface do Menu
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS - SELETIVO"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)

local function CreateBtn(text, pos, callback)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, 200, 0, 45)
    btn.Position = pos
    btn.Text = text
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

-- BOTOES
CreateBtn("ILUMINAÇÃO (DIA)", UDim2.new(0, 10, 0, 45), function()
    Lighting.ClockTime = 14
    Lighting.Brightness = 2
end)

local nBtn = CreateBtn("NOCLIP: OFF", UDim2.new(0, 10, 0, 95), function()
    _G.Noclip = not _G.Noclip
end)

local mBtn = CreateBtn("MAGNET FILTRADO: OFF", UDim2.new(0, 10, 0, 145), function()
    _G.MagnetOP = not _G.MagnetOP
end)

local fBtn = CreateBtn("AUTO FARM: OFF", UDim2.new(0, 10, 0, 195), function()
    _G.AutoFarm = not _G.AutoFarm
end)

CreateBtn("FECHAR MENU", UDim2.new(0, 10, 0, 245), function()
    MainFrame.Visible = false
end)

-- ATUALIZAÇÃO DE TEXTO E NOCLIP
RunService.Stepped:Connect(function()
    nBtn.Text = "NOCLIP: " .. (_G.Noclip and "ON" or "OFF")
    mBtn.Text = "MAGNET FILTRADO: " .. (_G.MagnetOP and "ON" or "OFF")
    fBtn.Text = "AUTO FARM: " .. (_G.AutoFarm and "ON" or "OFF")
    
    if _G.Noclip and LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetChildren()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end
end)

-- MAGNET EXCLUSIVO
task.spawn(function()
    -- APENAS os itens solicitados
    local itensAlvo = {
        "fire", "saco", "fogo",      -- Saco de Fogo
        "heavy", "battle", "axe",    -- Machado Forte
        "bandage", "bandagem",       -- Bandagem
        "medkit", "kit", "medico"    -- Kit Médico
    }
    
    while task.wait(1.5) do
        if _G.MagnetOP then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    -- Verifica se o objeto é um item solto no mapa
                    if (obj:IsA("Tool") or obj:IsA("Model") or obj:IsA("BasePart")) then
                        local nome = obj.Name:lower()
                        
                        -- Ignora itens já equipados ou de outros players
                        if not obj:IsDescendantOf(char) and not obj:IsDescendantOf(game.Players) then
                            for _, alvo in pairs(itensAlvo) do
                                if nome:find(alvo) then
                                    local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                                    
                                    if part then
                                        part.CFrame = hrp.CFrame
                                        
                                        -- Simula o toque para coletar
                                        if firetouchinterest then
                                            firetouchinterest(hrp, part, 0)
                                            task.wait(0.05)
                                            firetouchinterest(hrp, part, 1)
                                        end
                                    end
                                    break -- Sai do loop de nomes se já achou o item
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
