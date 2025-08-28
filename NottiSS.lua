local gui = Instance.new("ScreenGui")
gui.Name = "Notti Executor"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 500, 0, 350)
main.Position = UDim2.new(0.5, -250, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(25, 0, 0)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 12)

local border = Instance.new("UIStroke", main)
border.Thickness = 2
border.Color = Color3.fromRGB(255, 0, 0)

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "Notti Executor"
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(255, 50, 50)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 40)
title.Parent = main

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ScrollFrame"
scrollFrame.Position = UDim2.new(0.05, 0, 0.15, 0)
scrollFrame.Size = UDim2.new(0.9, 0, 0.55, 0)
scrollFrame.CanvasSize = UDim2.new(0, 0, 5, 0)
scrollFrame.ScrollBarThickness = 6
scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 0, 0)
scrollFrame.BorderSizePixel = 0
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ClipsDescendants = true
scrollFrame.Parent = main

local scrollCorner = Instance.new("UICorner", scrollFrame)
scrollCorner.CornerRadius = UDim.new(0, 8)

local codeBox = Instance.new("TextBox")
codeBox.Name = "CodeBox"
codeBox.MultiLine = true
codeBox.ClearTextOnFocus = false
codeBox.Size = UDim2.new(1, -8, 1, 0)
codeBox.Position = UDim2.new(0, 4, 0, 0)
codeBox.TextWrapped = true
codeBox.BackgroundTransparency = 1
codeBox.TextXAlignment = Enum.TextXAlignment.Left
codeBox.TextYAlignment = Enum.TextYAlignment.Top
codeBox.TextSize = 16
codeBox.TextColor3 = Color3.fromRGB(255, 255, 255)
codeBox.Font = Enum.Font.Code
codeBox.Text = "--created by Jdot"
codeBox.Parent = scrollFrame

local function createButton(name, text, position, parent)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Text = text
	btn.Size = UDim2.new(0.28, 0, 0.12, 0)
	btn.Position = position
	btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14
	btn.Parent = parent

	local uiCorner = Instance.new("UICorner", btn)
	uiCorner.CornerRadius = UDim.new(0, 8)

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	end)

	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	end)

	return btn
end

local executeBtn = createButton("Execute", "Execute", UDim2.new(0.05, 0, 0.75, 0), main)
local clearBtn = createButton("Clear", "Clear", UDim2.new(0.365, 0, 0.75, 0), main)
local closeBtn = createButton("Close", "Close SS", UDim2.new(0.68, 0, 0.75, 0), main)

executeBtn.MouseButton1Click:Connect(function()
	local code = codeBox.Text
	local success, result = pcall(function()
		local fn = loadstring(code)
		if typeof(fn) == "function" then
			fn()
		end
	end)
	if not success then
		warn("Execution failed:", result)
	end
end)

clearBtn.MouseButton1Click:Connect(function()
	codeBox.Text = ""
end)

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)
