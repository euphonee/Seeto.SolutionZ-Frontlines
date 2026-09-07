-- esp manager
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local ESPManager = {
    Initialized = false
}

function ESPManager.init(Config, Utils, SkeletonRenderer)
    SkeletonRenderer.init()
    ESPManager.Initialized = true
end

function ESPManager.update(Config, Utils, SkeletonRenderer)
    local indices = {
        lineIdx = 0,
        box2dIdx = 0,
        box3dIdx = 0,
        barIdx = 0,
        lookIdx = 0,
        nameIdx = 0
    }

    if Config.ESP_ENABLED == false then
        SkeletonRenderer.hideUnused(indices)
        if SkeletonRenderer.renderSnapline then
            SkeletonRenderer.renderSnapline(Config)
        end
        return
    end

    local soldierActors = Utils.getSoldierActors()
    local teamMap = Utils.getTeamMap()
    local enemyGuis = Utils.getEnemyGuis()

    for _, actor in ipairs(soldierActors) do
        local main = actor:FindFirstChild("main")
        local alive = main and main:FindFirstChild("alive")
        local modelVal = main and main:FindFirstChild("model")
        local model = modelVal and modelVal.Value
        local cidVal = main and main:FindFirstChild("client_id")
        local cid = cidVal and cidVal.Value

        if alive and alive.Value == true and model and model.Parent == Workspace then
            local headMesh = model:FindFirstChild("TPVBodyVanillaHead")
            local isLocal = headMesh and headMesh.LocalTransparencyModifier == 1
            local isFriendly = (teamMap[model] == "FRIENDLY")

            if not isLocal and (not Config.DISABLE_TEAMMATES or not isFriendly) then
                local isTarget = (actor == Config.CurrentTargetActor)
                local bones = Utils.getBones(model)

                SkeletonRenderer.renderSoldier(
                    model,
                    bones,
                    isTarget,
                    isFriendly,
                    cid,
                    enemyGuis,
                    Config,
                    Utils,
                    indices
                )
            end
        end
    end

    if SkeletonRenderer.renderSnapline then
        SkeletonRenderer.renderSnapline(Config)
    end

    SkeletonRenderer.hideUnused(indices)
end

function ESPManager.cleanup(SkeletonRenderer)
    if SkeletonRenderer and SkeletonRenderer.cleanup then
        SkeletonRenderer.cleanup()
    end
    ESPManager.Initialized = false
end

return ESPManager
