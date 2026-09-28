-- Mid-air jumps for reaching the sky islands. The ground jump is Roblox's own;
-- each extra jump (up to getMaxJumps() total) resets upward velocity while falling.
-- Movement is client-owned in Roblox anyway, so there's nothing for the server to check.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(game:GetService("ReplicatedStorage").Modules.GameConfig)

local MultiJump = {}

local AIR_JUMP_COOLDOWN = 0.3 -- JumpRequest repeats while jump is held; space jumps out

function MultiJump.Start(getMaxJumps)
	local player = Players.LocalPlayer
	local jumpsUsed = 0
	local lastJump = 0

	local function bind(character)
		local humanoid = character:WaitForChild("Humanoid")
		jumpsUsed = 0
		humanoid.StateChanged:Connect(function(_, state)
			if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
				jumpsUsed = 0
			elseif state == Enum.HumanoidStateType.Jumping then
				jumpsUsed = math.max(jumpsUsed, 1)
				lastJump = os.clock()
			end
		end)
	end
	if player.Character then
		task.spawn(bind, player.Character)
	end
	player.CharacterAdded:Connect(bind)

	UserInputService.JumpRequest:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or humanoid.Health <= 0 then
			return
		end
		if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
			return -- on the ground: Roblox handles the normal jump
		end
		if os.clock() - lastJump < AIR_JUMP_COOLDOWN then
			return
		end
		-- Walking off a ledge counts as having used the ground jump.
		jumpsUsed = math.max(jumpsUsed, 1)
		if jumpsUsed >= getMaxJumps() then
			return
		end
		jumpsUsed += 1
		lastJump = os.clock()
		local velocity = root.AssemblyLinearVelocity
		-- Set velocity directly; forcing the Jumping state would apply Roblox's weaker jump impulse instead.
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, GameConfig.ExtraJump.AirJumpVelocity, velocity.Z)
	end)
end

return MultiJump
