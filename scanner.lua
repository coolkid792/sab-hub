-- Services
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local generalChannel = TextChatService.TextChannels and TextChatService.TextChannels.RBXGeneral

-- Variables
local PlaceID = game.PlaceId
local startTime = tick()
local isTeleporting = false
local failedServerIds = {}
local teleportFailureCount = 0
local serverRetryCounts = {}
local currentServerList = {}
local sentBrainsGlobal = {}
local decalsyeeted = true
local scanResults = {} -- collected results for prioritization

-- Jitter seed per instance
math.randomseed(LocalPlayer.UserId + os.time())

-- Webhook (all unified)
local webhookUrl = "https://discord.com/api/webhooks/1418052458437152890/J6-sQoiJVrfejmhv5vNFIKUDOaYY6AiKZKPEtdEjlLE1KXhw-LXJaH9n9UZ7v7mONraE"

-- Debug helper (throttled)
local __lastDebugAt = 0
local function SendDebug(msg, attempts)
    if tick() - __lastDebugAt < 2 then return end
    __lastDebugAt = tick()
    local elapsedTime = math.floor(tick() - startTime)
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=150&height=150&format=png"
    local data = {
        embeds = {{
            description = msg,
            color = 0xFFFFFF,
            author = {name = LocalPlayer.Name, icon_url = avatarUrl},
            footer = {text = "⏰ "..elapsedTime.."s | Teleport Attempts: "..(attempts or teleportFailureCount)},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
        }}
    }
    pcall(function()
        request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Send Webhook
local function SendWebhook(url, data)
    local httpRequest = (syn and syn.request) or (http and http.request) or (http_request) or (fluxus and fluxus.request) or request
    if not httpRequest then
        warn("No HTTP request function available.")
        return
    end
    local success, err = pcall(function()
        httpRequest({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    if not success then
        warn("Webhook send failed: "..tostring(err))
    end
end

-- Send embed message
local function SendMessageEMBED(embed)
    local data = {
        embeds = {embed}
    }
    SendWebhook(webhookUrl, data)
end

-- Player/server info
local function getPlayerData()
    local playerCount = #Players:GetPlayers().."/8"
    local jobId = game.JobId or "N/A"
    local placeId = game.PlaceId
    local joinLink = jobId=="N/A" and "N/A (Public server)" or string.format("https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s", placeId, jobId)
    return playerCount, jobId, placeId, joinLink
end

-- Helper: get plot owner name
local function getPlotOwner(plot)
    local plotSign = plot:FindFirstChild("PlotSign")
    if not plotSign then return "Unknown" end
    local surfaceGui = plotSign:FindFirstChild("SurfaceGui")
    if not surfaceGui then return "Unknown" end
    local frame = surfaceGui:FindFirstChild("Frame")
    if not frame then return "Unknown" end
    local textLabel = frame:FindFirstChild("TextLabel")
    if not textLabel or not textLabel.Text then return "Unknown" end
    local raw = textLabel.Text
    local cleaned = raw:gsub(" Base$", "")
    cleaned = cleaned:gsub("'s$", "")
    return cleaned
end

-- Helper: determine floor number
local function getFloorNumber(podium)
    local parentName = podium.Name
    local floorNum = 1
    local num = tonumber(parentName)
    if num then
        if num >= 1 and num <= 10 then
            floorNum = 1
        elseif num >= 11 and num <= 18 then
            floorNum = 2
        else
            floorNum = 3
        end
    end
    return floorNum
end

-- Collect podium results (no immediate sending)
local function processPodium(podium, plotOwner, floorNum)
    local overhead
    for _, child in ipairs(podium:GetDescendants()) do
        if child.Name == "AnimalOverhead" then overhead = child break end
    end
    if not overhead then return end

    local displayName = overhead:FindFirstChild("DisplayName")
    local generation = overhead:FindFirstChild("Generation")
    local rarity = overhead:FindFirstChild("Rarity")
    if not (displayName and generation and rarity) then return end

    local name, gen, rarityValue = displayName.Text, generation.Text, rarity.Text
    local key = name.."|"..gen.."|"..rarityValue.."|"..game.JobId
    if sentBrainsGlobal[key] then return end
    sentBrainsGlobal[key] = true

    local numberMatch = gen:match("(%d+%.?%d*)")
    local genNumber = tonumber(numberMatch) or 0
    if gen:find("M") then genNumber = genNumber * 1e6
    elseif gen:find("K") then genNumber = genNumber * 1e3 end

    table.insert(scanResults, {
        name = name,
        gen = gen,
        genNumber = genNumber,
        rarity = rarityValue,
        owner = plotOwner,
        floor = floorNum
    })
end

-- Decide what to send after scan
local function sendScanResults()
    if #scanResults == 0 then return end
    local playerCount, jobId, _, joinLink = getPlayerData()

    -- Check if there are 5M+ finds
    local hasHighValue = false
    for _, r in ipairs(scanResults) do
        if r.genNumber >= 5e6 then
            hasHighValue = true
            break
        end
    end

    for _, r in ipairs(scanResults) do
        if not (hasHighValue and r.genNumber < 5e6) then
            local embed = {
                description = "# 🧠 "..r.name.." | 💰 "..r.gen.." | 👥 "..playerCount,
                fields = {
                    {name="🐾 Brainrot Name", value=r.name, inline=true},
                    {name="📜 Income", value=r.gen, inline=true},
                    {name="👥 Player Count", value=playerCount, inline=true},
                    {name="✨ Rarity", value=r.rarity, inline=true},
                    {name="☀️ Owner", value=r.owner.." (Floor "..r.floor..")", inline=true},
                    {name="🆔 Job ID", value="```"..jobId.."```"},
                    {name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..PlaceID..",\""..jobId.."\",game.Players.LocalPlayer)\n```"},
                    {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"}
                },
                author = {name="🧩 Puzzle's Notifier"},
                footer = {text = "Puzzle Brainrot Finder"},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
            }

            if r.genNumber >= 8.5e6 then
                embed.color, embed.ping = 0xFF0000, true
                SendMessageEMBED(embed)
            elseif r.genNumber >= 5e6 then
                embed.color = 0xFFA500
                SendMessageEMBED(embed)
            elseif r.genNumber >= 1e6 and r.genNumber < 5e6 then
                embed.color = 0xFFFFFF
                SendMessageEMBED(embed)
            end
        end
    end

    scanResults = {} -- clear after sending
end

-- Scan plots
local function scanPlotsOnce()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then SendDebug("Plots folder not found.") return 0 end
    local found = 0
    for _,playerBase in ipairs(plotsFolder:GetChildren()) do
        local plotOwner = getPlotOwner(playerBase)
        local podiumsFolder = playerBase:FindFirstChild("AnimalPodiums")
        if podiumsFolder then
            for _,podium in ipairs(podiumsFolder:GetChildren()) do
                local floorNum = getFloorNumber(podium)
                pcall(function() processPodium(podium, plotOwner, floorNum) found = found+1 end)
            end
        end
    end
    return found
end

local function scanPlotsTwice()
    SendDebug("Starting scan.")
    scanPlotsOnce()
    SendDebug("Finished scan. Sending results...")
    sendScanResults()
end

-- Lightweight optimization
pcall(function()
    RunService:Set3dRenderingEnabled(false)
    Lighting.GlobalShadows = false
    Lighting.Brightness = 0
    Lighting.ClockTime = 14
    Lighting.FogEnd = 9e9
    settings().Rendering.QualityLevel = "Level01"
    for _, e in pairs(Lighting:GetChildren()) do if e:IsA("PostEffect") then e.Enabled = false end end
    SendDebug("Lightweight optimization applied.")
end)

-- GUI overlay
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "BrainrotFinderUI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
local whiteFrame = Instance.new("Frame", ScreenGui)
whiteFrame.Size = UDim2.new(1,0,1,0)
whiteFrame.BackgroundColor3 = Color3.new(1,1,1)
whiteFrame.BorderSizePixel = 0
local statusLabel = Instance.new("TextLabel", whiteFrame)
statusLabel.Size = UDim2.new(1,0,0,50)
statusLabel.Position = UDim2.new(0.5,0,0.5,0)
statusLabel.AnchorPoint = Vector2.new(0.5,0.5)
statusLabel.Text = "Brainrot Finder Active"
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextColor3 = Color3.new(0,0,0)
statusLabel.TextScaled = true
statusLabel.BackgroundTransparency = 1

-- Server fetching
local function getServers()
    local servers = {}
    local proxyBase = "https://lingering-smoke-afa1.aarislmao827.workers.dev/servers/" .. PlaceID .. "?excludeJobId=" .. (game.JobId or "")
    local success, response = pcall(function()
        return game:HttpGet(proxyBase)
    end)
    if success and response ~= "" then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        if ok and data and data.data and type(data.data) == "table" then
            for _, server in ipairs(data.data) do
                if tonumber(server.playing) and tonumber(server.maxPlayers) and server.playing < server.maxPlayers - 1 and server.id and server.id ~= game.JobId then
                    table.insert(servers, server)
                end
            end
        end
    end
    return servers
end

-- Server hopping
local function hopToNewServer()
    if isTeleporting then return end
    isTeleporting = true
    if #currentServerList == 0 then
        currentServerList = getServers()
    end
    while #currentServerList > 0 do
        local idx = math.random(1, #currentServerList)
        local server = currentServerList[idx]
        table.remove(currentServerList, idx)
        if server and server.id then
            local success = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, server.id, LocalPlayer)
            end)
            if success then return end
        end
    end
    isTeleporting = false
end

TeleportService.TeleportInitFailed:Connect(function()
    isTeleporting = false
    hopToNewServer()
end)

-- Main loop
task.spawn(function()
    while true do
        scanPlotsTwice()
        hopToNewServer()
        task.wait(2)
    end
end)
