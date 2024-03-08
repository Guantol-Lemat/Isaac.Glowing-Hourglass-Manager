local mod = RegisterMod("Manager Test", 1)
local json = require("json")

--[[
local myFolder = "library_of_isaac"
local LOCAL_TSIL = require(myFolder .. ".TSIL")
LOCAL_TSIL.Init(myFolder)
]]

require("glowing_hourglass_manager")
DebugMessenger = require("debug_messenger")

local function SaveData()
    local saveTable = {}
    saveTable.MyData = {GameTime = Game().TimeCounter, }
    GHManager.SaveManagerData(saveTable)
    mod:SaveData(json.encode(saveTable))
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, SaveData)

mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, SaveData)

local function DebugGameState()
    DebugMessenger.AddLine("Game State Overwritten")
end

local function DebugRewindState(_, copyFromPhantom, copyPhantomHealthState)
    if copyFromPhantom then
        DebugMessenger.AddLine("Rewind State Updated - (Copy Phantom)")
        return
    end
    if copyPhantomHealthState then
        DebugMessenger.AddLine("Rewind State Updated - (Copy Game State [Copy Phantom Health])")
        return
    end
    DebugMessenger.AddLine("Rewind State Update - (Copy Game State)")
end

local function DebugPhantomRewindState()
    DebugMessenger.AddLine("Phantom Rewind State Updated")
end

GHManager.AddCallback(mod, GHManager.Callbacks.ON_GAME_STATE_OVERWRITE, DebugGameState)

GHManager.AddCallback(mod, GHManager.Callbacks.ON_REWIND_STATE_UPDATE, DebugRewindState)

GHManager.AddCallback(mod, GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE, DebugPhantomRewindState)