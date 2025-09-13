--// Services
local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local Lighting         = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------------------------------------------
--// Configuration
----------------------------------------------------------------------------------------------------
local Config = {
    PlaceID   = game.PlaceId,
    FPSCap    = 25,

    Webhooks = {
        Default   = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde",
        HighValue = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX",
        Debug     = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
    },

    Thresholds = {
        {limit = 15000000, color = 0xFF0000, ping = true,  webhook = "HighValue"},
        {limit =  5000000, color = 0xFFA500, ping = true,  webhook = "HighValue"},
        {limit =  1000000, color = 0xFFFFFF, ping = false, webhook = "Default"},
    }
}

----------------------------------------------------------------------------------------------------
--// Utilities
----------------------------------------------------------------------------------------------------
local Util = {}

function Util.formatNumber(str)
    local num = tonumber(str:match("(%d+%.?%d*)")) or 0
    if str:find("M") then
        num = num * 1000000
    elseif str:find("K") then
        num = num * 1000
    end
    return num
end

function Util.jsonEncode(tbl)
    return HttpService:JSONEncode(tbl)
end

function Util.request(url, payload)
    return pcall(function()
        request({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = Util.jsonEncode(payload)
        })
    end)
end

----------------------------------------------------------------------------------------------------
--// Embed Factory
----------------------------------------------------------------------------------------------------
local Embed = {}

function Embed.build(data)
    return {
        embeds = {{
            description = data.description,
            color       = data.color or 0,
            fields      = data.fields or {},
            author      = data.author,
            footer      = data.footer,
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%S.000Z"),
        }},
        content = data.ping and "<@&1414643713426194552>" or nil
    }
end

----------------------------------------------------------------------------------------------------
--// Notifier
----------------------------------------------------------------------------------------------------
local Notifier = {}
Notifier.__index = Notifier

function Notifier.new()
    return setmetatable({
        sentMessages = {},
        sentBrains   = {},
    }, Notifier)
end

function Notifier:getPlayerData()
    local actualCount = #Players:GetPlayers()
    local playerCount = math.max(actualCount - 1, 1)
    local jobId       = game.JobId or "N/A"
    local joinLink    = (jobId == "N/A") and "N/A (Public server)" or string.format(
        "https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s",
        Config.PlaceID, jobId
    )
    return playerCount, jobId, joinLink
end

function Notifier:sendOnce(webhookKey, embed)
    local id = Util.jsonEncode({ description = embed.description, fields = embed.fields })
    if self.sentMessages[id] then return end
    self.sentMessages[id] = true
    task.delay(120, function() self.sentMessages[id] = nil end)

    Util.request(Config.Webhooks[webhookKey], Embed.build(embed))
end

function Notifier:handlePodium(podium)
    if not podium or not podium.Parent then return end

    local overhead = podium:FindFirstChild("AnimalOverhead", true)
    if not overhead then return end

    local nameObj = overhead:FindFirstChild("DisplayName")
    local genObj = overhead:FindFirstChild("Generation")
    local rarityObj = overhead:FindFirstChild("Rarity")
    if not (nameObj and genObj and rarityObj) then return end

    -- Mutation lookup
    local mutationObj = overhead:FindFirstChild("Mutation")
    local mutationText = "None"
    if mutationObj and mutationObj.Visible then
        mutationText = mutationObj.Text or "None"
    end

    -- Parse generation number
    local genValue = Util.formatNumber(genObj.Text)
    if genValue < Config.Thresholds[#Config.Thresholds].limit then return end

    -- Deduplication key
    local key = table.concat({nameObj.Text, genObj.Text, rarityObj.Text, game.JobId}, "|")
    if self.sentBrains[key] then return end
    self.sentBrains[key] = true

    -- Player info
    local playerCount, jobId, joinLink = self:getPlayerData()
    local playerCountStr = playerCount .. "/8"

    -- Build embed
    local embed = {
        description = string.format("# 🧠 %s | 💰 %s | 👥 %s", nameObj.Text, genObj.Text, playerCountStr),
        fields = {
            {name="🐾 Brainrot Name", value=nameObj.Text, inline=true},
            {name="📜 Income", value=genObj.Text, inline=true},
            {name="👥 Player Count", value=playerCountStr, inline=true},
            {name="✨ Rarity", value=rarityObj.Text, inline=true},
            {name="☄️ Mutations", value=mutationText, inline=true},
            {name="🆔 Job ID", value=jobId},
            {name="💻 Join Script", value="```game:GetService(\"TeleportService\"):TeleportToPlaceInstance("..Config.PlaceID..", \""..jobId.."\", game.Players.LocalPlayer)```"},
            {name="🔗 Join Link", value=(jobId=="N/A") and "N/A" or "[Click to Join]("..joinLink..")"},
        },
        author={name="🧩 Puzzle's Notifier"},
        footer={text="Notifier System"},
    }

    -- Send based on thresholds
    for _, rule in ipairs(Config.Thresholds) do
        if genValue >= rule.limit then
            embed.color, embed.ping = rule.color, rule.ping
            self:sendOnce(rule.webhook, embed)
            break
        end
    end
end

----------------------------------------------------------------------------------------------------
--// Initialize Notifier
----------------------------------------------------------------------------------------------------
local notifier = Notifier.new()

--// Podium Scanning
local function processPodium(podium)
    notifier:handlePodium(podium)
end

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

----------------------------------------------------------------------------------------------------
--// Server Hopping
----------------------------------------------------------------------------------------------------
local isTeleporting = false
local startTime = tick()

local function getServers()
    local servers, cursor = {}, ""
    repeat
        local url = "https://games.roblox.com/v1/games/"..Config.PlaceID.."/servers/Public?sortOrder=Asc&limit=100"
        if cursor ~= "" then url = url .. "&cursor=" .. cursor end
        local success, response = pcall(function() return game:HttpGet(url) end)
        if success and response and response ~= "" then
            local decodeSuccess, data = pcall(function() return HttpService:JSONDecode(response) end)
            if decodeSuccess and data and data.data then
                for _, server in pairs(data.data) do
                    if tonumber(server.playing) and tonumber(server.maxPlayers) and tonumber(server.playing) < tonumber(server.maxPlayers) and server.id ~= game.JobId then
                        table.insert(servers, server)
                    end
                end
                cursor = data.nextPageCursor or ""
            else break end
        else break end
    until cursor == "" or #servers > 0
    return servers
end

local function hopToNewServer()
    if isTeleporting then return end
    isTeleporting = true

    local servers = getServers()
    if #servers == 0 then
        isTeleporting = false
        task.wait(5)
        return hopToNewServer()
    end

    local targetServer = servers[math.random(1, #servers)]
    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(Config.PlaceID, targetServer.id, LocalPlayer)
    end)

    local elapsedTime = math.floor(tick() - startTime)
    local avatarUrl = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=150&height=150&format=png"
    local color = elapsedTime > 300 and 0xFF0000 or 0xFFFFFF

    if success then
        notifier:sendOnce("Debug", {
            description = string.format("**%s** hopped servers after ⏰ %ds.", LocalPlayer.Name, elapsedTime),
            color = color,
            author = {name=LocalPlayer.Name, icon_url=avatarUrl}
        })
        isTeleporting = false
    else
        isTeleporting = false
        task.wait(5)
        hopToNewServer()
    end
end

TeleportService.TeleportInitFailed:Connect(function(player)
    if player == LocalPlayer then
        isTeleporting = false
        task.wait(5)
        hopToNewServer()
    end
end)

task.delay(10, hopToNewServer)

----------------------------------------------------------------------------------------------------
--// FPS / Rendering Optimizations
----------------------------------------------------------------------------------------------------
pcall(function() setfpscap(Config.FPSCap) end)
RunService:Set3dRenderingEnabled(false)
Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.Brightness = 0
Lighting.ClockTime = 14
for _, v in pairs(Lighting:GetChildren()) do if v:IsA("PostEffect") then v.Enabled = false end end

local function clearEffects(obj)
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Smoke") or child:IsA("Fire") or child:IsA("Sparkles") then
            child.Enabled = false
        elseif child:IsA("Decal") or child:IsA("Texture") then
            child:Destroy()
        elseif child:IsA("MeshPart") then
            child.Material = Enum.Material.Plastic
            child.Reflectance = 0
        end
    end
end

workspace.DescendantAdded:Connect(function(obj)
    task.delay(0.1, function() pcall(function() clearEffects(obj) end) end)
end)

----------------------------------------------------------------------------------------------------
--// Overlay
----------------------------------------------------------------------------------------------------
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
