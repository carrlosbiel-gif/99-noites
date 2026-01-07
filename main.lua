--// 99 Nights in the Forest [MINIMALIST EDITION] //--

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("99 NIGHTS", "DarkTheme")

-- Services & Vars
local LP = game:GetService("Players").LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local US = game:GetService("UserInputService")
local Config = {Farm = false, Aimbot = false, ESP = false}

-- Functions
local function fastClick()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- TAB: AUTOMAÇÃO
local Tab1 = Window:NewTab("Automação")
local Section1 = Tab1:NewSection("Farm & Sobrevivência")

Section1:NewToggle("Auto Tree Farm", "Bate em árvores próximas", function(state)
    Config.Farm = state
end)

Section1:NewToggle("NPC ESP", "Ver inimigos através das paredes", function(state)
    Config.ESP = state
end)

-- TAB: COMBATE
local Tab2 = Window:NewTab("Combate")
local Section2 = Tab2:NewSection("Assistência")

Section2:NewToggle("Aimbot (Segurar Botão Dir.)", "Mira suave em NPCs", function(state)
    Config.Aimbot = state
end)

Section2:NewSlider("Suavidade", "Ajusta o movimento da mira", 10, 1, function(s)
    Config.Smooth = s / 10
end)

-- TAB: TELEPORTE
local Tab3 = Window:NewTab("Teleport")
local Section3 = Tab3:NewSection("Locais Úteis")

local locations = {
    ["Acampamento"] = CFrame.new(0, 10, 0),
    ["Grinder"] = CFrame.new(16, 4, -4.6),
    ["Raygun Spawn"] = nil -- Busca dinâmica no loop
}

for name, cf in pairs(locations) do
    Section3:NewButton(name, "Teleportar para " .. name, function()
        if cf then 
            LP.Character:PivotTo(cf) 
        end
    end)
end

-- LOOP OTIMIZADO (Minimalista e Silencioso)
task.spawn(function()
    while task.wait(0.5) do
        if
