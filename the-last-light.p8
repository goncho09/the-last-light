pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- the last light

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

if ya_vio_instrucciones == nil then
    ya_vio_instrucciones = false
end

function _init()
    escena_actual = 0
    oro = 0
    zafiro = 0
    nivel_actual = 1
    nivel_max = 10

    antorcha = { x = 60, y = 60, spr = spr_antorcha, encendida = false }
    item_salida = { x = 90, y = 40, spr = spr_salida, activo = false }

    px = 24
    py = 24
    velocidad_base = 1.1
    velocidad = 1.1
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

    -- transicion
    timer_transicion = 0
    transicion_salida = false
    nivel_pendiente = 0
    mostrando_nivel_superado = false
    timer_nivel_superado = 0
    timer_apertura = 0
    timer_auto_volver = 0

    --contador de pasos del jugador
    contador_pasos = 0

    --hoguera
    en_hoguera = false
    opcion_hoguera = 1
    descanso = false

    timer_intro = 60
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
        combustible = 100
        px = 24
        py = 32
    elseif n == 10 then
        reload(0x2000, 0x2000, 0x1000)
        combustible = 100
        px = 272
        py = 32
    else
        generar_cueva_aleatoria()
        combustible = mid(40, 95 - (n * 3), 100)
        px = 24
        py = 35
    end

    timer_inmunidad = 0

    antorcha.encendida = false
    antorcha.spr = spr_antorcha

    if n == 10 then
        -- posiciones fijas de antorcha y salida en el mapa del jefe
        antorcha.x = 280
        antorcha.y = 80
        item_salida.x = 296
        item_salida.y = 112
    else
        local dist_minima = 65
        local dist_minima_spawn = (n == 1) and 60 or 110
        local intentos = 0

        repeat
            if n == 1 then
                antorcha.x = 60 + rnd(50)
                antorcha.y = 35 + rnd(70)
                item_salida.x = 16 + rnd(35)
                item_salida.y = 24 + rnd(70)
            else
                antorcha.x = 16 + rnd(200)
                antorcha.y = 35 + rnd(200)
                item_salida.x = 16 + rnd(200)
                item_salida.y = 35 + rnd(200)
            end
            intentos += 1
        until (posicion_valida_objeto(antorcha.x, antorcha.y, dist_minima, dist_minima_spawn)
                    and posicion_libre(item_salida.x, item_salida.y)) or intentos > 500
    end

    item_salida.activo = false
    item_salida.spr = spr_salida

    iniciar_minerales_nivel()
    iniciar_enemigos_nivel(n)
end

function spawn_enemigo(tipo, spr, v_base, radio_vision, danio)
    local ex, ey, intentos = 0, 0, 0
    repeat
        ex = 16 + rnd(200)
        ey = 35 + rnd(200)
        local dx = ex - px
        local dy = ey - py
        intentos += 1
    until (posicion_libre(ex, ey) and dx * dx + dy * dy > 70 * 70) or intentos > 200
    return {
        tipo = tipo, spr = spr, x = ex, y = ey, vx = 0, vy = 0,
        v_base = v_base, radio_vision = radio_vision, danio = danio,
        confundido = false, timer_confusion = 0
    }
end

function iniciar_enemigos_nivel(n)
    enemigos = {}
    if n > 1 and n < 10 then
        local num_serpientes = 2
        local num_escorpiones = (n >= 6) and 2 or 1

        for i = 1, num_serpientes do
            add(enemigos, spawn_enemigo("serpiente", spr_serpiente, 0.35, 55, 8))
        end
        for i = 1, num_escorpiones do
            add(enemigos, spawn_enemigo("escorpion", spr_escorpion, 0.2, 45, 15))
        end
    elseif n == 10 then
        local jefe = spawn_enemigo("jefe", spr_escorpion, 0.45, 90, 20)
        jefe.spr = spr_escorpion
        add(enemigos, jefe)
    end
end

function iniciar_minerales_nivel()
    minerales = {}
    if nivel_actual == 10 then return end

    local cantidad = mid(2, 1 + nivel_actual, 5)
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
    repeat
        if nivel_actual == 1 then
            m.x = 16 + rnd(90)
            m.y = 35 + rnd(80)
        else
            m.x = 16 + rnd(200)
            m.y = 35 + rnd(200)
        end
        dist_x = abs(m.x - px)
        dist_y = abs(m.y - py)

        local lejos_de_otros = true
        for otro in all(minerales) do
            if otro != m and otro.activo then
                local ox = abs(m.x - otro.x)
                local oy = abs(m.y - otro.y)
                if ox < 20 and oy < 20 then
                    lejos_de_otros = false
                end
            end
        end

        intentos += 1
    until (posicion_libre(m.x, m.y) and (dist_x > 25 or dist_y > 25) and lejos_de_otros) or intentos > 100
    m.activo = true
end

function obtener_mineral_aleatorio(m)
    local bonus = nivel_actual * 0.01
    local suerte = rnd(1)
    if suerte > 0.85 - bonus then
        m.tipo = "zafiro"
        m.spr = spr_zafiro
    elseif suerte > 0.6 - bonus then
        m.tipo = "oro"
        m.spr = spr_oro
    else
        m.tipo = "carbon"
        m.spr = spr_carbon
    end
end

function solido(x, y)
    return fget(mget(flr(x / 8), flr(y / 8)), 0)
end

function posicion_libre(x, y)
    return not solido(x, y)
            and not solido(x + 7, y)
            and not solido(x, y + 7)
            and not solido(x + 7, y + 7)
end

-->8
-- logica de juego (enemigos, hoguera, recoleccion, fx)

function aplicar_ataque_enemigo(e)
    if timer_inmunidad > 0 then return end

    vida = mid(0, vida - e.danio, 100)
    timer_inmunidad = 30
    timer_flash_dano = 6
    sfx(7)

    if e.tipo == "escorpion" and not envenenado then
        envenenado = true
        timer_envenenamiento = 180
        velocidad = velocidad_base * 0.7
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
        if e.confundido then
            e.timer_confusion -= 1
            e.vx = 0
            e.vy = 0
            if e.timer_confusion <= 0 then
                e.confundido = false
            end
        else
            local dx = e.x - px
            local dy = e.y - py
            local dist_sq = dx * dx + dy * dy
            local vis_sq = e.radio_vision * e.radio_vision

            if dist_sq < vis_sq then
                local dist = sqrt(dist_sq)
                if dist > 0 then
                    e.vx = (dx / dist) * -e.v_base
                    e.vy = (dy / dist) * -e.v_base
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
                and abs(px - e.x) < 6 and abs(py - e.y) < 6 then
            aplicar_ataque_enemigo(e)
        end
    end
end

function actualizar_hoguera()
    if nivel_actual == 10 and not descanso then
        local cx = flr((px + 4) / 8)
        local cy = flr((py + 4) / 8)

        if mget(cx, cy) == spr_hoguera or mget(cx + 1, cy) == spr_hoguera
                or mget(cx - 1, cy) == spr_hoguera or mget(cx, cy + 1) == spr_hoguera then
            en_hoguera = true

            -- controlar el menu con las flechas izquierda (si) y derecha (no)
            if btnp(0) then opcion_hoguera = 1 end
            if btnp(1) then opcion_hoguera = 2 end

            -- confirmar con z (boton 4) o x (boton 5)
            if btnp(4) or btnp(5) then
                if opcion_hoguera == 1 then
                    vida = 100
                    descanso = true
                    sfx(5)
                else
                    py += 4 -- empujoncito para salir del rango
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
                combustible = mid(0, combustible + 25, 100)
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
        color = 14
    elseif tipo == "zafiro" then
        color = 12
    end
    add(textos_flotantes, { x = x, y = y, texto = texto, color = color, vida = 30 })
end

function actualizar_textos_flotantes()
    for tf in all(textos_flotantes) do
        tf.y -= 0.4
        tf.vida -= 1
        if tf.vida <= 0 then
            del(textos_flotantes, tf)
        end
    end
end

-->8
-- update principal

function _update()
    if timer_intro > 0 then
        timer_intro -= 1
        return
    end

    if escena_actual == 0 then
        if btnp(4) or btnp(5) then
            if ya_vio_instrucciones then
                cargar_nivel(1)
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
            cargar_nivel(1)
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

    actualizar_hoguera()
    if en_hoguera then return end
    -- pausa total mientras decide

    if timer_inmunidad > 0 then timer_inmunidad -= 1 end
    if timer_flash_dano > 0 then timer_flash_dano -= 1 end

    if envenenado then
        timer_envenenamiento -= 1
        if timer_envenenamiento % 60 == 0 then
            vida = mid(0, vida - 1, 100)
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

    local pos_ant_x = px
    local pos_ant_y = py

    local dx, dy = 0, 0
    if btn(0) then
        dx -= velocidad mirando_izq = true
    end
    if btn(1) then
        dx += velocidad mirando_izq = false
    end
    if btn(2) then dy -= velocidad end
    if btn(3) then dy += velocidad end

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
        if contador_pasos % 14 == 0 then
            sfx(4)
        end
    else
        contador_pasos = 0
    end

    if timer_chispa > 0 then timer_chispa -= 1 end
    if chispa_efecto > 0 then chispa_efecto -= 0.5 end

    if btnp(4) and combustible > 5 and timer_chispa == 0 then
        chispa_efecto = 15
        combustible -= 20
        timer_chispa = 100
        sfx(8)

        local radio_cegado = radio_base + 25
        for e in all(enemigos) do
            local edx = e.x - px
            local edy = e.y - py
            if edx * edx + edy * edy < radio_cegado * radio_cegado then
                e.confundido = true
                e.timer_confusion = 180
            end
        end

        if not antorcha.encendida then
            local adx = abs((px + 4) - (antorcha.x + 4))
            local ady = abs((py + 4) - (antorcha.y + 4))
            if adx < 12 and ady < 12 then
                antorcha.encendida = true
                antorcha.spr = spr_antorcha_e
                item_salida.activo = true
                item_salida.spr = spr_salida_a
            end
        end
    end
    chequea_recoleccion()

    if item_salida.activo
            and abs((px + 4) - (item_salida.x + 4)) < 8
            and abs((py + 4) - (item_salida.y + 4)) < 8
            and not transicion_salida
            and not mostrando_nivel_superado then
        transicion_salida = true
        timer_transicion = 40
        nivel_pendiente = nivel_actual + 1
        sfx(6)
    end

    if not transicion_salida then
        if combustible > 0 then
            combustible -= 0.04
            radio_luz = radio_base + chispa_efecto
        else
            combustible = 0
            radio_luz = mid(0, radio_luz - 0.4, 100)
            if radio_luz <= 0 then vida -= 0.5 end
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
            timer_nivel_superado = 120
        end
        return
    end

    if mostrando_nivel_superado then
        timer_nivel_superado -= 1
        if timer_nivel_superado <= 0 then
            mostrando_nivel_superado = false
            if nivel_pendiente > 10 then
                escena_actual = 3
                music(-1)
                sfx(10)
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

    actualizar_enemigos()
    actualizar_textos_flotantes()
end

-->8
-- dibujo: hud, luz, juego

function dibujar_luz_personaje(scx, scy)
    if radio_luz <= 0 then
        rectfill(0, 16, 128, 128, 0)
        return
    end

    local radio_final = radio_luz
    local d1 = radio_final + 6
    local d2 = radio_final + 14
    local d3 = radio_final + 24

    local cx = px + 4
    local cy = py + 4
    local cam_x = mid(0, cx - 64, 256 - 128)
    local cam_y = mid(0, cy - 64, 256 - 128)

    for x = 0, 128, 4 do
        for y = 16, 128, 4 do
            local dx = abs(scx - x)
            local dy = abs(scy - y)
            local dist_cuadrado = dx * dx + dy * dy

            -- calculo de iluminacion extra para la hoguera (nivel 10)
            local luz_hoguera = false
            if nivel_actual == 10 then
                local map_x = flr((x + cam_x) / 8)
                local map_y = flr((y + cam_y) / 8)

                -- revisa si hay una hoguera en un pequeno radio alrededor
                for hx = -3, 3 do
                    for hy = -3, 3 do
                        if mget(map_x + hx, map_y + hy) == spr_hoguera then
                            luz_hoguera = true
                        end
                    end
                end
            end

            if luz_hoguera then
                -- no aplica niebla gruesa cerca de la hoguera
            elseif dist_cuadrado >= d3 * d3 then
                fillp()
                rectfill(x, y, x + 3, y + 3, 0)
            elseif dist_cuadrado >= d2 * d2 then
                fillp(0x5a5a)
                rectfill(x, y, x + 3, y + 3, 0)
            elseif dist_cuadrado >= d1 * d1 then
                fillp(0x8888)
                rectfill(x, y, x + 3, y + 3, 0)
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
    rect(4, 9, 60, 13, 5)
    rectfill(5, 10, 5 + (combustible / 1.85), 12, 9)

    print("vida", 67, 2, 6)
    rect(67, 9, 123, 13, 5)
    rectfill(68, 10, 68 + (vida / 1.85), 12, 8)

    line(63, 1, 63, 16, 5)

    spr(spr_oro, 2, 19)
    print(oro, 10, 20, 14)

    spr(spr_zafiro, 26, 18)
    print(zafiro, 34, 20, 12)

    print("nv" .. nivel_actual .. "/" .. nivel_max, 90, 20, 6)

    if timer_chispa == 0 and combustible > 5 then
        rect(119, 17, 125, 25, 10)
        print("z", 121, 19, 10)
    else
        rect(119, 17, 125, 25, 5)
        print("z", 121, 19, 5)
    end
end

function dibujar_juego()
    cls(0)

    local cx = px + 4
    local cy = py + 4
    local cam_x = mid(0, cx - 64, 256 - 128)
    local cam_y = mid(0, cy - 64, 256 - 128)

    local shake_x, shake_y = 0, 0
    local vida_critica = vida < 20 and vida > 0

    if vida_critica then
        shake_x = rnd(0.6) - 0.3
        shake_y = rnd(0.6) - 0.3
    end

    if timer_flash_dano > 0 then
        rect(0, 0, 127, 127, 8)
    end

    camera(cam_x + shake_x, cam_y + shake_y)
    local scx = cx - cam_x
    local scy = cy - cam_y

    map(0, 0, 0, 0, 32, 32)

    for m in all(minerales) do
        if m.activo then
            local bob = sin(t() * 3 + m.x) * 0.4
            spr(m.spr, m.x, m.y + bob)
        end
    end

    for tf in all(textos_flotantes) do
        print(tf.texto, tf.x, tf.y, tf.color)
    end

    for e in all(enemigos) do
        spr(e.spr, e.x, e.y)
        if e.confundido then
            spr(spr_confusion, e.x, e.y - 6)
        end
    end

    spr(antorcha.spr, antorcha.x, antorcha.y)
    spr(item_salida.spr, item_salida.x, item_salida.y)

    local mostrar_jugador = true
    if timer_inmunidad > 0 and flr(t() * 15) % 2 == 0 then
        mostrar_jugador = false
    end
    if transicion_salida then mostrar_jugador = false end

    if mostrar_jugador then
        palt(0, true)
        spr(spr_jugador, px, py, 1, 1, mirando_izq)
        if mirando_izq then
            spr(spr_brazo, px - 5, py + 2, 1, 1, true)
        else
            spr(spr_brazo, px + 5, py + 2, 1, 1, false)
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

    dibujar_luz_personaje(scx, scy)

    if not antorcha.encendida and nivel_actual != 10 then
        local adx = abs((px + 4) - (antorcha.x + 4))
        local ady = abs((py + 4) - (antorcha.y + 4))
        if adx < 14 and ady < 14 then
            print("z: encender antorcha", 24, 100, 10)
        end
    end

    dibujar_hud()

    -- borde de alerta cuando la vida es critica, se dibuja al final para que no lo tape nada
    if vida_critica and flr(t() * 6) % 2 == 0 then
        fillp(0x5a5a)
        rect(0, 0, 127, 127, 8)
        fillp()
    end

    if en_hoguera then
        rectfill(18, 48, 110, 88, 0)
        rect(17, 47, 111, 89, 7)

        print("¿deseas descansar?", 24, 54, 7)
        print("recuperara tu vida", 24, 62, 6)

        if opcion_hoguera == 1 then
            print("> si", 38, 76, 11)
            print("  no", 74, 76, 5)
        else
            print("  si", 38, 76, 5)
            print("> no", 74, 76, 8)
        end
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
    print("como jugar", 44, 10, 7)

    print("flechas: moverse", 8, 26, 6)
    print("z: chispa", 8, 36, 6)
    print("obten carbon para sobrevivir", 8, 46, 6)
    print("oro y zafiros = monedas", 8, 56, 6)
    print("cuidado con los enemigos", 8, 66, 6)
    print("para ganar:", 8, 76, 6)
    print("-enciende la antorcha", 12, 86, 6)
    print("-busca la salida del nivel", 12, 96, 6)

    if flr(t() * 2) % 2 == 0 then
        print("z: inciar juego", 38, 115, 10)
    end
end

function dibujar_game_over()
    camera()
    cls(0)
    local texto1 = "la oscuridad te ha consumido"
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
    if mostrando_nivel_superado then
        dibujar_nivel_superado() return
    end
    dibujar_juego()
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
0000000053d53535000ddd00000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000750650700000000
000660003000003300d0000000dd7d00000000000000000000000000000000000000000000000000000000000000000000000000000000005355535000000000
00577500330000350d000dd00dddd7d000000a000000000000000000000000000000000000000000000000000000000000000000000000000730373500000000
00055000503003050d00d00d0dddddd00004a0000000000000000000000000000000000000000000000000000000000000000000000000003007565700000000
00055000300030030d00000d00dddd00004994000000000000000000000000000000000000000000000000000000000000000000000000005053503600000000
000550005000000500d000d0000dd00004999a400000000000000000000000000000000000000000000000000000000000000000000000007375675300000000
0005500050000005000ddd0000000000499999940000000000000000000000000000000000000000000000000000000000000000000000000565367500000000
00000000300000030000000000000000555555550000000000000000000000000000000000000000000000000000000000000000000000003057553500000000
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
e1000000000000e00000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e1000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e1000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e1000000000000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0000000000041e10000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
e0e0e1e0e0e0e1e1e0e0e0e0e0e1e0e0e0e0e1e0e0e0e0e1e1e1e1e1e0e0e0e0e0e0e0e0e0e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000e10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
__sfx__
010e00200c0231951517516195150c0231751519516175150c0231951517516195150c0231751519516175150c023135151f0111f5110c0231751519516175150c0231e7111e7102a7100c023175151951617515
000e002000130070200c51000130070200a51000130070200c51000130070200a5200a5200a5120a5120a51200130070200c51000130070200a51000130070200c510001300b5200a5200a5200a5120a5120a512
00020000335602c540265200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000653004520005101270010700107000560000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800003c0303f0303f03000000000001d0001d0001d0001f0002000021000250002b000160002600018000190001a0001c0001e0002000022000240002600028000290002c0000000000000000000000000000
000800000c0100e0100e0100f0101002011020130201402015030160301703019030190401a0401b0401c0401d0501e0501f05020060220602306024060250702607028070290702a0002b0002c0002e0002f000
000400001f1701614013130101200c110020100311027100191001b100000001b10000000191001e100191001e100191000000000000000000000000000000000000000000000000000000000000000000000000
0004000024670206601a65016640106300c6200261000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000d0500d0500e0500e0500e0500f0500f05010050180501b0501c0501d0501d0501b0501c0501c0502705025050270502705026050270502605026050310502e0502f0502e0502d0502e0502e0502d050
001000003506034040330403404033040320403004030040250402104022040210302203020030200301f03017030160201602015020140201202011020140200d0200a0200a020090100c0100b0100c01009010
__music__
01 00014344
02 00014344
