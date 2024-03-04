local version = 2.1

-----------------------------------------------SETUP-----------------------------------------------

local OldCallbacks

if GHManager then
    OldCallbacks = GHManager.Callbacks
    if GHManager.Version >= version then
        return
    else
        Isaac.DebugString("Older version of Glowing Hourglass Manager detected")
        Isaac.DebugString("Removing Glowing Hourglass Manager v" .. GHManager.Version)
        GHManager.Utilities:RemoveAllCallbacks()
    end
end

Isaac.DebugString("Initializing Glowing Hourglass Manager v" .. version)

local log = {}

function log.print(Message)
    print(Message)
    Isaac.DebugString(Message)
end

GHManager = {
    Mod = RegisterMod("GlowingHourglassManager", 1),
    Version = version,
    Utilities = {},
    Callbacks = OldCallbacks or {}
}

local addedModCallbacks = {}

function GHManager.Mod:AddCallback(modCallback, callbackFunction, callbackArguments)
    Isaac.AddCallback(GHManager.Mod, modCallback, callbackFunction, callbackArguments)
    table.insert(addedModCallbacks, {
        Callback = modCallback,
        Function = callbackFunction,
    })
end

function GHManager.Mod:AddPriorityCallback(modCallback, callbackPriority, callbackFunction, callbackArguments)
    Isaac.AddPriorityCallback(GHManager.Mod, modCallback, callbackPriority, callbackFunction, callbackArguments)
    table.insert(addedModCallbacks, {
        Callback = modCallback,
        Function = callbackFunction,
    })
end

function GHManager.Utilities:RemoveAllCallbacks()
    for _, callbackData in pairs(addedModCallbacks) do
        Isaac.RemoveCallback(GHManager.Mod, callbackData.Callback, callbackData.Function)
    end
end

-----------------------------------------------ENUMS-----------------------------------------------

GHManager.Callbacks.ON_GENERIC_UPDATE = GHManager.Callbacks.ON_GLOWING_HOURGLASS_GAME_STATE_UPDATE or {}

GHManager.Callbacks.ON_TRANSITION = GHManager.Callbacks.ON_ROOM_TRANSITION or {}
GHManager.Callbacks.ON_REWIND = GHManager.Callbacks.ON_REWIND or {}
GHManager.Callbacks.ON_SPECIAL_EVENT = GHManager.Callbacks.ON_SPECIAL_EVENT or {}

GHManager.Callbacks.ON_REWIND_STATE_UPDATE = GHManager.Callbacks.ON_REWIND_STATE_UPDATE or {}
GHManager.Callbacks.ON_GAME_STATE_OVERWRITE = GHManager.Callbacks.ON_GAME_STATE_OVERWRITE or {}
GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE = GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE or {}

GHManager.HourglassUpdate = {
    New_State = 1,
    New_State_Warped = 2,
    Rewind_Previous_Room = 3,
    Rewind_Current_Room = 4,
    New_Session = 5,
    Continued_Session = 6,
    New_Stage = 7,
    New_Absolute_Stage = 8,
    Previous_Stage_Last_Room = 9,
    Previous_Stage_Penultimate_Room = 10,
    Failed_Stage_Return = 11,
    Save_Pre_Room_Clear_State = 12,
    Save_Pre_Curse_Damage_Health = 13
}

GHManager.Enums.HourglassUpdate = GHManager.HourglassUpdate

GHManager.Enums.TransitionType = {
    ROOM = 1,
    STAGE = 2
}

GHManager.Enums.RoomTransition = {
    REGULAR = 1,
    WARP = 2
}

GHManager.Enums.StageTransition = {
    REGULAR = 1,
    ABSOLUTE = 2
}

GHManager.Enums.RewindType = {
    ROOM = 1,
    STAGE = 2
}

GHManager.Enums.RoomRewind = {
    PREVIOUS_ROOM = 1,
    CURRENT_ROOM = 2,
    FAILED_STAGE_RETURN = 3
}

GHManager.Enums.StageRewind = {
    LAST_ROOM = 1,
    PENULTIMATE_ROOM = 2
}

GHManager.Enums.SpecialEvent = {
    ROOM_CLEAR = 1,
    CURSE_DAMAGE = 2
}

GHManager.HourglassStateType = { -- Internal Use Only
    State_Null = 0,
    Transition_To_Cleared_Room = 1,
    Transition_To_Uncleared_Room = 2,
    Cleared_Room = 3,
    Forget_Me_Now = 4,
    Session_Start = 5
}

GHManager.PhantomRewindState = { -- Internal Use Only
    Null = 0,
    New_Stage = 1,
    Warp = 2,
    Room_Clear = 3,
    Curse_Damage = 4
}

GHManager.CallbackPriority = {
    MAX = -1/0,
    MIN = 1/0,
    AFTER_MAX = -2^1023 * 1.999999999999999,
    BEFORE_MIN = 2^1023 * 1.999999999999999,
    IMPORTANT = -200,
    EARLY = -100,
    DEFAULT = 0,
    LATE = 100
}

---------------------------------------AFTERBIRTH + CALLBACK---------------------------------------

local CallbackIdToString = {
    [GHManager.Callbacks.ON_GENERIC_UPDATE] = "ON_GENERIC_UPDATE",
    [GHManager.Callbacks.ON_TRANSITION] = "ON_TRANSITION",
    [GHManager.Callbacks.ON_REWIND] = "ON_REWIND",
    [GHManager.Callbacks.ON_SPECIAL_EVENT] = "ON_SPECIAL_EVENT",
    [GHManager.Callbacks.ON_REWIND_STATE_UPDATE] = "ON_REWIND_STATE_UPDATE",
    [GHManager.Callbacks.ON_GAME_STATE_OVERWRITE] = "ON_GAME_STATE_OVERWRITE",
    [GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE] = "ON_PHANTOM_REWIND_STATE_UPDATE"
}

local Callbacks = {}

local function Reverse_Iterator(t,i)
    i=i-1
    local v=t[i]
    if v==nil then return v end
    return i,v
end

local function ReverseIterate(t)
    return Reverse_Iterator, t, #t+1
end

local function AddCallback(modReference, callbackId, priority, fn, ...)
    if not Callbacks[callbackId] then
        Callbacks[callbackId] = {}
    end

    local index = 1

    for i, callback in ReverseIterate(Callbacks[callbackId]) do
        if priority >= callback.Priority then
            index = i + 1
            break
        end
    end

    table.insert(Callbacks[callbackId], index, {
        Priority = priority,
        Function = fn,
        Mod = modReference,
        Params = {...},
        CallbackID = callbackId,
    }) -- Vanilla's GetCallback function returns a table containing only Mod, Priority and Function, however the others are still kept for convenience
end

local function RemoveCallback(modReference, callbackId, fn)
    for i, callback in ReverseIterate(Callbacks[callbackId]) do
        if callback.Mod == modReference and callback.Function == fn then
            table.remove(callback, i)
        end
    end
end

local function MatchesParams(callback, params)
    local matches = true
    for i, param in ipairs(params) do
        if callback.Params[i] then
            matches = matches and param == callback.Params[i]
        end
    end
    return matches
end

local function TryCallback(callback, ...)
    local success, ret = pcall(callback.Function, ...)
    if success then
        return true, ret
    else
        log.print("[Glowing Hourglass Manager Error in Callback " .. CallbackIdToString[callback.CallbackID] .. "]: " .. ret)
        return false
    end
end

local function RunCallbacks(callbackId, breakOnFirstReturn, ...)
    for _, callback in ipairs(GHManager.GetCallbacks(callbackId)) do
        TryCallback(callback, ...)
    end
end

local function RunCallbacksWithParam(callbackId, matchParams, ...)
    if type(matchParams) ~= "table" then
        matchParams = {matchParams}
    end

    local callbacks = GHManager.GetCallbacks(callbackId)
    for _, callback in ipairs(callbacks) do
        if MatchesParams(callback, matchParams) then
            TryCallback(callback, ...)
        end
    end
end

-------------------------------------CUSTOM CALLBACK FUNCTIONS-------------------------------------

if REPENTANCE then
    function GHManager.AddCallback(modReference, callbackId, callbackFunction, additionalParam)
        Isaac.AddCallback(modReference, callbackId, callbackFunction, additionalParam)
    end

    function GHManager.AddPriorityCallback(modReference, callbackId, priority, callbackFunction, additionalParam)
        Isaac.AddPriorityCallback(modReference, callbackId, priority, callbackFunction, additionalParam)
    end

    function GHManager.RemoveCallback(modReference, callbackId, callbackFunction)
        Isaac.RemoveCallback(modReference, callbackId, callbackFunction)
    end

    function GHManager.GetCallbacks(callbackId)
        if CallbackIdToString[callbackId] then
            return Isaac.GetCallbacks(callbackId) or {}
        else
            return {}
        end
    end

    function GHManager.RunCallback(callbackId, ...)
        GHManager.RunCallback(callbackId, ...)
    end

    function GHManager.RunCallbackWithParam(callbackId, param, ...)
        GHManager.RunCallbackWithParam(callbackId, param, ...)
    end

    function GHManager.UnregisterCallbacks(modReference)
        for _, callbackId in pairs(GHManager.Callbacks) do
            for i, callback in ReverseIterate(GHManager.GetCallbacks(callbackId)) do
                if callback.Mod == modReference then
                    Isaac.RemoveCallback(modReference, callbackId, callback.Function)
                end
            end
        end
    end
else
    function GHManager.AddCallback(modReference, callbackId, callbackFunction, additionalParam)
        AddCallback(modReference, callbackId, GHManager.Enums.CallbackPriority.DEFAULT, callbackFunction, additionalParam)
    end

    function GHManager.AddPriorityCallback(modReference, callbackId, priority, callbackFunction, additionalParam)
        AddCallback(modReference, callbackId, priority, callbackFunction, additionalParam)
    end

    function GHManager.RemoveCallback(modReference, callbackId, callbackFunction)
        RemoveCallback(modReference, callbackId, callbackFunction)
    end

    function GHManager.GetCallbacks(callbackId)
        return Callbacks[callbackId] or {}
    end

    function GHManager.RunCallback(callbackId, ...)
        RunCallbacks(callbackId, ...)
    end

    function GHManager.RunCallbackWithParam(callbackId, param, ...)
        RunCallbacksWithParam(callbackId, param, ...)
    end

    function GHManager.UnregisterCallbacks(modReference)
        for callbackId, callbacks in pairs(Callbacks) do
            for i, callback in ReverseIterate(callbacks) do
                if callback.Mod == modReference then
                    table.remove(callbacks, i)
                end
            end
        end
    end
end

---------------------------------------------VARIABLES---------------------------------------------

local game = Game()

local hasCursedDoorDamageBeenTaken = false
local wasNewStage = false
local wasPreviousFloorStateNull = false

local glowingHourglassTransactions = {}
local previousStageHourglassGameState = {
    Time = 0,
    Type = GHManager.HourglassStateType.State_Null
}
local currentPhantomRewindState = GHManager.PhantomRewindState.Null

---------------------------------------------SAVE DATA---------------------------------------------

-- This section should be customized to fit the needs of your specific mod,
-- alongside the MC_PRE_GAME_EXIT callback function
-- Save Data is only need if your mod doesn't use REPENTOGON or if you wish to have
-- compatibility with vanilla

local ModReference = GHManager.Mod -- Replace this with your own Mod Reference
local json = require("json")

local defaultManagerData = {
    RewindStateType = GHManager.HourglassStateType.Session_Start
}

function GHManager:SaveManagerData(SaveDataTable)
    SaveDataTable.GHManagerData = {}
    SaveDataTable.GHManagerData.RewindStateType = previousStageHourglassGameState.Type
end

local function LoadGHManagerData(IsContinued)
    local GHManagerData = {}
    if IsContinued and ModReference:HasData() then
        local loadedData = json.decode(ModReference:LoadData())
        GHManagerData = loadedData["GHManagerData"] or defaultManagerData
    else
        GHManagerData = defaultManagerData
    end
    previousStageHourglassGameState.Type = GHManagerData.RewindStateType
end

--[[

local function ExampleSaveDataFunction()
    local SaveData = DataToSave
    GHManager:SavaManagerData(SaveData)
    ModReference:SaveData(json.encode(SaveData))
end

ModReference:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, ExampleSaveDataFunction)

]]

---------------------------------------------UTILITIES---------------------------------------------

if REPENTOGON then
    GHManager.Utilities.CanStartTrueCoop = function()
        return Isaac.CanStartTrueCoop()
    end
else
    GHManager.Utilities.CanStartTrueCoop = function()
        return previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null
    end
end

GHManager.Utilities.CanRewindToHome = function()
    return GHManager.Utilities.CanStartTrueCoop() and game:GetLevel():GetStage() == LevelStage.STAGE1_1
    -- The game only cares that LevelStage is 1, and that the CanStartTrueCoop flag is true, so even if you
    -- obtain a Forget Me Now in the first stage or go to Downpour/Dross I and, somehow keep the
    -- CanStartTrueCoop flag set to true, you will be taken to Home when you use Glowing Hourglass
    -- (R key also resets the CanStartTrueCoop flag to true)
end

---------------------------------------------------------------------------------------------------
-----------------------------------------------MAIN------------------------------------------------
---------------------------------------------------------------------------------------------------

local function HandleNewSessions(transactionCount, isNewStage)
    -- MC_POST_GAME_STARTED is not needed for New Sessions since we can figure out if the run IsContinued by checking if
    -- transactionCount <= 0 and isNewStage for a New Run and transactionCount <= 0 and not isNewStage for Continued Runs
    if transactionCount <= 0 then
        if isNewStage then
            table.insert(glowingHourglassTransactions, game.TimeCounter)
            previousStageHourglassGameState = {
                Time = game.TimeCounter,
                Type = GHManager.HourglassStateType.State_Null
            }
            local copyFromPhantom = false
            local copyPhantomHealthState = false

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Session, transactionCount + 1, GHManager.HourglassUpdate.New_Session, copyPhantomHealthState)

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

            GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
        else
            if not REPENTOGON then
                LoadGHManagerData(true)
            end
            if GHManager.Utilities.CanStartTrueCoop() then
                table.insert(glowingHourglassTransactions, game.TimeCounter)
                previousStageHourglassGameState = {
                    Time = game.TimeCounter,
                    Type = GHManager.HourglassStateType.State_Null
                }
                local copyFromPhantom = false
                local copyPhantomHealthState = false

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Session, transactionCount + 1, GHManager.HourglassUpdate.New_Session)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

                GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
            else
                table.insert(glowingHourglassTransactions, game.TimeCounter)
                previousStageHourglassGameState = {
                    Time = game.TimeCounter,
                    Type = GHManager.HourglassStateType.Session_Start
                }
                local copyFromPhantom = false
                local copyPhantomHealthState = false

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Continued_Session, transactionCount + 1, GHManager.HourglassUpdate.Continued_Session)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

                GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
            end
        end
        currentPhantomRewindState = GHManager.PhantomRewindState.Null
        wasNewStage = false
        return true
    end
    return false
end

local function HandleTransitions(transactionCount, level, isNewStage)
    if game.TimeCounter > glowingHourglassTransactions[transactionCount] then
        if isNewStage then
            if not REPENTANCE or previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null then
                glowingHourglassTransactions = {game.TimeCounter}
                previousStageHourglassGameState.Type = GHManager.HourglassStateType.State_Null
                transactionCount = 1
                local copyFromPhantom = false
                local copyPhantomHealthState = false

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Absolute_Stage, transactionCount, GHManager.HourglassUpdate.New_Absolute_Stage)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.StageTransition.ABSOLUTE, copyPhantomHealthState)

                GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
            else
                table.insert(glowingHourglassTransactions, game.TimeCounter)
                local copyPhantomHealthState = false

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Stage, transactionCount + 1, GHManager.HourglassUpdate.New_Stage)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.StageTransition.REGULAR, copyPhantomHealthState)

                if currentPhantomRewindState > GHManager.PhantomRewindState.New_Stage then
                    local copyFromPhantom = true
                    GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
                end
                GHManager.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)
            end
            currentPhantomRewindState = GHManager.PhantomRewindState.New_Stage
            wasNewStage = true
        else
            wasPreviousFloorStateNull = previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null
            if transactionCount >= 2 then
                glowingHourglassTransactions = {glowingHourglassTransactions[transactionCount]}
                transactionCount = 1
            end
            table.insert(glowingHourglassTransactions, game.TimeCounter)

            if not game:GetRoom():IsClear() or game:GetRoom():IsFirstVisit() then
                previousStageHourglassGameState = {
                    Time = game.TimeCounter,
                    Type = GHManager.HourglassStateType.Transition_To_Uncleared_Room
                }
                -- If you go to an uncleared room right before leaving, the state is saved
                -- and in the case that you revert to the previous Floor you will end up
                -- in the uncleared room when returning
            else
                previousStageHourglassGameState = {
                    Time = game.TimeCounter,
                    Type = GHManager.HourglassStateType.Transition_To_Cleared_Room
                }
                -- If you go trough a cleared right before leaving, the state is saved to
                -- the moment you made the Room Transition but if you return to the previous
                -- floor you will be sent to the previous room relative to when you left
                -- this is regardless of if the previous room is Cleared or Not, so for
                -- example: you created a Trap Door in the starting room -> you go fight
                -- the Boss, but instead of killing it you escape using the Fool -> you
                -- exit the Stage. if you use Glowing Hourglass right after, you will
                -- be taken to the Boss Fight of the previous floor.
            end
            local copyPhantomHealthState = not (hasCursedDoorDamageBeenTaken and (game:GetRoom():GetType() == RoomType.ROOM_CURSE or level:GetRoomByIdx(level:GetPreviousRoomIndex()).Data.Type == RoomType.ROOM_CURSE))
            if level.LeaveDoor == -1 then
                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_State_Warped, transactionCount + 1, GHManager.HourglassUpdate.New_State_Warped, copyPhantomHealthState)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.WARP)

                if currentPhantomRewindState ~= GHManager.PhantomRewindState.Null then
                    local copyFromPhantom = true
                    GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
                end
                GHManager.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

                currentPhantomRewindState = GHManager.PhantomRewindState.Warp
            else
                local copyFromPhantom = false

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_State, transactionCount + 1, GHManager.HourglassUpdate.New_State, copyPhantomHealthState)

                GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR)

                GHManager.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)

                currentPhantomRewindState = GHManager.PhantomRewindState.Null
            end
            -- Technically to detect a Warp you need to check for level.LeaveDoor == -1 and level.EnterDoor ~= -1
            -- but that extra is needed to account for Stage Transitions, and since we already account for them there
            -- is no need
            wasNewStage = false
        end
        return true
    end
    return false
end

local function HandleRewinds(transactionCount)
    if wasNewStage then
        if previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null then
            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Failed_Stage_Return, 1, GHManager.HourglassUpdate.Failed_Stage_Return)

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.FAILED_STAGE_RETURN)

            GHManager.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        elseif previousStageHourglassGameState.Type == GHManager.HourglassStateType.Transition_To_Cleared_Room then
            glowingHourglassTransactions = {previousStageHourglassGameState.Time}

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Previous_Stage_Penultimate_Room, 1, GHManager.HourglassUpdate.Previous_Stage_Penultimate_Room)

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.STAGE, GHManager.Enums.RewindType.STAGE, GHManager.Enums.StageRewind.PENULTIMATE_ROOM)

            GHManager.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        else
            glowingHourglassTransactions = {previousStageHourglassGameState.Time}

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Previous_Stage_Last_Room, 1, GHManager.HourglassUpdate.Previous_Stage_Last_Room)

            GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.STAGE, GHManager.Enums.RewindType.STAGE, GHManager.Enums.StageRewind.LAST_ROOM)

            GHManager.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        end
        currentPhantomRewindState = GHManager.PhantomRewindState.Null
        wasNewStage = false
        return true
    end
    -- In the unlikely situation that you can go trough multiple floors without ever leaving their
    -- respective starting room you will be transported back to the last "previous Floor State"
    -- even if it was at Basement 1 and you are currently at Sheol

    wasNewStage = false
    currentPhantomRewindState = GHManager.PhantomRewindState.Null
    if wasPreviousFloorStateNull then
        previousStageHourglassGameState.Type = GHManager.HourglassStateType.State_Null
    end

    if transactionCount == 1 then
        GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Rewind_Current_Room, transactionCount, GHManager.HourglassUpdate.Rewind_Current_Room)

        GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.CURRENT_ROOM)

        GHManager.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        return true
    end

    glowingHourglassTransactions = {game.TimeCounter}
    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Rewind_Previous_Room, transactionCount, GHManager.HourglassUpdate.Rewind_Previous_Room, nil, wasPreviousFloorStateNull)

    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.PREVIOUS_ROOM)

    GHManager.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)

    return true
end

local function HandleGlowingHourglassTransactions()
    local level = game:GetLevel()
    hasCursedDoorDamageBeenTaken = false
    local isNewStage = not (level:GetStateFlag(LevelStateFlag.STATE_LEVEL_START_TRIGGERED))
    local transactionCount = #glowingHourglassTransactions

    if HandleNewSessions(transactionCount, isNewStage) then
        return
    end

    if HandleTransitions(transactionCount, level, isNewStage) then
        return
    end

    if HandleRewinds(transactionCount) then
        return
    end
end

local function HandleGlowingHourglassPreClearState()
    previousStageHourglassGameState = {
        Time = game.TimeCounter,
        Type = GHManager.HourglassStateType.Cleared_Room
    }
    local transactionCount = #glowingHourglassTransactions

    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Save_Pre_Room_Clear_State, transactionCount)

    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_SPECIAL_EVENT, GHManager.Enums.SpecialEvent.ROOM_CLEAR, GHManager.Enums.SpecialEvent.ROOM_CLEAR)

    GHManager.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

    currentPhantomRewindState = GHManager.PhantomRewindState.Room_Clear
end

local function HandleGlowingHourglassPlayerHealthState(_, _, _, DamageFlags)
    if DamageFlags & DamageFlag.DAMAGE_CURSED_DOOR ~= 0 and not hasCursedDoorDamageBeenTaken then
        local transactionCount = #glowingHourglassTransactions
        hasCursedDoorDamageBeenTaken = true

        GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Save_Pre_Curse_Damage_Health, transactionCount)

        GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_SPECIAL_EVENT, GHManager.Enums.SpecialEvent.CURSE_DAMAGE, GHManager.Enums.SpecialEvent.CURSE_DAMAGE)

        GHManager.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

        currentPhantomRewindState = GHManager.PhantomRewindState.Curse_Damage
    end
end

local function ResetPreviousFloorStateToNull()
    previousStageHourglassGameState = {
        Time = game.TimeCounter,
        Type = GHManager.HourglassStateType.State_Null
    }
    currentPhantomRewindState = GHManager.PhantomRewindState.Null
end

local function SetPreviousFloorStateToForget()
    if previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null then
        return
    end
    previousStageHourglassGameState.Type = GHManager.HourglassStateType.Forget_Me_Now
    -- The game doesn't save the state when using forget me now, but instead it causes
    -- the previous floor rewind to become of Last_Room type, even when it would otherwise
    -- be of Penultimate_Room type, Unless it the Stage Return Fails.
end

local function ResetHourglassStateOnExit()
    hasCursedDoorDamageBeenTaken = false
    wasNewStage = false
    glowingHourglassTransactions = {}
end

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassTransactions)

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassPreClearState)

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassPlayerHealthState, EntityType.ENTITY_PLAYER)

if REPENTANCE then
    GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, ResetPreviousFloorStateToNull, CollectibleType.COLLECTIBLE_R_KEY)
end

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, SetPreviousFloorStateToForget, CollectibleType.COLLECTIBLE_FORGET_ME_NOW)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, ResetHourglassStateOnExit)