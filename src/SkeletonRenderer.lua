-- visuals renderer
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local EPS = 0.01

local SkeletonRenderer = {
    Drawings = {},
    Snapline = nil,
    Initialized = false
}

local BOX_EDGES = {
    {1, 2}, {2, 3}, {3, 4}, {4, 1},
    {5, 6}, {6, 7}, {7, 8}, {8, 5},
    {1, 5}, {2, 6}, {3, 7}, {4, 8}
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

local function getSquare(name, zIndex)
    local d = SkeletonRenderer.Drawings[name]
    if not d then
        d = Drawing.new("Square")
        d.Thickness = 1.5
        d.Filled = false
        d.Transparency = 1
        d.Visible = false
        pcall(function() d.ZIndex = zIndex or 1 end)
        SkeletonRenderer.Drawings[name] = d
    end
    return d
end

local function getText(name, zIndex)
    local d = SkeletonRenderer.Drawings[name]
    if not d then
        d = Drawing.new("Text")
        d.Size = 13
        d.Center = true
        d.Outline = true
        d.Transparency = 1
        d.Visible = false
        pcall(function() d.ZIndex = zIndex or 2 end)
        SkeletonRenderer.Drawings[name] = d
    end
    return d
end

local function renderSegment(line, worldA, worldB, color, thickness)
    local spA = Camera:WorldToViewportPoint(worldA)
    local spB = Camera:WorldToViewportPoint(worldB)
    local za, zb = spA.Z, spB.Z

    if za > EPS and zb > EPS then
        line.From = Vector2.new(spA.X, spA.Y)
        line.To = Vector2.new(spB.X, spB.Y)
        line.Color = color
        line.Thickness = thickness or 1.5
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
        line.Thickness = thickness or 1.5
        line.Visible = true
        return true
    end
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

    if topScreen.Z <= 0 and btmScreen.Z <= 0 then
        return
    end

    local primaryColor = isTarget and Config.TARGET_COLOR or (isFriendly and Config.FRIENDLY_COLOR or Config.ENEMY_COLOR)

    local barTopY = topScreen.Y
    local barBtmY = btmScreen.Y
    local barHeight = math.max(10, barBtmY - barTopY)
    local boxWidth = math.max(10, barHeight * 0.45)
    local centerX = (topScreen.X + btmScreen.X) * 0.5
    local minScreenX = centerX - (boxWidth * 0.5)

    local boxEnabled = (Config.BOX_ESP_ENABLED ~= false)
    local skeletonEnabled = (Config.SKELETON_ENABLED ~= false)
    local bothEnabled = boxEnabled and skeletonEnabled

    local boxColor = primaryColor
    local skeletonColor = bothEnabled and Color3.fromRGB(255, 255, 255) or primaryColor

    -- Box ESP
    if boxEnabled then
        local boxType = Config.BOX_TYPE or "2D Box"
        if boxType == "2D Box" or boxType == "2D" then
            if topScreen.Z > 0 or btmScreen.Z > 0 then
                indices.box2dIdx = indices.box2dIdx + 1
                local box = getSquare("box2d_" .. indices.box2dIdx, 1)
                box.Position = Vector2.new(minScreenX, barTopY)
                box.Size = Vector2.new(boxWidth, barHeight)
                box.Color = boxColor
                box.Thickness = 1.5
                box.Filled = false
                box.Visible = true
            end
        elseif boxType == "3D Box" or boxType == "3D" then
            local rootPos = (rootBone and rootBone.TransformedWorldCFrame.Position) or model:GetPivot().Position
            local topY = topWorld.Y
            local btmY = btmWorld.Y
            local centerYWorld = (topY + btmY) * 0.5
            local height = math.max(1, topY - btmY)
            local centerWorld = Vector3.new(rootPos.X, centerYWorld, rootPos.Z)
            local rot = model:GetPivot().Rotation
            local cf = CFrame.new(centerWorld) * rot
            local halfX, halfY, halfZ = 1.35, height * 0.5, 1.35

            local corners = {
                cf * Vector3.new(-halfX,  halfY, -halfZ),
                cf * Vector3.new( halfX,  halfY, -halfZ),
                cf * Vector3.new( halfX,  halfY,  halfZ),
                cf * Vector3.new(-halfX,  halfY,  halfZ),
                cf * Vector3.new(-halfX, -halfY, -halfZ),
                cf * Vector3.new( halfX, -halfY, -halfZ),
                cf * Vector3.new( halfX, -halfY,  halfZ),
                cf * Vector3.new(-halfX, -halfY,  halfZ)
            }

            local minX, maxX = math.huge, -math.huge
            local minY, maxY = math.huge, -math.huge
            local anyRendered = false

            for _, edge in ipairs(BOX_EDGES) do
                local pA = corners[edge[1]]
                local pB = corners[edge[2]]
                indices.box3dIdx = indices.box3dIdx + 1
                local line = getLine("box3d_" .. indices.box3dIdx, 1)
                local ok = renderSegment(line, pA, pB, boxColor, 1.5)
                if ok then anyRendered = true end
            end

            if anyRendered then
                for _, corner in ipairs(corners) do
                    local sp = Camera:WorldToViewportPoint(corner)
                    if sp.Z > 0 then
                        if sp.X < minX then minX = sp.X end
                        if sp.X > maxX then maxX = sp.X end
                        if sp.Y < minY then minY = sp.Y end
                        if sp.Y > maxY then maxY = sp.Y end
                    end
                end

                if minX < maxX and minY < maxY then
                    barTopY = minY
                    barBtmY = maxY
                    barHeight = math.max(10, barBtmY - barTopY)
                    boxWidth = math.max(10, maxX - minX)
                    centerX = (minX + maxX) * 0.5
                    minScreenX = minX
                end
            end
        end
    end

    -- Skeleton Bones
    if skeletonEnabled then
        for _, pair in ipairs(Utils.CONNECTIONS) do
            local b1 = bones[pair[1]]
            local b2 = bones[pair[2]]
            if b1 and b2 then
                local p1 = b1.TransformedWorldCFrame.Position
                local p2 = b2.TransformedWorldCFrame.Position
                indices.lineIdx = indices.lineIdx + 1
                local line = getLine("line_" .. indices.lineIdx, 1)
                renderSegment(line, p1, p2, skeletonColor, 1.5)
            end
        end
    end

    -- View Angle Line
    if Config.VIEWANGLE_ENABLED ~= false then
        local lookDir = headBone.TransformedWorldCFrame.UpVector
        local lookLength = Config.LOOK_LINE_LENGTH or 4.5
        local lookTargetWorld = headWorld + (lookDir * lookLength)

        indices.lookIdx = indices.lookIdx + 1
        local lookLine = getLine("look_line_" .. indices.lookIdx, 3)
        renderSegment(lookLine, headWorld, lookTargetWorld, Config.LOOK_LINE_COLOR or Color3.fromRGB(255, 255, 255), 1.5)
    end

    -- Health Bar
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

    -- Player Name (below visuals)
    if Config.SHOW_NAMES_BELOW ~= false then
        local name = Utils.getEnemyName(cid, enemyGuis)
        indices.nameIdx = indices.nameIdx + 1
        local nameText = getText("name_" .. indices.nameIdx, 3)
        nameText.Text = name
        nameText.Position = Vector2.new(centerX, barBtmY + 4)
        nameText.Color = primaryColor
        nameText.Visible = true
    end
end

function SkeletonRenderer.renderKnifeIndicator(worldPos, Config, indices)
    local sp, vis = Camera:WorldToViewportPoint(worldPos)
    if sp.Z <= 0 then return end

    local cx, cy = sp.X, sp.Y
    local s = 4.24
    local col = Config.KNIFE_COLOR or Color3.fromRGB(255, 230, 0)

    local pTop = Vector2.new(cx, cy - s)
    local pRight = Vector2.new(cx + s, cy)
    local pBottom = Vector2.new(cx, cy + s)
    local pLeft = Vector2.new(cx - s, cy)

    indices.knifeIdx = indices.knifeIdx + 1
    local l1 = getLine("knife_l1_" .. indices.knifeIdx, 3)
    l1.From = pTop
    l1.To = pRight
    l1.Color = col
    l1.Thickness = 1.5
    l1.Visible = true

    local l2 = getLine("knife_l2_" .. indices.knifeIdx, 3)
    l2.From = pRight
    l2.To = pBottom
    l2.Color = col
    l2.Thickness = 1.5
    l2.Visible = true

    local l3 = getLine("knife_l3_" .. indices.knifeIdx, 3)
    l3.From = pBottom
    l3.To = pLeft
    l3.Color = col
    l3.Thickness = 1.5
    l3.Visible = true

    local l4 = getLine("knife_l4_" .. indices.knifeIdx, 3)
    l4.From = pLeft
    l4.To = pTop
    l4.Color = col
    l4.Thickness = 1.5
    l4.Visible = true
end

function SkeletonRenderer.renderSnapline(Config)
    local snapline = SkeletonRenderer.Snapline
    if not snapline then
        snapline = Drawing.new("Line")
        snapline.Thickness = 1.5
        snapline.Transparency = 1
        snapline.Visible = false
        pcall(function() snapline.ZIndex = 4 end)
        SkeletonRenderer.Snapline = snapline
    end

    if Config.TARGET_SNAPLINE_ENABLED and Config.CurrentTargetActor and Config.CurrentTargetHeadPos then
        local sp, vis = Camera:WorldToViewportPoint(Config.CurrentTargetHeadPos)
        if sp.Z > 0 then
            local center = Camera.ViewportSize * 0.5
            snapline.From = Vector2.new(center.X, center.Y)
            snapline.To = Vector2.new(sp.X, sp.Y)
            snapline.Color = Config.SNAPLINE_COLOR or Config.TARGET_COLOR or Color3.fromRGB(0, 255, 120)
            snapline.Visible = true
        else
            snapline.Visible = false
        end
    else
        snapline.Visible = false
    end
end

function SkeletonRenderer.hideUnused(indices)
    for k, obj in pairs(SkeletonRenderer.Drawings) do
        if k:find("^line_") then
            local id = tonumber(k:sub(6))
            if id and id > indices.lineIdx then obj.Visible = false end
        elseif k:find("^box2d_") then
            local id = tonumber(k:sub(7))
            if id and id > indices.box2dIdx then obj.Visible = false end
        elseif k:find("^box3d_") then
            local id = tonumber(k:sub(7))
            if id and id > indices.box3dIdx then obj.Visible = false end
        elseif k:find("^look_line_") then
            local id = tonumber(k:sub(11))
            if id and id > indices.lookIdx then obj.Visible = false end
        elseif k:find("^name_") then
            local id = tonumber(k:sub(6))
            if id and id > indices.nameIdx then obj.Visible = false end
        elseif k:find("^knife_l") then
            local id = tonumber(k:match("%d+$"))
            if id and id > indices.knifeIdx then obj.Visible = false end
        elseif k:find("^hbar_bg_") or k:find("^hbar_drain_") or k:find("^hbar_fill_") then
            local id = tonumber(k:match("%d+$"))
            if id and id > indices.barIdx then obj.Visible = false end
        end
    end
end

function SkeletonRenderer.cleanup()
    for _, obj in pairs(SkeletonRenderer.Drawings) do
        pcall(function() obj:Remove() end)
    end
    SkeletonRenderer.Drawings = {}

    if SkeletonRenderer.Snapline then
        pcall(function() SkeletonRenderer.Snapline:Remove() end)
        SkeletonRenderer.Snapline = nil
    end

    SkeletonRenderer.Initialized = false
end

return SkeletonRenderer
