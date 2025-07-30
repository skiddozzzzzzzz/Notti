-- NOTTI GUI | LLN & E4N FULL VERSION (SS Required for require() IDs)
local CoreGui = game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "NottiGui"
ScreenGui.ResetOnSpawn = false

local Main = Instance.new("Frame", ScreenGui)
Main.Size = UDim2.new(0, 700, 0, 420)
Main.Position = UDim2.new(0.5, -350, 0.5, -210)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 2
Main.BorderColor3 = Color3.fromRGB(255, 0, 0)
Main.Active = true
Main.Draggable = true

local Title = Instance.new("TextLabel", Main)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
Title.Text = "notti gui | lln & E4N"
Title.TextColor3 = Color3.fromRGB(255, 0, 0)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 22

local Holder = Instance.new("Frame", Main)
Holder.Size = UDim2.new(1, -10, 1, -50)
Holder.Position = UDim2.new(0, 5, 0, 40)
Holder.BackgroundTransparency = 1

local Layout = Instance.new("UIGridLayout", Holder)
Layout.CellSize = UDim2.new(0, 160, 0, 35)
Layout.CellPadding = UDim2.new(0, 4, 0, 4)

function MakeBtn(text, func)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = UDim2.new(0, 160, 0, 35)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.MouseButton1Click:Connect(func)
	b.Parent = Holder
end

MakeBtn("Skybox", function()
	local s = Instance.new("Sky", game.Lighting)
	local id = "rbxassetid://108402930625911"
	s.SkyboxBk = id s.SkyboxDn = id s.SkyboxFt = id s.SkyboxLf = id s.SkyboxRt = id s.SkyboxUp = id
end)

MakeBtn("Anti Ban", function()
	local mt = getrawmetatable(game)
	setreadonly(mt, false)
	local old = mt.__namecall
	mt.__namecall = newcclosure(function(self, ...)
		local method = getnamecallmethod()
		if method == "Kick" then return end
		return old(self, ...)
	end)
end)

MakeBtn("Anti Kick", function()
	game:GetService("Players").LocalPlayer.Kick = function() end
end)

MakeBtn("Decal Spam", function()
	while true do
		local d = Instance.new("Decal", workspace)
		d.Texture = "rbxassetid://108402930625911"
		wait()
	end
end)

MakeBtn("I Love You So Theme", function()
	local s = Instance.new("Sound", game.SoundService)
	s.SoundId = "rbxassetid://98364034458260"
	s.Volume = 10
	s.Looped = true
	s:Play()
end)

MakeBtn("Fling All", function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/skiddozzzzzzzz/GGGGGZIN/refs/heads/main/Bitch.lua"))()
end)

MakeBtn("NOTTI SS", function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/skiddozzzzzzzz/Notti/refs/heads/main/NottiSS.lua"))()
end)

MakeBtn("Nuke", function()
	local bomb = Instance.new("Part", workspace)
	bomb.Size = Vector3.new(20, 20, 20)
	bomb.Position = Vector3.new(0, 1000, 0)
	bomb.BrickColor = BrickColor.new("Really red")
	bomb.Anchored = false
	bomb.Touched:Connect(function()
		for _, plr in pairs(game.Players:GetPlayers()) do
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then hrp.Velocity = Vector3.new(0, 9999, 0) end
		end
		workspace:ClearAllChildren()
	end)
end)

MakeBtn("Ultimate Crypted GUI", function()
	require(100212893167529).LOLskidGNA("ScriptWareDoom")
end)

MakeBtn("Ball Rain", function()
	while true do
		local p = Instance.new("Part", workspace)
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(5,5,5)
		p.Position = Vector3.new(math.random(-100,100), 120, math.random(-100,100))
		p.BrickColor = BrickColor.Random()
		p.Anchored = false
		wait(0.05)
	end
end)

MakeBtn("Particles", function()
	local e = Instance.new("ParticleEmitter", game.Players.LocalPlayer.Character.Head)
	e.Texture = "rbxassetid://108402930625911"
	e.Rate = 100
end)

MakeBtn("Loop Hint", function()
	while true do
		local h = Instance.new("Hint", workspace)
		h.Text = "GAME IS FUCKED BY NOTTI LOL"
		wait(2)
		h:Destroy()
	end
end)

MakeBtn("n00z 666 GUI", function()
	require(0x3fc6a75fe).n00z666("ScriptWareDoom")
end)

MakeBtn("Anti Leave", function()
	pcall(function()
		game.CoreGui.RobloxGui:Destroy()
	end)
end)

MakeBtn("Toadroast", function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/skiddozzzzzzzz/Notti/refs/heads/main/Toadroast.lua"))()
end)

MakeBtn("m00p GUI V1", function()
	require(17340805099).ez("ScriptWareDoom")
end)

MakeBtn("Disco Mode", function()
	while true do
		game.Lighting.Ambient = Color3.new(math.random(), math.random(), math.random())
		wait(0.1)
	end
end)

MakeBtn("TreatKidd GUI", function()
	require(110104863384044).load("ScriptWareDoom")
end)

MakeBtn("N00zkidd Supra", function()
	require(137383100190557).Foodistzen("ScriptWareDoom")
end)
