local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- CONFIG
local AUTO_DISTANCE = 5
local DELAY = 2 -- wait 2 seconds AFTER completion

-- STATE
local autoEnabled = true
local screenGui = nil
local statusLabel = nil
local hrp = nil

-- Reused tables
local activePrompts = {}
local waitingForCompletion = {}
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

    -- COMPLETION METHOD #3: Enabled flips back to true
    prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        if prompt.Enabled then
            waitingForCompletion[prompt] = nil
            nextFireTime[prompt] = tick() + DELAY
        end
    end)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    -- COMPLETION METHOD #2: Hidden = complete
    activePrompts[prompt] = nil
    waitingForCompletion[prompt] = nil
    nextFireTime[prompt] = tick() + DELAY
end)

-- COMPLETION METHOD #1: PromptTriggered
ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
    if plr == player then
        waitingForCompletion[prompt] = nil
        nextFireTime[prompt] = tick() + DELAY
    end
end)

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")

    for k in pairs(activePrompts) do activePrompts[k] = nil end
    for k in pairs(waitingForCompletion) do waitingForCompletion[k] = nil end
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

                    -- If still waiting for completion, do nothing
                    if not waitingForCompletion[prompt] then

                        -- Check if cooldown expired
                        local nf = nextFireTime[prompt]
                        if not nf or now >= nf then
                            waitingForCompletion[prompt] = true
                            nextFireTime[prompt] = nil
                            fire(prompt)
                        end
                    end

                else
                    waitingForCompletion[prompt] = nil
                    nextFireTime[prompt] = nil
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
