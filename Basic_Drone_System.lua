--[[ Drone Controller Server Side Script :
     This Script Handles:
     • Basic Drone Movement	(Forward/Backward/Left/Right/up/Down)
     • Drone Tilting Based On Movement Direction
     • Camera Movement Based On Drone Movement
     • Stable Hovering Using VectorForce To Counteract Gravity Preventing The Drone From Falling When Going Up
     • Drone Rotating Based On Cam Position
     • Spinning Propellers TweenSerivce Animation
--]]

--// Services \\--
local RST = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
--// Variables \\--
local Drone = script.Parent
local DronePrimaryPart = Drone.PrimaryPart
local TiltLoopDelay = 0.01
local IsMovingForward = false
local IsMovingBackward = false
local IsMovingRight = false
local IsMovingLeft = false
--// Events \\--
local Events = RST:FindFirstChild("Events")
local ForwardEvent = Events:FindFirstChild("Forward")
local BackwardEvent = Events:FindFirstChild("Backward")
local RightEvent = Events:FindFirstChild("Right")
local LeftEvent = Events:FindFirstChild("Left")
local UpEvent = Events:FindFirstChild("Up")
local DownEvent = Events:FindFirstChild("Down")
local PlayerCameraInfoEvent = Events:FindFirstChild("CamInfoEvent")
--// Connections \\--
local ForwardConnection
local BackwardConnection
local RightConnection
local LeftConnection
local UpConnection
local DownConnection
--// Drone Data \\--
local TiltRate = 5
--// Functions \\--
local function MoveDrone(Direction)
	if Direction == "Forward" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(0,0,-1))
	elseif Direction == "Backward" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(0,0,1))
	elseif Direction == "Right" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(1,0,0))
	elseif Direction == "Left" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(-1,0,0))
	elseif Direction == "Up" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(0,1,0))
	elseif Direction == "Down" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.new(0,-1,0))
	end
end

local function TiltDrone(Direction)
	if Direction == "Forward" then
	   Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(math.rad(-TiltRate),0,0))
	elseif Direction == "Backward" then
	   Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(math.rad(TiltRate),0,0))
	elseif Direction == "Right" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(0,0,math.rad(-TiltRate)))
	elseif Direction == "Left" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(0,0,math.rad(TiltRate)))
	end
end

local function UntiltDrone(Direction)
	if Direction == "Forward" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(math.rad(TiltRate),0,0))
	elseif Direction == "Backward" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(math.rad(-TiltRate),0,0))
	elseif Direction == "Right" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(0,0,math.rad(TiltRate)))
	elseif Direction == "Left" then
		Drone:PivotTo(Drone:GetPivot() * CFrame.Angles(0,0,math.rad(-TiltRate)))
	end
end

local function DroneHover(DroneMass, Gravity)
	local BodyForce = DronePrimaryPart:FindFirstChild("VectorForce")
	BodyForce.Force = Vector3.new(0, DroneMass * Gravity, 0)
end

local function SpinPropellers()
	for _, Propeller in pairs(Drone:GetChildren()) do
		if Propeller:IsA("MeshPart") and Propeller.Name == "Propeller" then
			local Motor = Propeller:FindFirstChild("Motor6D")
			Motor.C0 = Motor.C0 * CFrame.Angles(0,math.rad(50),0)
		end
	end
end

local function UpdateDroneLookDirection(CamLookVector)
	local Pos = Drone:GetPivot().Position
	local Direction = Vector3.new(CamLookVector.X,0,CamLookVector.Z)
	local UpdatedLookDirectionCFrame = CFrame.lookAt(Pos, Pos + Direction)
	Drone:PivotTo(UpdatedLookDirectionCFrame)	
end

task.spawn(function()
	task.delay(2,function()
		RunService.Heartbeat:Connect(function()
			SpinPropellers()
		end)
	end)
end)

task.spawn(function()
	RunService.Heartbeat:Connect(function()
		local Gravity = workspace.Gravity
		local DroneMass = DronePrimaryPart:GetMass()
		DroneHover(DroneMass, Gravity)
	end)
end)

ForwardEvent.OnServerEvent:Connect(function(Player, State)
	IsMovingForward = State
	if State then
		ForwardConnection = RunService.Heartbeat:Connect(function()
			if IsMovingBackward then
				ForwardConnection:Disconnect()
				ForwardConnection = nil
				return
			end
			MoveDrone("Forward")
		end)
		task.spawn(function()
			while true do
				if IsMovingBackward then break end
				task.wait(TiltLoopDelay)
				TiltDrone("Forward")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(x) <= -20 or not IsMovingForward then
					break
				end
			end
		end)
	elseif not State then
		ForwardConnection:Disconnect()
		ForwardConnection = nil
		task.spawn(function()
			while true do
				task.wait(TiltLoopDelay)
				UntiltDrone("Forward")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(x) >= 0 or IsMovingForward then
					break
				end
			end
		end)
	end
end)

BackwardEvent.OnServerEvent:Connect(function(Player, State)
	IsMovingBackward = State
	if State then
		BackwardConnection = RunService.Heartbeat:Connect(function()
			if IsMovingForward then 
				BackwardConnection:Disconnect()
				BackwardConnection = nil
				return 
			end
			MoveDrone("Backward")
		end)
		task.spawn(function()
			while true do
				if IsMovingForward then break end
				task.wait(TiltLoopDelay)
				TiltDrone("Backward")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(x) >= 20 or not IsMovingBackward then
					break
				end
			end
		end)
	elseif not State then
		task.spawn(function()
			while true do
				task.wait(TiltLoopDelay)
				UntiltDrone("Backward")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(x) <= 0 or IsMovingBackward then
					break
				end
			end
		end)
		BackwardConnection:Disconnect()
		BackwardConnection = nil
	end
end)

RightEvent.OnServerEvent:Connect(function(Player, State)
	IsMovingRight = State
	if State then
		RightConnection = RunService.Heartbeat:Connect(function()
			if IsMovingLeft then
				RightConnection:Disconnect()
				RightConnection = nil
				return
			end
			MoveDrone("Right")
		end)
		task.spawn(function()
			while true do
				if IsMovingLeft then break end
				task.wait(TiltLoopDelay)
				TiltDrone("Right")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(z) <= -20 or not IsMovingRight then
					break
				end
			end
		end)
	elseif not State then
		task.spawn(function()
			while true  do
				task.wait(TiltLoopDelay)
				UntiltDrone("Right")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(z) >= 0 or IsMovingRight then
					break
				end
			end
		end)
		RightConnection:Disconnect()
		RightConnection = nil
	end
end)

LeftEvent.OnServerEvent:Connect(function(Player, State)
	IsMovingLeft = State
	if State then
		LeftConnection = RunService.Heartbeat:Connect(function()
			if IsMovingRight then
				LeftConnection:Disconnect()
				LeftConnection = nil
				return
			end
			MoveDrone("Left")
		end)
		task.spawn(function()
			while true do
				task.wait(TiltLoopDelay)
				TiltDrone("Left")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(z) >= 20 or not IsMovingLeft then
					break
				end
			end
		end)
	elseif not State then
		task.spawn(function()
			while true  do
				task.wait(TiltLoopDelay)
				UntiltDrone("Left")
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(z) <= 0 or IsMovingLeft then
					break
				end
			end
		end)
		LeftConnection:Disconnect()
		LeftConnection = nil
	end
end)

UpEvent.OnServerEvent:Connect(function(Player, State)
	if State then
		UpConnection = RunService.Heartbeat:Connect(function()
			MoveDrone("Up")
		end)
	elseif not State then
		UpConnection:Disconnect()
		UpConnection = nil	
	end
end)

DownEvent.OnServerEvent:Connect(function(Player, State)
	if State then
		DownConnection = RunService.Heartbeat:Connect(function()
			MoveDrone("Down")
		end)
	elseif not State then
		DownConnection:Disconnect()
		DownConnection = nil
	end
end)

PlayerCameraInfoEvent.OnServerEvent:Connect(function(Player,CamInfo)
	UpdateDroneLookDirection(CamInfo)
end)