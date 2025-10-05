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
local webhookMessageCache = {} -- Cache to track sent webhook messages
local lastScanTime = 0 -- Prevent rapid scanning
local scanCooldown = 10 -- Minimum seconds between scans

-- Jitter seed per instance
math.randomseed(LocalPlayer.UserId + os.time())

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"
local ultraHighWebhookUrl = "https://discord.com/api/webhooks/1418234733388894359/GEMiC5lwqCiFod59U88EM8Lfkg1dc1jnjG21f1Vg_QAPPCspZ-8sUj44lhlTwEy9-eVK"

-- Specific brainrots that should go to normal webhook even with high generation
local normalWebhookBrainrots = {
    "Dul Dul Dul",
    "Chachechi",
    "La Cucaracha",
    "Sammyni Spyderini",
    "La Vacca Saturno Saturnita",
    "Crabbo Limonetta"
}

-- Trait IDs for mapping
local traitIds = {
    [78474194088770] = "Rain",
    [115664804212096] = "Matteo's Hat",
    [99181785766598] = "Galactic",
    [118283346037788] = "Fire",
    [83627475909869] = "Snowy",
    [100601425541874] = "Bubblegum",
    [127455440418221] = "Starfall",
    [121332433272976] = "Glitched",
    [97725744252608] = "Bombardiro",
    [89041930759464] = "Taco",
    [104985313532149] = "Water",
    [104229924295526] = "Nyan Cat",
    [134655415681926] = "10B",
    [121100427764858] = "Fireworks",
    [82620342632406] = "Disco",
    [75650816341229] = "Brazil",
    [110723387483939] = "Evil Tung Tung",
    [110910518481052] = "UFO",
    [117478971325696] = "Spider",
    [84731118566493] = "Strawberry",
    [104964195846833] = "Crab",
    [139729696247144] = "mygame43",
    [115001117876534] = "Sleepy"
}

-- Debug log collection system
local debugLogs = {}
local lastTeleportTime = 0

local function AddDebugLog(msg)
    local timestamp = os.date("%H:%M:%S")
    table.insert(debugLogs, "[" .. timestamp .. "] " .. msg)
    
    -- Keep only last 15 logs to prevent message from getting too long
    if #debugLogs > 15 then
        table.remove(debugLogs, 1)
    end
end

local function SendDebugLogs(attempts)
    if #debugLogs == 0 then return end
    
    local elapsedTime = math.floor(tick() - startTime)
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=150&height=150&format=png"
    
    -- Check if stuck teleporting for 300+ seconds
    local shouldPing = false
    if isTeleporting and (tick() - lastTeleportTime) > 300 then
        shouldPing = true
    end
    
    local combinedLogs = table.concat(debugLogs, "\n")
    local data = {
        content = shouldPing and "@everyone" or nil,
        embeds = {{
            title = shouldPing and "🚨 STUCK TELEPORTING - NEEDS HELP" or "📊 Scan & Hop Report",
            description = "```\n" .. combinedLogs .. "\n```",
            color = shouldPing and 0xFF0000 or 0xFFFFFF,
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
    
    -- Clear logs after sending
    debugLogs = {}
end

-- Debug helper (collects logs instead of sending immediately)
local function SendDebug(msg, attempts)
    AddDebugLog(msg)
end

setfpscap(15)

-- Periodic cleanup of webhook message cache
task.spawn(function()
    while true do
        task.wait(300) -- Clean every 5 minutes
        local currentTime = tick()
        local cleaned = 0
        for key, timestamp in pairs(webhookMessageCache) do
            if currentTime - timestamp > 120 then -- Remove entries older than 2 minutes
                webhookMessageCache[key] = nil
                cleaned = cleaned + 1
            end
        end
        if cleaned > 0 then
            SendDebug("Cleaned " .. cleaned .. " old webhook cache entries")
        end
    end
end)

-- Railway-based duplicate prevention using external service
local function wasWebhookRecentlySent(webhookUrl, embedContent)
    local currentTime = tick()
    
    -- Extract brainrot name and generation from embed
    local embedData = HttpService:JSONDecode(embedContent)
    local brainrotName = "Unknown"
    local generation = "Unknown"
    
    if embedData.description then
        local nameMatch = embedData.description:match("🧠 ([^|]+)")
        local genMatch = embedData.description:match("💰 ([^|]+)")
        if nameMatch then brainrotName = nameMatch:gsub("^%s*(.-)%s*$", "%1") end
        if genMatch then generation = genMatch:gsub("^%s*(.-)%s*$", "%1") end
    end
    
    local serverId = game.JobId or "unknown"
    
    -- Check Railway duplicate service
    local success, response = pcall(function()
        local duplicateServiceUrl = "https://brainrot-duplicate-checker-production.up.railway.app/check-duplicate"
        local requestData = {
            brainrotName = brainrotName,
            generation = generation,
            serverId = serverId,
            timestamp = currentTime,
            webhookUrl = webhookUrl
        }
        
        -- Use exploit request function (same as your working test)
        local httpRequest = (syn and syn.request) or (housekeeper and housekeeper.request) or (http and http.request) or (http_request) or (fluxus and fluxus.request) or request
        
        if httpRequest then
            local result = httpRequest({
                Url = duplicateServiceUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "RobloxScript"
                },
                Body = HttpService:JSONEncode(requestData)
            })
            return result.Body -- Return the response body
        else
            -- Fallback to HttpService
            return game:HttpPost(duplicateServiceUrl, HttpService:JSONEncode(requestData), Enum.HttpContentType.ApplicationJson)
        end
    end)
    
    if success and response then
        local ok, result = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        
        if ok and result then
            if result.isDuplicate then
                SendDebug("Duplicate brainrot detected via Railway: " .. brainrotName .. " (" .. generation .. ")")
                return true
            end
            SendDebug("Railway: New brainrot allowed - " .. brainrotName .. " (" .. generation .. ")")
        else
            SendDebug("Failed to parse Railway response: " .. tostring(response))
        end
    else
        SendDebug("Railway duplicate check failed, using local fallback")
        
        -- Local fallback cache
        local cacheKey = brainrotName .. "|" .. generation .. "|" .. serverId
        if webhookMessageCache[cacheKey] and (currentTime - webhookMessageCache[cacheKey]) < 120 then
            SendDebug("Duplicate brainrot detected locally (fallback): " .. brainrotName .. " (" .. generation .. ")")
            return true
        end
        webhookMessageCache[cacheKey] = currentTime
    end
    
    return false
end

-- Send Webhook (patched)
local function SendWebhook(url, data)
    local httpRequest = (syn and syn.request) or ( housekeeper and housekeeper.request ) or (http and http.request) or (http_request) or (fluxus and fluxus.request) or request
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
    for i, url in ipairs(urls) do
        local embedCopy = table.clone(embed)
        if url == zzzHubWebhook then
            embedCopy.footer = {text = "zzzz hub x gg/brainrotfinder"}
            embedCopy.author = embedCopy.author or {}
            embedCopy.author.url = "https://discord.gg/brainrotfinder"
        end
        
        -- Create a unique content hash for duplicate checking
        local embedContent = HttpService:JSONEncode(embedCopy)
        
        -- Check if this exact embed was sent recently to this webhook
        if not wasWebhookRecentlySent(url, embedContent) then
            local data = {
                embeds = {embedCopy},
                content = embedCopy.ping and "<@&1414643713426194552>" or nil
            }
            SendWebhook(url, data)
        else
            SendDebug("Skipping duplicate webhook message to " .. url:match("webhooks/(%d+)"))
        end
        
        -- Small delay between webhook sends to prevent rate limiting
        if i < #urls then
            task.wait(0.1)
        end
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

-- Helper: extract traits
local function extractTraits(animalOverhead)
    local traits = animalOverhead:FindFirstChild("Traits")
    if not traits then
        return "None"
    end
    local traitList = {}
    for _, child in pairs(traits:GetChildren()) do
        if child:IsA("ImageLabel") and child.Image then
            local imageId = child.Image:match("rbxassetid://(%d+)")
            if imageId then
                local traitId = tonumber(imageId)
                if traitIds[traitId] then
                    table.insert(traitList, traitIds[traitId])
                end
            end
        end
    end
    if #traitList == 0 then
        return "None"
    end
    return table.concat(traitList, ", ")
end

-- Check if brainrot should go to normal webhook
local function shouldUseNormalWebhook(brainrotName)
    for _, normalName in ipairs(normalWebhookBrainrots) do
        if brainrotName == normalName then
            return true
        end
    end
    return false
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
    local mutation = overhead:FindFirstChild("Mutation")
    if not (displayName and generation and rarity) then return end

    local name, gen, rarityValue = displayName.Text, generation.Text, rarity.Text
    local mutationValue = "None"
    if mutation and mutation.Visible and mutation.Text then
        mutationValue = mutation.Text
        if mutationValue == '<stroke color="#fff" thickness="2"><font color="#000">Yin</font></stroke> <stroke color="#000" thickness="2"><font color="#fff">Yang</font></stroke>' then
            mutationValue = "Yin Yang"
        end
    end
    local traitsValue = extractTraits(overhead)
    
    -- Remove local duplicate checking - Railway handles this now
    -- local currentTime = math.floor(tick())
    -- local key = name.."|"..gen.."|"..rarityValue.."|"..game.JobId.."|"..currentTime
    -- local recentKey = name.."|"..gen.."|"..rarityValue.."|"..game.JobId
    -- if sentBrainsGlobal[recentKey] and (currentTime - sentBrainsGlobal[recentKey]) < 30 then 
    --     return 
    -- end
    -- sentBrainsGlobal[recentKey] = currentTime

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
            {name="🧬 Mutation", value=mutationValue, inline=true},
            {name="🎭 Traits", value=traitsValue, inline=true},
            {name="☀️ Owner", value=plotOwner.." (Floor "..floorNum..")", inline=true},
            {name="🆔 Job ID", value="```"..jobId.."```"},
            {name="💻 Join Script", value="`game:GetService(\"TeleportService\"):TeleportToPlaceInstance("..PlaceID..",\""..jobId.."\",game.Players.LocalPlayer)\n`"},
            {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"}
        },
        author = {name="🧩 Puzzle's Notifier"},
        footer = {text = "Puzzle Brainrot Finder"},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
    }

    -- Check if this brainrot should use normal webhook regardless of generation
    if shouldUseNormalWebhook(name) then
        embed.color = 0xFFFFFF
        SendMessageEMBED({webhookUrl, zzzHubWebhook}, embed)
    elseif genNumber >= 15e6 then
        embed.color, embed.ping = 0xFF0000, true
        SendMessageEMBED({highValueWebhookUrl}, embed)
    elseif genNumber >= 5e6 then
        embed.color = 0xFFA500
        SendMessageEMBED({highValueWebhookUrl}, embed)
    else
        embed.color = 0xFFFFFF
        SendMessageEMBED({webhookUrl, zzzHubWebhook}, embed)
    end

    -- Ultra high value special embed (only for non-normal webhook brainrots)
    if genNumber >= 15e6 and not shouldUseNormalWebhook(name) then
        local formattedName = name:gsub("%s+", "")
        local thumbnailUrl = "https://raw.githubusercontent.com/tfvs/brainrot-images/main/"..formattedName..".png"

        local footerTimestamp = "Today at " .. os.date("%I:%M %p")

        local specialEmbed = {
            title = "HIGH VALUE SECRET FOUND",
            description = "Want access to high end secrets?\n<#1413894765526913155>",
            color = 16730698,
            fields = {
                {name = "Generation", value = gen},
                {name = "Secret", value = name}
            },
            thumbnail = {url = thumbnailUrl},
            footer = {text = footerTimestamp}
        }

        -- Check if ultra high webhook was recently sent
        local ultraEmbedContent = HttpService:JSONEncode(specialEmbed)
        if not wasWebhookRecentlySent(ultraHighWebhookUrl, ultraEmbedContent) then
            local data = {content = nil, embeds = {specialEmbed}, attachments = {}}
            SendWebhook(ultraHighWebhookUrl, data)
        else
            SendDebug("Skipping duplicate ultra high webhook message")
        end
    end
end

-- Scan plots multiple times to ensure all brainrots are detected
local function scanPlotsMultiple()
    local currentTime = tick()
    
    -- Check scan cooldown
    if currentTime - lastScanTime < scanCooldown then
        local remainingTime = scanCooldown - (currentTime - lastScanTime)
        SendDebug("Scan cooldown active. Waiting " .. math.ceil(remainingTime) .. " more seconds.")
        return
    end
    
    lastScanTime = currentTime
    
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

    -- Perform multiple scans with delays to catch all brainrots
    SendDebug("Starting comprehensive scan (3 passes).")
    local totalFound = 0
    
    -- First scan - immediate
    totalFound = totalFound + scanOnce()
    task.wait(1) -- Wait for any delayed loading
    
    -- Second scan - after brief delay
    totalFound = totalFound + scanOnce()
    task.wait(8) -- Wait longer for slower loading
    
    -- Third scan - final check
    totalFound = totalFound + scanOnce()
    
    SendDebug("Comprehensive scan completed. Total podiums processed: "..totalFound)
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

-- Fetch servers via Cloudflare proxy with fallback to direct Roblox API
local function getServers()
    local servers = {}
    local maxAttempts = 3
    local proxyBase = "https://spring-leaf-5b44.macaroniwithtony67.workers.dev/servers/" .. PlaceID .. "?excludeJobId=" .. (game.JobId or "")

    -- Try Cloudflare proxy first
    for attempt = 1, maxAttempts do
        -- Increased jitter to spread requests better
        task.wait(0.1 + (LocalPlayer.UserId % 10) * 0.05 + math.random() * 0.1)

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
                if #servers > 0 then
                    SendDebug("Fetched "..#servers.." joinable servers via Cloudflare proxy")
                    return servers
                else
                    SendDebug("Cloudflare proxy returned 0 valid servers on attempt "..attempt)
                end
            else
                SendDebug("Failed to parse Cloudflare proxy response on attempt "..attempt)
            end
        else
            SendDebug("Failed to fetch from Cloudflare proxy on attempt "..attempt)
        end

        if attempt < maxAttempts then
            task.wait(0.5 * (attempt + 1))
        end
    end

    -- Fallback: Try direct Roblox API if Cloudflare fails
    SendDebug("Cloudflare proxy failed, trying direct Roblox API as fallback")
    local fallbackUrl = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=50"
    
    for attempt = 1, 2 do
        task.wait(0.2 + math.random() * 0.3) -- Small delay for fallback
        
        local success, response = pcall(function()
            return game:HttpGet(fallbackUrl)
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
                if #servers > 0 then
                    SendDebug("Fallback: Fetched "..#servers.." joinable servers via direct Roblox API")
                    return servers
                end
            end
        end
        
        if attempt < 2 then
            task.wait(1)
        end
    end

    -- If still no servers, wait and retry the whole process
    if #servers == 0 then
        SendDebug("All server fetch methods failed, waiting 5-10 seconds before retry")
        task.wait(5 + math.random() * 5)
        return getServers() -- Recursive retry
    end
    
    return servers
end

-- Server hopping with random selection & fast retry
local function hopToNewServer()
    if isTeleporting then SendDebug("Already teleporting") return end
    
    -- Send collected debug logs before hopping
    SendDebugLogs(teleportFailureCount)
    
    isTeleporting = true
    lastTeleportTime = tick() -- Track when teleport started
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
task.spawn(function()
    while true do
        SendDebug("Starting scan and hop cycle.")
        scanPlotsMultiple() -- Complete comprehensive scan (3 passes with delays)
        task.wait(3) -- Buffer to ensure all webhooks are sent
        SendDebug("Initiating server hops.")
        hopToNewServer() -- Hop to a new server after scanning
        task.wait(3) -- Delay before starting the next cycle
    end
end)
