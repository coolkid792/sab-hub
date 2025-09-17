-- Optimized Brainrot Finder with randomized server hopping and fast retry

-- Services
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TextChatService = game:GetService("TextChatService")
local generalChannel = TextChatService.TextChannels.RBXGeneral

-- Variables
local PlaceID = game.PlaceId
local startTime = tick()
local isTeleporting = false
local failedServerIds = {}
local teleportFailureCount = 0
local currentServerList = {}
local sentBrainsGlobal = {}
local decalsyeeted = true

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"

-- Chat messages
local messages = { "Want servers have 10m+ Sęcret Pęts?", "Easy brainrots! ínvítạtíọn: brainrotfinder"}
for _, msg in ipairs(messages) do
    pcall(function() generalChannel:SendAsync(msg) end)
    task.wait(1)
end

-- Debug helper
local function SendDebug(msg, attempts)
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

-- Send Webhook
local function SendWebhook(url, data)
    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
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

    local raw = textLabel.Text  -- e.g. "Puzzle's Base"
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

    if genNumber >= 1e7 then
        embed.color, embed.ping = 0xFF0000, true
        SendMessageEMBED({highValueWebhookUrl}, embed)
    elseif genNumber >= 5e6 then
        embed.color = 0xFFA500
        SendMessageEMBED({highValueWebhookUrl}, embed)
    else
        embed.color = 0xFFFFFF
        SendMessageEMBED({webhookUrl, zzzHubWebhook}, embed)
    end
end

-- Scan plots only twice
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

    scanOnce()
    task.wait(15)
    scanOnce()
end

-- Workspace optimization
pcall(function()
    RunService:Set3dRenderingEnabled(false)
    Lighting.GlobalShadows, Lighting.Brightness, Lighting.ClockTime = false, 0, 14
    Lighting.FogEnd = 9e9
    settings().Rendering.QualityLevel = "Level03"
    for _,v in pairs(game:GetDescendants()) do
        if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
            v.Material,v.Reflectance = "Plastic",0
        elseif (v:IsA("Decal") or v:IsA("Texture")) and decalsyeeted then v.Transparency=1
        elseif v:IsA("ParticleEmitter") then v.Lifetime,v.Rate,v.Enabled = NumberRange.new(0,0),0,false
        elseif v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then v.Enabled=false
        elseif v:IsA("Explosion") then v.BlastPressure,v.BlastRadius = 1,1
        elseif v:IsA("MeshPart") then v.Material,v.Reflectance,v.TextureID="Plastic",0,10385902758728957 end
    end
    for _,e in pairs(Lighting:GetChildren()) do if e:IsA("PostEffect") then e.Enabled=false end end
    SendDebug("Workspace optimization complete.")
end)

-- Hide other GUIs
spawn(function()
    while task.wait(2) do
        for _,gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and gui.Name~="BrainrotFinderUI" then gui.Enabled=false end
        end
    end
end)

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

-- 🆕 New Hopper System --

-- Fetch servers (new)
local function getServers()
    local servers, cursor, attempt = {}, '', 1
    local maxAttempts = 5
    repeat
        local url = 'https://games.roblox.com/v1/games/'..PlaceID..'/servers/Public?sortOrder=Asc&limit=100'
        if cursor ~= '' then
            url = url .. "&cursor=" .. cursor
        end

        local success, response = pcall(function()
            return game:HttpGet(url, true)
        end)

        if success and response and response ~= '' then
            local ok, data = pcall(function()
                return HttpService:JSONDecode(response)
            end)
            if ok and data and data.data then
                for _, server in ipairs(data.data) do
                    if tonumber(server.playing) and tonumber(server.maxPlayers) and server.playing < server.maxPlayers and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
                cursor = data.nextPageCursor or ''
            else
                cursor = '' -- stop on JSON fail
            end
        else
            attempt = attempt + 1
            task.wait(0.5)
        end
    until cursor == '' or attempt > maxAttempts

    for i = #servers, 2, -1 do
        local j = math.random(i)
        servers[i], servers[j] = servers[j], servers[i]
    end

    SendDebug('Fetched ' .. #servers .. ' joinable servers')
    return servers
end

-- Hop to server (new)
local function hopToNewServer(maxTime)
    local deadline = tick() + (maxTime or 30)
    while tick() < deadline do
        if #currentServerList == 0 then
            currentServerList = getServers()
        end
        if #currentServerList > 0 then
            local idx = math.random(1, #currentServerList)
            local server = table.remove(currentServerList, idx)
            local success, err = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, server.id, LocalPlayer)
            end)
            if success then
                return
            end
        else
            task.wait(0.5)
        end
    end
    SendDebug('Failed to hop within ' .. (maxTime or 30) .. 's')
end

TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage, placeId, jobId)
    teleportFailureCount = teleportFailureCount + 1
    SendDebug("Teleport failed for "..player.Name..": "..tostring(errorMessage))
    isTeleporting = false
    if jobId and type(jobId)=="string" then
        failedServerIds[jobId] = true
        task.spawn(function() task.wait(1) failedServerIds[jobId] = nil end)
    end
    task.wait(1)
    hopToNewServer()
end)

-- Stuck teleport timeout
spawn(function()
    while true do
        if isTeleporting then
            local start = tick()
            while isTeleporting and tick()-start < 10 do task.wait(1) end
            if isTeleporting then
                SendDebug("Teleport stuck, retrying")
                isTeleporting = false
                hopToNewServer()
            end
        end
        task.wait(1)
    end
end)

-- Start scanning & hopping
spawn(function()
    scanPlotsTwice()
    hopToNewServer()
end)
