local version = 2.1

-----------------------------------------------SETUP-----------------------------------------------

local OldCallbacks
local OldCustomCallbacks

if GHManager then
    OldCallbacks = GHManager.Callbacks
    OldCustomCallbacks = GHManager.CustomCallbacks
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

function log.file(Message)
    Isaac.DebugString(Message)
end

GHManager = {
    Mod = RegisterMod("Glowing Hourglass Manager", 1),
    Version = version,
    Utilities = {},
    Callbacks = OldCallbacks or {},
    CustomCallbacks = OldCustomCallbacks or {}
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

function GHManager.Utilities:RemoveAllCallbacks() -- Internal Use Only
    for _, callbackData in pairs(addedModCallbacks) do
        if callbackData.Custom then
            GHManager.RemoveCallback(GHManager.Mod, callbackData.Callback, callbackData.Function)
            goto continue
        end
        Isaac.RemoveCallback(GHManager.Mod, callbackData.Callback, callbackData.Function)
        ::continue::
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

GHManager.CustomCallbacks.POST_CLEAN_AWARD = GHManager.CustomCallbacks.POST_CLEAN_AWARD or {}
GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY = GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY or {}

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

GHManager.Enums = {}

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
        Isaac.RunCallback(callbackId, ...)
    end

    function GHManager.RunCallbackWithParam(callbackId, param, ...)
        Isaac.RunCallbackWithParam(callbackId, param, ...)
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

---------------------------------------------------------------------------------------------------
---------------------------------------ADDITIONAL CALLBACKS----------------------------------------
---------------------------------------------------------------------------------------------------

-----------------------------------------POST CLEAN AWARD------------------------------------------

local PostClearRoomAwardCallbacks = {
    ModCallbacks.MC_INPUT_ACTION,
    ModCallbacks.MC_POST_UPDATE
}

if REPENTOGON then
    table.insert(PostClearRoomAwardCallbacks, ModCallbacks.MC_POST_HUD_UPDATE)
    table.insert(PostClearRoomAwardCallbacks, ModCallbacks.MC_PLAYER_GET_HEALTH_TYPE)
end

local preClearReward = false

local function SetPreClearAward()
    preClearReward = true
end

local function FirePostCleanAward()
    if preClearReward then
        preClearReward = false
        GHManager.RunCallback(GHManager.CustomCallbacks.POST_CLEAN_AWARD)
    end
end

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, GHManager.CallbackPriority.AFTER_MAX, SetPreClearAward)

for _, callbackId in ipairs(PostClearRoomAwardCallbacks) do
    GHManager.Mod:AddPriorityCallback(callbackId, GHManager.CallbackPriority.AFTER_MAX, FirePostCleanAward)
end

----------------------------------------POST NEW ROOM EARLY----------------------------------------

local function GetEntities(entityType, variant, subType, ignoreFriendly)
	entityType = entityType or -1
	variant = variant or -1
	subType = subType or -1

	if ignoreFriendly == nil then
		ignoreFriendly = false
	end

	if entityType == -1 then
		return Isaac.GetRoomEntities()
	end

	return Isaac.FindByType(entityType, variant, subType, ignoreFriendly)
end

local function GetEntityPositions(entities)
    if entities == nil then
        entities = GetEntities()
    end

    local entityPositions = {}

    for _, entity in pairs(entities) do
		local ptr = EntityPtr(entity)
        entityPositions[ptr] = entity.Position
	end

    return entityPositions
end

local function GetEntityVelocities(entities)
    if entities == nil then
        entities = GetEntities()
    end

    local entityVelocities = {}

    for _, entity in pairs(entities) do
		local ptr = EntityPtr(entity)
        entityVelocities[ptr] = entity.Velocity
	end

    return entityVelocities
end

local function SetEntityPositions(positions, entities)
    if entities == nil then
        entities = GetEntities()
    end

    for _, entity in pairs(entities) do
        local ptr = EntityPtr(entity)
        local position = positions[ptr]

        if position then
            entity.Position = position
        end
    end
end

local function SetEntityVelocities(velocities, entities)
    if entities == nil then
        entities = GetEntities()
    end

    for _, entity in pairs(entities) do
        local ptr = EntityPtr(entity)
        local velocity = velocities[ptr]

        if velocity then
            entity.Velocity = velocity
        end
    end
end

local function UpdateRoom()
    local room = Game():GetRoom()
    local entities = GetEntities()

    local positions = GetEntityPositions(entities)
    local velocities = GetEntityVelocities(entities)

    room:Update()

    SetEntityPositions(positions, entities)
    SetEntityVelocities(velocities, entities)
end

local function RemoveGridEntity(gridEntityOrGridIndex, updateRoom)
    local room = Game():GetRoom()

    local gridEntity

    if type(gridEntityOrGridIndex) == "number" then
        gridEntity = room:GetGridEntity(gridEntityOrGridIndex)

        if not gridEntity then
            error("Couldn't find a grid entity at the given grid index: " .. gridEntityOrGridIndex)
        end
    else
        gridEntity = gridEntityOrGridIndex
    end

    room:RemoveGridEntity(gridEntity:GetGridIndex(), 0, false)

    if updateRoom then
        UpdateRoom()
    end
end

local function SpawnGridEntity(gridEntityType, gridEntityVariant, gridIndexOrPosition, force)
    if force == nil then
        force = true
    end

    local room = Game():GetRoom()
    local position = gridIndexOrPosition

    if type(gridIndexOrPosition) == "number" then
        position = room:GetGridPosition(gridIndexOrPosition)
    end

    local existingGridEntity = room:GetGridEntityFromPos(position)

    if existingGridEntity then
        if not force then
            return
        else
            RemoveGridEntity(existingGridEntity, true)
        end
    end

    local gridEntity = Isaac.GridSpawn(gridEntityType, gridEntityVariant, position, true)

    if not gridEntity then
        return
    end

    if gridEntityType == GridEntityType.GRID_PIT then
        local pit = gridEntity:ToPit()

        if pit then
            pit:UpdateCollision()
        end
    elseif gridEntityType == GridEntityType.GRID_WALL then
        gridEntity.CollisionClass = GridCollisionClass.COLLISION_WALL
    end

    return gridEntity
end

local GridInRoomShape = {
	[RoomShape.ROOMSHAPE_IH] = function (gridIndex)
		return gridIndex >= 30 and gridIndex <= 104
	end,

	[RoomShape.ROOMSHAPE_IV] = function (gridIndex)
		return gridIndex % 15 >= 4 and gridIndex % 15 <= 11
	end,

	[RoomShape.ROOMSHAPE_IIH] = function (gridIndex)
		return gridIndex >= 56 and gridIndex <= 195
	end,

	[RoomShape.ROOMSHAPE_IIV] = function (gridIndex)
		return gridIndex % 15 >= 4 and gridIndex % 15 <= 11
	end,

	[RoomShape.ROOMSHAPE_LTL] = function (gridIndex)
		if gridIndex < 224 then
			return gridIndex % 28 >= 13
		else
			return true
		end
	end,

	[RoomShape.ROOMSHAPE_LTR] = function (gridIndex)
		if gridIndex < 224 then
			return gridIndex % 28 <= 14
		else
			return true
		end
	end,

	[RoomShape.ROOMSHAPE_LBL] = function (gridIndex)
		if gridIndex > 251 then
			return gridIndex % 27 >= 13
		else
			return true
		end
	end,

	[RoomShape.ROOMSHAPE_LBR] = function (gridIndex)
		if gridIndex > 251 then
			return gridIndex % 27 <= 14
		else
			return true
		end
	end
}

local function IsGridIndexInRoomShape(gridIndex, roomShape)
	local IsInRoom = GridInRoomShape[roomShape]

	return not IsInRoom or IsInRoom(gridIndex)
end

local function GetTopLeftWallGridIndex()
	local room = Game():GetRoom()
	local gridSize = room:GetGridSize()
	local roomShape = room:GetRoomShape()

	for i = 0, gridSize, 1 do
		if IsGridIndexInRoomShape(i, roomShape) then
			return i
		end
	end

	return 0
end

local currentRoomTopLeftWallPtrHash = nil
local currentRoomTopLeftWallPtrHash2 = nil

local function IsNewRoom()
    local room = Game():GetRoom()
    local topLeftWallGridIndex = GetTopLeftWallGridIndex()
    local rightOfTopWallGridIndex = topLeftWallGridIndex + 1

    local topLeftWall = room:GetGridEntity(topLeftWallGridIndex)
    local topLeftWall2 = room:GetGridEntity(rightOfTopWallGridIndex)

    if topLeftWall == nil then
        print("nil top Wall")
        topLeftWall = SpawnGridEntity(GridEntityType.GRID_WALL, 0, topLeftWallGridIndex)
        if topLeftWall == nil then
            log.file("Failed to spawn a new wall (1) for the POST_NEW_ROOM_EARLY callback.")
            return false
        end
    end

    if topLeftWall2 == nil then
        print("nil top Wall2")
        topLeftWall2 = SpawnGridEntity(GridEntityType.GRID_WALL, 0, rightOfTopWallGridIndex)

        if topLeftWall2 == nil then
            log.file("Failed to spawn a new wall (2) for the POST_NEW_ROOM_EARLY callback.")
            return false
        end
    end

    local oldTopLeftWallPtrHash = currentRoomTopLeftWallPtrHash
    local oldTopLeftWallPtrHash2 = currentRoomTopLeftWallPtrHash2
    currentRoomTopLeftWallPtrHash = GetPtrHash(topLeftWall)
    currentRoomTopLeftWallPtrHash2 = GetPtrHash(topLeftWall2)

    return oldTopLeftWallPtrHash ~= currentRoomTopLeftWallPtrHash or
        oldTopLeftWallPtrHash2 ~= currentRoomTopLeftWallPtrHash2
end


local function CheckRoomChanged(isFromNewRoomCallback)
    local level = Game():GetLevel()
    local stage = level:GetStage()
    local frameCount = Game():GetFrameCount()

    --Fixes StageAPI crash
    if stage == 0 and frameCount == 0 then
        return
    end

    if IsNewRoom() then
        GHManager.RunCallback(GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY, isFromNewRoomCallback)
    end
end

local function OnNewRoom()
    CheckRoomChanged(true)
end
GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, GHManager.CallbackPriority.AFTER_MAX, OnNewRoom)

local function PreEntitySpawn()
    CheckRoomChanged(false)
end
GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, GHManager.CallbackPriority.AFTER_MAX, PreEntitySpawn)

----------------------------------POST_COMPLETED_ROOM_TRANSITION-----------------------------------

local PostCompletedRoomTransitionCallbacks = {}

if REPENTOGON then
    PostCompletedRoomTransitionCallbacks = {
        ModCallbacks.MC_POST_PLAYER_NEW_ROOM_TEMP_EFFECTS,
        ModCallbacks.MC_PRE_GRID_ENTITY_DECORATION_UPDATE,
        ModCallbacks.MC_POST_GRID_ENTITY_DECORATION_UPDATE,
        ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE,
        ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE,
        ModCallbacks.MC_PRE_GRID_ENTITY_SPIKES_UPDATE,
        ModCallbacks.MC_POST_GRID_ENTITY_SPIKES_UPDATE,
        ModCallbacks.MC_INPUT_ACTION,
        -- FULL UPDATE CYCLE (Without MC_POST_UPDATE THO)
        ModCallbacks.MC_PLAYER_GET_ACTIVE_MAX_CHARGE,
        ModCallbacks.MC_PLAYER_GET_ACTIVE_MIN_USABLE_CHARGE,
        ModCallbacks.MC_POST_WEAPON_FIRE,
        ModCallbacks.MC_POST_PEFFECT_UPDATE,
        ModCallbacks.MC_POST_PLAYER_UPDATE,
        ModCallbacks.MC_POST_EFFECT_UPDATE,
        ModCallbacks.MC_NPC_PICK_TARGET,
        ModCallbacks.MC_PRE_NPC_UPDATE,
        ModCallbacks.MC_NPC_UPDATE,
        -- FULL RENDER Cycle (Executed Multiple Times)
        ModCallbacks.MC_PRE_RENDER_ENTITY_LIGHTING,
        ModCallbacks.MC_PRE_RENDER_GRID_LIGHTING,
        ModCallbacks.MC_PRE_BACKDROP_RENDER_FLOOR,
        ModCallbacks.MC_PRE_GRID_ENTITY_DECORATION_RENDER,
        ModCallbacks.MC_POST_GRID_ENTITY_DECORATION_RENDER,
        ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER,
        -- Render Grid
        -- Render NPCs
        -- Render Effects
        -- HUD Update
        ModCallbacks.MC_PRE_RENDER,
        ModCallbacks.MC_POST_RENDER,
        ModCallbacks.MC_HUD_RENDER,
        -- Render Specific parts of the Hud
        ModCallbacks.MC_POST_HUD_RENDER,
        -- Some MC_INPUT_ACTION (Could probably be used for a POST_HUD_RENDER callback in vanilla)

        -- FULL UPDATE CYCLE (WITH POST_UPDATE)
        ModCallbacks.MC_POST_UPDATE
    }
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

local ModReference = GHManager.Mod -- Replace this with your own Mod Reference
local json = require("json")

local defaultManagerData = {
    RewindStateType = GHManager.HourglassStateType.Session_Start
}

function GHManager.SaveManagerData(SaveDataTable)
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
    function GHManager.Utilities.CanStartTrueCoop()
        return Isaac.CanStartTrueCoop()
    end
else
    function GHManager.Utilities.CanStartTrueCoop()
        return previousStageHourglassGameState.Type == GHManager.HourglassStateType.State_Null
    end
end

function GHManager.Utilities.CanRewindToHome()
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

local function HandleTransitions(transactionCount, level, isNewStage, shouldOverwriteHealthState)
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
            local copyPhantomHealthState = shouldOverwriteHealthState
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

            -- Going inside of a Crawlspace also causes level.LeveDoor to be set to -1, and altough this might seem
            -- counter intuitive, the game treats this as a warp and as such the Glowing Hourglass updates the same
            -- exact way it does when accounting for a warp.
            -- Proof: After Clearing a Room give yourself We Need To Go Deeper! and Spawn a Crawlspace then enter the
            -- Crawlspace and use GlowingHourglass. You will be taken back to the moment you cleared the room.
            -- As such you won't have Either We Need To Go Deeper! and the Crawlspace "Door" won't be there.

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
    local isNewStage = not (level:GetStateFlag(LevelStateFlag.STATE_LEVEL_START_TRIGGERED))
    local shouldOverwriteHealthState = hasCursedDoorDamageBeenTaken and (game:GetRoom():GetType() == RoomType.ROOM_CURSE or level:GetRoomByIdx(level:GetPreviousRoomIndex()).Data.Type == RoomType.ROOM_CURSE)
    hasCursedDoorDamageBeenTaken = false
    local transactionCount = #glowingHourglassTransactions

    if HandleNewSessions(transactionCount, isNewStage) then
        return
    end

    if HandleTransitions(transactionCount, level, isNewStage, shouldOverwriteHealthState) then
        return
    end

    if HandleRewinds(transactionCount) then
        return
    end
end

local function HandleGlowingHourglassPostClearState() -- This triggers the first time a callback is executed after the SPAWN logic
    previousStageHourglassGameState = {
        Time = game.TimeCounter,
        Type = GHManager.HourglassStateType.Cleared_Room
    }
    local transactionCount = #glowingHourglassTransactions

    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_GENERIC_UPDATE, GHManager.HourglassUpdate.Save_Pre_Room_Clear_State, transactionCount)

    GHManager.RunCallbackWithParam(GHManager.Callbacks.ON_SPECIAL_EVENT, GHManager.Enums.SpecialEvent.ROOM_CLEAR, GHManager.Enums.SpecialEvent.ROOM_CLEAR)

    GHManager.RunCallback(GHManager.Callbacks.ON_PHANTOM_REWIND_STATE_UPDATE)

    currentPhantomRewindState = GHManager.PhantomRewindState.Room_Clear
    -- Glowing Hourglass saves the state specifically when the Room Triggers a Clear, not when the Clear parameter of the room is set to True (by using something like Room:SetClear(true))
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

local postRoom = false

GHManager.Mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function() log.file("Room") print(Game():GetPlayer(0):GetNumCoins()) Game():GetPlayer(0):AddCoins(0) end)
GHManager.Mod:AddCallback(GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY, function() log.file("Early") print(Game():GetPlayer(0):GetNumCoins()) Game():GetPlayer(0):AddCoins(0) end)
GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_ROOM_EXIT, function() log.file("Exit") print(Game():GetPlayer(0):GetNumCoins()) Game():GetPlayer(0):AddCoins(0) end)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, function() postRoom = true end)
GHManager.Mod:AddCallback(13, function() if postRoom then log.print("1024") print(Game():GetPlayer(0):GetNumCoins()) Game():GetPlayer(0):AddCoins(1) end end)

GHManager.AddPriorityCallback(GHManager.Mod, GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassTransactions)
table.insert(addedModCallbacks, {
    Callback = GHManager.CustomCallbacks.POST_NEW_ROOM_EARLY,
    Function = HandleGlowingHourglassTransactions,
    Custom = true
}) -- Technically this should run on Repentogon's MC_PRE_ROOM_EXIT, as that is the exact moment the game saves the Glowing Hourglass State

-- It's Likely that the game uses a different Saving Mechanism, specifically one that is most likely implemented like this:

-- function CreatePhantomRewindState()
--     SaveGameState
-- end
-- function UpdateRewindState()
--     CopyPhantomRewindState
--     CreatePhantomRewindState()
-- end

-- The game then executes an UpdateRewindState() every MC_PRE_ROOM_EXIT but only if the NewLevel parameter is set to false otherwise it does nothing
-- Then on MC_POST_NEW_ROOM the game checks for Level:LeaveDoor if it is == -1 then it executes CreatePhantomRewindState(), otherwise it executes UpdateRewindState()
-- Add to that the special POST_CLEAN_AWARD and MC_ENTITY_TAKE_DMG special events that both execute CreatePhantomRewindState()

-- This implementation seems both completely accurate to what happens in-game, and way less complicated than the mess I first assumed.
-- Coupled with that the fact that in three very special circumstances the MC_PRE_ROOM_EXIT callback behaves "strangely":
-- On a New Session MC_PRE_ROOM_EXIT is executed after MC_POST_NEW_ROOM
-- On Rewind MC_PRE_ROOM_EXIT does not get called at all
-- On Multiplayer MC_PRE_ROOM_EXIT is called once for each player (Maybe it's hooked at the time where Each Player's Health State has to be overwritten?)

-- Of course that is only what probably happens on a regular transition.
-- On rewind something weird happens; aside from the fact that MC_PRE_ROOM_EXIT doesn't trigger, the Rewind State gets set to a State that comes after
-- MC_POST_NEW_ROOM, specifically the moment right after MC_POST_NEW_ROOM (After MC_EVALUATE_CACHE, Before MC_POST_PLAYER_NEW_ROOM_TEMP_EFFECTS (Repentogon), Before MC_INPUT_ACTION (Vanilla))

for index, callbackId in pairs(ModCallbacks) do
    GHManager.Mod:AddCallback(callbackId, function()  if postRoom then log.file("callbackId: " .. callbackId) end end)
end
GHManager.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()  if postRoom then log.file("End") end postRoom = false end)

GHManager.AddPriorityCallback(GHManager.Mod, GHManager.CustomCallbacks.POST_CLEAN_AWARD, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassPostClearState)
table.insert(addedModCallbacks, {
    Callback = GHManager.CustomCallbacks.POST_CLEAN_AWARD,
    Function = HandleGlowingHourglassPostClearState,
    Custom = true
})

GHManager.Mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, GHManager.CallbackPriority.AFTER_MAX, HandleGlowingHourglassPlayerHealthState, EntityType.ENTITY_PLAYER)

if REPENTANCE then
    GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, ResetPreviousFloorStateToNull, CollectibleType.COLLECTIBLE_R_KEY)
end

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, SetPreviousFloorStateToForget, CollectibleType.COLLECTIBLE_FORGET_ME_NOW)

GHManager.Mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, ResetHourglassStateOnExit)