local modReference = RegisterMod("GHManager Debugger", 1)

local function GetScreenSize()
    if REPENTANCE then
        return Vector(Isaac.GetScreenWidth(), Isaac.GetScreenHeight())
    end

    -- ab+ / based off of code from kilburn
    local room = Game():GetRoom()
    local pos = room:WorldToScreenPosition(Vector(0,0)) - room:GetRenderScrollOffset() - Game().ScreenShakeOffset

    local rx = pos.X + 60 * 26 / 40
    local ry = pos.Y + 140 * (26 / 40)

    return Vector(rx * 2 + 13 * 26, ry * 2 + 7 * 26)
end

local function GetScreenWidth()
    if REPENTANCE then
        return Isaac.GetScreenWidth()
    end

    return GetScreenSize().X
end

local function GetScreenHeight()
    if REPENTANCE then
        return Isaac.GetScreenHeight()
    end

    return GetScreenSize().Y
end

local function Reverse_Iterator(t,i)
    i=i-1
    local v=t[i]
    if v==nil then return v end
    return i,v
end

local function ReverseIterate(t)
    return Reverse_Iterator, t, #t+1
end

local Font = Font()
Font:Load('font/terminus8.fnt')

local LineColor = KColor(1, 1, 1, 1)
local LineHeight = Font:GetLineHeight()

local MaxAlpha = 1

local GameFrameRate = 60
local FullVisibilityTime = 3 --[[seconds]] * GameFrameRate
local FadeInTime = 2 --[[seconds]] * GameFrameRate
local OnScreenTime = FullVisibilityTime + FadeInTime

local XOffset = 4
local XModes = {
    Left = 1,
    Right = 2,
    Center = 3
}
local XMode = XModes.Left

local YOffset = 4
local TopToBottom = false

local function GetLineAlpha(Time)
    if Time <= FullVisibilityTime then
        return MaxAlpha
    end
    Time = Time - FullVisibilityTime
    return ((FadeInTime - Time) / FadeInTime) * MaxAlpha
end

local function GetLineXPosition(Message)
    if XMode == XModes.Left then
        return XOffset
    end
    if XMode == XModes.Right then
        return GetScreenWidth() - (XOffset + Font:GetStringWidthUTF8(Message))
    end
    return (GetScreenSize() / 2).X  - (Font:GetStringWidthUTF8(Message) / 2)
end

local function GetLineYPosition(LineIndex)
    if TopToBottom then
        return YOffset + (LineHeight * (LineIndex - 1))
    end
    return GetScreenHeight() - (YOffset + (LineHeight * LineIndex))
end

local DebugMessenger = {}
DebugMessenger.Lines = {}
DebugMessenger.DeletedLines = {}

function DebugMessenger.AddLine(String)
    table.insert(DebugMessenger.Lines, 1, {Message = String, Time = 0})
end

function DebugMessenger.MarkForDeletion(LineIndex)
    table.insert(DebugMessenger.DeletedLines, LineIndex)
end

function DebugMessenger.DeleteMarkedLines()
    for _, lineIndex in ReverseIterate(DebugMessenger.DeletedLines) do
        table.remove(DebugMessenger.Lines, lineIndex)
    end
    DebugMessenger.DeletedLines = {}
end

function DebugMessenger.Render()
    for index, line in ipairs(DebugMessenger.Lines) do
        LineColor.Alpha = GetLineAlpha(line.Time)
        local X = GetLineXPosition(line.Message)
        local Y = GetLineYPosition(index)
        Font:DrawStringUTF8(line.Message, X, Y, LineColor, 0, true)

        line.Time = line.Time + 1
        if line.Time >= OnScreenTime then
            DebugMessenger.MarkForDeletion(index)
        end
    end

    DebugMessenger.DeleteMarkedLines()
end

modReference:AddCallback(ModCallbacks.MC_POST_RENDER, DebugMessenger.Render)

return DebugMessenger