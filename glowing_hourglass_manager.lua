local version = 2.0

-----------------------------------------------SETUP-----------------------------------------------

local OldCallbacks

if GHManager then
    OldCallbacks = GHManager.Callbacks
    if GHManager.Version >= version then
        return
    else
        print("Older version of Glowing Hourglass Manager detected")
        print("Removing Glowing Hourglass Manager v" .. GHManager.Version)
        GHManager.Utilities:RemoveAllCallbacks()
    end
end


print("Initializing Glowing Hourglass Manager v" .. version)

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

GHManager.PhantomRewindState = {
    Null = 0,
    New_Stage = 1,
    Warp = 2,
    Room_Clear = 3,
    Curse_Damage = 4
}

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

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Session, transactionCount + 1, GHManager.HourglassUpdate.New_Session, copyPhantomHealthState)

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

            Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
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

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Session, transactionCount + 1, GHManager.HourglassUpdate.New_Session)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

                Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
            else
                table.insert(glowingHourglassTransactions, game.TimeCounter)
                previousStageHourglassGameState = {
                    Time = game.TimeCounter,
                    Type = GHManager.HourglassStateType.Session_Start
                }
                local copyFromPhantom = false
                local copyPhantomHealthState = false

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Continued_Session, transactionCount + 1, GHManager.HourglassUpdate.Continued_Session)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR, copyPhantomHealthState)

                Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
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
            if previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null then
                glowingHourglassTransactions = {game.TimeCounter}
                transactionCount = 1
                local copyFromPhantom = false
                local copyPhantomHealthState = false

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Absolute_Stage, transactionCount, GHManager.HourglassUpdate.New_Absolute_Stage)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.StageTransition.ABSOLUTE, copyPhantomHealthState)

                Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
            else
                table.insert(glowingHourglassTransactions, game.TimeCounter)
                local copyPhantomHealthState = false

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_Stage, transactionCount + 1, GHManager.HourglassUpdate.New_Stage)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.TransitionType.STAGE, GHManager.Enums.StageTransition.REGULAR, copyPhantomHealthState)

                if currentPhantomRewindState > GHManager.PhantomRewindState.New_Stage then
                    local copyFromPhantom = true
                    Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
                end
                Isaac.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)
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
                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_State_Warped, transactionCount + 1, GHManager.HourglassUpdate.New_State_Warped, copyPhantomHealthState)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.WARP)

                if currentPhantomRewindState ~= GHManager.PhantomRewindState.Null then
                    local copyFromPhantom = true
                    Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)
                end
                Isaac.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

                currentPhantomRewindState = GHManager.PhantomRewindState.Warp
            else
                local copyFromPhantom = false

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.New_State, transactionCount + 1, GHManager.HourglassUpdate.New_State, copyPhantomHealthState)

                Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_TRANSITION, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.TransitionType.ROOM, GHManager.Enums.RoomTransition.REGULAR)

                Isaac.RunCallback(GHManager.Callbacks.ON_REWIND_STATE_UPDATE, copyFromPhantom, copyPhantomHealthState)

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
            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Failed_Stage_Return, 1, GHManager.HourglassUpdate.Failed_Stage_Return)

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.FAILED_STAGE_RETURN)

            Isaac.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        elseif previousStageHourglassGameState.Type == GHManager.HourglassStateType.Transition_To_Cleared_Room then
            glowingHourglassTransactions = {previousStageHourglassGameState.Time}

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Previous_Stage_Penultimate_Room, 1, GHManager.HourglassUpdate.Previous_Stage_Penultimate_Room)

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.STAGE, GHManager.Enums.RewindType.STAGE, GHManager.Enums.StageRewind.PENULTIMATE_ROOM)

            Isaac.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        else
            glowingHourglassTransactions = {previousStageHourglassGameState.Time}

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Previous_Stage_Last_Room, 1, GHManager.HourglassUpdate.Previous_Stage_Last_Room)

            Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.STAGE, GHManager.Enums.RewindType.STAGE, GHManager.Enums.StageRewind.LAST_ROOM)

            Isaac.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
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
        Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Rewind_Current_Room, transactionCount, GHManager.HourglassUpdate.Rewind_Current_Room)

        Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.CURRENT_ROOM)

        Isaac.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)
        return true
    end

    glowingHourglassTransactions = {game.TimeCounter}
    Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Rewind_Previous_Room, transactionCount, GHManager.HourglassUpdate.Rewind_Previous_Room, nil, wasPreviousFloorStateNull)

    Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_REWIND, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RewindType.ROOM, GHManager.Enums.RoomRewind.PREVIOUS_ROOM)

    Isaac.RunCallback(GHManager.Callbacks.ON_GAME_STATE_OVERWRITE)

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

    Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Save_Pre_Room_Clear_State, transactionCount)

    Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_SPECIAL_EVENT, GHManager.Enums.SpecialEvent.ROOM_CLEAR, GHManager.Enums.SpecialEvent.ROOM_CLEAR)

    Isaac.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

    currentPhantomRewindState = GHManager.PhantomRewindState.Room_Clear
end

local function HandleGlowingHourglassPlayerHealthState(_, _, _, DamageFlags)
    if DamageFlags & DamageFlag.DAMAGE_CURSED_DOOR ~= 0 and not hasCursedDoorDamageBeenTaken then
        local transactionCount = #glowingHourglassTransactions
        hasCursedDoorDamageBeenTaken = true

        Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Save_Pre_Curse_Damage_Health, transactionCount)

        Isaac.RunCallbackWithParam(GHManager.Callbacks.ON_SPECIAL_EVENT, GHManager.Enums.SpecialEvent.CURSE_DAMAGE, GHManager.Enums.SpecialEvent.CURSE_DAMAGE)

        Isaac.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

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

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, CallbackPriority.IMPORTANT, HandleGlowingHourglassTransactions)

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, CallbackPriority.IMPORTANT, HandleGlowingHourglassPreClearState)

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.IMPORTANT, HandleGlowingHourglassPlayerHealthState, EntityType.ENTITY_PLAYER)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, ResetPreviousFloorStateToNull, CollectibleType.COLLECTIBLE_R_KEY)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, SetPreviousFloorStateToForget, CollectibleType.COLLECTIBLE_FORGET_ME_NOW)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, ResetHourglassStateOnExit)