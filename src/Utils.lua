-- utils
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Utils = {}

local boneCache = setmetatable({}, { __mode = "k" })

Utils.CONNECTIONS = {
    {"Head_M", "Neck_M"},
    {"Neck_M", "Chest_M"},
    {"Chest_M", "Spine1_M"},
    {"Spine1_M", "Root_M"},

    {"Neck_M", "Shoulder_L"},
    {"Shoulder_L", "Elbow_L"},
    {"Elbow_L", "Wrist_L"},

    {"Neck_M", "Shoulder_R"},
    {"Shoulder_R", "Elbow_R"},
    {"Elbow_R", "Wrist_R"},

    {"Root_M", "Hip_L"},
    {"Hip_L", "Knee_L"},
    {"Knee_L", "Ankle_L"},

    {"Root_M", "Hip_R"},
    {"Hip_R", "Knee_R"},
    {"Knee_R", "Ankle_R"},
}

function Utils.isLocalFireAttachment(inst)
    if not inst or not inst:IsA("Attachment") then return false end
    local n = inst.Name:lower()
    if n == "fire" or n == "receiver_barrel_muzzle" or n:find("flash") or n:find("muzzle") then
        if not n:find("aim") and not n:find("optic") and not n:find("sight") and not n:find("grip") then
            local p = inst.Parent
            if p and p:IsA("BasePart") then
                local cur = p
                local isThirdPerson = false
                while cur and cur ~= Workspace do
                    if cur:IsA("Model") and (cur.Name:find("soldier") or cur.Name:find("StarterCharacter")) then
                        isThirdPerson = true
                        break
                    end
                    cur = cur.Parent
                end
                if not isThirdPerson then
                    return true
                end
            end
        end
    end
    return false
end

function Utils.getLookMatrix(fromPos, toPos)
    local forwardDir = (toPos - fromPos)
    if forwardDir.Magnitude < 0.001 then
        return CFrame.new(fromPos)
    end
    local forwardUnit = forwardDir.Unit
    local vZ = -forwardUnit
    local vX = forwardUnit:Cross(Vector3.new(0, 1, 0))
    if vX.Magnitude < 0.001 then
        vX = forwardUnit:Cross(Vector3.new(1, 0, 0)).Unit
    else
        vX = vX.Unit
    end
    local vY = vZ:Cross(vX).Unit
    return CFrame.fromMatrix(fromPos, vX, vY, vZ)
end

function Utils.getBones(model)
    if not model then return {} end
    local cached = boneCache[model]
    if not cached then
        cached = {}
        for _, b in ipairs(model:GetDescendants()) do
            if b:IsA("Bone") then
                cached[b.Name] = b
            end
        end
        boneCache[model] = cached
    end
    return cached
end

function Utils.getSoldierActors()
    local actors = {}
    local pscripts = LocalPlayer:FindFirstChild("PlayerScripts")
    local fca = pscripts and pscripts:FindFirstChild("frontlines_client_actor")
    if fca then
        for _, child in ipairs(fca:GetChildren()) do
            if child:IsA("Actor") and child.Name == "soldier_actor" then
                table.insert(actors, child)
            end
        end
    end
    return actors
end

function Utils.getTeamMap()
    local modelTeam = {}
    for _, hb in ipairs(CollectionService:GetTagged("SOLDIER")) do
        local weld = hb:FindFirstChildOfClass("Weld")
        local model = weld and weld.Part0 and weld.Part0.Parent
        if model and model:IsA("Model") then
            if CollectionService:HasTag(hb, "ENEMY_SOLDIER") then
                modelTeam[model] = "ENEMY"
            elseif CollectionService:HasTag(hb, "FRIENDLY_SOLDIER") then
                modelTeam[model] = "FRIENDLY"
            end
        end
    end
    return modelTeam
end

function Utils.getEnemyGuis()
    local tsg = Workspace:FindFirstChild("tpv_sol_guis")
    if not tsg then return {} end
    local guis = {}
    for _, c in ipairs(tsg:GetChildren()) do
        if c.Name == "enemy_gui" then
            table.insert(guis, c)
        end
    end
    return guis
end

function Utils.getLiveHealth(cid, enemyGuis)
    if cid and enemyGuis and enemyGuis[cid] then
        local eg = enemyGuis[cid]
        local hf = eg:FindFirstChild("health_frame")
        local hb = hf and hf:FindFirstChild("health_bar")
        if hb and hb.Size then
            return math.clamp(hb.Size.X.Scale, 0, 1)
        end
    end
    return 1.0
end

function Utils.getHealthColor(pct)
    pct = math.clamp(pct or 1, 0, 1)
    local r = math.clamp(2 * (1 - pct), 0, 1)
    local g = math.clamp(2 * pct, 0, 1)
    return Color3.new(r, g, 0)
end

return Utils
