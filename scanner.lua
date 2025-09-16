-- Optimized Brainrot Finder (scan-on-join, 15s wait, scan again, hop)
-- Key changes:
-- 1) Single initial scan, wait 15s, second scan (no duplicates from first scan)
-- 2) No long de-dupe timers across hops (dedupe only for this run)
-- 3) Removed persistent ChildAdded/PlayerAdded listeners to save CPU/RAM
-- 4) Faster, bounded server-hop retry/backoff (keeps total delay low)
-- 5) Minor CPU optimizations and fixed webhook send ordering
-- 6) Full workspace and GUI optimizations integrated

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
local startTime = tick()
local processedPodiums = {}    -- per-run processed podiums
local sentBrains = {}          -- per-run dedupe for brain sends
local sentMessages = {}        -- per-run dedupe for discord embeds
local decalsyeeted = true      -- remove decals for fps boost

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"

-- Minimal chat spam
local TextChatService = game:GetService("TextChatService")
pcall(function()
    local generalChannel = TextChatService.TextChannels.RBXGeneral
    if generalChannel then
        local messages = {"Want servers have 10m+ Sęcret Pęts?", "Easy brainrots! ínvítạtíọn: brainrotfinder"}
        for _, msg in ipairs(messages) do
            pcall(function() generalChannel:SendAsync(msg) end)
            task.wait(0.9)
        end
    end
end)

-- Embed sender
local function SendMessageEMBED(urls, embed)
    local messageId = HttpService:JSONEncode({ description = embed.description or "", fields = embed.fields or {} })
    if sentMessages[messageId] then return end
    sentMessages[messageId] = true

    local data = {
        embeds = {{
            description = embed.description,
            color = embed.color or 0,
            fields = embed.fields,
            author = embed.author,
            footer = embed.footer,
            timestamp = embed.timestamp
        }}
    }
    if embed.ping then data.content = embed.ping end
    local body = HttpService:JSONEncode(data)

    for _, url in ipairs(urls) do
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

-- Player/server helper
local function getPlayerData()
    local playerCount = (#Players:GetPlayers()) .. "/8"
    local jobId = game.JobId or "N/A"
    local placeId = game.PlaceId
    local joinLink = jobId == "N/A" and "N/A (Public server)" or string.format(
        "https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s",
        placeId, jobId
    )
    return playerCount, jobId, placeId, joinLink
end

-- Process podium
local function processPodium(podium)
    if not podium or processedPodiums[podium] then return end
    processedPodiums[podium] = true

    local overhead = podium:FindFirstChild("AnimalOverhead") or podium:FindFirstChildWhichIsA("Model", true)
    if not overhead then overhead = podium:FindFirstChild("AnimalOverhead", true) if not overhead then return end end

    local displayName = overhead:FindFirstChild("DisplayName")
    local generation = overhead:FindFirstChild("Generation")
    local rarity = overhead:FindFirstChild("Rarity")
    if not (displayName and generation and rarity) then return end

    local name = tostring(displayName.Text or "")
    local gen = tostring(generation.Text or "")
    local rarityValue = tostring(rarity.Text or "")
    local key = name.."|"..gen.."|"..rarityValue.."|"..(game.JobId or "N/A")
    if sentBrains[key] then return end

    local numberMatch = gen:match("(%d+%.?%d*)")
    local genNumber = tonumber(numberMatch) or 0
    if gen:find("M", 1, true) then genNumber = genNumber * 1000000
    elseif gen:find("K", 1, true) then genNumber = genNumber * 1000 end
    if genNumber < 1000000 then return end

    sentBrains[key] = true

    local playerCount, jobId, _, joinLink = getPlayerData()
    local embed = {
        description = "# 🧠 "..name.." | 💰 "..gen.." | 👥 "..playerCount,
        fields = {
            { name="🐾 Brainrot Name", value=name, inline=true },
            { name="📜 Income", value=gen, inline=true },
            { name="👥 Player Count", value=playerCount, inline=true },
            { name="✨ Rarity", value=rarityValue, inline=true },
            { name="🆔 Job ID", value="```"..jobId.."```" },
            { name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..PlaceID..", \""..jobId.."\", game.Players.LocalPlayer)\n```" },
            { name="🔗 Join Link", value=jobId=="N/A" and "N/A" or ("[Click to Join]("..joinLink..")") },
        },
        author = { name="🧩 Puzzle's Notifier" },
        footer = { text="Made by tt.72" },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        ping = false
    }

    if genNumber >= 10000000 then
        embed.color = 0xFF0000
        embed.ping = "<@&1414643713426194552>"
        SendMessageEMBED({highValueWebhookUrl, debugWebhookUrl}, embed)
    elseif genNumber >= 5000000 then
        embed.color = 0xFFA500
        SendMessageEMBED({highValueWebhookUrl}, embed)
    else
        embed.color = 0xFFFFFF
        SendMessageEMBED({webhookUrl, zzzHubWebhook}, embed)
    end
end

-- Scan Plots once
local function scanPlotsOnce()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then return 0 end

    local found = 0
    for _, playerBase in ipairs(plotsFolder:GetChildren()) do
        local podiumsFolder = playerBase:FindFirstChild("AnimalPodiums")
        if podiumsFolder then
            for _, podium in ipairs(podiumsFolder:GetChildren()) do
                pcall(function() processPodium(podium) found = found + 1 end)
            end
        end
    end
    return found
end

-- Workspace & visual optimization
pcall(function()
    RunService:Set3dRenderingEnabled(false)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.ClockTime = 14
    settings().Rendering.QualityLevel = "Level01"

    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
        elseif (v:IsA("Decal") or v:IsA("Texture")) and decalsyeeted then
            v.Transparency = 1
        elseif v:IsA("ParticleEmitter") then
            v.Lifetime = NumberRange.new(0,0)
            v.Rate = 0
            v.Enabled = false
        elseif v:IsA("Trail") then
            v.Enabled = false
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") then
            v.Enabled = false
        elseif v:IsA("MeshPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
            v.TextureID = 10385902758728957
        end
    end

    for _, e in pairs(Lighting:GetChildren()) do
        if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
            e.Enabled = false
        end
    end

    -- Hide all GUI except custom
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Name ~= "BrainrotFinderUI" then
            pcall(function() gui.Enabled = false end)
        end
    end

    -- Remove bulky workspace objects
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name ~= "Plots" and not obj:IsA("Terrain") then
            if obj:IsA("Model") or obj:IsA("MeshPart") or obj:IsA("UnionOperation") or obj:IsA("Part") then
                if not obj:IsDescendantOf(Workspace:FindFirstChild("Plots")) then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end

    pcall(function() setfpscap(15) end)
end)

-- UI feedback
pcall(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui", 2)
    if playerGui then
        local ScreenGui = Instance.new("ScreenGui", playerGui)
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
    end
end)

-- Server listing helper
local function getServers()
    local servers = {}
    local url = "https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=50"
    local success, response = pcall(function() return game:HttpGet(url) end)
    if success and response and response ~= "" then
        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if ok and data and data.data then
            for _, server in ipairs(data.data) do
                if tonumber(server.playing) and tonumber(server.maxPlayers) and tonumber(server.playing) < tonumber(server.maxPlayers) and server.id ~= game.JobId then
                    table.insert(servers, server)
                end
            end
        end
    end
    return servers
end

-- Hop helper
local function hopToNewServer()
    local maxAttempts = 6
    local baseDelay = 0.5
    for attempt=1,maxAttempts do
        local servers = getServers()
        if #servers > 0 then
            local targetServer = servers[math.random(1,#servers)]
            local ok,_ = pcall(function()
                TeleportService:TeleportToPlaceInstance(PlaceID, targetServer.id, LocalPlayer)
            end)
            local elapsedTime = math.floor(tick() - startTime)
            pcall(function()
                SendMessageEMBED({debugWebhookUrl}, {
                    description="**"..(LocalPlayer and LocalPlayer.Name or "Unknown").."** attempted hop (try "..attempt..") after ⏰ "..elapsedTime.."s.",
                    color = elapsedTime>60 and 0xFF0000 or 0xFFFFFF,
                    timestamp=os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
                    author={name=LocalPlayer and LocalPlayer.Name or "client"}
                })
            end)
            if ok then return true else task.wait(baseDelay*math.min(attempt,3)) end
        else
            task.wait(baseDelay*math.min(attempt,4))
        end
    end
    return false
end

-- Main flow
spawn(function()
    scanPlotsOnce()
    task.wait(15)
    scanPlotsOnce()
    hopToNewServer()
end)
