-- target selector
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera

local TargetEngine = {
    Initialized = false
}

function TargetEngine.init(Config)
    TargetEngine.Initialized = true
end

function TargetEngine.update(Config, Utils)
    local isAimActive = false
    if type(Config.isSilentAimActive) == "function" then
        isAimActive = (Config.isSilentAimActive() == true)
    else
        isAimActive = (Config.SILENT_AIM_ENABLED ~= false)
    end

    if not isAimActive then
        Config.CurrentTargetActor = nil
        Config.CurrentTargetModel = nil
        Config.CurrentTargetHeadPos = nil
        return nil, nil
    end

    local viewportSize = Camera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
    local fovRadius = Config.FOV_RADIUS or 400

    local soldierActors = Utils.getSoldierActors()
    local teamMap = Utils.getTeamMap()

    local closestActor = nil
    local closestModel = nil
    local closestDist = fovRadius
    local targetWorldPos = nil
    local chosenPartName = "Head_M"

    for _, actor in ipairs(soldierActors) do
        local main = actor:FindFirstChild("main")
        local alive = main and main:FindFirstChild("alive")
        local modelVal = main and main:FindFirstChild("model")
        local model = modelVal and modelVal.Value

        if alive and alive.Value == true and model and model.Parent == Workspace then
            local headMesh = model:FindFirstChild("TPVBodyVanillaHead")
            local isLocal = headMesh and headMesh.LocalTransparencyModifier == 1
            local isFriendly = (teamMap[model] == "FRIENDLY")

            if not isLocal and (not Config.DISABLE_TEAMMATES or not isFriendly) then
                local bones = Utils.getBones(model)
                local headBone = bones["Head_M"]
                local chestBone = bones["Chest_M"]
                local rootBone = bones["Root_M"]

                local headPos = headBone and headBone.TransformedWorldCFrame.Position
                local chestPos = chestBone and chestBone.TransformedWorldCFrame.Position
                local rootPos = rootBone and rootBone.TransformedWorldCFrame.Position

                local testPositions = {headPos, chestPos, rootPos}
                for _, pos in ipairs(testPositions) do
                    if pos then
                        local sp, onScreen = Camera:WorldToViewportPoint(pos)
                        if sp.Z > 0 then
                            local screenPos2D = Vector2.new(sp.X, sp.Y)
                            local dist = (screenPos2D - screenCenter).Magnitude
                            if dist <= fovRadius and dist < closestDist then
                                closestDist = dist
                                closestActor = actor
                                closestModel = model

                                local priority = Config.TARGET_PRIORITY or "Auto"
                                if priority == "Head" then
                                    targetWorldPos = headPos or chestPos or rootPos
                                    chosenPartName = "Head_M"
                                elseif priority == "Torso" then
                                    targetWorldPos = chestPos or rootPos or headPos
                                    chosenPartName = "Chest_M"
                                elseif priority == "Random" then
                                    local candidates = {
                                        {pos = headPos, name = "Head_M"},
                                        {pos = chestPos, name = "Chest_M"},
                                        {pos = rootPos, name = "Root_M"},
                                        {pos = bones["Shoulder_L"] and bones["Shoulder_L"].TransformedWorldCFrame.Position, name = "Shoulder_L"},
                                        {pos = bones["Shoulder_R"] and bones["Shoulder_R"].TransformedWorldCFrame.Position, name = "Shoulder_R"}
                                    }
                                    local valid = {}
                                    for _, c in ipairs(candidates) do
                                        if c.pos then table.insert(valid, c) end
                                    end
                                    if #valid > 0 then
                                        local pick = valid[math.random(1, #valid)]
                                        targetWorldPos = pick.pos
                                        chosenPartName = pick.name
                                    else
                                        targetWorldPos = headPos or rootPos
                                    end
                                else -- "Auto"
                                    targetWorldPos = headPos or chestPos or rootPos
                                    chosenPartName = "Head_M"
                                end

                                break
                            end
                        end
                    end
                end
            end
        end
    end

    Config.CurrentTargetActor = closestActor
    Config.CurrentTargetModel = closestModel
    Config.CurrentTargetHeadPos = targetWorldPos
    Config.CurrentTargetPartName = chosenPartName

    return closestActor, targetWorldPos
end

function TargetEngine.cleanup()
    TargetEngine.Initialized = false
end

return TargetEngine
