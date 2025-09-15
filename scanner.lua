--// Services
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

--// Variables
local PlaceID = game.PlaceId
local visited = {}
local isTeleporting = false
local startTime = tick()
local processedPodiums = {}
local sentBrains = {}
local sentMessages = {}

--// Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"

pcall(function()
    setfpscap(25)
end)

--// Executor HTTP request helper
local function httpRequestExecutor(url, method, headers, body)
    local reqFunc = request or http_request or syn.request
    if not reqFunc then
        warn("[HOP DEBUG] No executor HTTP request function found!")
        return nil
    end

    local req = {
        Url = url,
        Method = method or "GET",
        Headers = headers or {},
        Body = body
    }

    local ok, res = pcall(reqFunc, req)
    if not ok then
        warn("[HOP DEBUG] HTTP request failed:", res)
        return nil
    end

    if type(res) == "table" then
        return res
    elseif type(res) == "string" then
        return {Body = res, StatusCode = 200, Success = true}
    else
        return nil
    end
end

--// Fetch JSON with retries & rate-limit handling
local function getJsonExecutor(url, maxRetries)
    maxRetries = maxRetries or 3

    while maxRetries > 0 do
        local res = httpRequestExecutor(url, "GET", {["Accept"]="application/json"})
        if not res then
            warn("[HOP DEBUG] HTTP request returned nil, retrying...")
            maxRetries = maxRetries - 1
            task.wait(1)
        else
            if res.StatusCode == 429 then
                local retryAfter = tonumber(res.Headers and (res.Headers["retry-after"] or res.Headers["Retry-After"])) or 15
                print("[HOP DEBUG] 429 rate limit detected, waiting "..retryAfter.."s")
                task.wait(retryAfter)
                maxRetries = maxRetries - 1
            elseif res.StatusCode ~= 200 then
                warn("[HOP DEBUG] HTTP error "..res.StatusCode)
                task.wait(1)
                maxRetries = maxRetries - 1
            else
                if not res.Body or res.Body == "" then
                    warn("[HOP DEBUG] Empty response body")
                    return nil
                end
                local ok, json = pcall(function() return HttpService:JSONDecode(res.Body) end)
                if ok then return json
                else
                    warn("[HOP DEBUG] Failed to decode JSON. Body snippet:", string.sub(res.Body,1,200))
                    return nil
                end
            end
        end
    end

    warn("[HOP DEBUG] Exhausted retries for:", url)
    return nil
end

--// Fetch multiple pages and pick fullest joinable server
local function fetchJoinableServer()
    local servers = {}
    local cursor = ""
    repeat
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(PlaceID)
        if cursor ~= "" then url = url.."&cursor="..cursor end

        local data = getJsonExecutor(url)
        if not data or not data.data then
            print("[HOP DEBUG] No server data returned, stopping pagination.")
            break
        end

        for _, s in ipairs(data.data) do
            if s.playing < s.maxPlayers and s.id ~= game.JobId and not visited[s.id] then
                table.insert(servers, s)
            end
        end

        cursor = data.nextPageCursor or ""
    until cursor == "" or #servers >= 50 -- limit cached servers

    if #servers == 0 then
        print("[HOP DEBUG] No joinable servers found.")
        return nil
    end

    -- Pick server with highest player count
    table.sort(servers, function(a,b) return a.playing > b.playing end)
    local target = servers[1]
    return target
end

--// Hop to a new server
local function hopToNewServer()
    if isTeleporting then return end
    isTeleporting = true

    local targetServer = fetchJoinableServer()
    if not targetServer then
        isTeleporting = false
        print("[HOP DEBUG] No available servers. Retrying in 2s...")
        task.wait(2)
        return hopToNewServer()
    end

    visited[targetServer.id] = true
    print(string.format("[HOP DEBUG] Hopping to server ID: %s | %d/%d players",
        targetServer.id, targetServer.playing, targetServer.maxPlayers))

    local teleportStarted = tick()
    local teleportTimeout = 12

    task.spawn(function()
        while isTeleporting do
            if tick() - teleportStarted > teleportTimeout then
                print("[HOP DEBUG] Teleport stuck, retrying...")
                isTeleporting = false
                hopToNewServer()
                break
            end
            task.wait(1)
        end
    end)

    local success, err = pcall(function()
        task.wait(0.5)
        TeleportService:TeleportToPlaceInstance(PlaceID, targetServer.id, LocalPlayer)
    end)

    if success then
        print("[HOP DEBUG] Teleport request sent successfully.")
    else
        warn("[HOP DEBUG] Teleport failed:", err)
        isTeleporting = false
        task.wait(1)
        hopToNewServer()
    end
end

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == LocalPlayer then
        isTeleporting = false
        print("[HOP DEBUG] Teleport failed, retrying in 0.5s...")
        task.wait(0.5)
        hopToNewServer()
    end
end)

task.delay(17.5, hopToNewServer)

--// Prevent duplicate messages
local function SendMessageEMBED(...)
    local args = {...}
    local embed = args[#args]
    local urls = table.pack(table.unpack(args, 1, #args - 1))

    local messageId = HttpService:JSONEncode({
        description = embed.description,
        fields = embed.fields
    })

    if sentMessages[messageId] then return end
    sentMessages[messageId] = true

    task.delay(120, function()
        sentMessages[messageId] = nil
    end)

    for _, url in ipairs(urls) do
        local embedCopy = table.clone(embed)
        if url == zzzHubWebhook then
            embedCopy.footer = { text = "zzz hub x gg/brainrotfinder" }
            if not embedCopy.author then embedCopy.author = {} end
            embedCopy.author.url = "https://discord.gg/brainrotfinder"
        end

        local data = {
            embeds = {{
                description = embedCopy.description,
                color = embedCopy.color or 0,
                fields = embedCopy.fields,
                author = embedCopy.author,
                footer = embedCopy.footer,
                timestamp = embedCopy.timestamp
            }}
        }

        if embedCopy.ping then data.content = "<@&1414643713426194552>" end

        local body = HttpService:JSONEncode(data)

        pcall(function()
            request({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
        end)
    end
end

--// Send plain text (zzzHub)
local function SendMessagePlain(url, brainrotData)
    local message = string.format(
        "Brainrot Name: %s\nGeneration: %s\nPlayer Count: %s\nRarity: %s\nJob ID: %s\nJoin Script:\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance(%d, \"%s\", game.Players.LocalPlayer)\n\nJoin Link: %s",
        brainrotData.name,
        brainrotData.gen,
        brainrotData.playerCount,
        brainrotData.rarity,
        brainrotData.jobId,
        PlaceID,
        brainrotData.jobId,
        brainrotData.joinLink
    )

    local body = HttpService:JSONEncode({content = message})

    pcall(function()
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
end

--// Player data
local function getPlayerData()
    local playerCount = #Players:GetPlayers() .. "/8"
    local jobId = game.JobId or "N/A"
    local placeId = game.PlaceId
    local joinLink = jobId == "N/A" and "N/A (Public server)" or string.format(
        "https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s",
        placeId, jobId
    )
    return playerCount, jobId, placeId, joinLink
end

--// Podium scanner
local function processPodium(podium)
    if processedPodiums[podium] then return end
    processedPodiums[podium] = true

    local overhead
    for _, child in ipairs(podium:GetDescendants()) do
        if child.Name == "AnimalOverhead" then
            overhead = child
            break
        end
    end
    if not overhead then return end

    local displayName = overhead:FindFirstChild("DisplayName")
    local generation = overhead:FindFirstChild("Generation")
    local rarity = overhead:FindFirstChild("Rarity")
    if not (displayName and generation and rarity) then return end

    local name = tostring(displayName.Text)
    local gen = tostring(generation.Text)
    local rarityValue = tostring(rarity.Text)

    local key = name .. "|" .. gen .. "|" .. rarityValue .. "|" .. game.JobId
    if sentBrains[key] then return end
    sentBrains[key] = true

    local numberMatch = gen:match("(%d+%.?%d*)")
    local genNumber = tonumber(numberMatch) or 0
    if string.find(gen, "M", 1, true) then
        genNumber = genNumber * 1000000
    elseif string.find(gen, "K", 1, true) then
        genNumber = genNumber * 1000
    end
    if genNumber < 1000000 then return end

    local playerCount, jobId, _, joinLink = getPlayerData()
    local embed = {
        description = "# 🧠 " .. name .. " | 💰 " .. gen .. " | 👥 " .. playerCount,
        fields = {
            {name="🐾 Brainrot Name", value=name, inline=true},
            {name="📜 Income", value=gen, inline=true},
            {name="👥 Player Count", value=playerCount, inline=true},
            {name="✨ Rarity", value=rarityValue, inline=true},
            {name="🆔 Job ID", value="```"..jobId.."```"},
            {name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..PlaceID..", \""..jobId.."\", game.Players.LocalPlayer)\n```"},
            {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"},
        },
        author={name="🧩 Puzzle's Notifier"},
        footer={text="Made by tt.72"},
        timestamp=os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        ping = false
    }

    local brainrotData = {
        name = name,
        gen = gen,
        playerCount = playerCount,
        rarity = rarityValue,
        jobId = jobId,
        joinLink = jobId=="N/A" and "N/A" or joinLink
    }

    if genNumber >= 10000000 then
        embed.color = 0xFF0000
        embed.ping = true
        SendMessageEMBED(highValueWebhookUrl, embed)
    elseif genNumber >= 5000000 then
        embed.color = 0xFFA500
        SendMessageEMBED(highValueWebhookUrl, embed)
    else
        embed.color = 0xFFFFFF
        SendMessageEMBED(webhookUrl, zzzHubWebhook, embed)
    end
end

--// Scan plots
local function scanPlots()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return end
    for _, playerBase in ipairs(plotsFolder:GetChildren()) do
        local podiumsFolder = playerBase:FindFirstChild("AnimalPodiums")
        if podiumsFolder then
            for _, podium in ipairs(podiumsFolder:GetChildren()) do
                processPodium(podium)
            end
            podiumsFolder.ChildAdded:Connect(processPodium)
        end
    end
end

scanPlots()
Workspace.Plots.ChildAdded:Connect(function(newBase)
    local podiumsFolder = newBase:FindFirstChild("AnimalPodiums")
    if podiumsFolder then
        podiumsFolder.ChildAdded:Connect(processPodium)
    end
end)

--// Scan every time a player joins
Players.PlayerAdded:Connect(function(player)
    task.delay(0.5, scanPlots)
end)

--// White overlay screen
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

local whiteFrame = Instance.new("Frame", ScreenGui)
whiteFrame.Size = UDim2.new(1,0,1,0)
whiteFrame.BackgroundColor3 = Color3.new(1,1,1)
whiteFrame.BorderSizePixel = 0
whiteFrame.AnchorPoint = Vector2.new(0.5,0.5)
whiteFrame.Position = UDim2.new(0.5,0,0.5,0)

local statusLabel = Instance.new("TextLabel", whiteFrame)
statusLabel.Size = UDim2.new(1,0,0,50)
statusLabel.Position = UDim2.new(0.5,0,0.5,0)
statusLabel.AnchorPoint = Vector2.new(0.5,0.5)
statusLabel.Text = "Brainrot Finder Active"
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.TextColor3 = Color3.new(0,0,0)
statusLabel.TextScaled = true
statusLabel.TextStrokeTransparency = 0.5
statusLabel.BackgroundTransparency = 1

--// FPS Booster + Render Disable
RunService:Set3dRenderingEnabled(false)
pcall(function() setfpscap(30) end)

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.Brightness = 0
Lighting.ClockTime = 14

for _, v in pairs(Lighting:GetChildren()) do
    if v:IsA("PostEffect") then
        v.Enabled = false
    end
end

local function clearEffects(obj)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("ParticleEmitter")
        or child:IsA("Trail")
        or child:IsA("Smoke")
        or child:IsA("Fire")
        or child:IsA("Sparkles") then
            child.Enabled = false
        elseif child:IsA("Decal") or child:IsA("Texture") then
            child:Destroy()
        elseif child:IsA("MeshPart") then
            child.Material = Enum.Material.Plastic
            child.Reflectance = 0
        end
    end
end

local function preservePathToPlots()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end

    local preserve = {}
    local obj = plots
    while obj and obj ~= Workspace do
        preserve[obj] = true
        obj = obj.Parent
    end
    preserve[Workspace] = true

    for _, child in ipairs(Workspace:GetChildren()) do
        if not preserve[child] then
            child:Destroy()
        end
    end
end

preservePathToPlots()
clearEffects(workspace)

workspace.DescendantAdded:Connect(function(obj)
    task.delay(0.1, function()
        pcall(function() clearEffects(obj) end)
    end)
end)
