local ADDON, ns = ...
local db
local lastPopup, lastFact, token, learn = 0, nil, 0, false
local COOLDOWN = 300 -- seconds between automatic popups

local function Msg(t) print("|cffffd200CampfireTales:|r " .. tostring(t)) end

-- Secret values (combat-restricted) must never be compared or used as keys.
local function Safe(v)
  if issecretvalue and issecretvalue(v) then return nil end
  return v
end

local function Pick()
  local pool = {}
  for _, t in ipairs(ns.facts) do pool[#pool + 1] = t end
  for _, t in ipairs(db.custom) do pool[#pool + 1] = t end
  if #pool == 0 then return nil end
  local n = #pool
  local i = math.random(n)
  if n > 1 and pool[i] == lastFact then i = (i % n) + 1 end
  lastFact = pool[i]
  return lastFact
end

-- SAY/YELL need a hardware event, so these only run from a click or typed slash command.
local function Speak(channel)
  if not lastFact then return end
  SendChatMessage(lastFact, channel)
end

local popup
local function BuildPopup()
  popup = CreateFrame("Frame", "CampfireTalesPopup", UIParent, "BackdropTemplate")
  popup:SetSize(340, 120)
  popup:SetPoint("CENTER", 0, 180)
  popup:SetFrameStrata("DIALOG")
  popup:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  popup:SetMovable(true); popup:EnableMouse(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  popup.text:SetPoint("TOPLEFT", 16, -16); popup.text:SetPoint("TOPRIGHT", -16, -16)
  popup.text:SetHeight(55); popup.text:SetJustifyH("LEFT"); popup.text:SetJustifyV("TOP")
  local function Btn(label, x, fn)
    local b = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    b:SetSize(70, 22); b:SetText(label); b:SetPoint("BOTTOMLEFT", x, 14)
    b:SetScript("OnClick", fn)
    return b
  end
  Btn("Say", 16, function() Speak("SAY"); popup:Hide() end)
  Btn("Yell", 92, function() Speak("YELL"); popup:Hide() end)
  Btn("Another", 168, function() popup.text:SetText(Pick() or "") end)
  Btn("Close", 244, function() popup:Hide() end)
  popup:Hide()
end

local function ShowPopup()
  if not popup then BuildPopup() end
  local fact = Pick()
  if not fact then Msg("No lines available."); return end
  popup.text:SetText(fact)
  popup:Show()
  token = token + 1
  local mine = token
  C_Timer.After(45, function() if mine == token and popup then popup:Hide() end end)
end

local function Matches(aura)
  local id, name = Safe(aura.spellId), Safe(aura.name)
  if id and db.watchIds[id] then return true end
  if name then
    local l = name:lower()
    for _, p in ipairs(db.patterns) do
      if l:find(p, 1, true) then return true end
    end
  end
  return false
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, a1, a2)
  if event == "ADDON_LOADED" and a1 == ADDON then
    CampfireTalesDB = CampfireTalesDB or {}
    db = CampfireTalesDB
    if db.auto == nil then db.auto = true end
    db.custom = db.custom or {}
    db.watchIds = db.watchIds or {}
    db.patterns = db.patterns or { "camp" } -- unconfirmed guess; use /campfact learn
    self:RegisterUnitEvent("UNIT_AURA", "player")
    math.randomseed(time())
  elseif event == "UNIT_AURA" then
    local info = a2
    if not info or not info.addedAuras then return end
    for _, aura in ipairs(info.addedAuras) do
      if learn then
        Msg("gained: " .. tostring(Safe(aura.name)) .. " (id " .. tostring(Safe(aura.spellId)) .. ")")
      end
      if db.auto and Matches(aura) and (GetTime() - lastPopup) > COOLDOWN then
        lastPopup = GetTime()
        ShowPopup()
        return
      end
    end
  end
end)

SLASH_CAMPFACT1 = "/campfact"
SlashCmdList.CAMPFACT = function(msg)
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = cmd:lower()
  if cmd == "" then ShowPopup()
  elseif cmd == "say" or cmd == "yell" then
    if Pick() then Speak(cmd == "say" and "SAY" or "YELL") end
  elseif cmd == "auto" then
    db.auto = (rest:lower() ~= "off"); Msg("auto popup " .. (db.auto and "on" or "off"))
  elseif cmd == "learn" then
    learn = not learn; Msg("learn mode " .. (learn and "on: sit at a campfire and read the buff names" or "off"))
  elseif cmd == "watch" and rest ~= "" then
    local n = tonumber(rest)
    if n then db.watchIds[n] = true else table.insert(db.patterns, rest:lower()) end
    Msg("watching: " .. rest)
  elseif cmd == "add" and rest ~= "" then
    if #rest > 255 then Msg("Too long (max 255).") else table.insert(db.custom, rest); Msg("Added.") end
  else
    Msg("/campfact [say|yell|auto on|off|learn|watch <id or name part>|add <text>]")
  end
end
