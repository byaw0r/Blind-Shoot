local BdevLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/byaw0r/Bdev-UI/main/Bdev.lua"))()

local CONFIG = {
    LASER_LENGTH = 75,
    MAIN_WIDTH = 0.8,
    THICKNESS_WIDTH = 0.4,
    TRANSPARENCY = 0.3,
    THICKNESS_TRANSPARENCY = 0.25,
    THICKNESS_COUNT = 3,
    THICKNESS_SPACING = 0.1,
    UPDATE_PRIORITY = Enum.RenderPriority.Camera.Value - 1,
    DEBOUNCE_DELAY = 0.5
}

local window = BdevLib:CreateWindow({
    Name = "Bdev Hub"
})

local lasers = {}
local laserEnabled = false
local updateConnection

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function createSquareBeamLaser(head)
    local laserContainer = Instance.new("Folder")
    laserContainer.Name = "SquareLaserContainer"
    laserContainer.Parent = workspace
    
    local startAttachment = Instance.new("Attachment")
    startAttachment.Name = "LaserStart"
    
    local endAttachment = Instance.new("Attachment")
    endAttachment.Name = "LaserEnd"
    
    local mainBeam = Instance.new("Beam")
    mainBeam.Name = "SquareBeamLaser"
    mainBeam.Attachment0 = startAttachment
    mainBeam.Attachment1 = endAttachment
    mainBeam.Color = ColorSequence.new(Color3.new(0, 0, 0))
    mainBeam.Width0 = CONFIG.MAIN_WIDTH
    mainBeam.Width1 = CONFIG.MAIN_WIDTH
    mainBeam.Transparency = NumberSequence.new(CONFIG.TRANSPARENCY)
    mainBeam.Texture = ""
    mainBeam.TextureSpeed = 0
    mainBeam.FaceCamera = false
    mainBeam.LightEmission = 0
    mainBeam.LightInfluence = 0
    mainBeam.Segments = 1
    mainBeam.CurveSize0 = 0
    mainBeam.CurveSize1 = 0
    
    local thicknessBeams = {}
    for i = 1, CONFIG.THICKNESS_COUNT do
        local offset = (i - (CONFIG.THICKNESS_COUNT + 1) / 2) * CONFIG.THICKNESS_SPACING
        
        local startAttach = Instance.new("Attachment")
        startAttach.Name = "LaserThicknessStart" .. i
        
        local endAttach = Instance.new("Attachment")
        endAttach.Name = "LaserThicknessEnd" .. i
        
        local beam = Instance.new("Beam")
        beam.Name = "SquareBeamThickness" .. i
        beam.Attachment0 = startAttach
        beam.Attachment1 = endAttach
        beam.Color = ColorSequence.new(Color3.new(0, 0, 0))
        beam.Width0 = CONFIG.THICKNESS_WIDTH
        beam.Width1 = CONFIG.THICKNESS_WIDTH
        beam.Transparency = NumberSequence.new(CONFIG.THICKNESS_TRANSPARENCY)
        beam.Texture = ""
        beam.FaceCamera = false
        beam.Segments = 1
        beam.CurveSize0 = 0
        beam.CurveSize1 = 0
        
        thicknessBeams[i] = {
            beam = beam,
            startAttachment = startAttach,
            endAttachment = endAttach,
            offset = Vector3.new(offset, 0, 0)
        }
    end
    
    mainBeam.Parent = laserContainer
    startAttachment.Parent = laserContainer
    endAttachment.Parent = laserContainer
    
    for _, data in ipairs(thicknessBeams) do
        data.beam.Parent = laserContainer
        data.startAttachment.Parent = laserContainer
        data.endAttachment.Parent = laserContainer
    end
    
    return {
        container = laserContainer,
        mainBeam = mainBeam,
        mainStart = startAttachment,
        mainEnd = endAttachment,
        thicknessBeams = thicknessBeams,
        head = head,
        lastUpdate = 0
    }
end

local function updateLaserPosition(laserData)
    if not laserData or not laserData.head or not laserData.head.Parent then
        return false
    end
    
    local head = laserData.head
    local currentTime = tick()
    
    if currentTime - laserData.lastUpdate < 0.016 then
        return true
    end
    
    laserData.lastUpdate = currentTime
    
    local headCFrame = head.CFrame
    local headPosition = head.Position
    local lookDirection = headCFrame.LookVector
    
    local endPosition = headPosition + (lookDirection * CONFIG.LASER_LENGTH)
    
    laserData.mainStart.WorldPosition = headPosition
    laserData.mainEnd.WorldPosition = endPosition
    
    for _, thicknessData in ipairs(laserData.thicknessBeams) do
        if thicknessData.offset then
            local rightVector = headCFrame.RightVector
            local offsetWorld = rightVector * thicknessData.offset.X
            
            local thicknessStart = headPosition + offsetWorld
            local thicknessEnd = thicknessStart + (lookDirection * CONFIG.LASER_LENGTH)
            
            thicknessData.startAttachment.WorldPosition = thicknessStart
            thicknessData.endAttachment.WorldPosition = thicknessEnd
        end
    end
    
    return true
end

local function addLaserToPlayer(player)
    if not laserEnabled or player == LocalPlayer or lasers[player.Name] then
        return
    end
    
    local function setupLaser(character)
        local head = character:WaitForChild("Head", 2)
        if not head then return end
        
        if lasers[player.Name] then
            removeLaserFromPlayer(player.Name)
        end
        
        local laserData = createSquareBeamLaser(head)
        lasers[player.Name] = laserData
        
        updateLaserPosition(laserData)
        
        return true
    end
    
    if player.Character then
        task.spawn(function()
            task.wait(CONFIG.DEBOUNCE_DELAY)
            setupLaser(player.Character)
        end)
    end
    
    player.CharacterAdded:Connect(function(character)
        if laserEnabled then
            task.wait(CONFIG.DEBOUNCE_DELAY)
            setupLaser(character)
        end
    end)
    
    player.CharacterRemoving:Connect(function()
        if laserEnabled then
            removeLaserFromPlayer(player.Name)
        end
    end)
end

local function removeLaserFromPlayer(playerName)
    local laserData = lasers[playerName]
    if not laserData then return end
    
    if laserData.container and laserData.container.Parent then
        laserData.container:Destroy()
    end
    
    lasers[playerName] = nil
end

local function setupLasers()
    for playerName, _ in pairs(lasers) do
        removeLaserFromPlayer(playerName)
    end
    table.clear(lasers)
    
    if not laserEnabled then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            addLaserToPlayer(player)
        end
    end
end

local function startLaserUpdate()
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
    
    updateConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not laserEnabled then
            if updateConnection then
                updateConnection:Disconnect()
                updateConnection = nil
            end
            return
        end
        
        for playerName, laserData in pairs(lasers) do
            local player = Players:FindFirstChild(playerName)
            
            if not player or not player.Character or not player.Character:FindFirstChild("Head") then
                removeLaserFromPlayer(playerName)
            else
                laserData.head = player.Character:FindFirstChild("Head")
                
                if not updateLaserPosition(laserData) then
                    removeLaserFromPlayer(playerName)
                end
            end
        end
    end)
end

local laserToggle = window:CreateToggle({
    Name = "Esp Laser",
    Default = false,
    Callback = function(state)
        laserEnabled = state
        
        if state then
            setupLasers()
            startLaserUpdate()
        else
            if updateConnection then
                updateConnection:Disconnect()
                updateConnection = nil
            end
            
            for playerName, _ in pairs(lasers) do
                removeLaserFromPlayer(playerName)
            end
            table.clear(lasers)
        end
    end
})

local settingsSection = window:CreateSection("Settings")

local lengthSlider = window:CreateSlider({
    Name = "Laser Length",
    Min = 10,
    Max = 200,
    Default = CONFIG.LASER_LENGTH,
    Callback = function(value)
        CONFIG.LASER_LENGTH = value
    end
})

local transparencySlider = window:CreateSlider({
    Name = "Transparency",
    Min = 0,
    Max = 1,
    Default = CONFIG.TRANSPARENCY,
    Precision = 0.1,
    Callback = function(value)
        CONFIG.TRANSPARENCY = value
        
        if laserEnabled then
            for _, laserData in pairs(lasers) do
                if laserData.mainBeam then
                    laserData.mainBeam.Transparency = NumberSequence.new(value)
                end
            end
        end
    end
})

Players.PlayerAdded:Connect(function(player)
    if laserEnabled then
        addLaserToPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if laserEnabled then
        removeLaserFromPlayer(player.Name)
    end
end)

task.spawn(function()
    task.wait(1)
    
    if laserEnabled then
        setupLasers()
    end
end)

local function cleanup()
    if updateConnection then
        updateConnection:Disconnect()
        updateConnection = nil
    end
    
    for playerName, _ in pairs(lasers) do
        removeLaserFromPlayer(playerName)
    end
    table.clear(lasers)
end

game:BindToClose(cleanup)

print("Bdev Hub loaded!")
