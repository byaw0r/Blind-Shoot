local BdevLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/byaw0r/Bdev-UI/main/Bdev.lua"))()

local window = BdevLib:CreateWindow({
    Name = "Bdev Hub"
})

local laserEnabled = false
local playerEspEnabled = false
local autoParkourEnabled = false

local function initializeLaserScript()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local playerLocal = Players.LocalPlayer

    local modelsSkin = {}
    local listLasers = {}

    local COLOR_LASER = Color3.fromRGB(255, 0, 0)
    local SCALE_WIDTH_LASER = 1/12.5
    local OFFSET_HEIGHT_LASER = 0.5
    local SHORTEN_LASER = 0.50

    local function followModel(model)
        if modelsSkin[model] then return end
        if model:IsA("Model") and model.Name:lower():sub(1,5) == "skin_" then
            modelsSkin[model] = true
            local beam = Instance.new("Part")
            beam.Anchored = true
            beam.CanCollide = false
            beam.Material = Enum.Material.Neon
            beam.Color = COLOR_LASER
            beam.Transparency = 0
            beam.Name = "SkinLaser"
            beam.Parent = Workspace
            listLasers[model] = beam
        end
    end

    for _, object in ipairs(Workspace:GetDescendants()) do
        followModel(object)
    end

    Workspace.DescendantAdded:Connect(followModel)

    local function getBounds(model)
        local position, dimensions
        pcall(function()
            position, dimensions = model:GetBoundingBox()
        end)
        return position, dimensions
    end

    local laserConnection
    laserConnection = RunService.RenderStepped:Connect(function()
        for model, _ in pairs(modelsSkin) do
            if model.Parent then
                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 0
                        part.CanCollide = false
                        if part.Material == Enum.Material.ForceField then
                            part.Material = Enum.Material.SmoothPlastic
                        end
                    end
                end

                local beam = listLasers[model]
                if beam then
                    local position, dimensions = getBounds(model)
                    if position and dimensions then
                        local lineSize = Vector3.new(0.1, 0.1, dimensions.Z - SHORTEN_LASER*2)
                        beam.Size = lineSize
                        beam.CFrame = position * CFrame.new(0, OFFSET_HEIGHT_LASER, 0)
                    end
                end
            else
                if listLasers[model] then
                    listLasers[model]:Destroy()
                    listLasers[model] = nil
                end
                modelsSkin[model] = nil
            end
        end
    end)

    return laserConnection, listLasers, modelsSkin
end

local function initializePlayerEsp()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")

    local playerLocal = Players.LocalPlayer

    local function checkHitbox(part)
        local nameLower = part.Name:lower()
        if nameLower:find("hitbox") or nameLower == "hb" then
            return true
        end
        if part.Size.Magnitude > 10 then
            return true
        end
        return false
    end

    local function fixCharacter(character)
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("BasePart") then
                if obj.Name ~= "HumanoidRootPart" then
                    if checkHitbox(obj) then
                        obj.Transparency = 1
                        obj.LocalTransparencyModifier = 1
                        obj.CanCollide = false
                    else
                        obj.Transparency = 0
                        obj.LocalTransparencyModifier = 0
                    end
                end
            elseif obj:IsA("Decal") then
                obj.Transparency = 0
            end
        end
    end

    local espConnection
    espConnection = RunService.RenderStepped:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= playerLocal then
                local character = player.Character
                if character and character.Parent then
                    fixCharacter(character)
                end
            end
        end
    end)

    return espConnection
end

local function initializeAutoParkour()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    
    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")
    
    local originalCFrame = humanoidRootPart.CFrame
    local teleporting = false
    local targetName = "Trophy"
    local FALL_HEIGHT = 15
    local WAIT_AFTER_FALL = 1
    local DELAY_AFTER_RETURN = 0.5
    
    local function findTrophy()
        local trophy = Workspace:FindFirstChild(targetName)
        if not trophy then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == targetName then
                    return obj
                end
            end
        end
        return trophy
    end
    
    local function getTrophyPosition(trophy)
        if trophy:IsA("BasePart") then
            return trophy.Position
        elseif trophy:IsA("Model") then
            if trophy.PrimaryPart then
                return trophy.PrimaryPart.Position
            else
                local success, pos = pcall(function()
                    return trophy:GetPivot().Position
                end)
                if success then
                    return pos
                else
                    return trophy:GetModelCFrame().Position
                end
            end
        end
        return nil
    end
    
    local function waitForFallCompletion()
        local startTime = tick()
        local maxWaitTime = 1
        
        while tick() - startTime < maxWaitTime do
            if math.abs(humanoidRootPart.Velocity.Y) < 1 then
                task.wait(0.2)
                return true
            end
            task.wait(0.1)
        end
        
        return true
    end
    
    local autoParkourConnection
    autoParkourConnection = RunService.Heartbeat:Connect(function()
        if not autoParkourEnabled or teleporting then
            return
        end
        
        teleporting = true
        
        local trophy = findTrophy()
        if not trophy then
            warn("Trophy not found in Workspace!")
            teleporting = false
            return
        end
        
        local trophyPosition = getTrophyPosition(trophy)
        if not trophyPosition then
            teleporting = false
            return
        end
        
        originalCFrame = humanoidRootPart.CFrame
        
        local positionAboveTrophy = Vector3.new(
            trophyPosition.X,
            trophyPosition.Y + FALL_HEIGHT,
            trophyPosition.Z
        )
        
        humanoidRootPart.Anchored = true
        humanoidRootPart.CFrame = CFrame.new(positionAboveTrophy)
        
        humanoidRootPart.Anchored = false
        
        waitForFallCompletion()
        
        task.wait(WAIT_AFTER_FALL)
        
        humanoidRootPart.Anchored = true
        humanoidRootPart.CFrame = originalCFrame
        humanoidRootPart.Anchored = false
        
        task.wait(DELAY_AFTER_RETURN)
        
        teleporting = false
    end)
    
    return autoParkourConnection
end

local laserConnection, laserObjects, skinModels
local espConnection
local autoParkourConnection

local laserToggle = window:CreateToggle({
    Name = "ESP Laser",
    Default = false,
    Callback = function(state)
        laserEnabled = state
        if state then
            laserConnection, laserObjects, skinModels = initializeLaserScript()
        else
            if laserConnection then
                laserConnection:Disconnect()
                laserConnection = nil
            end
            if laserObjects then
                for model, laser in pairs(laserObjects) do
                    if laser then
                        laser:Destroy()
                    end
                end
                laserObjects = {}
            end
            if skinModels then
                for model in pairs(skinModels) do
                    skinModels[model] = nil
                end
            end
        end
    end
})

local playerToggle = window:CreateToggle({
    Name = "ESP Player",
    Default = false,
    Callback = function(state)
        playerEspEnabled = state
        if state then
            espConnection = initializePlayerEsp()
        else
            if espConnection then
                espConnection:Disconnect()
                espConnection = nil
            end
        end
    end
})

local autoParkourToggle = window:CreateToggle({
    Name = "Auto Parkour",
    Default = false,
    Callback = function(state)
        autoParkourEnabled = state
        if state then
            autoParkourConnection = initializeAutoParkour()
        else
            if autoParkourConnection then
                autoParkourConnection:Disconnect()
                autoParkourConnection = nil
            end
        end
    end
})

game:GetService("Players").PlayerRemoving:Connect(function(player)
    local playerLocal = game:GetService("Players").LocalPlayer
    if player == playerLocal then
        if laserConnection then
            laserConnection:Disconnect()
        end
        if espConnection then
            espConnection:Disconnect()
        end
        if autoParkourConnection then
            autoParkourConnection:Disconnect()
        end
    end
end)
