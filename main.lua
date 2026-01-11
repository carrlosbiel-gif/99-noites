--// 99 NIGHTS - MAGNET ULTRA SELETIVO //--

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Variáveis de Controle
_G.Noclip = false
_G.MagnetOP = false
_G.AutoFarm = false

-- Interface
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 220, 0, 300)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 2

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "99 NIGHTS - SELETIVO V2"
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

-- LOOP INTERFACE
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

-- MAGNET SELETIVO COM BLOQUEIO DE ITENS INDESEJADOS
task.spawn(function()
    -- ITENS PERMITIDOS
    local itensAlvo = {
        "fire bag", "firebag", "saco de fogo", -- Saco de fogo específico
        "heavy axe", "battle axe", "machado forte", -- Machados fortes
        "bandage", "bandagem",
        "medkit", "kit", "medico"
    }
    
    -- ITENS PROIBIDOS (VERGALHÕES, FOGUEIRA, ETC)
    local blacklist = {
        "campfire", "fogueira", "scrap", "metal", "iron", "vergalhao", "material", "wood"
    }
    
    while task.wait(1) do
        if _G.MagnetOP then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            
            if hrp then
                for _, obj in pairs(workspace:GetDescendants()) do
                    if (obj:IsA("Tool") or obj:IsA("BasePart") or obj:IsA("Model")) then
                        local nome = obj.Name:lower()
                        
                        -- Verifica se o nome está na lista de permitidos
                        local ehAlvo = false
                        for _, alvo in pairs(itensAlvo) do
                            if nome:find(alvo) then
                                ehAlvo = true
                                break
                            end
                        end
                        
                        -- Verifica se o nome está na lista de proibidos (Blacklist)
                        local ehProibido = false
                        for _, p in pairs(blacklist) do
                            if nome:find(p) then
                                ehProibido = true
                                break
                            end
                        end
                        
                        -- Só puxa se for alvo e NÃO for proibido e não estiver com outro player
                        if ehAlvo and not ehProibido and not obj:IsDescendantOf(char) and not obj:IsDescendantOf(game.Players) then
                            local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart", true)
                            
                            if part then
                                part.CFrame = hrp.CFrame
                                if firetouchinterest then
                                    firetouchinterest(hrp, part, 0)
                                    task.wait(0.05)
                                    firetouchinterest(hrp, part, 1)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)
