pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- the last light
-- ==========================================
-- apartado de pruebas / debug
modo_prueba_jefe = false
-- ==========================================
-- constantes
spr_jugador = 1
spr_brazo = 2
spr_escorpion = 4
spr_serpiente = 5
spr_antorcha_e = 6
spr_oro = 8
spr_zafiro = 9
spr_carbon = 10
spr_salida_a = 15
spr_antorcha = 16
spr_salida = 17
spr_confusion = 18
spr_veneno = 19
spr_hoguera = 20
spr_farola = 7

-- inicializar variables globales de control antes de _init
if ya_vio_instrucciones == nil then
    ya_vio_instrucciones = false
end

function _init()
    -- 0: titulo, 1: instrucciones, 2: gameplay, 3: creditos/final
    escena_actual = 0
    nivel_actual = 1
    nivel_max = 5
    antorcha = { x = 60, y = 60, spr = spr_antorcha, encendida = false }
    item_salida = { x = 90, y = 40, spr = spr_salida, activo = false }
    px = 24
    py = 24
    velocidad_base = 0.9
    velocidad = 0.9
    mirando_izq = false
    vida = 100
    sonido_gameover_sonado = false
    timer_inmunidad = 0
    radio_base = 23
    radio_luz = 23
    chispa_efecto = 0
    timer_chispa = 0
    envenenado = false
    timer_envenenamiento = 0
    burbujas_veneno = {}
    minerales = {}
    enemigos = {}
    textos_flotantes = {}
    timer_flash_dano = 0
    causa_muerte = "oscuridad"

    -- transicion
    timer_transicion = 0
    transicion_salida = false
    nivel_pendiente = 0
    mostrando_nivel_superado = false
    timer_nivel_superado = 0
    timer_apertura = 0
    timer_auto_volver = 0
    timer_en_puerta = 0

    --contador de pasos del jugador
    contador_pasos = 0

    --hoguera
    en_hoguera = false
    opcion_hoguera = 1
    descanso = false

    -- jefe final
    jefe_vida = 0
    jefe_vida_max = 0
    jefe_fase = 1
    proyectiles_jefe = {}
    jefe_muerto = false
    jefe_timer_muerte = 0
    escorpios = nil
    veces_molestado = 0
    jefe_en_intro = false
    jefe_shake = 0
    mostrando_intro_boss = false

    vida_max = 100
    combustible_max = 100
    tiene_farola = false

    -- === variables del duende ===
    en_tienda = false
    en_tienda_duende = false
    preguntando_duende = false
    opcion_tienda = 1
    opcion_pregunta_duende = 1

    -- duende (nivel 10)
    if modo_prueba_jefe == true then
        duende_x = 112
        duende_y = 280
    else
        duende_x = nil
        duende_y = nil
    end

    timer_intro = 60
    spr_jugador_actual = spr_jugador

    -- SOLO PARA TESTING
    if modo_prueba_jefe then
        cargar_nivel(5)
        escena_actual = 2
        oro = 9999
        zafiro = 9999
    else
        oro = 0
        zafiro = 0
    end
end
-->8
-- generacion de nivel

function generar_cueva_aleatoria()
    for x = 0, 31 do
        for y = 0, 31 do
            if rnd(1) > 0.25 then
                mset(x, y, 14)
            else
                mset(x, y, 30)
            end
        end
    end

    local wx = 3
    local wy = 3

    for x = 1, 4 do
        for y = 4, 7 do
            mset(x, y, 0)
        end
    end

    local suelo_objetivo = 280
    local suelo_tallado = 16

    while suelo_tallado < suelo_objetivo do
        local dir = flr(rnd(4))
        if dir == 0 and wx > 2 then
            wx -= 1
        elseif dir == 1 and wx < 29 then
            wx += 1
        elseif dir == 2 and wy > 4 then
            wy -= 1
        elseif dir == 3 and wy < 29 then
            wy += 1
        end

        for dx = 0, 1 do
            for dy = 0, 1 do
                local tile = mget(wx + dx, wy + dy)
                if tile == 14 or tile == 30 then
                    mset(wx + dx, wy + dy, 0)
                    suelo_tallado += 1
                end
            end
        end
    end
end

function posicion_valida_objeto(x, y, dist_min_entre_si, dist_min_spawn)
    local dx1 = x - item_salida.x
    local dy1 = y - item_salida.y
    local dx2 = x - px
    local dy2 = y - py
    return posicion_libre(x, y)
            and dx1 * dx1 + dy1 * dy1 > dist_min_entre_si ^ 2
            and dx2 * dx2 + dy2 * dy2 > dist_min_spawn ^ 2
end

function cargar_nivel(n)
    nivel_actual = n
    descanso = false

    if n == 1 then
        music(0)
        reload(0x2000, 0x2000, 0x1000)
        combustible = combustible_max
        px = 24
        py = 30
    elseif n == 5 then
        reload(0x2000, 0x2000, 0x1000)
        combustible = combustible_max
        px = 16
        py = 280
        duende_x = 100
        duende_y = 288
    else
        generar_cueva_aleatoria()
        px = 24
        py = 35
    end

    timer_inmunidad = 0
    antorcha.encendida = false
    antorcha.spr = spr_antorcha

    if n == 1 then
        antorcha.x = 24
        antorcha.y = 80
        item_salida.x = 16
        item_salida.y = 32
    elseif n == 5 then
        antorcha.x = -100
        antorcha.y = -100
        item_salida.x = -100
        item_salida.y = -100
    else
        -- ヌうそ correcciれ⧗n: separaciれはn estricta entre objetos en niveles aleatorios
        local dist_minima = 75 -- pれとxeles de distancia mれとnima entre antorcha y puerta
        local dist_minima_spawn = 45 -- pれとxeles de distancia respecto al jugador
        local intentos = 0

        repeat
            antorcha.x = 16 + rnd(160)
            antorcha.y = 35 + rnd(160)
            item_salida.x = 16 + rnd(160)
            item_salida.y = 35 + rnd(160)

            local dx_entre_si = antorcha.x - item_salida.x
            local dy_entre_si = antorcha.y - item_salida.y
            local dist_entre_si_sq = dx_entre_si * dx_entre_si + dy_entre_si * dy_entre_si

            local dx_p_ant = antorcha.x - px
            local dy_p_ant = antorcha.y - py
            local dist_p_ant_sq = dx_p_ant * dx_p_ant + dy_p_ant * dy_p_ant

            intentos += 1

            local valida = posicion_libre(antorcha.x, antorcha.y)
                    and posicion_libre(item_salida.x, item_salida.y)
                    and dist_entre_si_sq > (dist_minima * dist_minima)
                    and dist_p_ant_sq > (dist_minima_spawn * dist_minima_spawn)
            -- distancia entre la antorcha y la puerta

            -- distancia de la antorcha al jugador
        until valida or intentos > 600
    end

    item_salida.activo = false
    item_salida.spr = spr_salida

    if combustible < 20 then
        combustible = 20
    end

    iniciar_minerales_nivel()
    iniciar_enemigos_nivel(n)
end

function spawn_enemigo(tipo, spr, v_base, radio_vision, danio)
    local ex, ey, intentos = 0, 0, 0
    repeat
        if nivel_actual == 1 then
            ex = 32 + rnd(40)
            ey = 32 + rnd(40)
        else
            ex = 16 + rnd(160)
            ey = 35 + rnd(160)
        end
        local dx = ex - px
        local dy = ey - py
        intentos += 1
    until (posicion_libre(ex, ey) and dx * dx + dy * dy > 40 * 40) or intentos > 200
    return {
        tipo = tipo, spr = spr, x = ex, y = ey, vx = 0, vy = 0,
        v_base = v_base, radio_vision = radio_vision, danio = danio,
        confundido = false, timer_confusion = 0, panico = false, timer_panico = 0
    }
end

function iniciar_enemigos_nivel(n)
    enemigos = {}
    if n == 5 then
        iniciar_jefe()
    elseif n > 1 then
        local num_serpientes = 2
        local num_escorpiones = (n >= 4) and 2 or 1
        for i = 1, num_serpientes do
            add(enemigos, spawn_enemigo("serpiente", spr_serpiente, 0.35, 55, 8))
        end
        for i = 1, num_escorpiones do
            add(enemigos, spawn_enemigo("escorpion", spr_escorpion, 0.2, 45, 15))
        end
    end
end

function iniciar_minerales_nivel()
    minerales = {}
    if nivel_actual == 5 then return end

    local cantidad = mid(3, 1 + nivel_actual, 5)
    for i = 1, cantidad do
        local m = {
            tipo = "carbon",
            spr = spr_carbon,
            activo = true,
            x = 0,
            y = 0
        }
        respawn_mineral(m)
        obtener_mineral_aleatorio(m)
        add(minerales, m)
    end
end

function respawn_mineral(m)
    local intentos = 0
    local dist_x, dist_y = 0, 0
    local lejos_de_otros = true
    local lejos_antorcha = true

    repeat
        if nivel_actual == 1 then
            m.x = 32 + rnd(60)
            m.y = 32 + rnd(60)
        else
            m.x = 16 + rnd(160)
            m.y = 35 + rnd(160)
        end
        dist_x = abs(m.x - px)
        dist_y = abs(m.y - py)

        lejos_de_otros = true
        for otro in all(minerales) do
            if otro != m and otro.activo then
                local ox = abs(m.x - otro.x)
                local oy = abs(m.y - otro.y)
                if ox < 12 and oy < 12 then
                    lejos_de_otros = false
                end
            end
        end

        lejos_antorcha = abs(m.x - antorcha.x) > 16 or abs(m.y - antorcha.y) > 16

        intentos += 1
    until (posicion_libre(m.x, m.y) and (dist_x > 15 or dist_y > 15) and lejos_de_otros and lejos_antorcha) or intentos > 100
    m.activo = true
end

function obtener_mineral_aleatorio(m)
    local bonus = nivel_actual * 0.01
    local suerte = rnd(1)
    if suerte > 0.75 - bonus then
        m.tipo = "zafiro"
        m.spr = spr_zafiro
    elseif suerte > 0.4 - bonus then
        m.tipo = "oro"
        m.spr = spr_oro
    else
        m.tipo = "carbon"
        m.spr = spr_carbon
    end
end

function solido(x, y)
    local max_x = (nivel_actual == 5) and 511 or 255
    local max_y = (nivel_actual == 5) and 511 or 255
    if x < 0 or x > max_x or y < 0 or y > max_y then return true end
    return fget(mget(flr(x / 8), flr(y / 8)), 0)
end

function posicion_libre(x, y)
    return not solido(x, y)
            and not solido(x + 7, y)
            and not solido(x, y + 7)
            and not solido(x + 7, y + 7)
end
-->8
-- logic for game (enemies, hoguera, recolect, fx)

function aplicar_ataque_enemigo(e)
    if timer_inmunidad > 0 then return end
    vida = mid(0, vida - e.danio, vida_max)
    timer_inmunidad = 30
    timer_flash_dano = 6
    sfx(7)
    -- sfx de danio asignado al 7

    if vida <= 0 then
        causa_muerte = "enemigo"
    end

    if e.tipo == "escorpion" and not envenenado then
        envenenado = true
        timer_envenenamiento = 180
        velocidad = velocidad_base * 0.85
        for i = 1, 4 do
            crear_burbuja_veneno()
        end
    end
end

function crear_burbuja_veneno()
    local b = {
        x = px + 2 + rnd(4),
        y = py + 2 + rnd(4),
        vx = rnd(0.4) - 0.2,
        vy = rnd(0.4) - 0.2,
        spr = spr_veneno,
        vida_util = 20 + rnd(20)
    }
    add(burbujas_veneno, b)
end

function actualizar_burbujas_veneno()
    for b in all(burbujas_veneno) do
        b.x += b.vx
        b.y += b.vy
        b.vida_util -= 1
        if b.vida_util <= 0 then
            del(burbujas_veneno, b)
        end
    end
end

function actualizar_enemigos()
    for e in all(enemigos) do
        if e.tipo == "jefe" then
            if not jefe_muerto then
                actualizar_jefe(e)
            end
        elseif e.confundido then
            e.timer_confusion -= 1
            e.vx = 0
            e.vy = 0
            if e.timer_confusion <= 0 then
                e.confundido = false
            end
        else
            local dx_torch = e.x - antorcha.x
            local dy_torch = e.y - antorcha.y
            local dist_sq_torch = dx_torch * dx_torch + dy_torch * dy_torch
            local scare_radius_sq = 36 * 36
            local stop_panic_sq = 70 * 70

            if e.panico then
                e.timer_panico -= 1
                if e.timer_panico <= 0 or dist_sq_torch > stop_panic_sq then
                    e.panico = false
                end
            elseif antorcha.encendida and dist_sq_torch < scare_radius_sq then
                e.panico = true
                e.timer_panico = 60
            end

            if e.panico then
                local dist_torch = sqrt(dist_sq_torch)
                if dist_torch > 0 then
                    local unit_x = dx_torch / dist_torch
                    local unit_y = dy_torch / dist_torch
                    local panic_speed = e.v_base * 1.5
                    e.vx = unit_x * panic_speed
                    e.vy = unit_y * panic_speed
                else
                    e.vx = (rnd(2) - 1) * e.v_base * 1.5
                    e.vy = (rnd(2) - 1) * e.v_base * 1.5
                end
                if e.tipo == "escorpion" then
                    e.spr = spr_escorpion
                elseif e.tipo == "serpiente" then
                    e.spr = spr_serpiente
                end
            else
                if e.tipo == "escorpion" then
                    e.spr = spr_escorpion
                elseif e.tipo == "serpiente" then
                    e.spr = spr_serpiente
                end

                local dx = px - e.x
                local dy = py - e.y
                local dist_sq = dx * dx + dy * dy
                local vis_sq = e.radio_vision * e.radio_vision

                if dist_sq < vis_sq then
                    local dist = sqrt(dist_sq)
                    if dist > 0 then
                        e.vx = (dx / dist) * e.v_base
                        e.vy = (dy / dist) * e.v_base
                    end
                else
                    if rnd(1) < 0.02 then
                        e.vx = (rnd(2) - 1) * e.v_base * 0.3
                        e.vy = (rnd(2) - 1) * e.v_base * 0.3
                    end
                end
            end

            local nx, ny = e.x + e.vx, e.y + e.vy
            if e.vx ~= 0 then
                if posicion_libre(nx, e.y) then e.x = nx end
            end
            if e.vy ~= 0 then
                if posicion_libre(e.x, ny) then e.y = ny end
            end

            if timer_inmunidad <= 0 and not e.confundido
                    and abs(px - e.x) < 8 and abs(py - e.y) < 8 then
                aplicar_ataque_enemigo(e)
            end
        end
    end
end

function actualizar_hoguera()
    if nivel_actual == 5 and not descanso then
        local cx = flr((px + 4) / 8)
        local cy = flr((py + 4) / 8)

        if mget(cx, cy) == spr_hoguera or mget(cx + 1, cy) == spr_hoguera
                or mget(cx - 1, cy) == spr_hoguera or mget(cx, cy + 1) == spr_hoguera then
            en_hoguera = true

            if btnp(0) or btnp(2) then opcion_hoguera = 1 end
            if btnp(1) or btnp(3) then opcion_hoguera = 2 end

            if btnp(5) then
                if opcion_hoguera == 1 then
                    vida = vida_max
                    descanso = true
                    sfx(5)
                else
                    -- soluciれ⧗n: empujar a la izquierda (x) en lugar de abajo (y)
                    -- para alejarlo de la hoguera sin enterrarlo en el suelo
                    px -= 8
                end
                en_hoguera = false
            end
        else
            en_hoguera = false
        end
    else
        en_hoguera = false
    end
end

function chequea_recoleccion()
    for m in all(minerales) do
        if m.activo and abs(px - m.x) < 7 and abs(py - m.y) < 7 then
            if m.tipo == "carbon" then
                combustible = mid(0, combustible + 25, combustible_max)
                sfx(5)
            elseif m.tipo == "oro" then
                oro += 1
                sfx(5)
                crear_texto_flotante(m.x, m.y, m.tipo)
            elseif m.tipo == "zafiro" then
                zafiro += 1
                sfx(5)
                crear_texto_flotante(m.x, m.y, m.tipo)
            end
            obtener_mineral_aleatorio(m)
            respawn_mineral(m)
        end
    end
end

function crear_texto_flotante(x, y, tipo)
    local texto = "+1"
    local color = 7
    if tipo == "oro" then
        color = 7
    elseif tipo == "zafiro" then
        color = 12
    end
    add(textos_flotantes, { x = x, y = y, texto = texto, color = color, vida = 30 })
end

function actualizar_textos_flotantes()
    for tf in all(textos_flotantes) do
        tf.y -= 0.4
        tf.vida -= 1
        if tf.vida <= 0 then del(textos_flotantes, tf) end
    end
end

-->8
function _update()
    if timer_intro > 0 then
        timer_intro -= 1
        return
    end

    if mostrando_intro_boss then
        if btnp(5) then
            mostrando_intro_boss = false
            cargar_nivel(5)
            timer_apertura = 20
        end
        return
    end

    if escena_actual == 0 then
        if btnp(4) or btnp(5) then
            if ya_vio_instrucciones then
                local nivel_inicio = 1
                cargar_nivel(nivel_inicio)
                escena_actual = 2
            else
                escena_actual = 1
            end
        end
        return
    end

    if escena_actual == 1 then
        if btnp(4) or btnp(5) then
            ya_vio_instrucciones = true
            local nivel_inicio = 1
            cargar_nivel(nivel_inicio)
            escena_actual = 2
        end
        return
    end

    if escena_actual == 3 then
        timer_auto_volver += 1
        if btnp(4) or btnp(5) or timer_auto_volver > 300 then
            _init()
        end
        return
    end

    if vida <= 0 then
        if not sonido_gameover_sonado then
            music(-1)
            sfx(11)
            sonido_gameover_sonado = true
        end
        timer_auto_volver += 1
        if btn(5) or timer_auto_volver > 300 then
            sonido_gameover_sonado = false
            _init()
        end
        return
    end

    -- 1. actualizacion de menれむs interactivos (hoguera y tienda)
    actualizar_hoguera()
    if en_hoguera then return end

    -- 2. logica del duende verde
    actualizar_logica_duende()
    if en_tienda_duende or preguntando_duende then
        manejar_menu_duende()
        return -- detiene movimiento del jugador
    end

    -- 3. timers y estados del jugador
    if timer_inmunidad > 0 then timer_inmunidad -= 1 end
    if timer_flash_dano > 0 then timer_flash_dano -= 1 end
    if envenenado then
        timer_envenenamiento -= 1
        if timer_envenenamiento % 60 == 0 then
            vida = mid(0, vida - 3, vida_max)
        end
        if flr(t() * 4) % 2 == 0 then
            crear_burbuja_veneno()
        end
        actualizar_burbujas_veneno()
        if timer_envenenamiento <= 0 then
            envenenado = false
            velocidad = velocidad_base
            burbujas_veneno = {}
        end
    end

    -- 4. movimiento del jugador
    local pos_ant_x = px
    local pos_ant_y = py
    local dx, dy = 0, 0

    if not jefe_en_intro and not transicion_salida and timer_apertura <= 0 then
        if btn(0) then
            dx -= velocidad mirando_izq = true
        end
        if btn(1) then
            dx += velocidad mirando_izq = false
        end
        if btn(2) then dy -= velocidad end
        if btn(3) then dy += velocidad end
    end

    if dx ~= 0 then
        local nx = px + dx
        if posicion_libre(nx, py) then px = nx end
    end
    if dy ~= 0 then
        local ny = py + dy
        if posicion_libre(px, ny) and ny >= 30 then
            py = ny
        end
    end
    if px ~= pos_ant_x or py ~= pos_ant_y then
        contador_pasos += 1
        if contador_pasos % 14 == 0 then sfx(4) end
        if (contador_pasos % 14) < 7 then
            spr_jugador_actual = spr_jugador
        else
            spr_jugador_actual = 21
        end
    end

    -- 5. chispa y antorcha
    if timer_chispa > 0 then timer_chispa -= 1 end
    if chispa_efecto > 0 then chispa_efecto -= 0.5 end
    if btnp(4) and combustible > 5 and timer_chispa == 0 then
        chispa_efecto = 15
        combustible -= 20
        timer_chispa = 135
        sfx(8)

        local radio_cegado = radio_base + 25
        for e in all(enemigos) do
            local edx = e.x - px
            local edy = e.y - py
            if edx * edx + edy * edy < radio_cegado * radio_cegado then
                if e.tipo == "jefe" then
                    if not jefe_muerto and not jefe_en_intro and e.timer_molestado <= 0 then
                        e.vx = 0
                        e.vy = 0
                        veces_molestado += 1
                        if veces_molestado == 1 then
                            e.estado = "carga_laser"
                            e.timer_estado = 30
                            e.lx = px + 4
                            e.ly = py + 4
                            add(textos_flotantes, { x = e.x, y = e.y - 4, texto = "!carga!", color = 9, vida = 20 })
                        elseif veces_molestado == 2 then
                            e.estado = "ataque_pinzas"
                            e.timer_estado = 60
                            local pdx = (px + 4) - (e.x + 4)
                            local pdy = (py + 4) - (e.y + 4)
                            local pdist = sqrt(pdx * pdx + pdy * pdy)
                            if pdist > 0 then
                                e.p_dir_x = pdx / pdist
                                e.p_dir_y = pdy / pdist
                            else
                                e.p_dir_x = 0 e.p_dir_y = 1
                            end
                            add(textos_flotantes, { x = e.x, y = e.y - 4, texto = "!pinzas!", color = 10, vida = 30 })
                        elseif veces_molestado == 3 then
                            e.estado = "ataque_slam"
                            e.timer_estado = 20
                            if jefe_terremoto_molesto then jefe_terremoto_molesto() end
                            veces_molestado = 0
                            add(textos_flotantes, { x = e.x, y = e.y - 4, texto = "!furia!", color = 8, vida = 30 })
                        end
                    end
                else
                    e.confundido = true
                    e.timer_confusion = 90
                end
            end
        end
    end

    -- encender antorcha con x
    if btnp(5) and not antorcha.encendida and nivel_actual != 5 then
        local dist_torch_x = abs(px - antorcha.x)
        local dist_torch_y = abs(py - antorcha.y)
        if dist_torch_x < 24 and dist_torch_y < 24 then
            antorcha.encendida = true
            sfx(5)
            item_salida.activo = true
            item_salida.spr = spr_salida_a
        end
    end

    -- 6. transicion de salida
    if item_salida.activo
            and abs((px + 4) - (item_salida.x + 4)) < 6
            and abs((py + 4) - (item_salida.y + 4)) < 6
            and not transicion_salida
            and not mostrando_nivel_superado then
        timer_en_puerta += 1
        if timer_en_puerta > 15 then
            transicion_salida = true
            timer_transicion = 40
            nivel_pendiente = nivel_actual + 1
            sfx(6)
        end
    else
        timer_en_puerta = 0
    end

    if not transicion_salida then
        if combustible > 0 then
            local gasto = 0.04
            if tiene_farola then gasto = gasto * 0.95 end
            combustible -= gasto
            radio_luz = radio_base + chispa_efecto
        else
            combustible = 0
            radio_luz = mid(0, radio_luz - 0.4, 100)
            if radio_luz <= 0 then vida -= 3 end
            if vida <= 0 then causa_muerte = "oscuridad" end
        end
    end
    if transicion_salida then
        timer_transicion -= 1
        if timer_transicion > 0 then
            radio_luz = radio_luz * 0.85
        end
        if timer_transicion <= 0 then
            transicion_salida = false
            mostrando_nivel_superado = true
            timer_nivel_superado = (nivel_actual == 4) and 30 or 120
        end
        return
    end

    if mostrando_nivel_superado then
        timer_nivel_superado -= 1
        if timer_nivel_superado <= 0 then
            mostrando_nivel_superado = false
            if nivel_pendiente > 5 then
                escena_actual = 3
                music(-1)
                sfx(10)
            elseif nivel_pendiente == 5 then
                mostrando_intro_boss = true
            else
                cargar_nivel(nivel_pendiente)
                timer_apertura = 20
            end
        end
        return
    end

    if timer_apertura > 0 then
        timer_apertura -= 1
        radio_luz = radio_base - (radio_base * (timer_apertura / 40))
    end

    -- 7. resto del mundo
    actualizar_enemigos()
    chequea_recoleccion()
    if nivel_actual == 5 then
        if actualizar_proyectiles_jefe then actualizar_proyectiles_jefe() end
        if actualizar_piedras then actualizar_piedras() end
        if jefe_muerto and jefe_timer_muerte > 0 then
            jefe_timer_muerte -= 1
            if jefe_timer_muerte <= 0 then
                for e in all(enemigos) do
                    if e.tipo == "jefe" then del(enemigos, e) end
                end
                item_salida.activo = true
                item_salida.spr = spr_salida_a
                if escorpios then
                    item_salida.x = escorpios.x
                    item_salida.y = escorpios.y
                else
                    item_salida.x = 128
                    item_salida.y = 128
                end
            end
        end
    end
    actualizar_textos_flotantes()
end

-- funcion auxiliar para el duende
function actualizar_logica_duende()
    if duende_x != nil and duende_y != nil then
        local dist_x = abs(px - duende_x)
        local dist_y = abs(py - duende_y)

        if dist_x < 16 and dist_y < 16 then
            preguntando_duende = true
        else
            preguntando_duende = false
            en_tienda_duende = false
            en_tienda = false
        end
    end
end

-- funciれはn auxiliar para cerrar la tienda y evitar bucle
function cerrar_tienda_duende()
    en_tienda = false
    en_tienda_duende = false
    preguntando_duende = false
    px -= 8

    -- empuja al jugador hacia la izquierda
    sfx(1)
end

function manejar_menu_duende()
    if preguntando_duende and not en_tienda_duende then
        if btnp(0) or btnp(1) then
            opcion_pregunta_duende = 3 - opcion_pregunta_duende
        end
        if btnp(5) then
            if opcion_pregunta_duende == 1 then
                preguntando_duende = false
                en_tienda_duende = true
                en_tienda = true
                opcion_tienda = 1
                sfx(5)
            else
                cerrar_tienda_duende()
            end
        end
        return
    end

    if en_tienda or en_tienda_duende then
        if btnp(2) then opcion_tienda = max(1, opcion_tienda - 1) end
        if btnp(3) then opcion_tienda = min(4, opcion_tienda + 1) end

        if btnp(5) then
            if opcion_tienda == 1 and not tiene_farola and zafiro >= 4 then
                tiene_farola = true
                zafiro -= 4
                sfx(2)
            elseif opcion_tienda == 2 and oro >= 5 then
                vida_max += 25
                vida = vida_max
                oro -= 5
                sfx(2)
            elseif opcion_tienda == 3 and zafiro >= 5 then
                combustible_max += 60
                combustible = combustible_max
                zafiro -= 5
                sfx(2)
            elseif opcion_tienda == 4 then
                cerrar_tienda_duende()
            end
        end
    end
end

-->8
-- dibujo: hud, luz, juego

function dibujar_luz_personaje(scx, scy)
    if radio_luz <= 0 then
        rectfill(0, 16, 128, 128, 0)
        return
    end

    local radio_final = radio_luz
    if tiene_farola then radio_final = radio_luz + 10 end

    local d1 = radio_final + 6
    local d2 = radio_final + 12
    local d3 = radio_final + 18
    local d4 = radio_final + 26

    local cx_for_fog = px + 4
    local cy_for_fog = py + 4
    local cam_x_for_fog = mid(0, cx_for_fog - 64, 256 - 128)

    local max_cam_y_fog = (nivel_actual == 5) and (512 - 128) or (256 - 128)
    local cam_y_for_fog = mid(0, cy_for_fog - 64, max_cam_y_fog)

    if jefe_en_intro and escorpios then
        cam_x_for_fog = mid(0, escorpios.x - 64, 256 - 128)
        cam_y_for_fog = mid(0, escorpios.y - 64, 512 - 128)
    end

    for x = 0, 128, 4 do
        for y = 16, 128, 4 do
            local dx = abs(scx - x)
            local dy = abs(scy - y)
            local dist_cuadrado = dx * dx + dy * dy

            local mx_point = x + cam_x_for_fog
            local my_point = y + cam_y_for_fog

            local luz_antorcha = false
            if antorcha.encendida and not transicion_salida then
                local t_dx = abs(mx_point - (antorcha.x + 4))
                local t_dy = abs(my_point - (antorcha.y + 4))
                local t_dist_sq = t_dx * t_dx + t_dy * t_dy
                if t_dist_sq < 30 * 30 then luz_antorcha = true end
            end

            local luz_hoguera = false
            if nivel_actual == 5 and not transicion_salida then
                local h_dx = abs(mx_point - 24)
                local h_dy = abs(my_point - 288)
                if h_dx < 35 and h_dy < 35 then
                    luz_hoguera = true
                end
            end

            if luz_antorcha or luz_hoguera then
            elseif dist_cuadrado >= d4 * d4 then
                fillp() rectfill(x, y, x + 3, y + 3, 0)
            elseif dist_cuadrado >= d3 * d3 then
                fillp(0xa5a5) rectfill(x, y, x + 3, y + 3, 0)
            elseif dist_cuadrado >= d2 * d2 then
                fillp(0x5a5a) rectfill(x, y, x + 3, y + 3, 0)
            elseif dist_cuadrado >= d1 * d1 then
                fillp(0x8888) rectfill(x, y, x + 3, y + 3, 0)
            end
        end
    end
    fillp()
    circ(scx, scy, radio_final, 6)
end

function dibujar_hud()
    rectfill(0, 0, 127, 28, 1)
    rectfill(0, 0, 127, 27, 0)
    line(0, 27, 127, 27, 5)

    print("combustible", 4, 2, 6)
    rect(4, 9, 60, 13, 7)
    rectfill(5, 10, 5 + (combustible / (combustible_max or 100)) * 54, 12, 9)

    print("vida", 67, 2, 6)
    rect(67, 9, 123, 13, 7)
    rectfill(68, 10, 68 + (vida / (vida_max or 100)) * 54, 12, 10)

    line(63, 1, 63, 16, 5)

    spr(spr_oro, 2, 19)
    print(oro, 10, 20, 7)

    spr(spr_zafiro, 26, 18)
    print(zafiro, 34, 20, 12)

    if nivel_actual == 1 then
        print("tutorial", 49, 20, 10)
    end

    print("nv" .. nivel_actual .. "/" .. nivel_max, 90, 20, 6)

    if timer_chispa == 0 and combustible > 5 then
        rect(119, 17, 125, 25, 10) print("z", 121, 19, 10)
    else
        rect(119, 17, 125, 25, 5) print("z", 121, 19, 5)
    end
end

function dibujar_juego()
    cls(0)

    local cx = px + 4
    local cy = py + 4
    local cam_x = mid(0, cx - 64, 256 - 128)
    local max_cam_y = (nivel_actual == 5) and (512 - 128) or (256 - 128)
    local cam_y = mid(0, cy - 64, max_cam_y)

    if jefe_en_intro and escorpios then
        cam_x = mid(0, escorpios.x - 64, 256 - 128)
        cam_y = mid(0, escorpios.y - 64, 512 - 128)
    end

    local shake_x, shake_y = 0, 0
    local vida_critica = vida < 20 and vida > 0

    if vida_critica then
        shake_x = rnd(0.6) - 0.3 shake_y = rnd(0.6) - 0.2
    elseif jefe_shake > 0 then
        shake_x = rnd(jefe_shake) - jefe_shake / 2
        shake_y = rnd(jefe_shake) - jefe_shake / 2
    end

    camera(cam_x + shake_x, cam_y + shake_y)
    local scx = cx - cam_x
    local scy = cy - cam_y

    if nivel_actual == 5 then map(0, 0, 0, 0, 32, 64) else map(0, 0, 0, 0, 32, 32) end

    for m in all(minerales) do
        if m.activo then
            local bob = sin(t() * 3 + m.x) * 0.4
            spr(m.spr, m.x, m.y + bob)
        end
    end

    for tf in all(textos_flotantes) do
        print(tf.texto, tf.x, tf.y, tf.color)
    end

    if nivel_actual != 5 and not transicion_salida then
        if antorcha.encendida then
            spr(spr_antorcha_e, antorcha.x, antorcha.y)
        else
            spr(spr_antorcha, antorcha.x, antorcha.y)
        end
    end

    for e in all(enemigos) do
        if e.tipo == "jefe" then
            if not jefe_muerto then
                dibujar_escorpios(e)
            else
                if jefe_timer_muerte > 45 then
                    dibujar_escorpios_offset(e, rnd(4) - 2, rnd(4) - 2)
                elseif jefe_timer_muerte > 0 then
                    for i = 1, 5 do
                        pset(e.x + rnd(24), e.y + rnd(8), 8 + flr(rnd(4)))
                    end
                end
            end
        else
            spr(e.spr, e.x, e.y)
        end
        if e.confundido then spr(spr_confusion, e.x, e.y - 6) end
    end

    for p in all(piedras_caendo) do
        spr(p.spr, p.x, p.y)
    end

    if nivel_actual != 5 and not transicion_salida then
        if item_salida.activo then
            spr(spr_salida_a, item_salida.x, item_salida.y)
        else
            spr(spr_salida, item_salida.x, item_salida.y)
        end
    elseif item_salida.activo and not transicion_salida then
        spr(item_salida.spr, item_salida.x, item_salida.y)
    end

    -- =======================================================
    -- dibujo del duende (solo en el nivel 5)
    -- =======================================================
    if nivel_actual == 5 and duende_x != nil and duende_y != nil then
        palt(0, true)
        spr(22, duende_x, duende_y)
        palt()
    end
    -- =======================================================

    local mostrar_jugador = true
    if timer_inmunidad > 0 and flr(t() * 15) % 2 == 0 then mostrar_jugador = false end
    if transicion_salida then mostrar_jugador = false end

    if mostrar_jugador then
        palt(0, true)
        spr(spr_jugador_actual, px, py, 1, 1, mirando_izq)
        if mirando_izq then
            if tiene_farola then
                spr(spr_farola, px - 5, py + 2, 1, 1, true)
            else
                spr(spr_brazo, px - 5, py + 2, 1, 1, true)
            end
        else
            if tiene_farola then
                spr(spr_farola, px + 5, py + 2, 1, 1, false)
            else
                spr(spr_brazo, px + 5, py + 2, 1, 1, false)
            end
        end
        palt()
    end

    if envenenado then
        palt(0, true)
        for b in all(burbujas_veneno) do
            sspr(b.spr % 16 * 8, flr(b.spr / 16) * 8, 8, 8, b.x, b.y, 4, 4)
        end
        palt()
    end

    camera()

    if not jefe_en_intro then dibujar_luz_personaje(scx, scy) end
    if jefe_en_intro then
        rectfill(0, 0, 127, 14, 0) rectfill(0, 114, 127, 127, 0)
    end

    dibujar_barra_jefe()

    if not antorcha.encendida and nivel_actual != 5 then
        local adx = abs((px + 4) - (antorcha.x + 4))
        local ady = abs((py + 4) - (antorcha.y + 4))
        if adx < 14 and ady < 14 then
            print("x: encender antorcha", 24, 100, 10)
        end
    end

    if not jefe_en_intro then dibujar_hud() end

    if vida_critica and flr(t() * 6) % 2 == 0 then
        rect(0, 0, 127, 127, 10)
    end

    if en_hoguera then
        rectfill(18, 48, 110, 94, 0)
        rect(17, 47, 111, 95, 7)
        print("deseas descansar?", 24, 54, 7)
        print("recuperara tu vida", 24, 62, 6)
        if opcion_hoguera == 1 then
            print("> si", 38, 76, 11) print("  no", 74, 76, 5)
        else
            print("  si", 38, 76, 5) print("> no", 74, 76, 8)
        end
        print("x: confirmar", 36, 86, 6)
    end

    -- mensaje de confirmation del duende
    if preguntando_duende then
        rectfill(16, 44, 112, 90, 0)
        rect(15, 43, 113, 91, 14)
        print("comerciar con", 28, 51, 7)
        print("el duende?", 28, 59, 7)
        if opcion_pregunta_duende == 1 then
            print("> si", 34, 72, 11) print("  no", 78, 72, 5)
        else
            print("  si", 34, 72, 5) print("> no", 78, 72, 8)
        end
        print("x: confirmar", 36, 84, 6)
    end

    -- menu de la tienda del duende
    if en_tienda then
        rectfill(10, 32, 118, 122, 0)
        rect(9, 31, 119, 123, 11)
        print("--- duende mercader ---", 18, 36, 12)

        local col1 = (opcion_tienda == 1) and 11 or 6
        local col2 = (opcion_tienda == 2) and 11 or 6
        local col3 = (opcion_tienda == 3) and 11 or 6
        local col4 = (opcion_tienda == 4) and 11 or 8

        if tiene_farola then
            print("1. farola [comprado]", 14, 48, 5)
        else
            print("1. farola +rango", 14, 48, col1)
            print("   costo: 4 zafiro", 14, 56, 5)
        end
        print("2. +40 vida max", 14, 66, col2)
        print("   costo: 5 oro", 14, 74, 5)
        print("3. +60 combustible", 14, 84, col3)
        print("   costo: 5 zafiro", 14, 92, 5)
        print("4. salir", 14, 102, col4)

        print("x:comprar", 20, 112, 5)
    end
end

-->8
-- dibujo: pantallas (titulo, instrucciones, fin)

function dibujar_titulo()
    cls(0)
    local offset_x = cos(t() * 0.5) * 4
    local pulso_luz = 25 + sin(t() * 2) * 2
    circfill(63 + offset_x, 61, pulso_luz, 10)

    spr(spr_jugador, 60, 58)

    print("the last light", 37, 50, 1)
    local col_titulo = 7
    if rnd(1) > 0.9 then col_titulo = 6 end
    print("the last light", 36, 49, col_titulo)

    if flr(t() * 2) % 2 == 0 then
        print("presiona z para comenzar", 16, 90, 6)
    end
end

function dibujar_instrucciones()
    cls(0)
    local titulo = "como jugar"
    print(titulo, (128 - #titulo * 4) / 2, 8, 7)

    print("flechas: moverse", 8, 24, 6)
    print("z: chispa  x: antorcha", 8, 34, 6)
    print("recolecta minerales", 8, 44, 6)
    print("cuidado con los enemigos", 8, 54, 6)
    print("para ganar:", 8, 66, 6)
    print("-enciende la antorcha", 12, 76, 6)
    print("-busca la salida", 12, 86, 6)

    if flr(t() * 2) % 2 == 0 then
        local texto_z = "z: iniciar juego"
        print(texto_z, (128 - #texto_z * 4) / 2, 112, 10)
    end
end

function dibujar_game_over()
    camera()
    cls(0)
    local texto1 = ""
    if causa_muerte == "enemigo" then
        texto1 = "caiste ante las sombras"
    else
        texto1 = "la oscuridad te ha consumido"
    end
    local x1 = (128 - #texto1 * 4) / 2
    print(texto1, x1, 60, 7)

    local texto2 = "pulsa x para reintentar"
    local x2 = (128 - #texto2 * 4) / 2
    print(texto2, x2, 70, 6)
end

function dibujar_nivel_superado()
    camera()
    cls(0)
    local texto = "nivel " .. (nivel_pendiente - 1) .. " superado!"
    local ancho = #texto * 4
    local x = (128 - ancho) / 2
    print(texto, x, 45, 7)

    local resumen = "oro:" .. oro .. "  zafiros:" .. zafiro
    local x2 = (128 - #resumen * 4) / 2
    print(resumen, x2, 58, 6)

    if flr(t() * 2) % 2 == 0 then
        local texto2 = "preparate..."
        local x2b = (128 - #texto2 * 4) / 2
        print(texto2, x2b, 75, 6)
    end
end

function dibujar_victoria()
    camera()
    cls(0)
    local pulso = 20 + sin(t() * 2) * 3
    circfill(64, 55, pulso, 10)
    spr(spr_jugador, 60, 51)

    local texto1 = "escapaste de la cueva!"
    local x1 = (128 - #texto1 * 4) / 2
    print(texto1, x1, 82, 7)

    local texto2 = "the last light"
    local x2 = (128 - #texto2 * 4) / 2
    print(texto2, x2, 92, 9)

    if flr(t() * 2) % 2 == 0 then
        local texto3 = "z: volver al inicio"
        local x3 = (128 - #texto3 * 4) / 2
        print(texto3, x3, 105, 6)
    end
end

function dibujar_intro_boss()
    camera()
    cls(0)
    local t1 = "nivel final"
    print(t1, (128 - #t1 * 4) / 2, 20, 8)

    local t2 = "algo oscuro te espera"
    print(t2, (128 - #t2 * 4) / 2, 36, 6)

    local t3 = "prepara tus recursos"
    print(t3, (128 - #t3 * 4) / 2, 46, 6)

    print("--- tienda disponible ---", 14, 62, 12)

    local t4 = "x: enfrentar al jefe"
    print(t4, (128 - #t4 * 4) / 2, 108, 10)

    -- mostrar recursos actuales
    print("oro:" .. oro .. " zaf:" .. zafiro, 38, 118, 14)
end

function _draw()
    if timer_intro > 0 then
        cls(0)
        local progreso = 60 - timer_intro
        local radio = progreso * 1.5
        circfill(64, 64, radio, 10)
        if radio > 20 then
            print("the last light", 36, 60, 7)
        end
        return
    end

    if escena_actual == 0 then
        dibujar_titulo() return
    end
    if escena_actual == 1 then
        dibujar_instrucciones() return
    end
    if escena_actual == 3 then
        dibujar_victoria() return
    end
    if vida <= 0 then
        dibujar_game_over() return
    end

    if mostrando_nivel_superado or mostrando_intro_boss then
        if mostrando_intro_boss then
            dibujar_intro_boss() return
        end
        if nivel_pendiente != 5 then
            dibujar_nivel_superado() return
        end
        cls(0) return
    end

    dibujar_juego()
end
-->8
-- jefe final: escorpios

spr_pinza_izq = 23
spr_cabeza = 24
spr_pinza_der = 25

escorpios = nil
jefe_en_intro = false
jefe_shake = 0

function iniciar_jefe()
    proyectiles_jefe = {}
    piedras_caendo = {}
    jefe_muerto = false
    jefe_timer_muerte = 0
    jefe_vida_max = 100
    jefe_vida = jefe_vida_max
    jefe_fase = 1
    jefe_en_intro = false
    jefe_shake = 0

    escorpios = {
        tipo = "jefe",
        x = 184,
        y = 232,
        vx = 0,
        vy = 0,
        v_base = 0.5,
        radio_vision = 60,
        danio = 15,
        confundido = false,
        timer_confusion = 0,
        pinza_offset = 0,
        pinza_dir = 1,
        estado = "durmiendo",
        timer_estado = 0,
        timer_ataque = 0,
        timer_terremoto = 150,
        timer_molestado = 0,
        lx = 0,
        ly = 0,
        p_dir_x = 0,
        p_dir_y = 1
    }
    -- no borramos la lista completa, solo agregamos a escorpios de forma limpia
    add(enemigos, escorpios)
end

function actualizar_jefe(e)
    if jefe_shake > 0 then jefe_shake -= 0.015 end
    if e.timer_molestado > 0 then e.timer_molestado -= 1 end

    -- 1. estado: durmiendo
    if e.estado == "durmiendo" then
        e.pinza_offset = 0
        local dx = px - e.x
        local dy = py - e.y
        local dist = sqrt(dx * dx + dy * dy)
        if dist < 55 then
            e.estado = "despertando"
            e.timer_estado = 120
            jefe_en_intro = true
            sfx(7)
        end
        return
    end

    -- 2. estado: despertando
    if e.estado == "despertando" then
        e.timer_estado -= 1
        e.pinza_offset += 0.5 * e.pinza_dir
        if e.pinza_offset > 5 then e.pinza_dir = -1 end
        if e.pinza_offset < -5 then e.pinza_dir = 1 end

        if e.timer_estado == 60 then
            jefe_golpe_suelo(false)
            sfx(11)
        end

        if e.timer_estado <= 0 then
            e.estado = "combate"
            jefe_en_intro = false
            e.timer_ataque = 0
        end
        return
    end

    -- 3. estado: combate activo
    if e.estado == "combate" then
        e.pinza_offset += 0.08 * e.pinza_dir
        if e.pinza_offset > 3 then e.pinza_dir = -1 end
        if e.pinza_offset < -3 then e.pinza_dir = 1 end

        local dx = px - e.x
        local dy = py - e.y
        local dist = sqrt(dx * dx + dy * dy)
        if dist > 0 then
            e.vx = (dx / dist) * e.v_base
            e.vy = (dy / dist) * e.v_base
        end

        local nx = e.x + e.vx
        local ny = e.y + e.vy
        if posicion_libre(nx, e.y) then e.x = nx end
        if posicion_libre(e.x, ny) then e.y = ny end

        e.timer_ataque += 1
        if e.timer_ataque % 60 == 0 then
            disparar_proyectil_jefe(e.x + 4, e.y + 4)
        end

        e.timer_terremoto -= 1
        if e.timer_terremoto <= 0 then
            e.estado = "ataque_slam"
            e.timer_estado = 45
            e.vx = 0
            e.vy = 0
        end
    end

    -- anticipaciれ⧗n: carga del lれくser
    if e.estado == "carga_laser" then
        e.timer_estado -= 1
        e.pinza_offset = sin(t() * 25) * 2
        if e.timer_estado <= 0 then
            e.estado = "ataque_laser"
            e.timer_estado = 45 -- るくreducida la duraciれ⧗n a la mitad! (rれくpido y justo)
            sfx(11)
        end
    end

    -- habilidad 1: ataque rayo laser (optimizado contra lag + corto alcance)
    if e.estado == "ataque_laser" then
        e.timer_estado -= 1

        local factor_progreso = 1 - (e.timer_estado / 45)
        local vel_seguimiento = mid(0.5, 0.5 + (factor_progreso * 2.0), 2.5)

        local ldx = (px + 4) - e.lx
        local ldy = (py + 4) - e.ly
        local ldist = sqrt(ldx * ldx + ldy * ldy)
        if ldist > 0 then
            e.lx += (ldx / ldist) * vel_seguimiento
            e.ly += (ldy / ldist) * vel_seguimiento
        end

        -- るくrango reducido a 48 pれ♪xeles maximo! (medio alcance total)
        local bx = e.x + 4
        local by = e.y + 4
        local v_dx = e.lx - bx
        local v_dy = e.ly - by
        local v_dist = sqrt(v_dx * v_dx + v_dy * v_dy)

        if v_dist > 48 then
            e.lx = bx + (v_dx / v_dist) * 48
            e.ly = by + (v_dy / v_dist) * 48
        end

        -- optimizaciれはn anti-lag: comprobaciれはn directa por proximidad en vez de bucles redundantes
        if timer_inmunidad <= 0 then
            if abs(e.lx - (px + 4)) < 8 and abs(e.ly - (py + 4)) < 8 then
                vida = mid(0, vida - 12, 100)
                timer_inmunidad = 30
                timer_flash_dano = 6
                sfx(7)
            end
        end

        if e.timer_estado <= 0 then
            e.estado = "combate"
            e.timer_ataque = 0
        end
    end

    -- habilidad 2: ataque pinzas extensibles
    if e.estado == "ataque_pinzas" then
        e.timer_estado -= 1

        if e.timer_estado > 45 then
            e.pinza_offset = -3 + sin(t() * 35) * 1
        elseif e.timer_estado > 20 then
            local progreso_lanzamiento = 1 - ((e.timer_estado - 20) / 25)
            local vel_incremental = 0.3 + (progreso_lanzamiento * 2.5)
            e.pinza_offset += vel_incremental

            if e.pinza_offset > 32 then e.pinza_offset = 32 end
        else
            e.pinza_offset -= 4.5
            if e.pinza_offset < 0 then e.pinza_offset = 0 end
        end

        if timer_inmunidad <= 0 and e.timer_estado <= 45 then
            local cx = (e.x + 4) + (e.p_dir_x * e.pinza_offset)
            local cy = (e.y + 4) + (e.p_dir_y * e.pinza_offset)

            if abs(cx - (px + 4)) < 8 and abs(cy - (py + 4)) < 8 then
                vida = mid(0, vida - 15, 100)
                timer_inmunidad = 30
                timer_flash_dano = 6
                sfx(7)
            end
        end

        if e.timer_estado <= 0 then
            e.pinza_offset = 0
            e.estado = "combate"
            e.timer_ataque = 0
        end
    end

    -- 4. estado: atacando el suelo
    if e.estado == "ataque_slam" then
        e.timer_estado -= 1
        e.pinza_offset = -6
        if e.timer_estado <= 0 then
            jefe_golpe_suelo(false)
            sfx(11)
            e.estado = "vulnerable"
            e.timer_estado = 90
            e.timer_terremoto = 180 + rnd(100)
        end
    end

    -- 5. estado: vulnerable
    if e.estado == "vulnerable" then
        e.timer_estado -= 1
        e.pinza_offset = 6
        if e.timer_estado <= 0 then
            e.estado = "combate"
            e.timer_ataque = 0
        end
    end

    if timer_inmunidad <= 0 and not e.confundido
            and e.estado != "carga_laser" and e.estado != "ataque_laser" and e.estado != "ataque_pinzas"
            and abs(px - e.x) < 12 and abs(py - e.y) < 10 then
        aplicar_ataque_enemigo(e)
    end
end

function disparar_proyectil_jefe(x, y)
    local dx = px - x
    local dy = py - y
    local dist = sqrt(dx * dx + dy * dy)
    if dist > 0 then
        local p = {
            x = x,
            y = y,
            vx = (dx / dist) * 1.6,
            vy = (dy / dist) * 1.6,
            vida_util = 90
        }
        add(proyectiles_jefe, p)
        sfx(8)
    end
end

function actualizar_proyectiles_jefe()
    for p in all(proyectiles_jefe) do
        p.x += p.vx
        p.y += p.vy
        p.vida_util -= 1

        if abs(p.x - (px + 4)) < 6 and abs(p.y - (py + 4)) < 6 then
            if timer_inmunidad <= 0 then
                vida = mid(0, vida - 10, 100)
                timer_inmunidad = 30
                timer_flash_dano = 6
                sfx(7)
            end
            del(proyectiles_jefe, p)
        elseif p.vida_util <= 0 or not posicion_libre(p.x, p.y) then
            del(proyectiles_jefe, p)
        end
    end
end

function jefe_terremoto_molesto()
    jefe_shake = 4
    local r = rnd(1)
    local cantidad_directas = 1
    if r > 0.85 and r <= 0.97 then cantidad_directas = 2 end
    if r > 0.97 then cantidad_directas = 3 end

    for i = 1, cantidad_directas do
        crear_piedra(escorpios.x + 4 + (i * 2) - 2, true)
    end

    local cantidad_extras = 1 + flr(rnd(2))
    for i = 1, cantidad_extras do
        local rand_x = escorpios.x - 30 + rnd(60)
        crear_piedra(rand_x, false)
    end
end

function jefe_golpe_suelo(forzar_piedra_en_jefe)
    jefe_shake = 4
    if forzar_piedra_en_jefe then
        crear_piedra(escorpios.x + 4, true)
    end

    local cantidad = 2 + flr(rnd(3))
    for i = 1, cantidad do
        local rand_x = escorpios.x - 40 + rnd(80)
        crear_piedra(rand_x, false)
    end
end

function crear_piedra(pos_x, va_a_jefe)
    local inicio_y = escorpios.y - 64
    add(
        piedras_caendo, {
            x = pos_x,
            y = inicio_y,
            vy = 2.5,
            spr = 26,
            hacia_jefe = va_a_jefe,
            suelo_y = escorpios.y + 6
        }
    )
end

function actualizar_piedras()
    for p in all(piedras_caendo) do
        p.y += p.vy
        local romperse = false
        local golpe_objetivo = false

        if abs(p.x - (px + 4)) < 6 and abs(p.y - (py + 4)) < 6 then
            vida = mid(0, vida - 25, 100)
            timer_flash_dano = 4
            romperse = true
            golpe_objetivo = true
        end

        if not golpe_objetivo then
            local centro_jefe_x = escorpios.x + 4
            local centro_jefe_y = escorpios.y + 4
            if abs(p.x - centro_jefe_x) < 10 and abs(p.y - centro_jefe_y) < 10 then
                jefe_recibir_danio(8)
                romperse = true
                golpe_objetivo = true
            end
        end

        if p.y >= p.suelo_y then romperse = true end

        if romperse then
            if rnd(1) < 0.75 then
                add(
                    minerales, {
                        spr = 10,
                        x = p.x,
                        y = p.y - 2,
                        tipo = "carbon",
                        activo = true
                    }
                )
            end
            del(piedras_caendo, p)
        end
    end
end

function dibujar_escorpios(e)
    local po = flr(e.pinza_offset)
    palt(0, true)

    if e.estado == "carga_laser" then
        local r_circulo = 4 + sin(t() * 15) * 2
        local col_carga = (flr(t() * 15) % 2 == 0) and 9 or 8
        circ(e.x + 4, e.y + 4, r_circulo, col_carga)
    end

    if e.estado == "ataque_laser" then
        local rem = e.timer_estado
        if rem > 30 then
            line(e.x + 4, e.y + 4, e.lx, e.ly, 8)
            line(e.x + 3, e.y + 4, e.lx - 1, e.ly, 9)
            line(e.x + 5, e.y + 4, e.lx + 1, e.ly, 10)
        else
            line(e.x + 4, e.y + 4, e.lx, e.ly, 9)
        end
    end

    if e.estado == "vulnerable" and flr(t() * 12) % 2 == 0 then
        -- parpadeo indicador
    else
        if e.estado == "ataque_pinzas" then
            local ox = e.p_dir_x * e.pinza_offset
            local oy = e.p_dir_y * e.pinza_offset
            spr(spr_pinza_izq, e.x - 8 + ox, e.y + oy)
            spr(spr_cabeza, e.x, e.y)
            spr(spr_pinza_der, e.x + 8 + ox, e.y + oy)
        else
            spr(spr_pinza_izq, e.x - 8, e.y + po)
            spr(spr_cabeza, e.x, e.y)
            spr(spr_pinza_der, e.x + 8, e.y + po)
        end
    end

    for p in all(proyectiles_jefe) do
        circfill(p.x, p.y, 2, 11)
    end
    palt()
end

function dibujar_escorpios_offset(e, ox, oy)
    local po = flr(e.pinza_offset)
    palt(0, true)
    spr(spr_pinza_izq, e.x - 8 + ox, e.y + po + oy)
    spr(spr_cabeza, e.x + ox, e.y + oy)
    spr(spr_pinza_der, e.x + 8 + ox, e.y + po + oy)
    palt()
end

function jefe_recibir_danio(cantidad)
    jefe_vida = mid(0, jefe_vida - cantidad, jefe_vida_max)
    sfx(7)
    if jefe_vida <= 0 and not jefe_muerto then
        jefe_muerto = true
        jefe_timer_muerte = 90
        sfx(6)
    end
end

function dibujar_barra_jefe()
    if nivel_actual == 5 and escorpios and escorpios.estado != "durmiendo" and not jefe_muerto then
        rectfill(24, 114, 104, 118, 1)
        local ancho_hp = flr((jefe_vida / jefe_vida_max) * 78)
        rectfill(25, 115, 25 + ancho_hp, 117, 8)
        print("escorpios", 46, 106, 7)
    end
end

__gfx__
00000000005555000000000000600600000004400000000000000000000000000000000000000000000000000000000000076000000000050750650753d53535
000000000555555000000000065555600000440000000730000440000005500000aaaa00000cc00000555500000000000007600000000055555555503aaaaa33
00700700056ff650000a4000605445060004400000000334005aa500005555000a7aaa9000c7cc00056755500066600000076000000005500750670533aaaa35
0007700000ffff00006556000654456000555500000033000005500005aaaa500aaaaa900ccc7cc005765550005555000007600000005500000756575a3aa3a5
0007700001111110006556000055550005655650000330000005500005aa4a500aaaaa900c1c11c005555550000590000007600000055000505650563aaa3aa3
0070070001111110006556000055550005555550003300000005500005a4aa500099990000c1cc0005555550000500000055550005550000767567555aaaaaa5
000000000001100000655600065555609595595903300000000550000055550000000000000cc00000555500000500000005500005050000056576755aaaaaa5
0000000004400440000000006000000609000090330000000000000000000000000000000000000000000000000000000005500005550000505755553aaaaaa3
0000000053d53535000ddd00000dd000000000000055550004000040000000000005900000099000005555000000000000000000000000000750650700000000
000660003000003300d0000000dd7d00000000000555555004444440000999000009590000988900056666500000000000000000000000005355535000000000
00577500330000350d000dd00dddd7d000000a00056ff65003a33a30099888900095890009888990565766650000000000000000000000000730373500000000
00055000503003050d00d00d0dddddd00004a00000ffff0003333330988888890988889009888889567566650000000000000000000000003007565700000000
00055000300030030d00000d00dddd00004994000111111000333300988088899888888909880889566666650000000000000000000000005053503600000000
000550005000000500d000d0000dd00004999a400111111000b33b009808899098a88a8900988089566666650000000000000000000000007375675300000000
0005500050000005000ddd0000000000499999940001100000033000098889000985589000988890056666500000000000000000000000000565367500000000
00000000300000030000000000000000555555550044440005500550009990000099990000099900005555000000000000000000000000003057553500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e1000000000000e00000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e1000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e10000000000000000000000000000e0000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e10000000000000000000000000000e0000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e10000000000000000000000000000e0000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000000041e100000000000000e0000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e1e0e0e0e1e1e0e0e0e0e0e1e0e0e0e0e1e0e0e0e0e1e1e1e1e1e0e0e0e00000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000010100010000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e00000000000000000000000e0e0e0e0e0e0e0e0e0e0e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000000000000000000000000e0e0e000000000000000e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000000000000000000000000e0e0e0000000000000000000e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e000000000000000000000000000000000000000000000000000e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e000000000000000000000000000000000000000000000000000e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e000000000000000000000e0e0e0e0e0e0e0e0e0000000000000e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0000000e0000000e0e0e0e0000000e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00000000000000000e00000000000e0000000e00000000000e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000000000000000000000000000000000000e00000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0000000000000000000000000000000000000e00000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00000000000000000e0000000000000000000e0e000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00000000000000000e000000000000000000000e000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000e0e00000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0e0000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0e00000000000000000000000000000e0000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1e0000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010e00200c0231951517516195150c0231751519516175150c0231951517516195150c0231751519516175150c023135151f0111f5110c0231751519516175150c0231e7111e7102a7100c023175151951617515
000e002000130070200c51000130070200a51000130070200c51000130070200a5200a5200a5120a5120a51200130070200c51000130070200a51000130070200c510001300b5200a5200a5200a5120a5120a512
00020000335602c540265200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000553004520005100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800003d0303f0303f0301270010700107000560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000011010120101301013010140201502016020180201a0301b0301c0301d0301e0401f0402004021040230502505026050280502a0602c0602d0602f0603007032070330700000000000000000000000000
000400001d17015140121300e1200911004010031101400015000160001700019000190001a0001b0001c0001d0001e0001f00020000220002300024000250002600028000290002a0002b0002c0002e0002f000
0004000024670206601a65016640106300c6200261000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000024600206001a60016600106000c6000260000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000d0500d0500e0500e0500e0500f0500f05010050180501b0501c0501d0501d0501b0501c0501c0502705025050270502705026050270502605026050310502e0502f0502e0502d0502e0502e0502d050
001000003506034040330403404033040320403004030040250402104022040210302203020030200301f03017030160201602015020140201202011020140200d0200a0200a020090100c0100b0100c01009010
__music__
01 40410344
02 00014344

