local ScreenGui = Instance.new("ScreenGui")
local Main = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local TextBox = Instance.new("TextBox")
local Execute = Instance.new("TextButton")
local Clear = Instance.new("TextButton")
local Close = Instance.new("TextButton")
local UICorner = Instance.new("UICorner")
local Border = Instance.new("UIStroke")

ScreenGui.Name = "NottiSS"
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Main.Name = "Main"
Main.Parent = ScreenGui
Main.BackgroundColor3 = Color3.fromRGB(30, 0, 0)
Main.Position = UDim2.new(0.3, 0, 0.25, 0)
Main.Size = UDim2.new(0, 450, 0, 300)
Main.Active = true
Main.Draggable = true

UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Main

Border.Thickness = 2
Border.Color = Color3.fromRGB(255, 0, 0)
Border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Border.Parent = Main

Title.Name = "Title"
Title.Parent = Main
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "Notti SS"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 20
Title.TextColor3 = Color3.fromRGB(255, 0, 0)

TextBox.Name = "CodeBox"
TextBox.Parent = Main
TextBox.BackgroundColor3 = Color3.fromRGB(50, 0, 0)
TextBox.Position = UDim2.new(0.05, 0, 0.15, 0)
TextBox.Size = UDim2.new(0.9, 0, 0.5, 0)
TextBox.Font = Enum.Font.Code
TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TextBox.TextSize = 16
TextBox.TextXAlignment = Enum.TextXAlignment.Left
TextBox.TextYAlignment = Enum.TextYAlignment.Top
TextBox.TextWrapped = true
TextBox.ClearTextOnFocus = false
TextBox.MultiLine = true
TextBox.Text = "-- paste your Lua, loadstring(), or require() code here"

Execute.Name = "Execute"
Execute.Parent = Main
Execute.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
Execute.Position = UDim2.new(0.05, 0, 0.7, 0)
Execute.Size = UDim2.new(0.27, 0, 0.2, 0)
Execute.Font = Enum.Font.Gotham
Execute.Text = "Execute"
Execute.TextColor3 = Color3.fromRGB(255, 255, 255)
Execute.TextSize = 14

Clear.Name = "Clear"
Clear.Parent = Main
Clear.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
Clear.Position = UDim2.new(0.365, 0, 0.7, 0)
Clear.Size = UDim2.new(0.27, 0, 0.2, 0)
Clear.Font = Enum.Font.Gotham
Clear.Text = "Clear"
Clear.TextColor3 = Color3.fromRGB(255, 255, 255)
Clear.TextSize = 14

Close.Name = "Close"
Close.Parent = Main
Close.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
Close.Position = UDim2.new(0.68, 0, 0.7, 0)
Close.Size = UDim2.new(0.27, 0, 0.2, 0)
Close.Font = Enum.Font.Gotham
Close.Text = "Close SS"
Close.TextColor3 = Color3.fromRGB(255, 255, 255)
Close.TextSize = 14

Execute.MouseButton1Click:Connect(function()
    local code = TextBox.Text
    local success, result = pcall(function()
        local fn = loadstring(code)
        if typeof(fn) == "function" then
            fn()
        end
    end)
    if not success then
        warn("Execution Error: ", result)
    end
end)

Clear.MouseButton1Click:Connect(function()
    TextBox.Text = ""
end)

Close.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)
