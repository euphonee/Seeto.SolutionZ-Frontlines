-- visuals renderer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local SkeletonRenderer = {
    Drawings = {},
    Initialized = false
}

local function getLine(name, zIndex)
    local d = SkeletonRenderer.Drawings[name]
    if not d then
        d = Drawing.new("Line")
        d.Thickness = 1.5
        d.Transparency = 1
        d.Visible = false
        pcall(function() d.ZIndex = zIndex or 1 end)
        SkeletonRenderer.Drawings[name] = d
    end
    return d
end

local function getCircle(name, zIndex)
    local d = SkeletonRenderer.Drawings[name]
    if not d then
        d = Drawing.new("Circle")
        d.Thickness = 1.5
        d.Filled = false
        d.Transparency = 1
        d.Visible = false
        pcall(function() d.ZIndex = zIndex or 1 end)
        SkeletonRenderer.Drawings[name] = d
    end
    return d
end

function SkeletonRenderer.init()
    SkeletonRenderer.Initialized = true
end

function SkeletonRenderer.renderSoldier(model, bones, isTarget, isFriendly, cid, enemyGuis, Config, Utils, indices)
    local headBone = bones["Head_M"]
    local ankleL = bones["Ankle_L"]
    local ankleR = bones["Ankle_R"]
    local rootBone = bones["Root_M"]

    if not headBone or (not ankleL and not ankleR and not rootBone) then
        return
    end

    local headWorld = headBone.TransformedWorldCFrame.Position
    local topWorld = headWorld + Vector3.new(0, 0.7, 0)

    local btmWorld
    if ankleL and ankleR then
        local pL = ankleL.TransformedWorldCFrame.Position
        local pR = ankleR.TransformedWorldCFrame.Position
        btmWorld = (pL.Y < pR.Y and pL or pR) - Vector3.new(0, 0.35, 0)
    elseif rootBone then
        btmWorld = rootBone.TransformedWorldCFrame.Position - Vector3.new(0, 2.5, 0)
    else
        btmWorld = headWorld - Vector3.new(0, 5.0, 0)
    end

    local topScreen, topVis = Camera:WorldToViewportPoint(topWorld)
    local btmScreen, btmVis = Camera:WorldToViewportPoint(btmWorld)

    if topScreen.Z <= 0 or btmScreen.Z <= 0 then
        return
    end

    local primaryColor = isTarget and Config.TARGET_COLOR or (isFriendly and Config.FRIENDLY_COLOR or Config.ENEMY_COLOR)

    local barTopY = topScreen.Y
    local barBtmY = btmScreen.Y
    local barHeight = math.max(10, barBtmY - barTopY)
    local boxWidth = math.max(10, barHeight * 0.45)
    local minScreenX = math.min(topScreen.X, btmScreen.X) - (boxWidth / 2)

    -- head circle
    if Config.HEAD_CIRCLE_ENABLED ~= false then
        local headScreen, headVis = Camera:WorldToViewportPoint(headWorld)
        if headScreen.Z > 0 then
            local dist = (Camera.CFrame.Position - headWorld).Magnitude
            local rad = math.clamp(140 / math.max(dist, 1), 3, 22)
            indices.circleIdx = indices.circleIdx + 1
            local circle = getCircle("circle_" .. indices.circleIdx, 1)
            circle.Position = Vector2.new(headScreen.X, headScreen.Y)
            circle.Radius = rad
            circle.Color = primaryColor
            circle.Transparency = 1
            circle.Visible = true
        end
    end

    -- bones
    if Config.SKELETON_ENABLED ~= false then
        for _, pair in ipairs(Utils.CONNECTIONS) do
            local b1 = bones[pair[1]]
            local b2 = bones[pair[2]]
            if b1 and b2 then
                local p1 = b1.TransformedWorldCFrame.Position
                local p2 = b2.TransformedWorldCFrame.Position
                local sp1 = Camera:WorldToViewportPoint(p1)
                local sp2 = Camera:WorldToViewportPoint(p2)

                if sp1.Z > 0 and sp2.Z > 0 then
                    indices.lineIdx = indices.lineIdx + 1
                    local line = getLine("line_" .. indices.lineIdx, 1)
                    line.From = Vector2.new(sp1.X, sp1.Y)
                    line.To = Vector2.new(sp2.X, sp2.Y)
                    line.Color = primaryColor
                    line.Visible = true
                end
            end
        end
    end

    -- look dir
    if Config.VIEWANGLE_ENABLED ~= false then
        local lookDir = headBone.TransformedWorldCFrame.UpVector
        local lookLength = Config.LOOK_LINE_LENGTH or 4.5
        local lookTargetWorld = headWorld + (lookDir * lookLength)
        local spLookStart = Camera:WorldToViewportPoint(headWorld)
        local spLookEnd = Camera:WorldToViewportPoint(lookTargetWorld)

        if spLookStart.Z > 0 and spLookEnd.Z > 0 then
            indices.lookIdx = indices.lookIdx + 1
            local lookLine = getLine("look_line_" .. indices.lookIdx, 3)
            lookLine.From = Vector2.new(spLookStart.X, spLookStart.Y)
            lookLine.To = Vector2.new(spLookEnd.X, spLookEnd.Y)
            lookLine.Thickness = 1.5
            lookLine.Color = Config.LOOK_LINE_COLOR or Color3.fromRGB(255, 255, 255)
            lookLine.Visible = true
        end
    end

    -- health bar
    if Config.HEALTH_BAR_ENABLED ~= false then
        local hpPct = Utils.getLiveHealth(cid, enemyGuis)
        local hpCol = Utils.getHealthColor(hpPct)

        indices.barIdx = indices.barIdx + 1
        local barX = minScreenX - 6

        local bgLine = getLine("hbar_bg_" .. indices.barIdx, 1)
        bgLine.From = Vector2.new(barX, barTopY - 1)
        bgLine.To = Vector2.new(barX, barBtmY + 1)
        bgLine.Thickness = 4
        bgLine.Color = Color3.fromRGB(15, 15, 15)
        bgLine.Visible = true

        local drainLine = getLine("hbar_drain_" .. indices.barIdx, 2)
        drainLine.From = Vector2.new(barX, barTopY)
        drainLine.To = Vector2.new(barX, barBtmY)
        drainLine.Thickness = 2.5
        drainLine.Color = Color3.fromRGB(50, 10, 10)
        drainLine.Visible = true

        local fillHeight = barHeight * hpPct
        local fillTopY = barBtmY - fillHeight
        local fillLine = getLine("hbar_fill_" .. indices.barIdx, 3)

        if fillHeight > 0.5 then
            fillLine.From = Vector2.new(barX, barBtmY)
            fillLine.To = Vector2.new(barX, fillTopY)
            fillLine.Thickness = 2.5
            fillLine.Color = hpCol
            fillLine.Visible = true
        else
            fillLine.Visible = false
        end
    end
end

function SkeletonRenderer.hideUnused(indices)
    for k, obj in pairs(SkeletonRenderer.Drawings) do
        if k:find("line_") and not k:find("look_line_") then
            local id = tonumber(k:sub(6))
            if id and id > indices.lineIdx then obj.Visible = false end
        elseif k:find("look_line_") then
            local id = tonumber(k:sub(11))
            if id and id > indices.lookIdx then obj.Visible = false end
        elseif k:find("circle_") and k ~= "fov_circle" then
            local id = tonumber(k:sub(8))
            if id and id > indices.circleIdx then obj.Visible = false end
        elseif k:find("hbar_bg_") then
            local id = tonumber(k:sub(9))
            if id and id > indices.barIdx then obj.Visible = false end
        elseif k:find("hbar_drain_") then
            local id = tonumber(k:sub(12))
            if id and id > indices.barIdx then obj.Visible = false end
        elseif k:find("hbar_fill_") then
            local id = tonumber(k:sub(11))
            if id and id > indices.barIdx then obj.Visible = false end
        end
    end
end

function SkeletonRenderer.cleanup()
    for _, obj in pairs(SkeletonRenderer.Drawings) do
        pcall(function() obj:Remove() end)
    end
    SkeletonRenderer.Drawings = {}
    SkeletonRenderer.Initialized = false
end

return SkeletonRenderer
