local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- !! PUT YOUR WEBHOOK HERE
local WEBHOOK_URL = "https://discord.com/api/webhooks/1406970787478634610/2-a_1e8XweoASfU6EdE6mDSbSCIXPjHWJ5PRikjO6JkRjMxRb4m5SIRTuo3HtAiPorYA"

local EMBED_COLOR_DEFAULT = 5763719
local MAX_EMBED_DESC = 3500
local CHUNK_POST_DELAY = 0.8

-- executor request (KRNL / Synapse compatibility)
local request = request or http_request or (syn and syn.request)

----------------------------------------------------
-- Suspicious Keywords (expandable)
----------------------------------------------------
local suspiciousKeywords = {
	"httpget","getfenv","loadstring","synapse","krnl",
	"backdoor","admin","owner","executor","exploit",
	"remote","kick","ban","crash","serverhop","http","request"
}

local function isSuspicious(name)
	if not name then return false end
	local lower = tostring(name):lower()
	for _,word in ipairs(suspiciousKeywords) do
		if lower:find(word) then return true end
	end
	return false
end

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

-- Try to find map asset id using common patterns: Map object, Terrain/mesh ids, attributes, children with MeshId/TextureID/AssetId
local function detectMapAssetId()
	-- 1) If there's a top-level "Map" or "map" folder
	local candidate = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
	if candidate then
		-- look for attributes
		local attr = candidate:GetAttribute("MapAssetId") or candidate:GetAttribute("AssetId") or candidate:GetAttribute("MapId")
		if attr then return tostring(attr) end
		-- search for any MeshParts / SpecialMesh / Decals with asset ids
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

	-- 2) Check workspace for first MeshPart / SpecialMesh with MeshId
	for _,desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("MeshPart") and desc.MeshId and desc.MeshId ~= "" then
			return tostring(desc.MeshId)
		elseif desc:IsA("SpecialMesh") and desc.MeshId and desc.MeshId ~= "" then
			return tostring(desc.MeshId)
		end
	end

	-- 3) Check for attributes on workspace
	local wattr = workspace:GetAttribute("MapAssetId") or workspace:GetAttribute("MapId") or workspace:GetAttribute("AssetId")
	if wattr then return tostring(wattr) end

	-- fallback: return PlaceId and GameId so you at least have identifiers
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
		-- AccountAge may not always be accessible via client; attempt pcall
		local ok, age = pcall(function() return plr.AccountAge end)
		if ok then info.AccountAge = age end
		-- containers
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
	local suspicious = {}

	-- helper to process an instance
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

			-- snippet
			local s = getSnippet(inst)
			if s then
				snippets[inst:GetFullName()] = s
			end
		end

		-- suspicious names
		if isSuspicious(inst.Name) then
			table.insert(suspicious, inst:GetFullName() .. " [" .. inst.ClassName .. "]")
		end
	end

	-- scan static containers
	for _,container in ipairs(SCAN_CONTAINERS) do
		for _,inst in ipairs(safeDescendants(container)) do
			processInstance(inst)
		end
	end

	-- scan player containers
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
		snippets = snippets,
		suspicious = suspicious
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

	-- payload_json (embed)
	local payload = { embeds = embedTable }
	table.insert(bodyParts, "--" .. boundary)
	table.insert(bodyParts, 'Content-Disposition: form-data; name="payload_json"')
	table.insert(bodyParts, "")
	table.insert(bodyParts, HttpService:JSONEncode(payload))

	-- file
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

	-- Collect targets but update progress visually by iterating same way while counting
	local lines = {}
	local counts = { RemoteEvent = 0, RemoteFunction = 0, CmdScripts = 0, GlobalMsg = 0, total = 0 }
	local remotes = {}
	local cmdScripts = {}
	local globalMessages = {}
	local snippets = {}
	local suspicious = {}

	local function processAndUpdate(inst)
		-- process instance (same logic as collectTargets)
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
			if s then snippets[inst:GetFullName()] = s end
		end

		if isSuspicious(inst.Name) then
			table.insert(suspicious, inst:GetFullName() .. " [" .. inst.ClassName .. "]")
		end

		-- update scanned count and UI
		scannedCount = scannedCount + 1
		if ui and ui.progressSetter then ui.progressSetter(scannedCount, totalToScan) end
		-- update log (no-op) with latest suspicious count
		if ui and ui.setLog then
			local logtxt = string.format("Suspicious found: %d\nRemotes: %d  CmdScripts: %d  GlobalMsgs: %d", #suspicious, #remotes, #cmdScripts, #globalMessages)
			ui.setLog(logtxt)
		end
	end

	-- scan containers
	for _,container in ipairs(SCAN_CONTAINERS) do
		for _,inst in ipairs(safeDescendants(container)) do
			pcall(processAndUpdate, inst)
		end
	end

	-- scan player containers
	for _,plr in ipairs(Players:GetPlayers()) do
		for _,container in ipairs({ plr:FindFirstChild("Backpack"), plr:FindFirstChild("PlayerGui"), plr:FindFirstChild("PlayerScripts") }) do
			if container then
				for _,inst in ipairs(safeDescendants(container)) do
					pcall(processAndUpdate, inst)
				end
			end
		end
	end

	-- finalize progress
	if ui and ui.progressSetter then ui.progressSetter(totalToScan, totalToScan) end
	if ui and ui.setLog then ui.setLog("Preparing results...") end

	-- collect players info
	local playersInfo = collectPlayersInfo()

	-- detect map asset id
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
	table.insert(txtLines, "== Suspicious Items ==")
	if #suspicious == 0 then table.insert(txtLines, "None") else for _,s in ipairs(suspicious) do table.insert(txtLines, s) end end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Remotes ==")
	if #remotes == 0 then table.insert(txtLines, "None") else for _,r in ipairs(remotes) do table.insert(txtLines, string.format("%s | Parent=%s", r.full, r.parent)) end end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Command Scripts ==")
	if #cmdScripts == 0 then table.insert(txtLines, "None") else for _,c in ipairs(cmdScripts) do table.insert(txtLines, tostring(c.full)) end end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Global Messages ==")
	if #globalMessages == 0 then table.insert(txtLines, "None") else for _,g in ipairs(globalMessages) do table.insert(txtLines, string.format("%s | %s", tostring(g.full), tostring(g.type))) end end
	table.insert(txtLines, "")
	table.insert(txtLines, "== Snippets (first ~200 chars) ==")
	for k,v in pairs(snippets) do table.insert(txtLines, k .. ": " .. v) end

	local txtContent = table.concat(txtLines, "\n")

	-- decide embed color
	local color = 65280 -- green
	if #suspicious > 0 and #suspicious < 10 then color = 16776960 end -- yellow
	if #suspicious >= 10 then color = 16711680 end -- red

	-- prepare embed fields (limited lengths)
	local fields = {
		{name = "Remotes", value = tostring(#remotes), inline = true},
		{name = "CmdScripts", value = tostring(#cmdScripts), inline = true},
		{name = "GlobalMessages", value = tostring(#globalMessages), inline = true},
		{name = "Suspicious", value = (#suspicious > 0) and table.concat(suspicious, ", "):sub(1,1000) or "None", inline = false},
		{name = "MapAssetId", value = tostring(mapAssetId), inline = false},
		{name = "PlayersInServer", value = tostring(#playersInfo), inline = true},
	}

	-- game thumbnail URL
	local thumbUrl = string.format("https://www.roblox.com/asset-thumbnail/image?assetId=%d&width=420&height=420&format=png", game.PlaceId)
	local gameInfoOk, gameInfo = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	local gameName = game.Name
	local creatorName = "Unknown"
	if gameInfoOk and gameInfo and gameInfo.Name then
		gameName = gameInfo.Name
		if gameInfo.Creator and gameInfo.Creator.Name then creatorName = gameInfo.Creator.Name end
	end

	local embed = makeEmbed(gameName .. " – Deep Scan Summary", "Full container scan complete.", fields, color, thumbUrl, "PlaceId:" .. tostring(game.PlaceId) .. " | GameId:" .. tostring(game.GameId))

	-- post initial embed + txt attachment
	postWebhookMultipart({embed}, "scan_results_"..tostring(game.PlaceId)..".txt", txtContent)

	-- details in chunks if many lines
	if #lines > 0 then
		local chunks = chunkLines(lines, MAX_EMBED_DESC - 10)
		for i,chunk in ipairs(chunks) do
			local title = string.format("%s – Details (Part %d/%d)", gameName, i, #chunks)
			postWebhookMultipart({ makeEmbed(title, codeBlock(chunk), nil, color, thumbUrl) }, nil, nil)
			if i < #chunks then task.wait(CHUNK_POST_DELAY) end
		end
	else
		postWebhookMultipart({ makeEmbed(gameName.." – Details", codeBlock("No Remotes, Cmd Scripts, or Global Messages found."), nil, color, thumbUrl) }, nil, nil)
	end

	-- update UI log final
	if ui and ui.setLog then ui.setLog(string.format("Scan complete. Suspicious: %d | Remotes: %d | Cmds: %d", #suspicious, #remotes, #cmdScripts)) end

	return {
		lines = lines,
		counts = counts,
		remotes = remotes,
		cmdScripts = cmdScripts,
		globalMessages = globalMessages,
		snippets = snippets,
		suspicious = suspicious,
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
		-- results already posted inside performFullScan
	end)

	-- manual rescan
	ui.rescanButton.MouseButton1Click:Connect(function()
		-- reset progress & log quickly
		ui.progressSetter(0,1)
		ui.setLog("Manual rescan started...")
		task.spawn(function()
			local r = performFullScan(ui)
		end)
	end)

	-- live monitoring: when new descendant is added to workspace or ReplicatedStorage, do light check and optionally full rescan if suspicious
	local monitoredContainers = { workspace, game:GetService("ReplicatedStorage") }
	for _,c in ipairs(monitoredContainers) do
		c.DescendantAdded:Connect(function(inst)
			-- quick local check
			local name = tostring(inst.Name or "")
			if isSuspicious(name) or isGlobalMessageName(name) or SCAN_CLASSES[inst.ClassName] then
				-- small debounce per instance to avoid spam
				task.spawn(function()
					-- perform a full scan and post if suspicious
					local results = performFullScan(ui)
				end)
			end
		end)
	end

	return ui
end

-- run
local ui = setupScanner()

-- END OF SCRIPT
