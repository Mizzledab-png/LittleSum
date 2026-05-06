local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- CONFIG
local AUTO_DISTANCE = 5

-- STATE
local autoEnabled = true
local screenGui = nil
local statusLabel = nil
local hrp = nil

-- Reused tables (never recreated)
local activePrompts = {}
local promptCooldown = {}

-- Predefined strings (no new strings created at runtime)
local STATUS_ON = "Auto Prompt: ON"
local STATUS_OFF = "Auto Prompt: OFF"

-- GUI creation (only called on start/respawn)
local function createGUI()
    if screenGui ~= nil then
        screenGui:Destroy()
        screenGui = nil
        statusLabel = nil
    end

    local pg = player:FindFirstChild("PlayerGui")
    if not pg then
        pg = player:WaitForChild("PlayerGui")
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AutoPromptGUI"
    gui.ResetOnSpawn = false
    gui.Parent = pg
    screenGui = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 250, 0, 40)
    label.Position = UDim2.new(0, 20, 1, -60)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = STATUS_ON
    label.Parent = gui

    statusLabel = label
end

local function updateStatus()
    if statusLabel ~= nil then
        statusLabel.Text = autoEnabled and STATUS_ON or STATUS_OFF
    end
end

-- Fast prompt position resolver
local function getPromptPosition(prompt)
    local parent = prompt.Parent
    while parent ~= nil and not parent:IsA("BasePart") do
        parent = parent.Parent
    end
    return parent and parent.Position or nil
end

-- EVENTS

ProximityPromptService.PromptShown:Connect(function(prompt)
    prompt.MaxActivationDistance = AUTO_DISTANCE
    activePrompts[prompt] = true
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    activePrompts[prompt] = nil
    promptCooldown[prompt] = nil
end)

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")

    -- Clear tables without reallocating
    for k in pairs(activePrompts) do activePrompts[k] = nil end
    for k in pairs(promptCooldown) do promptCooldown[k] = nil end

    createGUI()
    updateStatus()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        autoEnabled = not autoEnabled
        updateStatus()
    end
end)

-- MAIN LOOP (zero allocations)
RunService.Heartbeat:Connect(function()
    if not autoEnabled then return end
    local root = hrp
    if root == nil then return end

    local rootPos = root.Position
    local maxDist = AUTO_DISTANCE

    for prompt in pairs(activePrompts) do
        if prompt.Enabled then
            local pos = getPromptPosition(prompt)
            if pos ~= nil then
                local dist = (rootPos - pos).Magnitude

                if dist <= maxDist then
                    -- Only fire once per approach
                    if not promptCooldown[prompt] then
                        promptCooldown[prompt] = true
                        fireproximityprompt(prompt)
                    end
                else
                    -- Reset cooldown when leaving range
                    if promptCooldown[prompt] then
                        promptCooldown[prompt] = nil
                    end
                end
            end
        end
    end
end)

-- INITIAL SETUP
createGUI()
updateStatus()

local char = player.Character
if char then
    hrp = char:FindFirstChild("HumanoidRootPart")
end
