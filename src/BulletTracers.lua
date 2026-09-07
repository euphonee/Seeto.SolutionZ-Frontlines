-- bullet tracers
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera

local BulletTracers = {
    Initialized = false,
    Connections = {},
    ActiveBeams = {},
    CachedMuzzles = {},
    Container = nil
}

function BulletTracers.refreshCachedMuzzles(Utils)
    local list = {}
    if Utils and type(Utils.isLocalFireAttachment) == "function" then
        for _, inst in ipairs(Workspace:GetDescendants()) do
            if Utils.isLocalFireAttachment(inst) then
                table.insert(list, inst)
            end
        end
    end
    BulletTracers.CachedMuzzles = list
end

function BulletTracers.getActiveMuzzle()
    local camPos = Camera.CFrame.Position
    local muzzles = BulletTracers.CachedMuzzles
    for i = #muzzles, 1, -1 do
        local inst = muzzles[i]
        if not inst or not inst.Parent then
            table.remove(muzzles, i)
        else
            local p = inst.Parent
            if p:IsA("BasePart") and (p.Position - camPos).Magnitude < 8 then
                return inst.WorldPosition, -inst.WorldCFrame.ZVector
            end
        end
    end
    return nil, nil
end

function BulletTracers.init(Config, Utils)
    if BulletTracers.Initialized then return end
    BulletTracers.Initialized = true

    local container = Workspace:FindFirstChild("__solutionz_tracers")
    if not container then
        container = Instance.new("Folder")
        container.Name = "__solutionz_tracers"
        container.Parent = Workspace
    end
    BulletTracers.Container = container

    BulletTracers.refreshCachedMuzzles(Utils)

    local descConn = Workspace.DescendantAdded:Connect(function(inst)
        if Utils and Utils.isLocalFireAttachment(inst) then
            table.insert(BulletTracers.CachedMuzzles, inst)
        end
    end)
    table.insert(BulletTracers.Connections, descConn)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true

    local childConn = Workspace.ChildAdded:Connect(function(child)
        if not Config or Config.TRACER_BEAMS_ENABLED == false then return end

        if child.Name == "tracer" then
            local camPos = Camera.CFrame.Position
            local dist = (child.Position - camPos).Magnitude

            -- local bullets only
            if child.Transparency < 0.9 or dist > 8 then
                return
            end

            local p0, dir = BulletTracers.getActiveMuzzle()
            if not p0 or not dir then
                p0 = child.CFrame.Position
                dir = Camera.CFrame.LookVector
            end

            local rayRes = Workspace:Raycast(p0, dir * 2000, rayParams)
            local p1 = (rayRes and rayRes.Position) or (p0 + dir * 500)

            BulletTracers.spawnBeam(p0, p1, Config)
        end
    end)
    table.insert(BulletTracers.Connections, childConn)

    -- fade active beams
    local updateConn = RunService.Heartbeat:Connect(function(dt)
        local beams = BulletTracers.ActiveBeams
        for i = #beams, 1, -1 do
            local b = beams[i]
            b.elapsed = b.elapsed + dt
            local alpha = b.elapsed / b.duration
            if alpha >= 1 then
                pcall(function() b.beam:Destroy() end)
                pcall(function() b.a0:Destroy() end)
                pcall(function() b.a1:Destroy() end)
                table.remove(beams, i)
            else
                pcall(function()
                    b.beam.Transparency = NumberSequence.new(math.clamp(alpha, 0, 1))
                end)
            end
        end
    end)
    table.insert(BulletTracers.Connections, updateConn)
end

function BulletTracers.spawnBeam(p0, p1, Config)
    if not BulletTracers.Container then return end

    local a0 = Instance.new("Attachment")
    a0.WorldPosition = p0
    a0.Parent = BulletTracers.Container

    local a1 = Instance.new("Attachment")
    a1.WorldPosition = p1
    a1.Parent = BulletTracers.Container

    local beam = Instance.new("Beam")
    beam.Attachment0 = a0
    beam.Attachment1 = a1

    -- width
    local width = (Config.TRACER_BEAM_WIDTH or 6) / 100
    beam.Width0 = width
    beam.Width1 = width
    beam.Color = ColorSequence.new(Config.TRACER_BEAM_COLOR or Color3.fromRGB(0, 160, 255))
    beam.FaceCamera = true
    beam.LightEmission = 0
    beam.LightInfluence = 0
    beam.Texture = ""
    beam.Transparency = NumberSequence.new(0)
    beam.Parent = BulletTracers.Container

    local fadeoutTime = math.max(0.1, Config.TRACER_FADEOUT_TIME or 2.0)

    table.insert(BulletTracers.ActiveBeams, {
        beam = beam,
        a0 = a0,
        a1 = a1,
        elapsed = 0,
        duration = fadeoutTime
    })
end

function BulletTracers.cleanup()
    for _, conn in ipairs(BulletTracers.Connections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    BulletTracers.Connections = {}

    for _, b in ipairs(BulletTracers.ActiveBeams) do
        pcall(function() b.beam:Destroy() end)
        pcall(function() b.a0:Destroy() end)
        pcall(function() b.a1:Destroy() end)
    end
    BulletTracers.ActiveBeams = {}
    BulletTracers.CachedMuzzles = {}

    if BulletTracers.Container then
        pcall(function() BulletTracers.Container:Destroy() end)
        BulletTracers.Container = nil
    end

    BulletTracers.Initialized = false
end

return BulletTracers
