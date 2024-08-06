print("|cff00FF00[|cff00FFFFAntiBoost|cff00FF00]|cffFFFFFF -|cffFFAAAA For a boost-ad free WoW Classic experience!|r")

-- Liste med ord som må være med i meldingen for at den skal vurderes for ignorering
local mustContainWords = { "wts", "boost" }

-- Liste med erstatningsord som kan brukes i stedet for de nødvendige ordene
local replacementWords = { "maraudon", "strath","zg","cath","strat" }

-- Liste med ord som ikke må være med i meldingen for at den skal vurderes for ignorering
local avoidWords = { "lf1m", "strat", "ud" }

-- Variabel for å kontrollere umiddelbar ignorering
local instaignore = true

-- Lag en tabell for å lagre siste meldinger og tidspunkter
local recentMessages = {}

-- Lag en tabell for å holde oversikt over allerede ignorerte spillere
local ignoredPlayers = {}
-- Funksjon for å fjerne spesialtegn fra meldingen og gjøre alt til små bokstaver
local function CleanMessage(message)
    return message:gsub("[%p%s]", " "):lower()
end

-- Funksjon for å sjekke om meldingen inneholder alle nødvendige ord
local function ContainsAllMustContainWords(message)
    local cleanMessage = CleanMessage(message)
    for _, word in ipairs(mustContainWords) do
        if not cleanMessage:find("%f[%a]" .. word .. "%f[%A]") then
            return false
        end
    end
    return true
end

-- Funksjon for å sjekke om meldingen inneholder minst ett nødvendig ord og minst ett erstatningsord
local function ContainsMustAndReplacementWords(message)
    local cleanMessage = CleanMessage(message)
    local containsMustWord = false
    local containsReplacementWord = false

    for _, word in ipairs(mustContainWords) do
        if cleanMessage:find("%f[%a]" .. word .. "%f[%A]") then
            containsMustWord = true
            break
        end
    end

    for _, word in ipairs(replacementWords) do
        if cleanMessage:find("%f[%a]" .. word .. "%f[%A]") then
            containsReplacementWord = true
            break
        end
    end

    return containsMustWord and containsReplacementWord
end

-- Funksjon for å sjekke om meldingen inneholder unngåelsesord
local function ContainsAvoidWords(message)
    local cleanMessage = CleanMessage(message)
    for _, word in ipairs(avoidWords) do
        if cleanMessage:find("%f[%a]" .. word .. "%f[%A]") then
            return true
        end
    end
    return false
end

-- Funksjon for å filtrere meldinger
local function ShouldIgnoreMessage(author, message)
    -- Hvis meldingen inneholder unngåelsesord, returner FALSE
    if ContainsAvoidWords(message) then
        return false
    end

    -- Hvis meldingen inneholder alle nødvendige ord, returner TRUE
    if ContainsAllMustContainWords(message) then
        return true
    end

    -- Hvis meldingen inneholder minst ett nødvendig ord og minst ett erstatningsord, returner TRUE
    if ContainsMustAndReplacementWords(message) then
        return true
    end

    return false
end

-- Funksjon for å håndtere repeterende meldinger
local function HandleRepeatingMessages(author, message)
    -- Fjern gamle meldinger (eldre enn 60 sekunder)
    local currentTime = time()
    for k, v in pairs(recentMessages) do
        if currentTime - v.time > 60 then
            recentMessages[k] = nil
        end
    end

    -- Sjekk om meldingen er repetert på tvers av kanaler
    if recentMessages[author] then
        if recentMessages[author].message == message then
            recentMessages[author].count = recentMessages[author].count + 1
        else
            recentMessages[author].message = message
            recentMessages[author].count = 1
        end
        recentMessages[author].time = currentTime
    else
        recentMessages[author] = { message = message, count = 1, time = currentTime }
    end

    -- Returner true hvis meldingen er repetert mer enn én gang (kanal uavhengig)
    if recentMessages[author].count > 1 then
        return true
    end

    return false
end

-- Funksjon for å ignorere spillere automatisk
local function AutoIgnorePlayer(author)
    local name, realm = strsplit("-", author)
    if not realm then
        realm = GetRealmName()
    end
    name = name .. "-" .. realm

    -- Sjekk om spilleren allerede er ignorert denne sesjonen
    if ignoredPlayers[name] then
        return
    end

    -- Sjekk om spilleren allerede er ignorert i spillet
    for i = 1, C_FriendList.GetNumIgnores() do
        if C_FriendList.GetIgnoreName(i) == name then
            ignoredPlayers[name] = true
            return
        end
    end

    -- Ignorer spilleren
    C_FriendList.AddIgnore(name)
    ignoredPlayers[name] = true
    print("Auto-ignored player: " .. name .. " for selling their boosting services!")
end

-- Funksjon for å vise en popup med meldingens detaljer
local function ShowMessagePopup(author, message)
    local popup = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    popup:SetSize(300, 200)
    popup:SetPoint("CENTER")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", popup.TitleBg, "LEFT", 5, 0)
    title:SetText("Boost Seller Detected")

    local messageText = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    messageText:SetPoint("TOPLEFT", 10, -30)
    messageText:SetPoint("BOTTOMRIGHT", -10, 30)
    messageText:SetText("Player: " .. author .. "\nMessage: " .. message)

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 30)
    closeButton:SetText("Close")
    closeButton:SetPoint("BOTTOM", popup, "BOTTOM", 0, 10)
    closeButton:SetScript("OnClick", function() popup:Hide() end)

    popup:Show()
end

-- Funksjon for å lage en klikkbar melding
local function CreateClickableMessage(author, message)
    -- Lag en klikkbar melding som bruker chatlink-systemet
local chatMessage = string.format(
    "|cff00ff00Booster has been detected!|r |Hshowmessage:%s:%s|h[More Information]|h",
    
    author, message
)
ChatFrame1:AddMessage(chatMessage, 1.0, 1.0, 0.0)
end

-- Event frame for å fange opp meldinger
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_CHANNEL")
f:RegisterEvent("CHAT_MSG_SAY")
f:RegisterEvent("CHAT_MSG_YELL")

f:SetScript("OnEvent", function(self, event, message, author, ...)
    -- Først, sjekk om meldingen inneholder nødvendige ord og ikke inneholder unngåelsesord
    if ShouldIgnoreMessage(author, message) then
        if instaignore then
            AutoIgnorePlayer(author)
        else
            -- Hvis meldingen skal ignoreres, sjekk om den er repeterende
            if HandleRepeatingMessages(author, message) then
                AutoIgnorePlayer(author)
            end
        end
        -- Opprett en klikkbar melding
        CreateClickableMessage(author, message)
        return true -- Hindre visning av meldingen
    end
end)





-- Definer en funksjon som skal håndtere eventet
local function OnHyperlinkClick(self, link, text, button)
    print("we clicked a hl")
    local linkType, author, message = strsplit(":", link)
    if linkType == "showmessage" then
        print("Author: " .. author)
        print("Message: " .. message)
        -- Gjør noe med informasjonen, f.eks. vis en ny dialogboks eller meldingsboks
    end
end

-- Registrer event handler for HyperlinkClick
ChatFrame1:HookScript("OnHyperlinkClick", OnHyperlinkClick)

