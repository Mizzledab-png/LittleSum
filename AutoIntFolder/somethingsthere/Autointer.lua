local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- CONFIG
local AUTO_DISTANCE = 5
local DELAY = 0.1

-- STATE
local autoEnabled = true
local screenGui = nil
local statusLabel = nil
local hrp = nil

local activePrompts = {}
local waitingForCompletion = {}
local nextFireTime = {}

local STATUS_ON = "Auto Prompt: ON"
local STATUS_OFF = "Auto Prompt: OFF"

local maxDistSquared = AUTO_DISTANCE * AUTO_DISTANCE

-- GUI
local function createGUI()
    if screenGui then
        screenGui:Destroy()
    end

    local pg = player:WaitForChild("PlayerGui")

    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoPromptGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = pg

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 250, 0, 40)
    statusLabel.Position = UDim2.new(0, 20, 1, -60)
    statusLabel.BackgroundTransparency = 0.3
    statusLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextScaled = true
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.Text = STATUS_ON
    statusLabel.Parent = screenGui
end

local function updateStatus()
    if statusLabel then
        statusLabel.Text = autoEnabled and STATUS_ON or STATUS_OFF
    end
end

-- Prompt registry
ProximityPromptService.PromptShown:Connect(function(prompt)
    local parent = prompt.Parent
    while parent and not parent:IsA("BasePart") do
        parent = parent.Parent
    end

    activePrompts[prompt] = {
        pos = parent and parent.Position or nil,
        enabledConn = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
            if prompt.Enabled then
                waitingForCompletion[prompt] = nil
                nextFireTime[prompt] = tick() + DELAY
            end
        end)
	}
    prompt.MaxActivationDistance = AUTO_DISTANCE
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    local data = activePrompts[prompt]
    if data then
        if data.enabledConn then
            data.enabledConn:Disconnect()
        end
        activePrompts[prompt] = nil
    end
    waitingForCompletion[prompt] = nil
    nextFireTime[prompt] = tick() + DELAY
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, plr)
    if plr == player then
        waitingForCompletion[prompt] = nil
        nextFireTime[prompt] = tick() + DELAY
    end
end)

player.CharacterAdded:Connect(function(char)
    hrp = char:WaitForChild("HumanoidRootPart")

    table.clear(activePrompts)
    table.clear(waitingForCompletion)
    table.clear(nextFireTime)

    createGUI()
    updateStatus()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Y then
        autoEnabled = not autoEnabled
        updateStatus()
    end
end)

-- MAIN LOOP (optimized)
RunService.Heartbeat:Connect(function()
    if not autoEnabled or not hrp then return end

    local now = tick()
    local rootPos = hrp.Position

    for prompt, data in pairs(activePrompts) do
        if not prompt.Parent then
            activePrompts[prompt] = nil
            waitingForCompletion[prompt] = nil
            nextFireTime[prompt] = nil
        elseif prompt.Enabled and data.pos then
            local diff = rootPos - data.pos
            if diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z <= maxDistSquared then
                local nf = nextFireTime[prompt]
                if (not nf or now >= nf) and not waitingForCompletion[prompt] then
                    waitingForCompletion[prompt] = true
                    nextFireTime[prompt] = nil

              fireproximityprompt(prompt, 0)
			
                end
            else
                nextFireTime[prompt] = nil
            end
        end
    end
end)

-- INITIAL
createGUI()
updateStatus()

local char = player.Character
if char then
    hrp = char:FindFirstChild("HumanoidRootPart")
end
