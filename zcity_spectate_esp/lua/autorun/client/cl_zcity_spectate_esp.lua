if SERVER then return end

--[[----------------------------------------------------------------
    ZCity Spectate ESP
    Compact grayscale overlay for spectators.
------------------------------------------------------------------]]

surface.CreateFont("ZCitySpec.Name", {
    font      = "Roboto",
    size      = 15,
    weight    = 600,
    antialias = true,
    extended  = true
})

surface.CreateFont("ZCitySpec.NameShadow", {
    font      = "Roboto",
    size      = 15,
    weight    = 600,
    antialias = true,
    blursize  = 2,
    extended  = true
})

surface.CreateFont("ZCitySpec.HP", {
    font      = "Roboto",
    size      = 13,
    weight    = 700,
    antialias = true,
    extended  = true
})

surface.CreateFont("ZCitySpec.Hint", {
    font      = "Roboto",
    size      = 14,
    weight    = 500,
    antialias = true,
    extended  = true
})

-- Palette (grayscale)
local COL_PANEL    = Color(22, 23, 25)
local COL_PANEL_HL = Color(40, 42, 45)
local COL_BORDER   = Color(64, 66, 70)
local COL_TEXT     = Color(232, 234, 237)
local COL_TEXT_DIM = Color(146, 149, 154)
local COL_TRACK    = Color(46, 48, 51)
local COL_HP_HIGH  = Color(196, 199, 204)
local COL_HP_LOW   = Color(108, 110, 114)
local COL_CONNECT  = Color(90, 93, 98)

local SpectateHideNick = false
local keyOld = false
local lerpData = {}

net.Receive("ZCity_Spectator_Health_Sync", function()
    local count = net.ReadUInt(8)
    for i = 1, count do
        local ply = net.ReadEntity()
        local health = net.ReadFloat()
        if IsValid(ply) then
            ply.ZCitySpectatorHealth = health
        end
    end
end)

local function lerpColor(a, b, frac)
    return Color(
        a.r + (b.r - a.r) * frac,
        a.g + (b.g - a.g) * frac,
        a.b + (b.b - a.b) * frac
    )
end

local function drawPanel(x, y, w, h, alpha)
    draw.RoundedBox(5, x, y, w, h, ColorAlpha(COL_PANEL, alpha))
    draw.RoundedBoxEx(5, x, y, w, math.ceil(h * 0.5), ColorAlpha(COL_PANEL_HL, alpha * 0.3), true, true, false, false)
    surface.SetDrawColor(COL_BORDER.r, COL_BORDER.g, COL_BORDER.b, alpha * 0.55)
    surface.DrawOutlinedRect(x, y, w, h, 1)
end

hook.Add("HUDPaint", "ZCity_Spectate_ALT_ESP", function()
    local lply = LocalPlayer()
    if not IsValid(lply) then return end
    if lply:Alive() and lply:GetObserverMode() == OBS_MODE_NONE then return end

    local key = input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
    if keyOld ~= key and key then
        SpectateHideNick = not SpectateHideNick
    end
    keyOld = key

    -- Hint pill (bottom-left)
    do
        local label = SpectateHideNick and "Nicknames hidden" or "Nicknames visible"
        local hint  = "ALT  -  " .. label
        surface.SetFont("ZCitySpec.Hint")
        local hw, hh = surface.GetTextSize(hint)
        local padX, padY = 12, 6
        local dot = 7
        local boxW = dot + 8 + hw + padX * 2
        local boxH = hh + padY * 2
        local bx, by = 16, ScrH() - boxH - 18
        drawPanel(bx, by, boxW, boxH, 235)

        local cy = by + boxH * 0.5
        local dotCol = SpectateHideNick and COL_TEXT_DIM or COL_TEXT
        draw.RoundedBox(dot * 0.5, bx + padX, cy - dot * 0.5, dot, dot, dotCol)
        draw.SimpleText(hint, "ZCitySpec.Hint", bx + padX + dot + 8, cy, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    if SpectateHideNick then return end

    local ft = FrameTime()

    for _, v in ipairs(player.GetAll()) do
        if not v:Alive() or v == lply then continue end

        local ent = IsValid(v:GetNWEntity("Ragdoll")) and v:GetNWEntity("Ragdoll") or v
        local pos = ent:GetPos()
        pos.z = pos.z + 16
        local screen = pos:ToScreen()
        if not screen.visible then continue end

        local x, y = math.Round(screen.x), math.Round(screen.y)

        local distance = lply:GetPos():Distance(v:GetPos())
        local factor = 1 - math.Clamp(distance / 2200, 0, 1)
        factor = math.ease.OutQuad(factor)
        local alpha = math.Clamp(255 * factor, 60, 255)

        -- Smoothed health
        local rawHealth = v.ZCitySpectatorHealth or v:Health()
        local healthFrac = math.Clamp(rawHealth / 100, 0, 1)
        local cache = lerpData[v]
        if not cache then
            cache = { hp = healthFrac }
            lerpData[v] = cache
        end
        cache.hp = Lerp(math.Clamp(ft * 8, 0, 1), cache.hp, healthFrac)
        local hp = cache.hp

        -- Measure text
        local name = v:Name()
        surface.SetFont("ZCitySpec.Name")
        local nameW, nameH = surface.GetTextSize(name)

        local hpTxt = tostring(math.Round(hp * 100))
        surface.SetFont("ZCitySpec.HP")
        local hpW, hpH = surface.GetTextSize(hpTxt)

        -- Layout: [ name  <gap>  hp ] over a full-width bar
        local padX  = 9
        local padTop = 5
        local rowGap = 5   -- between name row and bar
        local barH  = 3
        local colGap = 12  -- between name and hp

        local rowH   = math.max(nameH, hpH)
        local innerW = nameW + colGap + hpW
        local panelW = innerW + padX * 2
        local panelH = padTop + rowH + rowGap + barH + padTop

        local px = math.Round(x - panelW * 0.5)
        local py = math.Round(y - panelH - 12)

        drawPanel(px, py, panelW, panelH, alpha)

        -- Connector line toward the player
        surface.SetDrawColor(COL_CONNECT.r, COL_CONNECT.g, COL_CONNECT.b, alpha * 0.5)
        surface.DrawLine(x, py + panelH, x, y)

        -- Name (left) with soft shadow
        local rowY = py + padTop + rowH * 0.5
        local nameX = px + padX
        draw.SimpleText(name, "ZCitySpec.NameShadow", nameX, rowY + 1, ColorAlpha(color_black, alpha * 0.55), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(name, "ZCitySpec.Name", nameX, rowY, ColorAlpha(COL_TEXT, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- HP value (right)
        local hpCol = lerpColor(COL_HP_LOW, COL_HP_HIGH, hp)
        draw.SimpleText(hpTxt, "ZCitySpec.HP", px + panelW - padX, rowY, ColorAlpha(hpCol, alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

        -- Health bar (full inner width)
        local barW = panelW - padX * 2
        local barX = px + padX
        local barY = py + padTop + rowH + rowGap
        draw.RoundedBox(2, barX, barY, barW, barH, ColorAlpha(COL_TRACK, alpha))
        if hp > 0.01 then
            draw.RoundedBox(2, barX, barY, math.max(barH, barW * hp), barH, ColorAlpha(hpCol, alpha))
        end
    end
end)

-- Clean interpolation cache
hook.Add("Think", "ZCity_Spectate_ESP_Cleanup", function()
    for ply in pairs(lerpData) do
        if not IsValid(ply) then
            lerpData[ply] = nil
        end
    end
end)
