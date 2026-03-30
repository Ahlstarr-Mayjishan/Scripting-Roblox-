--[[
    Synapse.lua — Communication Signal System
    Analogy: The neural synapses connecting different regions of the brain.
    Allows decoupled cross-module communication (Events).
]]

local Synapse = {}
Synapse.__index = Synapse

local _events = {}

function Synapse.on(name, callback)
    if not _events[name] then _events[name] = {} end
    table.insert(_events[name], callback)
    
    return {
        Disconnect = function()
            for i, cb in ipairs(_events[name]) do
                if cb == callback then
                    table.remove(_events[name], i)
                    break
                end
            end
        end
    }
end

function Synapse.fire(name, ...)
    if not _events[name] then return end
    for _, callback in ipairs(_events[name]) do
        task.spawn(callback, ...)
    end
end

return Synapse
