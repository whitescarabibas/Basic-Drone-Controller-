-- Services -- 
local RST = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Variables --
local Drone = script.Parent
local DronePrimaryPart = Drone.PrimaryPart

-- Delay used when gradually tilting or untilting the drone
local TiltLoopDelay = 0.01

-- Movement states (tracks which keys are currently being held)
local IsMovingForward = false
local IsMovingBackward = false
local IsMovingRight = false
local IsMovingLeft = false

-- Events --
local Events = RST:FindFirstChild("Events")
local ForwardEvent = Events:FindFirstChild("Forward")
local BackwardEvent = Events:FindFirstChild("Backward")
local RightEvent = Events:FindFirstChild("Right")
local LeftEvent = Events:FindFirstChild("Left")
local UpEvent = Events:FindFirstChild("Up")
local DownEvent = Events:FindFirstChild("Down")
local PlayerCameraInfoEvent = Events:FindFirstChild("CamInfoEvent")

-- Connections --
-- Stored connections so they can be disconnected when movement stops
local ForwardConnection
local BackwardConnection
local RightConnection
local LeftConnection
local UpConnection
local DownConnection

-- Drone Data --
-- Increasement rate for the tilt angle applied when moving
local TiltRate = 5

-- Functions --
-- Moves the drone relative to its current orientation
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

-- X rotation = forward/back tilt 
-- Z rotation = side tilt 
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

-- reverses tilt back to neutral
-- simulates stabilization when the player stops moving the drone
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

-- Keeps the drone hovering by applying an upward force equal to its weight
local function DroneHover(DroneMass, Gravity)
	local BodyForce = DronePrimaryPart:FindFirstChild("VectorForce")
	BodyForce.Force = Vector3.new(0, DroneMass * Gravity, 0)
end

-- uses Motor6D to rotate parts smoothly each frame
local function SpinPropellers()
	for _, Propeller in pairs(Drone:GetChildren()) do
		if Propeller:IsA("MeshPart") and Propeller.Name == "Propeller" then
			local Motor = Propeller:FindFirstChild("Motor6D")
			Motor.C0 = Motor.C0 * CFrame.Angles(0,math.rad(50),0)
		end
	end
end

-- Rotates the drone to face the same direction as the players camera
local function UpdateDroneLookDirection(CamLookVector)
	local Pos = Drone:GetPivot().Position

	local Direction = Vector3.new(CamLookVector.X,0,CamLookVector.Z)

	local UpdatedLookDirectionCFrame = CFrame.lookAt(Pos, Pos + Direction)
	Drone:PivotTo(UpdatedLookDirectionCFrame)	
end

-- spins propellers every frame
task.spawn(function()
	task.delay(2,function()
		RunService.Heartbeat:Connect(function()
			SpinPropellers()
		end)
	end)
end)

-- applies hover force to counteract gravity
task.spawn(function()
	RunService.Heartbeat:Connect(function()
		local Gravity = workspace.Gravity
		local DroneMass = DronePrimaryPart:GetMass()
		DroneHover(DroneMass, Gravity)
	end)
end)

-- Handles forward movement
ForwardEvent.OnServerEvent:Connect(function(Player, State)
	IsMovingForward = State

	if State then
		-- Move forward every frame
		ForwardConnection = RunService.Heartbeat:Connect(function()
			if IsMovingBackward then
				ForwardConnection:Disconnect()
				ForwardConnection = nil
				return
			end
			MoveDrone("Forward")
		end)

		-- tilts forward until max tilt is reached
		task.spawn(function()
			while true do
				if IsMovingBackward then break end
				task.wait(TiltLoopDelay)
				TiltDrone("Forward")

				-- Converts model orientation from radians to degrees to check tilt limit
				local x, y, z = Drone:GetPivot():ToOrientation()
				if math.deg(x) <= -20 or not IsMovingForward then
					break
			end
		    end
		end)

	elseif not State then
		ForwardConnection:Disconnect()
		ForwardConnection = nil

		-- returns to normal tilt
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

-- (Same structure applies for Backward/Right/Left)
-- Moves drone continuously
-- Applies tilt until limit
-- Restores tilt when released

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

	else
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

-- Vertical movement
UpEvent.OnServerEvent:Connect(function(Player, State)
	if State then
		UpConnection = RunService.Heartbeat:Connect(function()
			MoveDrone("Up")
		end)
	else
		UpConnection:Disconnect()
		UpConnection = nil	
	end
end)

DownEvent.OnServerEvent:Connect(function(Player, State)
	if State then
		DownConnection = RunService.Heartbeat:Connect(function()
			MoveDrone("Down")
		end)
	else
		DownConnection:Disconnect()
		DownConnection = nil
	end
end)

-- Updates drone rotation based on the camera direction which is being sent from client
PlayerCameraInfoEvent.OnServerEvent:Connect(function(Player,CamInfo)
	UpdateDroneLookDirection(CamInfo)
end)
