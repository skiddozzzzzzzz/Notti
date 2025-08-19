-- Drop in StarterPlayerScripts (LocalScript)

local WEBHOOK_URL = "https://discord.com/api/webhooks/1407513636104048640/u74QFZ18YRPlfcxswld5VeBquTFOkgLdcfpudX7bzFGVKlNyltvuecwqSnl64gpA7hoZ"
local EMBED_COLOR_DEC = 671130 -- Dark blue (#0A3D9A)
local SCAN_SERVICES = {
	game,
	game:GetService("ReplicatedStorage"),
	game:GetService("Workspace"),
	game:GetService("Players"),
	game:GetService("Lighting"),
	game:GetService("ReplicatedFirst"),
}
local GLOBAL_MSG_KEYWORDS = { "message","broadcast","announce","global","system","chat" }

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer

local function safe(f, ...)
	local ok, res = pcall(f, ...)
	if ok then return res end
	return nil
end

local function getGameName()
	local info = safe(MarketplaceService.GetProductInfo, MarketplaceService, game.PlaceId)
	return (info and info.Name) or ("Place "..tostring(game.PlaceId))
end

local function isLikelyGlobalMessage(name)
	if not name then return false end
	local lower = string.lower(name)
	for _,kw in ipairs(GLOBAL_MSG_KEYWORDS) do
		if string.find(lower, kw, 1, true) then
			return true
		end
	end
	return false
end

local function pathOf(obj)
	return typeof(obj) == "Instance" and obj:GetFullName() or tostring(obj)
end

local function makeUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RemoteScanUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	gui.DisplayOrder = 999999
	gui.Parent = LP:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.82)
	holder.Size = UDim2.fromOffset(420, 90)
	holder.BackgroundColor3 = Color3.fromRGB(10, 15, 30)
	holder.BorderSizePixel = 0
	holder.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = holder

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 170, 255)),
	}
	grad.Rotation = 0
	grad.Parent = stroke

	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.98, 0.8)
	inner.BackgroundColor3 = Color3.fromRGB(15, 20, 45)
	inner.BorderSizePixel = 0
	inner.Parent = holder

	local corner1 = Instance.new("UICorner")
	corner1.CornerRadius = UDim.new(0, 14)
	corner1.Parent = holder

	local corner2 = Instance.new("UICorner")
	corner2.CornerRadius = UDim.new(0, 12)
	corner2.Parent = inner

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 24)
	title.Position = UDim2.fromOffset(10, 8)
	title.Font = Enum.Font.GothamSemibold
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(220, 235, 255)
	title.Text = "Scanning remotes…"
	title.Parent = inner

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -20, 0, 20)
	subtitle.Position = UDim2.fromOffset(10, 32)
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 14
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = Color3.fromRGB(170, 195, 255)
	subtitle.Text = "Please wait while we enumerate objects"
	subtitle.Parent = inner

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, -20, 0, 10)
	bar.Position = UDim2.fromOffset(10, 58)
	bar.BackgroundColor3 = Color3.fromRGB(25, 35, 70)
	bar.BorderSizePixel = 0
	bar.Parent = inner
	local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0, 6); barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Position = UDim2.fromOffset(0, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fillCorner = Instance.new("UICorner"); fillCorner.CornerRadius = UDim.new(0, 6); fillCorner.Parent = fill

	task.spawn(function()
		while gui.Parent do
			local up = TweenService:Create(holder, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = holder.Position - UDim2.fromOffset(0, 8)})
			up:Play(); up.Completed:Wait()
			local down = TweenService:Create(holder, TweenInfo.new(1.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = holder.Position + UDim2.fromOffset(0, 8)})
			down:Play(); down.Completed:Wait()
		end
	end)

	task.spawn(function()
		while gui.Parent do
			for r = 0, 360, 6 do
				grad.Rotation = r
				task.wait(0.02)
			end
		end
	end)

	return gui, title, subtitle, fill
end

local function setBar(fill, pct)
	local tw = TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0)})
	tw:Play()
end

local function gatherScanTargets()
	local list = {}
	for _,svc in ipairs(SCAN_SERVICES) do
		if typeof(svc) == "Instance" then
			for _,d in ipairs(svc:GetDescendants()) do
				table.insert(list, d)
			end
		end
	end
	return list
end

local function runScan(updateProgress)
	local remotes, globalMsgRemotes = {}, {}
	local replicatedContent = {}
	for _,d in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
		table.insert(replicatedContent, string.format("[%s] %s", d.ClassName, pathOf(d)))
	end

	local all = gatherScanTargets()
	local total = #all
	for i,obj in ipairs(all) do
		if updateProgress then updateProgress(i/total, obj) end
		local cls = obj.ClassName
		if cls == "RemoteEvent" or cls == "RemoteFunction" then
			local entry = string.format("[%s] %s", cls, pathOf(obj))
			table.insert(remotes, entry)
			if isLikelyGlobalMessage(obj.Name) then
				table.insert(globalMsgRemotes, entry)
			end
		end
	end
	return remotes, globalMsgRemotes, replicatedContent
end

local function chunkStrings(items, maxLen)
	local chunks, cur = {}, ""
	for _,line in ipairs(items) do
		if #cur + #line + 1 > maxLen then
			table.insert(chunks, cur)
			cur = line
		else
			if cur == "" then cur = line else cur = cur .. "\n" .. line end
		end
	end
	if cur ~= "" then table.insert(chunks, cur) end
	return chunks
end

local function postWebhook(remotes, globals, replContent)
	local gameName = getGameName()
	local fields = {}

	local function addField(name, valueList)
		if #valueList == 0 then
			table.insert(fields, { name = name .. " (0)", value = "`None`", inline = false })
			return
		end
		local parts = chunkStrings(valueList, 1000)
		for idx,part in ipairs(parts) do
			local label = (idx == 1 and name or (name .. " (cont.)"))
			table.insert(fields, { name = label, value = "```txt\n" .. part .. "\n```", inline = false })
		end
	end

	addField("All Remotes", remotes)
	addField("Likely Global Message Remotes", globals)
	addField("ReplicatedStorage Contents", replContent)

	local payload = {
		embeds = {{
			title = "Results",
			description = string.format("**Place:** %s\n**PlaceId:** %d\n**Time:** <t:%d:f>", gameName, game.PlaceId, math.floor(os.time())),
			color = EMBED_COLOR_DEC,
			fields = fields,
			footer = { text = "Scan complete" }
		}}
	}

	local json = HttpService:JSONEncode(payload)
	local ok, err = pcall(function()
		HttpService:PostAsync(WEBHOOK_URL, json, Enum.HttpContentType.ApplicationJson, false)
	end)
	return ok, err
end

local gui, title, subtitle, fill = makeUI()
local function prog(pct, obj)
	setBar(fill, pct)
	if obj and obj.Name then
		subtitle.Text = "Scanning: " .. obj.ClassName .. " — " .. obj.Name
	end
end

setBar(fill, 0.1); task.wait(0.15)
local remotes, globals, repl = runScan(prog)
setBar(fill, 0.85); task.wait(0.1)
title.Text = "Sending results to webhook…"
subtitle.Text = string.format("Found %d remotes, %d global-message, %d replicated items", #remotes, #globals, #repl)
setBar(fill, 0.92)
local ok, err = postWebhook(remotes, globals, repl)
setBar(fill, 1.0); task.wait(0.25)
title.Text = ok and "Completed" or "Failed to send"
subtitle.Text = ok and "Results delivered. Cleaning up UI…" or ("Error: ".. tostring(err or "Unknown"))
safe(function()
	StarterGui:SetCore("SendNotification", {
		Title = ok and "Remote Scan Complete" or "Remote Scan Error",
		Text = ok and (("Found %d remotes • Sent to webhook"):format(#remotes)) or "Check webhook URL / proxy",
		Duration = 4
	})
end)
task.delay(0.75, function()
	if gui then gui:Destroy() end
end)
