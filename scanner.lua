-- Optimized Brainrot Finder with working webhooks, debug, and Join Script

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
local isTeleporting = false
local processedPodiums = {}
local sentBrains = {}
local sentMessages = {}
local decalsyeeted = true

-- Webhooks
local webhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local highValueWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local zzzHubWebhook = "https://discord.com/api/webhooks/1416751065080008714/0PDDHTPpHsVUeOqA0Hoabz0CPznl1t4LqNiOGcgDGHT1WHRoPcoSkdSO7EM-3K2tEkhh"

-- Debug helper
local function SendDebug(msg)
    print("[DEBUG]", msg)
    local success, err = pcall(function()
        local data = {
            content = "[DEBUG] " .. msg
        }
        request({
            Url = debugWebhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    if not success then
        warn("[DEBUG ERROR] Failed to send webhook: " .. tostring(err))
    end
end
-- Working Embed Sender
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
        local embedCopy = table.clone(embed) -- clone so each URL can be modified separately

        -- Special handling for zzzHub
        if url == zzzHubWebhook then
            embedCopy.footer = { text = "zzz hub x gg/brainrotfinder" }
            if not embedCopy.author then
                embedCopy.author = {}
            end
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
                Headers = {["Content-Type"] = "application/json"},
                Body = body
            })
        end)
    end
end


-- Player/server info
local function getPlayerData()
    local playerCount = #Players:GetPlayers().."/8"
    local jobId = game.JobId or "N/A"
    local placeId = game.PlaceId
    local joinLink = jobId=="N/A" and "N/A (Public server)" or string.format(
        "https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s", placeId, jobId
    )
    return playerCount, jobId, placeId, joinLink
end

-- Process a single podium
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
        embed.ping = false
        SendMessageEMBED(highValueWebhookUrl, embed)

    else
        embed.color = 0xFFFFFF
        SendMessageEMBED(webhookUrl, zzzHubWebhook, embed)
    end
end

-- Scan all plots once
local function scanPlotsOnce()
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if not plotsFolder then
        SendDebug("Plots folder not found.")
        return 0
    end

    local found = 0
    for _, playerBase in ipairs(plotsFolder:GetChildren()) do
        local podiumsFolder = playerBase:FindFirstChild("AnimalPodiums")
        if podiumsFolder then
            for _, podium in ipairs(podiumsFolder:GetChildren()) do
                pcall(function() processPodium(podium) found = found + 1 end)
            end
        end
    end
    SendDebug("ScanPlotsOnce found "..found.." podiums.")
    return found
end

-- Workspace & visual optimizations
pcall(function()
    RunService:Set3dRenderingEnabled(false)
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.ClockTime = 14
    settings().Rendering.QualityLevel = "Level03"

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
        elseif v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
            v.Enabled = false
        elseif v:IsA("Explosion") then
            v.BlastPressure = 1
            v.BlastRadius = 1
        elseif v:IsA("MeshPart") then
            v.Material = "Plastic"
            v.Reflectance = 0
            v.TextureID = 10385902758728957
        end
    end

    for _, e in pairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then e.Enabled=false end
    end
    SendDebug("Workspace optimization complete.")
end)

-- Hide all other GUIs
for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
    if gui:IsA("ScreenGui") and gui.Name ~= "BrainrotFinderUI" then
        gui.Enabled = false
    end
end

-- Preserve Plots and remove other objects
local function preservePathToPlots()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then
        SendDebug("No Plots folder to preserve.")
        return
    end
    local preserve,obj = {},plots
    while obj and obj ~= Workspace do
        preserve[obj] = true
        obj = obj.Parent
    end
    preserve[Workspace] = true

    for _,child in ipairs(Workspace:GetChildren()) do
        if not preserve[child] then
            pcall(function() child:Destroy() end)
        end
    end
    SendDebug("Workspace cleaned except Plots.")
end

preservePathToPlots()

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

-- Main flow: scan-on-join, 15s wait, scan again, hop
spawn(function()
    scanPlotsOnce()
    task.wait(15)
    scanPlotsOnce()

    local function getServers()
        local servers = {}
        local url = "https://games.roblox.com/v1/games/"..PlaceID.."/servers/Public?sortOrder=Asc&limit=100"
        local success,response = pcall(function() return game:HttpGet(url) end)
        if success and response~="" then
            local ok,data = pcall(function() return HttpService:JSONDecode(response) end)
            if ok and data and data.data then
                for _,server in ipairs(data.data) do
                    if tonumber(server.playing)<tonumber(server.maxPlayers) and server.id~=game.JobId then
                        table.insert(servers,server)
                    end
                end
            end
        end
        SendDebug("Found "..#servers.." available servers.")
        return servers
    end

    local function hop()
        if isTeleporting then return end
        isTeleporting = true
        local servers = getServers()
        if #servers == 0 then
            isTeleporting = false
            task.delay(1, hop)
            return
        end
        local targetServer = servers[math.random(1,#servers)]
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceID,targetServer.id,LocalPlayer)
        end)
        if success then
            SendDebug("Teleporting to server: "..targetServer.id)
        else
            SendDebug("Failed to teleport: "..tostring(err))
        end
        isTeleporting = false
    end

    hop()
end)
