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

-- Jitter seed per instance
math.randomseed(LocalPlayer.UserId + os.time())

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"
local ultraHighWebhookUrl = "https://discord.com/api/webhooks/1418234733388894359/GEMiC5lwqCiFod59U88EM8Lfkg1dc1jnjG21f1Vg_QAPPCspZ-8sUj44lhlTwEy9-eVK"


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
            Url = debugWebhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Send Webhook (patched)
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
local function SendMessageEMBED(urls, embed)
    for _, url in ipairs(urls) do
        local embedCopy = table.clone(embed)
        if url == zzzHubWebhook then
            embedCopy.footer = {text = "zzz hub x gg/brainrotfinder"}
            embedCopy.author = embedCopy.author or {}
            embedCopy.author.url = "https://discord.gg/brainrotfinder"
        end
        local data = {
            embeds = {embedCopy},
            content = embedCopy.ping and "<@&1414643713426194552>" or nil
        }
        SendWebhook(url, data)
    end
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

local function getPing()
    local stats = game:GetService("Stats")
    local pingStat = stats.Network.ServerStatsItem["Data Ping"]
    if pingStat and pingStat:GetValue() then
        return math.floor(pingStat:GetValue())
    end
    return 0
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

-- Process podium
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
    if genNumber < 1e6 then return end

    local playerCount, jobId, _, joinLink = getPlayerData()
    local embed = {
        description = "# 🧠 "..name.." | 💰 "..gen.." | 👥 "..playerCount,
        fields = {
            {name="🐾 Brainrot Name", value=name, inline=true},
            {name="📜 Income", value=gen, inline=true},
            {name="👥 Player Count", value=playerCount, inline=true},
            {name="✨ Rarity", value=rarityValue, inline=true},
            {name="☀️ Owner", value=plotOwner.." (Floor "..floorNum..")", inline=true},
            {name="🆔 Job ID", value="```"..jobId.."```"},
            {name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..PlaceID..",\""..jobId.."\",game.Players.LocalPlayer)\n```"},
            {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"}
        },
        author = {name="🧩 Puzzle's Notifier"},
        footer = {text = "Puzzle Brainrot Finder"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    }

    if genNumber >= 20e6 then
        embed.color, embed.ping = 0xFF0000, true
        SendMessageEMBED({highValueWebhookUrl}, embed)
    elseif genNumber >= 5e6 then
        embed.color = 0xFFA500
        SendMessageEMBED({highValueWebhookUrl}, embed)
    else
        embed.color = 0xFFFFFF
        SendMessageEMBED({webhookUrl, zzzHubWebhook}, embed)
    end

        if genNumber >= 20e6 then
        local formattedName = name:gsub("%s+", "")
        local thumbnailUrl = "https://raw.githubusercontent.com/tfvs/brainrot-images/main/"..formattedName..".png"

        local footerTimestamp = "Today at " .. os.date("%I:%M %p")

        local specialEmbed = {
            title = "HIGH VALUE SECRET FOUND",
            description = "Want access to 10M+ high value secrets?\n<#1413894765526913155>",
            color = 16730698,
            fields = {
                {name = "Generation", value = gen},
                {name = "Secret", value = name}
            },
            thumbnail = {url = thumbnailUrl},
            footer = {text = footerTimestamp}
        }

        local data = {content = nil, embeds = {specialEmbed}, attachments = {}}
        SendWebhook(ultraHighWebhookUrl, data)
    end
end

-- Scan plots only twice (short delay)
local function scanPlotsTwice()
    local function scanOnce()
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
        SendDebug("Scan found "..found.." podiums.")
        return found
    end

    SendDebug("Starting first scan.")
    scanOnce()
    SendDebug("Finished scanning plots.")
end

-- Lightweight workspace optimization (fast on multi-instance)
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

-- Hide other GUIs (event-based)
local function disableGuiIfNeeded(gui)
    if gui:IsA("ScreenGui") and gui.Name ~= "BrainrotFinderUI" then
        gui.Enabled = false
    end
end
for _,gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do disableGuiIfNeeded(gui) end
LocalPlayer.PlayerGui.ChildAdded:Connect(disableGuiIfNeeded)

-- UI overlay
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

-- Fetch servers via Cloudflare proxy (single call, retries on failure)
local function getServers()
    local servers = {}
    local maxAttempts = 3
    local proxyBase = "https://spring-leaf-5b44.macaroniwithtony67.workers.dev/servers/" .. PlaceID .. "?excludeJobId=" .. (game.JobId or "")

    for attempt = 1, maxAttempts do
        -- jitter to de-sync across instances
        task.wait(0.05 + (LocalPlayer.UserId % 6) * 0.03 + math.random() * 0.07)

        local success, response = pcall(function()
            return game:HttpGet(proxyBase)
        end)

        if success and response ~= "" then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(response)
            end)

            if ok and data and data.data and type(data.data) == "table" then
                for _, server in ipairs(data.data) do
                    if tonumber(server.playing)
                        and tonumber(server.maxPlayers)
                        and server.playing < server.maxPlayers - 1
                        and server.id
                        and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
                SendDebug("Fetched "..#servers.." joinable servers via proxy")
                return servers
            else
                SendDebug("Failed to parse proxy response on attempt "..attempt)
            end
        else
            SendDebug("Failed to fetch from proxy on attempt "..attempt)
        end

        if attempt < maxAttempts then
            task.wait(0.5 * (attempt + 1))
        end
    end

    SendDebug("Proxy fetch failed after "..maxAttempts.." attempts, falling back to 0 servers")
    return servers
end

-- Server hopping with random selection & fast retry
local function hopToNewServer()
    if isTeleporting then SendDebug("Already teleporting") return end
    isTeleporting = true
    teleportFailureCount = 0

    if #currentServerList == 0 then
        currentServerList = getServers()
        serverRetryCounts = {}
        for _,server in ipairs(currentServerList) do
            serverRetryCounts[server.id] = 0
        end
    end

    while #currentServerList > 0 do
        local idx = math.random(1, #currentServerList)
        local server = currentServerList[idx]
        if server and server.id and not failedServerIds[server.id] and (serverRetryCounts[server.id] or 0) < 2 then
            serverRetryCounts[server.id] = (serverRetryCounts[server.id] or 0) + 1
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, server.id, LocalPlayer)
            end)
            if success then
                isTeleporting = false
                return
            else
                teleportFailureCount = teleportFailureCount + 1
                SendDebug("Teleport failed: "..tostring(err))
                failedServerIds[server.id] = true
                task.spawn(function() task.wait(0.75) failedServerIds[server.id] = nil end)
                task.wait(0.25 + math.random() * 0.1)
            end
        end
        table.remove(currentServerList, idx)
    end

    currentServerList = {}
    isTeleporting = false
    task.wait(0.35 + math.random() * 0.15)
    hopToNewServer()
end

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage, placeId, jobId)
    teleportFailureCount = teleportFailureCount + 1
    SendDebug("Teleport failed for "..player.Name..": "..tostring(errorMessage))
    isTeleporting = false
    if jobId and type(jobId)=="string" then
        failedServerIds[jobId] = true
        task.spawn(function() task.wait(0.75) failedServerIds[jobId] = nil end)
    end
    task.wait(0.35 + math.random() * 0.15)
    hopToNewServer()
end)

-- Stuck teleport timeout (faster recovery)
task.spawn(function()
    while true do
        if isTeleporting then
            local start = tick()
            while isTeleporting and tick()-start < 6 do task.wait(0.5) end
            if isTeleporting then
                SendDebug("Teleport stuck, retrying")
                isTeleporting = false
                hopToNewServer()
            end
        end
        task.wait(0.5)
    end
end)

-- Main loop: Scan and hop sequentially
-- Main loop: Scan and hop sequentially
task.spawn(function()
    while true do
        SendDebug("Starting scan and hop cycle.")
        scanPlotsTwice() -- Complete the full scan (two passes with 4-second delay)
        task.wait(3) -- Small buffer to ensure scanning is fully complete
        SendDebug("Initiating server hops.")
        hopToNewServer() -- Hop to a new server after scanning
        task.wait(2) -- Small delay before starting the next cycle
    end
end)
