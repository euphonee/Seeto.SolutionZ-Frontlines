-- bullet tracers
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Camera = Workspace.CurrentCamera
local EPS = 0.01

local BulletTracers = {
    Initialized = false,
    Connections = {},
    ActiveTracers = {},
    DrawingPool = {},
    CachedMuzzles = {}
}

local function getTracerLine(index)
    local line = BulletTracers.DrawingPool[index]
    if not line then
        line = Drawing.new("Line")
        line.Thickness = 2
        line.Transparency = 1
        line.Visible = false
        pcall(function() line.ZIndex = 3 end)
        BulletTracers.DrawingPool[index] = line
    end
    return line
end

local function renderTracerSegment(line, worldA, worldB, color, thickness, alpha)
    local spA = Camera:WorldToViewportPoint(worldA)
    local spB = Camera:WorldToViewportPoint(worldB)
    local za, zb = spA.Z, spB.Z

    if za > EPS and zb > EPS then
        line.From = Vector2.new(spA.X, spA.Y)
        line.To = Vector2.new(spB.X, spB.Y)
        line.Color = color
        line.Thickness = thickness or 2
        line.Transparency = math.clamp(alpha, 0, 1)
        line.Visible = true
        return true
    elseif za <= EPS and zb <= EPS then
        line.Visible = false
        return false
    else
        local t = (za - EPS) / (za - zb)
        local clipped = worldA:Lerp(worldB, t)
        local spc = Camera:WorldToViewportPoint(clipped)
        local clip2D = Vector2.new(spc.X, spc.Y)

        if za > EPS then
            line.From = Vector2.new(spA.X, spA.Y)
            line.To = clip2D
        else
            line.From = clip2D
            line.To = Vector2.new(spB.X, spB.Y)
        end
        line.Color = color
        line.Thickness = thickness or 2
        line.Transparency = math.clamp(alpha, 0, 1)
        line.Visible = true
        return true
    end
end

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

            local fadeoutTime = math.max(0.1, Config.TRACER_FADEOUT_TIME or 2.0)
            local width = math.max(1, Config.TRACER_BEAM_WIDTH or 2)
            local col = Config.TRACER_BEAM_COLOR or Color3.fromRGB(0, 160, 255)

            table.insert(BulletTracers.ActiveTracers, {
                p0 = p0,
                p1 = p1,
                elapsed = 0,
                duration = fadeoutTime,
                color = col,
                thickness = width
            })
        end
    end)
    table.insert(BulletTracers.Connections, childConn)

    local updateConn = RunService.RenderStepped:Connect(function(dt)
        local tracers = BulletTracers.ActiveTracers
        local activeCount = 0

        for i = #tracers, 1, -1 do
            local t = tracers[i]
            t.elapsed = t.elapsed + dt

            if t.elapsed >= t.duration then
                table.remove(tracers, i)
            else
                activeCount = activeCount + 1
                local alpha = 1 - (t.elapsed / t.duration)
                local line = getTracerLine(activeCount)
                renderTracerSegment(line, t.p0, t.p1, t.color, t.thickness, alpha)
            end
        end

        for i = activeCount + 1, #BulletTracers.DrawingPool do
            BulletTracers.DrawingPool[i].Visible = false
        end
    end)
    table.insert(BulletTracers.Connections, updateConn)
end

function BulletTracers.cleanup()
    for _, conn in ipairs(BulletTracers.Connections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    BulletTracers.Connections = {}
    BulletTracers.ActiveTracers = {}
    BulletTracers.CachedMuzzles = {}

    for _, line in ipairs(BulletTracers.DrawingPool) do
        pcall(function() line:Remove() end)
    end
    BulletTracers.DrawingPool = {}

    BulletTracers.Initialized = false
end

return BulletTracers
