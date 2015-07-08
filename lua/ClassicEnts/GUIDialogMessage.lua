// Natural Selection 2 'Classic Entities Mod'
// Adds some additional entities inspired by Half-Life 1 and the Extra Entities Mod by JimWest - https://github.com/JimWest/ExtraEntitesMod
// Designed to work with maps developed for Extra Entities Mod.  
// Source located at - https://github.com/xToken/ClassicEnts
// lua\ClassicEnts\GUIDialogMessage.lua
// - Dragon

Script.Load("lua/GUIScript.lua")
Script.Load("lua/NS2Utility.lua")

class 'GUIDialogMessage' (GUIScript)

local kScreenScaleAspect = 1280

local function ScreenSmallAspect()

    local screenWidth = Client.GetScreenWidth()
    local screenHeight = Client.GetScreenHeight()
    return ConditionalValue(screenWidth > screenHeight, screenHeight, screenWidth)

end

local function GUICorrectedScale(size)
    if ScreenSmallAspect() > kScreenScaleAspect then
        return (ScreenSmallAspect() / kScreenScaleAspect) * size * 1.15
    else
        return math.scaledown(size, ScreenSmallAspect(), kScreenScaleAspect) * (2 - (ScreenSmallAspect() / kScreenScaleAspect))
    end
end

local kAlienBackgroundTexture = "ui/alien_commander_background.dds"
local kMarineBackgroundTexture = "ui/marine_commander_background.dds"

local kBackgroundTopCoords = { X1 = 758, Y1 = 452, X2 = 987, Y2 = 487 }
local kBackgroundCenterCoords = { X1 = 758, Y1 = 472, X2 = 987, Y2 = 505 }
local kBackgroundBottomCoords = { X1 = 758, Y1 = 505, X2 = 987, Y2 = 536 }

local kBackgroundWidth = GUICorrectedScale(320)
local kBackgroundHeight = GUICorrectedScale(5)
local kBackgroundTopHeight = 20
local kBackgroundBottomHeight = 20
local kBackgroundXOffset = GUICorrectedScale(20)
local kBackgroundColor = Color(1,1,1,0)

local kTextXOffset = GUICorrectedScale(30)
local kTextYOffset = GUICorrectedScale(17)
local kTextMaxHeight = 100
local kTextFont = Fonts.kAgencyFB_Medium

function GUIDialogMessage:Initialize()

    self.textureName = kMarineBackgroundTexture
    if PlayerUI_IsOnAlienTeam() then
        self.textureName = kAlienBackgroundTexture
    end

    self:InitializeBackground()
    self:InitializeTextObject()
    self.timeLastData = 0
	self.displayTime = 0
	
end

function GUIDialogMessage:InitializeBackground()

    self.backgroundTop = GUIManager:CreateGraphicItem()
    self.backgroundTop:SetAnchor(GUIItem.Left, GUIItem.Center)
    self.backgroundTop:SetSize(Vector(kBackgroundWidth, kBackgroundTopHeight, 0))
	self.backgroundTop:SetPosition(Vector(kBackgroundXOffset, 0, 0))
    self.backgroundTop:SetTexture(self.textureName)
	self.backgroundTop:SetColor(kBackgroundColor)
	self.background = self.backgroundTop
	GUISetTextureCoordinatesTable(self.backgroundTop, kBackgroundTopCoords)
	
	self.backgroundCenter = GUIManager:CreateGraphicItem()
    self.backgroundCenter:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    self.backgroundCenter:SetSize(Vector(kBackgroundWidth, kBackgroundHeight, 0))
    self.backgroundCenter:SetTexture(self.textureName)
	self.backgroundCenter:SetColor(kBackgroundColor)
	self.backgroundTop:AddChild(self.backgroundCenter)
    GUISetTextureCoordinatesTable(self.backgroundCenter, kBackgroundCenterCoords)
	
	self.backgroundBottom = GUIManager:CreateGraphicItem()
    self.backgroundBottom:SetAnchor(GUIItem.Left, GUIItem.Bottom)
    self.backgroundBottom:SetSize(Vector(kBackgroundWidth, kBackgroundBottomHeight, 0))
    self.backgroundBottom:SetTexture(self.textureName)
	self.backgroundBottom:SetColor(kBackgroundColor)
	self.backgroundCenter:AddChild(self.backgroundBottom)
    GUISetTextureCoordinatesTable(self.backgroundBottom, kBackgroundBottomCoords)
	
	self.backGroundColor = kBackgroundColor

end

function GUIDialogMessage:InitializeTextObject()

	self.text = GUIManager:CreateTextItem()
    self.text:SetAnchor(GUIItem.Left, GUIItem.Top)
    self.text:SetTextAlignmentX(GUIItem.Align_Min)
    self.text:SetTextAlignmentY(GUIItem.Align_Min)
    self.text:SetPosition(Vector(kTextXOffset, kTextYOffset, 0))
    self.text:SetColor(Color(1, 1, 1, 1))
    self.text:SetFontIsBold(true)
    self.text:SetFontName(kTextFont)
    self.text:SetInheritsParentAlpha(true)
    self.background:AddChild(self.text)

end

function GUIDialogMessage:Uninitialize()

    // Everything is attached to the background so uninitializing it will destroy all items.
    if self.background then
        GUI.DestroyItem(self.background)
    end
    
end

function GUIDialogMessage:SetBackgroundColor(color)

    self.backgroundTop:SetColor(color)
    self.backgroundCenter:SetColor(color)
    self.backgroundBottom:SetColor(color)

end

function GUIDialogMessage:OnResolutionChanged(oldX, oldY, newX, newY)

	kBackgroundWidth = GUICorrectedScale(320)
	kBackgroundHeight = GUICorrectedScale(5)
	kBackgroundXOffset = GUICorrectedScale(20)
	kTextXOffset = GUICorrectedScale(30)
	kTextYOffset = GUICorrectedScale(17)
	
	self.backgroundTop:SetSize(Vector(kBackgroundWidth, kBackgroundTopHeight, 0))
	self.backgroundCenter:SetSize(Vector(kBackgroundWidth, kBackgroundHeight, 0))
	self.backgroundBottom:SetSize(Vector(kBackgroundWidth, kBackgroundBottomHeight, 0))
	self.text:SetPosition(Vector(kTextXOffset, kTextYOffset, 0))
	
end

function GUIDialogMessage:UpdateDialog(text, displayTime)

    self.backGroundColor.a = 1
    self.timeLastData = Shared.GetTime()
	self.displayTime = displayTime
	
	local wrappedText = WordWrap(self.text, text, 0, kBackgroundWidth - (kTextXOffset * 2))
	self.text:SetText(wrappedText)
	self:SetBackgroundColor(self.backGroundColor)
    local adjustedHeight = math.max(kBackgroundHeight + self.text:GetTextHeight(wrappedText) - (kBackgroundTopHeight - kBackgroundBottomHeight), 0)
	//Top and Bottom fixed for rounded texture edges, scale inside piece according to text size.
    self.backgroundCenter:SetSize(Vector(kBackgroundWidth, adjustedHeight, 0))
	
end

function GUIDialogMessage:Update(deltaTime)

	//Fades out after displayTime.
    if PlayerUI_IsACommander() then
    
        self.backGroundColor.a = 0
        self:SetBackgroundColor(self.backGroundColor)
        
    else

        if self.timeLastData + self.displayTime < Shared.GetTime() then

            self.backGroundColor.a = math.max(0, self.backGroundColor.a - deltaTime)
            self:SetBackgroundColor(self.backGroundColor)

        end
        
        self.textureName = kMarineBackgroundTexture
        if PlayerUI_IsOnAlienTeam() then
            self.textureName = kAlienBackgroundTexture
        end

        self.backgroundTop:SetTexture(self.textureName)
        self.backgroundCenter:SetTexture(self.textureName)
        self.backgroundBottom:SetTexture(self.textureName)
    
    end

end