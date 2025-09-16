-- Services
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- Variables
local PlaceID = game.PlaceId
local isTeleporting = false
local startTime = tick()
local processedPodiums = {}
local sentBrains = {}
local sentMessages = {}

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"

local TextChatService = game:GetService("TextChatService")
local generalChannel = TextChatService.TextChannels.RBXGeneral
local messages = {"Want servers have 10m+ Sęcret Pęts?", "Easy brainrots! ínvítạtíọn: brainrotfinder"}

for _, msg in ipairs(messages) do
    generalChannel:SendAsync(msg)
    wait(1)
end

-- Prevent duplicate messages
local function SendMessageEMBED(...)
    local args = {...}
    local embed = args[#args] -- last argument is always embed
    local urls = table.pack(table.unpack(args, 1, #args - 1)) -- everything except last

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
            embedCopy.author = embedCopy.author or {}
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

        if embedCopy.ping then
            data.content = "<@&1414643713426194552>"
        end

        local body = HttpService:JSONEncode(data)

        pcall(function()
            request({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body
            })
        end)
    end
end

-- Player data
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

-- Podium scanner
local function processPodium(podium)
    if processedPodiums[podium] then return end
    processedPodiums[podium] = true

    local overhead = podium:FindFirstChild("AnimalOverhead", true)
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
    if gen:find("M", 1, true) then
        genNumber = genNumber * 1000000
    elseif gen:find("K", 1, true) then
        genNumber = genNumber * 1000
    end
    if genNumber < 1000000 then return end

    local playerCount, jobId, _, joinLink = getPlayerData()
    local embed = {
        description = "# 🧠 " .. name .. " | 💰 " .. gen .. " | 👥 " .. playerCount,
        fields = {
            { name = "🐾 Brainrot Name", value = name, inline = true },
            { name = "📜 Income", value = gen, inline = true },
            { name = "👥 Player Count", value = playerCount, inline = true },
            { name = "✨ Rarity", value = rarityValue, inline = true },
            { name = "🆔 Job ID", value = "```" .. jobId .. "```" },
            { name = "🔗 Join Link", value = jobId == "N/A" and "N/A" or "[Click to Join](" .. joinLink .. ")" },
        },
        author = { name = "🧩 Puzzle's Notifier" },
        footer = { text = "Made by tt.72" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        ping = false
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
        -- FIX: Send to zzzHubWebhook properly
        SendMessageEMBED(webhookUrl, zzzHubWebhook, embed)
    end
end

-- Scan plots
local function scanPlots()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return end
    for _, playerBase in ipairs(plotsFolder:GetChildren()) do
        local podiumsFolder = playerBase:FindFirstChild("AnimalPodiums")
        if podiumsFolder then
            for _, podium in ipairs(podiumsFolder:GetChildren()) do
                processPodium(podium)
            end
            -- ChildAdded connection once
            if not podiumsFolder:FindFirstChild("ChildAddedConnection") then
                local connection = podiumsFolder.ChildAdded:Connect(processPodium)
                local marker = Instance.new("BoolValue", podiumsFolder)
                marker.Name = "ChildAddedConnection"
            end
        end
    end
end

-- Initial scan
scanPlots()

-- New plot added
Workspace.Plots.ChildAdded:Connect(function(newBase)
    local podiumsFolder = newBase:FindFirstChild("AnimalPodiums")
    if podiumsFolder then
        for _, podium in ipairs(podiumsFolder:GetChildren()) do
            processPodium(podium)
        end
        if not podiumsFolder:FindFirstChild("ChildAddedConnection") then
            local connection = podiumsFolder.ChildAdded:Connect(processPodium)
            local marker = Instance.new("BoolValue", podiumsFolder)
            marker.Name = "ChildAddedConnection"
        end
    end
end)

-- New player joins
Players.PlayerAdded:Connect(scanPlots)

-- Server hopping
local function getServers()
    local servers, cursor = {}, ""
    local url = "https://games.roblox.com/v1/games/" .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=50"
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response and response ~= "" then
        local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(response) end)
        if decodeSuccess and data and data.data then
            for _, server in pairs(data.data) do
                if tonumber(server.playing)
                    and tonumber(server.maxPlayers)
                    and tonumber(server.playing) < tonumber(server.maxPlayers)
                    and server.id ~= game.JobId then
                    table.insert(servers, server)
                end
            end
        end
    end
    return servers
end

local function hopToNewServer()
    if isTeleporting then return end
    isTeleporting = true
    local servers = getServers()
    if #servers == 0 then
        isTeleporting = false
        task.delay(1, hopToNewServer)
        return
    end

    local targetServer = servers[math.random(1, #servers)]
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(PlaceID, targetServer.id, LocalPlayer)
    end)

    local elapsedTime = math.floor(tick() - startTime)
    if success then
        SendMessageEMBED(debugWebhookUrl, {
            description = "**" .. LocalPlayer.Name .. "** hopped servers after ⏰ " .. elapsedTime .. "s.",
            color = elapsedTime > 300 and 0xFF0000 or 0xFFFFFF,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
            author = { name = LocalPlayer.Name }
        })
        isTeleporting = false
    else
        isTeleporting = false
        task.delay(1, hopToNewServer)
    end
end

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == LocalPlayer then
        isTeleporting = false
        task.delay(1, hopToNewServer)
    end
end)

-- Hop after 15 seconds
task.delay(15, hopToNewServer)

-- White overlay screen
local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.Name = "BrainrotFinderUI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false

local whiteFrame = Instance.new("Frame", ScreenGui)
whiteFrame.Size = UDim2.new(1, 0, 1, 0)
whiteFrame.BackgroundColor3 = Color3.new(1, 1, 1)
whiteFrame.BorderSizePixel = 0

local statusLabel = Instance.new("TextLabel", whiteFrame)
statusLabel.Size = UDim2.new(1, 0, 0, 50)
statusLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
statusLabel.AnchorPoint = Vector2.new(0.5, 0.5)
statusLabel.Text = "Brainrot Finder Active"
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextColor3 = Color3.new(0, 0, 0)
statusLabel.TextScaled = true
statusLabel.BackgroundTransparency = 1

-- FPS & render booster
RunService:Set3dRenderingEnabled(false)
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.Brightness = 0
Lighting.ClockTime = 14
for _, v in pairs(Lighting:GetChildren()) do
    if v:IsA("PostEffect") then v.Enabled = false end
end

local function clearEffects(obj)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Smoke") or child:IsA("Fire") or child:IsA("Sparkles") then
            child.Enabled = false
        elseif child:IsA("Decal") or child:IsA("Texture") or child:IsA("MeshPart") then
            child:Destroy()
        end
    end
end

local function preservePathToPlots()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return end

    local preserve, obj = {}, plots
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
clearEffects(Workspace)
pcall(function() setfpscap(10) end)
