-- Script Path: game:GetService("ReplicatedStorage").SharedModules.Core.Index.UpgradeIndex.DefuseKit
-- Took 0.39s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
return {
    Name = "Defuse Kit",
    Description = "<font color=\"#00FF0D\">+20%</font> Chance for <font color=\"#BB00FF\">Tripmines</font> to not explode. (Max 60%)",
    LongDescription = "I\'m the long description, allow me to tell you the fabled tales of this upgrade..",
    Icon = "rbxassetid://104218601740188",
    MaxStack = 3,
    Price = 30,
    Prerequisites = {
        Difficulty = 2,
        PlayerCount = 0,
        Stage = 4,
        Enemies = {},
        Upgrades = {},
        Curses = {}
    }
}

-- Script Path: game:GetService("ReplicatedStorage").SharedModules.Core.Index.UpgradeIndex
-- Took 0.35s to decompile.
-- Executor: Potassium (v2.2.4)

-- https://lua.expert/
local t = {}
local t2 = {}

t.Items = {}
function t.GetSortedKeys() --[[ GetSortedKeys | Line: 42 | Upvalues: t2 (copy) ]]
    return t2
end
function Initialize() --[[ Initialize | Line: 50 | Upvalues: t (copy), t2 (copy) ]]
    for k, v in pairs(script:GetChildren()) do
        if v:IsA("ModuleScript") and v.Name ~= "Template" then
            local v1 = require(v)

            t.Items[v.Name] = v1
            table.insert(t2, {
                Name = v.Name,
                MinimumStage = v1.Prerequisites.Stage
            })
        end
    end

    table.sort(t2, function(p1, p2) --[[ Line: 64 ]]
        return p1.MinimumStage < p2.MinimumStage
    end)
end
task.spawn(Initialize)

return t

rbxassetid://118717483906381 - tripmine  defuse sound Index