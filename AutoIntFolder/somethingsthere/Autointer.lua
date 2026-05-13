local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- CONFIG
local AUTO_DISTANCE = 5
local DELAY = 0.5 -- repeat delay

-- STATE
local autoEnabled = true
local screenGui = nil
local statusLabel = nil
local hrp = nil

-- Reused tables (never recreated)
local activePrompts = {}
local promptCooldown = {}
local nextFireTime = {}

-- Predefined strings
local STATUS_ON = "Auto Prompt: ON"
local STATUS_OFF = "Auto Prompt: OFF"

-- GUI creation
local function createGUI()
    if screenGui ~= nil then
        screenGui:Destroy()
        screenGui = nil
        statusLabel = nil
    end

    local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui")

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
    if statusLabel then
        statusLabel.Text = autoEnabled and STATUS_ON or STATUS_OFF
    end
end

-- Fast prompt position resolver
local function getPromptPosition(prompt)
    local parent = prompt.Parent
    while parent and not parent:IsA("BasePart") do
        parent = parent.Parent
    end
    return parent and parent.Position
end

-- EVENTS

ProximityPromptService.PromptShown:Connect(function(prompt)
    prompt.MaxActivationDistance = AUTO_DISTANCE
    activePrompts[prompt] = true
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    activePrompts[prompt] = nil
    promptCooldown[prompt] = nil
    nextFireTime[prompt] = nil
end)

-- Reset cooldown after prompt completes (if the prompt supports it)
ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
    if plr == player then
        promptCooldown[prompt] = nil
    end
end)

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")

    for k in pairs(activePrompts) do activePrompts[k] = nil end
    for k in pairs(promptCooldown) do promptCooldown[k] = nil end
    for k in pairs(nextFireTime) do nextFireTime[k] = nil end

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

-- MAIN LOOP
local fire = fireproximityprompt
local maxDist = AUTO_DISTANCE

RunService.Heartbeat:Connect(function()
    if not autoEnabled then return end
    local root = hrp
    if not root then return end

    local rootPos = root.Position
    local now = tick()

    local prompt = next(activePrompts)
    while prompt do
        if prompt.Enabled then
            local pos = getPromptPosition(prompt)
            if pos then
                if (rootPos - pos).Magnitude <= maxDist then

                    -- Reset cooldown when delay expires
                    local nf = nextFireTime[prompt]
                    if nf and now >= nf then
                        promptCooldown[prompt] = nil
                    end

                    -- Fire if ready
                    if not promptCooldown[prompt] then
                        nextFireTime[prompt] = now + DELAY
                        promptCooldown[prompt] = true
                        fire(prompt)
                    end

                else
                    promptCooldown[prompt] = nil
                end
            end
        end
        prompt = next(activePrompts, prompt)
    end
end)

-- INITIAL SETUP
createGUI()
updateStatus()

local char = player.Character
if char then
    hrp = char:FindFirstChild("HumanoidRootPart")
end
