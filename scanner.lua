local workspace = game:GetService("Workspace")
local teleportService = game:GetService("TeleportService")
local players = game:GetService("Players")
local lighting = game:GetService("Lighting")
local runService = game:GetService("RunService")
local brainrotTable = {}
local scannedBrainrots = {}
local freeWebhookUrl = "https://discord.com/api/webhooks/1413509205415170058/MIAXe3Xyt_gNhvRlaPALmEy6jWtD1Y6D6Q9SDdlzGdRGXyPnUDekeg_bGyF5-Js5aJde"
local paidWebhookUrl = "https://discord.com/api/webhooks/1413908979930628469/EjsDg2kHlaCkCt8vhsLR4tjtH4Kkq-1XWHl1gQwjdgEs6TinMs6m0JInfk2B_RSv4fbX"
local debugWebhookUrl = "https://discord.com/api/webhooks/1413717796122001418/-l-TEBCuptznTy7EiNnyQXSfuj4ASgcNMCtQnEIwSaQbEdsdqgcVIE1owi1VSVVa1a6H"
local ultraHighWebhookUrl = "https://discord.com/api/webhooks/1418234733388894359/GEMiC5lwqCiFod59U88EM8Lfkg1dc1jnjG21f1Vg_QAPPCspZ-8sUj44lhlTwEy9-eVK"
local serverApiUrl = "https://morning-wind-4aa7.verifybot17.workers.dev/servers"

-- Special brainrot names that always go to free webhook
local specialBrainrotNames = {
    "Dul Dul Dul",
    "Chachechi", 
    "La Cucaracha",
    "Sammyni Spyderini",
    "La Vacca Saturno Saturnita",
    "Crabbo Limonetta"
}
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
-- Function to send debug message
local function sendDebugMessage(description, startTime)
    local elapsedTime = os.time() - startTime
    local minutes = math.floor(elapsedTime / 60)
    local seconds = elapsedTime % 60
    local timeString = string.format("%dm %ds", minutes, seconds)
    
    local debugData = {
        content = nil,
        embeds = {
            {
                description = description,
                color = 16316664,
                author = {
                    name = players.LocalPlayer.Name,
                    icon_url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. players.LocalPlayer.UserId .. "&size=150x150&format=Png&isCircular=false"
                },
                footer = {
                    text = "🚀 Time elapsed: " .. timeString
                }
            }
        },
        attachments = {}
    }
    
    local success, response = pcall(function()
        return request({
            Url = debugWebhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(debugData)
        })
    end)
end

local function optimizeGame()
for _, obj in pairs(workspace:GetDescendants()) do
if obj:IsA("Texture") or obj:IsA("Decal") then
obj:Destroy()
end
end
lighting.Brightness = 2
lighting.Ambient = Color3.new(0.5, 0.5, 0.5)
lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
lighting.ColorShift_Top = Color3.new(0, 0, 0)
lighting.OutdoorAmbient = Color3.new(0.5, 0.5, 0.5)
lighting.ShadowSoftness = 0
lighting.GeographicLatitude = 0
lighting.ExposureCompensation = 0
lighting.FogEnd = 1000000
lighting.FogStart = 0
lighting.GlobalShadows = false
pcall(function() lighting.Bloom.Enabled = false end)
pcall(function() lighting.Blur.Enabled = false end)
pcall(function() lighting.ColorCorrection.Enabled = false end)
pcall(function() lighting.DepthOfField.Enabled = false end)
pcall(function() lighting.SunRays.Enabled = false end)
runService:Set3dRenderingEnabled(false)
end
local function getServerList(startTime)
    local maxAttempts = 3
    local proxyBase = serverApiUrl .. "/" .. game.PlaceId .. "?excludeJobId=" .. (game.JobId or "")
    
    sendDebugMessage("Fetching server list... (attempt 1/" .. maxAttempts .. ")", startTime)
    
    for attempt = 1, maxAttempts do
        wait(0.05 + (players.LocalPlayer.UserId % 6) * 0.03 + math.random() * 0.07)
        local success, response = pcall(function()
            if request then
                return request({
                    Url = proxyBase,
                    Method = "GET"
                })
            else
                error("request function not available")
            end
        end)
        if success and response then
            local body
            if type(response) == "table" and response.Body then
                body = response.Body
            elseif type(response) == "string" then
                body = response
            end
            if body and body ~= "" then
                local ok, data = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(body)
                end)
                if ok and data and data.data and type(data.data) == "table" then
                    local servers = {}
                    for _, server in pairs(data.data) do
                        if tonumber(server.playing) and tonumber(server.maxPlayers) and 
                           server.playing < server.maxPlayers - 1 and 
                           server.id and server.id ~= game.JobId then
                            table.insert(servers, server)
                        end
                    end
                    sendDebugMessage("Fetched " .. #servers .. " joinable servers via proxy", startTime)
                    return servers
                end
            end
        end
        if attempt < maxAttempts then
            sendDebugMessage("Server fetch failed, retrying... (attempt " .. (attempt + 1) .. "/" .. maxAttempts .. ")", startTime)
            wait(0.5 * (attempt + 1))
        end
    end
    sendDebugMessage("Failed to fetch servers after " .. maxAttempts .. " attempts, using fallback", startTime)
    return {
        {
            id = "fallback-" .. math.random(100000, 999999),
            playing = 1,
            maxPlayers = 8
        }
    }
end
local function serverHop(startTime)
    local servers = getServerList(startTime)
    if #servers == 0 then
        sendDebugMessage("No servers available, using fallback teleport...", startTime)
        local success, error = pcall(function()
            teleportService:Teleport(game.PlaceId, players.LocalPlayer)
        end)
        return
    end
    local randomIndex = math.random(1, #servers)
    local selectedServer = servers[randomIndex]
    if not selectedServer then
        sendDebugMessage("No suitable servers found, using fallback teleport...", startTime)
        local success, error = pcall(function()
            teleportService:Teleport(game.PlaceId, players.LocalPlayer)
        end)
        return
    end
    if selectedServer.id:find("fallback-") then
        sendDebugMessage("Using fallback teleport (no specific server)", startTime)
        local success, error = pcall(function()
            teleportService:Teleport(game.PlaceId, players.LocalPlayer)
        end)
        return
    end
    sendDebugMessage("Teleporting to server: " .. selectedServer.id, startTime)
    local success, error = pcall(function()
        teleportService:TeleportToPlaceInstance(game.PlaceId, selectedServer.id, players.LocalPlayer)
    end)
    if not success then
        sendDebugMessage("Server hop failed: " .. tostring(error) .. ", using fallback teleport...", startTime)
        local fallbackSuccess, fallbackError = pcall(function()
            teleportService:Teleport(game.PlaceId, players.LocalPlayer)
        end)
    end
end
local function getTextSafely(textLabel)
if textLabel and textLabel:IsA("TextLabel") then
return textLabel.Text
end
return ""
end
local function isTextLabelVisible(textLabel)
if textLabel and textLabel:IsA("TextLabel") then
return textLabel.Visible
end
return false
end
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
local function extractBrainrotStats(podiumModel, plotOwner)
local base = podiumModel:FindFirstChild("Base")
if not base then return nil end
local spawn = base:FindFirstChild("Spawn")
if not spawn then return nil end
local attachment = spawn:FindFirstChild("Attachment")
if not attachment then return nil end
local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
if not animalOverhead then return nil end
local displayName = animalOverhead:FindFirstChild("DisplayName")
local generation = animalOverhead:FindFirstChild("Generation")
local rarity = animalOverhead:FindFirstChild("Rarity")
local mutation = animalOverhead:FindFirstChild("Mutation")
if not displayName or not generation or not rarity then
return nil
end
local brainrotName = getTextSafely(displayName)
if brainrotName == "" then return nil end
local brainrotGeneration = getTextSafely(generation)
local brainrotRarity = getTextSafely(rarity)
local brainrotMutation = "None"
if mutation and isTextLabelVisible(mutation) then
local mutationText = getTextSafely(mutation)
brainrotMutation = mutationText:gsub("<[^>]*>", ""):gsub("^%s*(.-)%s*$", "%1")
if brainrotMutation == "" then
brainrotMutation = "None"
end
end
local brainrotTraits = extractTraits(animalOverhead)
local floorNum = getFloorNumber(podiumModel)
return {
Name = brainrotName,
Generation = brainrotGeneration,
Rarity = brainrotRarity,
Mutation = brainrotMutation,
Traits = brainrotTraits,
Owner = plotOwner,
Floor = floorNum
}
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

local function getPlotOwner(plotModel)
local plotSign = plotModel:FindFirstChild("PlotSign")
if not plotSign then return "Unknown" end
local surfaceGui = plotSign:FindFirstChild("SurfaceGui")
if not surfaceGui then return "Unknown" end
local frame = surfaceGui:FindFirstChild("Frame")
if not frame then return "Unknown" end
local textLabel = frame:FindFirstChild("TextLabel")
if not textLabel or not textLabel:IsA("TextLabel") then return "Unknown" end
local text = textLabel.Text
local username = text:gsub("'s Base$", "")
return username
end
-- Function to determine which webhook to use based on brainrot name and generation
local function getWebhookUrl(brainrotName, genNumber)
    -- Check if brainrot name is in special list
    for _, specialName in pairs(specialBrainrotNames) do
        if brainrotName == specialName then
            return freeWebhookUrl
        end
    end
    
    -- Route based on generation
    if genNumber >= 5000000 then -- 5M+
        return paidWebhookUrl
    elseif genNumber >= 1000000 then -- 1M+ but less than 5M
        return freeWebhookUrl
    else
        return nil -- Don't send if below 1M
    end
end

-- Function to send data to Discord webhook
local function sendToWebhook(data, webhookUrl)
    local success, response = pcall(function()
        return request({
            Url = webhookUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(data)
        })
    end)
    
    if success then
        print("Successfully sent data to Discord webhook")
    else
        print("Failed to send data to webhook:", response)
    end
end

local function scanPlot(plotModel)
local plotName = plotModel.Name
local plotOwner = getPlotOwner(plotModel)
local animalPodiums = plotModel:FindFirstChild("AnimalPodiums")
if not animalPodiums then
return
end
local brainrotCount = 0
for _, podiumModel in pairs(animalPodiums:GetChildren()) do
if podiumModel:IsA("Model") then
local brainrotStats = extractBrainrotStats(podiumModel, plotOwner)
if brainrotStats then
local isDuplicate = false
for _, existingBrainrot in pairs(brainrotTable) do
if existingBrainrot.Name == brainrotStats.Name and existingBrainrot.Owner == brainrotStats.Owner then
isDuplicate = true
break
end
end
if not isDuplicate then
table.insert(brainrotTable, brainrotStats)
brainrotCount = brainrotCount + 1
local brainrotKey = brainrotStats.Name .. "|" .. brainrotStats.Owner
scannedBrainrots[brainrotKey] = true
end
end
end
end
end
local function main()
    local startTime = os.time()
    print("=== Brainrot Scanner Started ===")
    
    -- Send initial debug message
    sendDebugMessage("Starting brainrot scanner...", startTime)
    
    -- Optimize game for maximum FPS
    optimizeGame()
    sendDebugMessage("Game optimized for maximum performance", startTime)
    
    local plotsFolder = workspace:WaitForChild("Plots", 10)
    if not plotsFolder then
        sendDebugMessage("ERROR: Plots folder not found!", startTime)
        return
    end
    local plotModels = {}
    for _, child in pairs(plotsFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(plotModels, child)
        end
    end
    
    sendDebugMessage("Found " .. #plotModels .. " plot models, starting scan...", startTime)
    
    for i, plotModel in pairs(plotModels) do
        scanPlot(plotModel)
        wait(0.1)
    end
    
    sendDebugMessage("First scan complete! Found " .. #brainrotTable .. " brainrots", startTime)
    
    local placeId = game.PlaceId
    local jobId = game.JobId
    local joinLink = jobId == "N/A" and "N/A (Public server)" or string.format("https://tfvs.github.io/roblox-scripts/?placeId=%d&gameInstanceId=%s", placeId, jobId)
    
    sendDebugMessage("Sending " .. #brainrotTable .. " brainrots to webhooks...", startTime)
    
    for i, brainrot in pairs(brainrotTable) do
    local genNumber = 0
    local genText = brainrot.Generation
    local numberMatch = genText:match("(%d+%.?%d*)")
    if numberMatch then
        genNumber = tonumber(numberMatch) or 0
        if genText:find("M") then
            genNumber = genNumber * 1000000
        elseif genText:find("K") then
            genNumber = genNumber * 1000
        end
    end
    
    -- Determine which webhook to use
    local targetWebhookUrl = getWebhookUrl(brainrot.Name, genNumber)
    
    -- Only send if we have a valid webhook URL
    if targetWebhookUrl then
        local embedColor = 0xFFFFFF
        local shouldPing = false
        if genNumber >= 15000000 then
            embedColor = 0xFF0000
            shouldPing = true
        elseif genNumber >= 5000000 then
            embedColor = 0xFFA500
        end
        
        local brainrotData = {
            content = shouldPing and "<@&1414068044480774185>" or nil,
            embeds = {
                {
                    description = string.format("# 🧠 %s | 📜 %s | 👥 %d/8", brainrot.Name, brainrot.Generation, #game.Players:GetPlayers()),
                    color = embedColor,
                    fields = {
                        {name="🐾 Brainrot Name", value=brainrot.Name, inline=true},
                        {name="📜 Generation", value=brainrot.Generation, inline=true},
                        {name="👥 Player Count", value=tostring(#game.Players:GetPlayers()), inline=true},
                        {name="✨ Rarity", value=brainrot.Rarity, inline=true},
                        {name="🧬 Mutation", value=brainrot.Mutation, inline=true},
                        {name="🎭 Traits", value=brainrot.Traits, inline=true},
                        {name="☀️ Owner", value=brainrot.Owner .. " (Floor " .. brainrot.Floor .. ")", inline=true},
                        {name="🆔 Job ID", value="```"..jobId.."```"},
                        {name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..placeId..",\""..jobId.."\",game.Players.LocalPlayer)\n```"},
                        {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"}
                    },
                    author = {name="🧩 Puzzle's Notifier"},
                    footer = {text = "Puzzle Brainrot Finder"},
                    timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
                }
            }
        }
        
        sendToWebhook(brainrotData, targetWebhookUrl)
        
        -- Ultra high value special embed (only for non-special brainrots)
        if genNumber >= 15000000 then
            local isSpecialName = false
            for _, specialName in pairs(specialBrainrotNames) do
                if brainrot.Name == specialName then
                    isSpecialName = true
                    break
                end
            end
            
            if not isSpecialName then
                local formattedName = brainrot.Name:gsub("%s+", "")
                local thumbnailUrl = "https://raw.githubusercontent.com/tfvs/brainrot-images/main/"..formattedName..".png"
                local footerTimestamp = "Today at " .. os.date("%I:%M %p")
                
                local specialEmbed = {
                    title = "HIGH VALUE SECRET FOUND",
                    description = "Want access to high end secrets?\n<#1413894765526913155>",
                    color = 16730698,
                    fields = {
                        {name = "Generation", value = brainrot.Generation},
                        {name = "Secret", value = brainrot.Name}
                    },
                    thumbnail = {url = thumbnailUrl},
                    footer = {text = footerTimestamp}
                }
                
                local ultraData = {content = nil, embeds = {specialEmbed}, attachments = {}}
                sendToWebhook(ultraData, ultraHighWebhookUrl)
            end
        end
        
        wait(0.5)
    end
    end
    
    sendDebugMessage("All brainrots sent! Waiting 10 seconds for second scan...", startTime)
    wait(10)
    
    sendDebugMessage("Starting second scan for new brainrots...", startTime)
    local newBrainrots = {}
    for _, plotModel in pairs(plotModels) do
        local plotName = plotModel.Name
        local plotOwner = getPlotOwner(plotModel)
        local animalPodiums = plotModel:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            for _, podiumModel in pairs(animalPodiums:GetChildren()) do
                if podiumModel:IsA("Model") then
                    local brainrotStats = extractBrainrotStats(podiumModel, plotOwner)
                    if brainrotStats then
                        local brainrotKey = brainrotStats.Name .. "|" .. brainrotStats.Owner
                        if not scannedBrainrots[brainrotKey] then
                            table.insert(newBrainrots, brainrotStats)
                            scannedBrainrots[brainrotKey] = true
                        end
                    end
                end
            end
        end
        wait(0.1)
    end
    
    if #newBrainrots > 0 then
        sendDebugMessage("Found " .. #newBrainrots .. " new brainrots in second scan!", startTime)
        for _, brainrot in pairs(newBrainrots) do
            local genNumber = 0
            local genText = brainrot.Generation
            local numberMatch = genText:match("(%d+%.?%d*)")
            if numberMatch then
                genNumber = tonumber(numberMatch) or 0
                if genText:find("M") then
                    genNumber = genNumber * 1000000
                elseif genText:find("K") then
                    genNumber = genNumber * 1000
                end
            end
            
            -- Determine which webhook to use
            local targetWebhookUrl = getWebhookUrl(brainrot.Name, genNumber)
            
            -- Only send if we have a valid webhook URL
            if targetWebhookUrl then
                local embedColor = 0xFFFFFF
                local shouldPing = false
                if genNumber >= 15000000 then
                    embedColor = 0xFF0000
                    shouldPing = true
                elseif genNumber >= 5000000 then
                    embedColor = 0xFFA500
                end
                
                local brainrotData = {
                    content = shouldPing and "<@&1414068044480774185>" or nil,
                    embeds = {
                        {
                            description = string.format("# 🧠 %s | 📜 %s | 👥 %d/8", brainrot.Name, brainrot.Generation, #game.Players:GetPlayers()),
                            color = embedColor,
                            fields = {
                                {name="🐾 Brainrot Name", value=brainrot.Name, inline=true},
                                {name="📜 Generation", value=brainrot.Generation, inline=true},
                                {name="👥 Player Count", value=tostring(#game.Players:GetPlayers()), inline=true},
                                {name="✨ Rarity", value=brainrot.Rarity, inline=true},
                                {name="🧬 Mutation", value=brainrot.Mutation, inline=true},
                                {name="🎭 Traits", value=brainrot.Traits, inline=true},
                                {name="☀️ Owner", value=brainrot.Owner .. " (Floor " .. brainrot.Floor .. ")", inline=true},
                                {name="🆔 Job ID", value="```"..jobId.."```"},
                                {name="💻 Join Script", value="```lua\ngame:GetService(\"TeleportService\"):TeleportToPlaceInstance("..placeId..",\""..jobId.."\",game.Players.LocalPlayer)\n```"},
                                {name="🔗 Join Link", value=jobId=="N/A" and "N/A" or "[Click to Join]("..joinLink..")"}
                            },
                            author = {name="🧩 Puzzle's Notifier"},
                            footer = {text = "Puzzle Brainrot Finder"},
                            timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
                        }
                    }
                }
                
                sendToWebhook(brainrotData, targetWebhookUrl)
                
                -- Ultra high value special embed (only for non-special brainrots)
                if genNumber >= 15000000 then
                    local isSpecialName = false
                    for _, specialName in pairs(specialBrainrotNames) do
                        if brainrot.Name == specialName then
                            isSpecialName = true
                            break
                        end
                    end
                    
                    if not isSpecialName then
                        local formattedName = brainrot.Name:gsub("%s+", "")
                        local thumbnailUrl = "https://raw.githubusercontent.com/tfvs/brainrot-images/main/"..formattedName..".png"
                        local footerTimestamp = "Today at " .. os.date("%I:%M %p")
                        
                        local specialEmbed = {
                            title = "HIGH VALUE SECRET FOUND",
                            description = "Want access to high end secrets?\n<#1413894765526913155>",
                            color = 16730698,
                            fields = {
                                {name = "Generation", value = brainrot.Generation},
                                {name = "Secret", value = brainrot.Name}
                            },
                            thumbnail = {url = thumbnailUrl},
                            footer = {text = footerTimestamp}
                        }
                        
                        local ultraData = {content = nil, embeds = {specialEmbed}, attachments = {}}
                        sendToWebhook(ultraData, ultraHighWebhookUrl)
                    end
                end
                
                wait(0.5)
            end
        end
    else
        sendDebugMessage("No new brainrots found in second scan", startTime)
    end
    
    sendDebugMessage("Starting server hop...", startTime)
    local serverHopStartTime = os.time()
    serverHop(startTime)
    local serverHopEndTime = os.time()
    local serverHopDuration = serverHopEndTime - serverHopStartTime
    
    -- Send final comprehensive debug summary
    local totalTime = os.time() - startTime
    local totalMinutes = math.floor(totalTime / 60)
    local totalSeconds = totalTime % 60
    local timeString = string.format("%dm %ds", totalMinutes, totalSeconds)
    
    local finalDebugData = {
        content = nil,
        embeds = {
            {
                title = "🧩 Brainrot Scanner Complete",
                description = "**Session Summary**",
                color = 65280, -- Green color
                fields = {
                    {
                        name = "👤 Roblox Username",
                        value = players.LocalPlayer.Name,
                        inline = true
                    },
                    {
                        name = "⏱️ Total Time Elapsed",
                        value = timeString,
                        inline = true
                    },
                    {
                        name = "🧠 Total Brainrots Found",
                        value = tostring(#brainrotTable),
                        inline = true
                    },
                    {
                        name = "🆕 New Brainrots (2nd Scan)",
                        value = tostring(#newBrainrots),
                        inline = true
                    },
                    {
                        name = "🚀 Server Hop Duration",
                        value = serverHopDuration .. "s",
                        inline = true
                    },
                    {
                        name = "👥 Current Players",
                        value = tostring(#game.Players:GetPlayers()) .. "/8",
                        inline = true
                    },
                    {
                        name = "🆔 Job ID",
                        value = "```" .. jobId .. "```",
                        inline = false
                    },
                    {
                        name = "📊 Webhook Distribution",
                        value = "Free: 1M-5M + Special Names\nPaid: 5M+\nDebug: All operations",
                        inline = false
                    }
                },
                author = {
                    name = "🧩 Puzzle's Notifier",
                    icon_url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. players.LocalPlayer.UserId .. "&size=150x150&format=Png&isCircular=false"
                },
                footer = {
                    text = "🚀 Total execution time: " .. timeString
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%S.000Z")
            }
        },
        attachments = {}
    }
    
    sendToWebhook(finalDebugData, debugWebhookUrl)
    
    return brainrotTable
end
local success, result = pcall(main)
