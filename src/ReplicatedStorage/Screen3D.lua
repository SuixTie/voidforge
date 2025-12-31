--!strict


--VERSION NOTIFIER (OPTIONAL)
local currentVersion = '2.1.0'
local latestVersion: string?

local versionControl = script:FindFirstChild('VersionControl')

if versionControl and versionControl:FindFirstChild('VersionNotifier') then
	latestVersion = versionControl:InvokeServer()  :: string --comment this line to disable update notifier
end


if latestVersion and currentVersion ~= latestVersion then
	warn(`SCREEN3D - OUTDATED VERSION: {currentVersion} -> {latestVersion}`)
end





local componentGen = require(script.Component3D)
local D = require(script.Definitions)
local guiService = game:GetService('GuiService')


local screenGen : D.screenGen = {} :: D.screenGen

screenGen.__index = screenGen

function screenGen.new(screenGui,displayDistance : number)


	local partIndex : {[GuiObject] : D.component3D} = {}


	local self = setmetatable(
		{
			partIndex = partIndex,
			rootGui = screenGui,
			displayDistance = displayDistance,
			rootOffset = CFrame.new()


		},
		screenGen

	)



	for _,Component2D in ipairs(screenGui:GetDescendants()) do

		if Component2D:IsA("GuiObject") then

			partIndex[Component2D] = componentGen.new(Component2D,self)

		end

	end

	screenGui.DescendantAdded:Connect(function(AddedComponent)
		
		local AddedComponent = AddedComponent :: GuiObject
		
		if partIndex[AddedComponent] then
			return
		end
		
		if AddedComponent:IsA('GuiObject') then
			partIndex[AddedComponent] = componentGen.new(AddedComponent,self)
		end

		for _,Component2D in ipairs(AddedComponent:GetDescendants()) do

			if Component2D:IsA("GuiObject") and not partIndex[Component2D] then

				partIndex[Component2D] = componentGen.new(Component2D,self)

			end

		end

	end)


	return self 
end



function screenGen:GetRealCanvasSize()
	return workspace.CurrentCamera.ViewportSize
end

function screenGen:GetInset()
	local inset = guiService:GetGuiInset()
	return inset
end

function screenGen:GetInsetCanvasSize()

	return self:GetRealCanvasSize() - self:GetInset()
end

function screenGen:GetIntendedCanvasSize()
	if self.rootGui.IgnoreGuiInset then
		return self:GetRealCanvasSize()
	end
	return self:GetInsetCanvasSize()
end


function screenGen:GetComponent3D(Component2D)
	return self.partIndex[Component2D]
end

print('SCREEN3D LOADED')
return screenGen