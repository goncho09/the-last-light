pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- the last light

-- constantes
    SPR_JUGADOR    = 1
SPR_BRAZO      = 2
SPR_ESCORPION  = 4
SPR_SERPIENTE  = 5
SPR_ANTORCHA_E = 6
SPR_ORO        = 8
SPR_ZAFIRO     = 9
SPR_CARBON     = 10
SPR_SALIDA_A   = 15
SPR_ANTORCHA   = 16
SPR_SALIDA     = 17
SPR_CONFUSION  = 18
SPR_VENENO     = 19

function _init()
  escena_actual = 0
  oro = 0
  zafiro = 0
  nivel_actual = 1
  timer_tutorial = 300

  antorcha   = {x=60, y=60, spr=SPR_ANTORCHA, encendida=false}
  item_salida = {x=90, y=40, spr=SPR_SALIDA,  activo=false}

  px = 24
  py = 24
  velocidad_base = 1.1
  velocidad      = 1.1
  mirando_izq    = false
  vida           = 100

  timer_inmunidad = 0

  radio_base  = 23
  radio_luz   = 23
  chispa_efecto = 0
  timer_chispa  = 0

  envenenado           = false
  timer_envenenamiento = 0
  burbujas_veneno      = {}

  minerales = {}
  enemigos  = {}
end

function generar_cueva_aleatoria()
  for x=0,31 do
    for y=0,31 do
      if rnd(1) > 0.25 then
        mset(x, y, 14)
      else
        mset(x, y, 30)
      end
    end
  end

  local wx = 3
  local wy = 3

  for x=1,4 do
    for y=1,4 do
      mset(x,y,0)
    end
  end

  local suelo_objetivo = 280
  local suelo_tallado  = 16

  while suelo_tallado < suelo_objetivo do
    local dir = flr(rnd(4))
    if     dir == 0 and wx > 2  then wx -= 1
    elseif dir == 1 and wx < 29 then wx += 1
    elseif dir == 2 and wy > 2  then wy -= 1
    elseif dir == 3 and wy < 29 then wy += 1
    end

    for dx=0,1 do
      for dy=0,1 do
        local tile = mget(wx+dx, wy+dy)
        if tile == 14 or tile == 30 then
          mset(wx+dx, wy+dy, 0)
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
     and dx1*dx1+dy1*dy1 > dist_min_entre_si^2
     and dx2*dx2+dy2*dy2 > dist_min_spawn^2
end

function cargar_nivel(n)
  nivel_actual   = n
  timer_tutorial = (n == 1) and 300 or 0

  if n == 1 then
    reload(0x2000, 0x2000, 0x1000)
    combustible   = 100
    texto_tutorial = "enciende la antorcha\ncon z para abrir salida."
  else
    generar_cueva_aleatoria()
    combustible   = mid(40, 95 - (n * 3), 100)
    texto_tutorial = ""
  end

  px = 24
  py = 24
  timer_inmunidad = 0

  antorcha.encendida = false
  antorcha.spr       = SPR_ANTORCHA

  local dist_minima       = 65
  local dist_minima_spawn = (n == 1) and 60 or 110
  local intentos          = 0

  repeat
    if n == 1 then
      antorcha.x    = 60 + rnd(50)
      antorcha.y    = 24 + rnd(70)
      item_salida.x = 16 + rnd(35)
      item_salida.y = 24 + rnd(70)
    else
      antorcha.x    = 16 + rnd(200)
      antorcha.y    = 16 + rnd(200)
      item_salida.x = 16 + rnd(200)
      item_salida.y = 16 + rnd(200)
    end
    intentos += 1
  until (posicion_valida_objeto(antorcha.x, antorcha.y, dist_minima, dist_minima_spawn)
     and posicion_libre(item_salida.x, item_salida.y)) or intentos > 500

  item_salida.activo = false
  item_salida.spr    = SPR_SALIDA

  iniciar_minerales_nivel()
  iniciar_enemigos_nivel(n)
end

function spawn_enemigo(tipo, spr, v_base, radio_vision, danio)
  local ex, ey, intentos = 0, 0, 0
  repeat
    ex = 16 + rnd(200)
    ey = 16 + rnd(200)
    local dx = ex - px
    local dy = ey - py
    intentos += 1
  until (posicion_libre(ex, ey) and dx*dx+dy*dy > 70*70) or intentos > 200
  return {tipo=tipo, spr=spr, x=ex, y=ey, vx=0, vy=0,
          v_base=v_base, radio_vision=radio_vision, danio=danio,
          confundido=false, timer_confusion=0}
end

function iniciar_enemigos_nivel(n)
  enemigos = {}
  if n > 1 then
    local num_serpientes  = 2
    local num_escorpiones = (n >= 6) and 2 or 1

    for i=1, num_serpientes  do add(enemigos, spawn_enemigo("serpiente", SPR_SERPIENTE, 0.35, 55,  5)) end
    for i=1, num_escorpiones do add(enemigos, spawn_enemigo("escorpion", SPR_ESCORPION, 0.2,  45, 10)) end
  end
end

function iniciar_minerales_nivel()
  minerales = {}
  local cantidad = mid(3, 2 + nivel_actual, 7)
  for i=1, cantidad do
    local m = {
      tipo  = "carbon",
      spr   = SPR_CARBON,
      activo = true,
      x = 0,
      y = 0
    }
    respawn_mineral(m)
    add(minerales, m)
  end
end

function respawn_mineral(m)
  local intentos = 0
  repeat
    if nivel_actual == 1 then
      m.x = 16 + rnd(90)
      m.y = 24 + rnd(80)
    else
      m.x = 16 + rnd(200)
      m.y = 16 + rnd(200)
    end
    local dist_x = abs(m.x - px)
    local dist_y = abs(m.y - py)
    intentos += 1
  until (posicion_libre(m.x, m.y) and (dist_x > 25 or dist_y > 25)) or intentos > 100
  m.activo = true
end

function obtener_mineral_aleatorio(m)
  local suerte = rnd(1)
  if suerte > 0.9 then
    m.tipo = "zafiro"
    m.spr  = SPR_ZAFIRO
  elseif suerte > 0.7 then
    m.tipo = "oro"
    m.spr  = SPR_ORO
  else
    m.tipo = "carbon"
    m.spr  = SPR_CARBON
  end
end

function solido(x, y)
  return fget(mget(flr(x/8), flr(y/8)), 0)
end

function posicion_libre(x, y)
  return not solido(x, y)
     and not solido(x + 7, y)
     and not solido(x, y + 7)
     and not solido(x + 7, y + 7)
end

function aplicar_ataque_enemigo(e)
  if timer_inmunidad > 0 then return end

  vida            = mid(0, vida - e.danio, 100)
  timer_inmunidad = 45

  if e.tipo == "escorpion" and not envenenado then
    envenenado           = true
    timer_envenenamiento = 180
    velocidad            = velocidad_base * 0.7
    for i=1, 4 do
      crear_burbuja_veneno()
    end
  end
end

function crear_burbuja_veneno()
  local b = {
    x         = px + 2 + rnd(4),
    y         = py + 2 + rnd(4),
    vx        = rnd(0.4) - 0.2,
    vy        = rnd(0.4) - 0.2,
    spr       = SPR_VENENO,
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
      local dx      = e.x - px
      local dy      = e.y - py
      local dist_sq = dx*dx + dy*dy
      local vis_sq  = e.radio_vision * e.radio_vision

      if dist_sq < vis_sq then
        local dist = sqrt(dist_sq)
        if dist > 0 then
          e.vx = (dx / dist) * -e.v_base
          e.vy = (dy / dist) * -e.v_base
        end
      else
        e.vx = 0
        e.vy = 0
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

function _update()
  if escena_actual == 0 then
    if btnp(4) or btnp(5) then
      cargar_nivel(1)
      escena_actual = 1
    end
    return
  end

  if vida <= 0 then
    if btn(5) then _init() end
    return
  end

  if timer_inmunidad > 0 then timer_inmunidad -= 1 end

  if envenenado then
    timer_envenenamiento -= 1
    if timer_envenenamiento % 60 == 0 then
      vida = mid(0, vida - 1, 100)
    end
    if flr(t()*4) % 2 == 0 then
      crear_burbuja_veneno()
    end
    actualizar_burbujas_veneno()
    if timer_envenenamiento <= 0 then
      envenenado      = false
      velocidad       = velocidad_base
      burbujas_veneno = {}
    end
  end

  local dx, dy = 0, 0
  if btn(0) then dx -= velocidad  mirando_izq = true  end
  if btn(1) then dx += velocidad  mirando_izq = false end
  if btn(2) then dy -= velocidad end
  if btn(3) then dy += velocidad end

  if dx ~= 0 then
    local nx = px + dx
    if posicion_libre(nx, py) then px = nx end
  end
  if dy ~= 0 then
    local ny = py + dy
    if posicion_libre(px, ny) then py = ny end
  end

  if timer_chispa > 0 then timer_chispa -= 1 end
  if chispa_efecto > 0 then chispa_efecto -= 0.5 end

  if btnp(4) and combustible > 5 and timer_chispa == 0 then
    chispa_efecto = 15
    combustible  -= 10
    timer_chispa  = 100

    local radio_cegado = radio_base + 25
    for e in all(enemigos) do
      local edx = e.x - px
      local edy = e.y - py
      if edx*edx + edy*edy < radio_cegado*radio_cegado then
        e.confundido      = true
        e.timer_confusion = 180
      end
    end

    if not antorcha.encendida then
      local adx = abs((px+4) - (antorcha.x+4))
      local ady = abs((py+4) - (antorcha.y+4))
      if adx < 12 and ady < 12 then
        antorcha.encendida = true
        antorcha.spr       = SPR_ANTORCHA_E
        item_salida.activo = true
        item_salida.spr    = SPR_SALIDA_A
      end
    end
  end

  if combustible > 0 then
    combustible -= 0.04
    radio_luz    = radio_base + chispa_efecto
  else
    combustible = 0
    radio_luz   = mid(0, radio_luz - 0.4, 100)
    if radio_luz <= 0 then vida -= 0.5 end
  end

  chequea_recoleccion()

  if item_salida.activo
     and abs((px+4) - (item_salida.x+4)) < 8
     and abs((py+4) - (item_salida.y+4)) < 8 then
    cargar_nivel(nivel_actual + 1)
  end

  if timer_tutorial > 0 then timer_tutorial -= 1 end

  actualizar_enemigos()
end

function chequea_recoleccion()
  for m in all(minerales) do
    if m.activo and abs(px - m.x) < 7 and abs(py - m.y) < 7 then
      if m.tipo == "carbon" then
        combustible = mid(0, combustible + 25, 100)
      elseif m.tipo == "oro" then
        oro += 1
      elseif m.tipo == "zafiro" then
        zafiro += 1
      end
      obtener_mineral_aleatorio(m)
      respawn_mineral(m)
    end
  end
end

function dibujar_luz_personaje(scx, scy)
  if radio_luz <= 0 then
    rectfill(0, 16, 128, 128, 0)
    return
  end

<<<<<<< HEAD
  local radio_final = radio_luz 
  local d1 = radio_final + 6
  local d2 = radio_final + 14
  local d3 = radio_final + 24

  for x = 0, 128, 4 do
    for y = 16, 128, 4 do
      local dx            = abs(scx - x)
      local dy            = abs(scy - y)
      local dist_cuadrado = dx*dx + dy*dy

      if dist_cuadrado >= d3*d3 then
        rectfill(x, y, x+3, y+3, 0)
      elseif dist_cuadrado >= d2*d2 then
        fillp(0x5a5a)
        rectfill(x, y, x+3, y+3, 0)
      elseif dist_cuadrado >= d1*d1 then
        fillp(0x8888)
  rectfill(x, y, x+3, y+3, 0)
end
=======
  local radio_penumbra = radio_luz + 14

  for x = 0, 128, 4 do
    for y = 16, 128, 4 do
      local dx          = abs(scx - x)
      local dy          = abs(scy - y)
      local dist_cuadrado = dx * dx + dy * dy

      if dist_cuadrado >= radio_penumbra * radio_penumbra then
        rectfill(x, y, x + 3, y + 3, 0)
      elseif dist_cuadrado > radio_luz * radio_luz then
        fillp(0x5a5a)
        rectfill(x, y, x + 3, y + 3, 0)
      end
>>>>>>> faaa64b6104e6097d28be13c917d6476c337b897
    end
  end
  fillp()

<<<<<<< HEAD
  circ(scx, scy, radio_final, 6)
=======
  circ(scx, scy, radio_luz, 6)
>>>>>>> faaa64b6104e6097d28be13c917d6476c337b897
end

function dibujar_titulo()
  cls(0)
  local offset_x  = cos(t()*0.5) * 4
  local pulso_luz = 25 + sin(t()*2)*2
  circfill(63 + offset_x, 61, pulso_luz, 10)

  spr(SPR_JUGADOR, 60, 58)

  print("the last light", 37, 50, 1)
  local col_titulo = 7
  if rnd(1) > 0.9 then col_titulo = 6 end
  print("the last light", 36, 49, col_titulo)

  if flr(t()*2)%2==0 then
    print("presiona z para comenzar", 16, 90, 6)
  end
end

function dibujar_game_over()
  cls(0)
  print("la oscuridad te ha consumido", 10, 60, 7)
  print("pulsa x para reintentar", 20, 70, 6)
end

function dibujar_hud()
  rectfill(0, 0, 127, 15, 0)
  line(0, 15, 127, 15, 5)
  print("combustible", 4, 1, 6)
  rectfill(4, 8, 4 + (combustible/2.5), 9, 10)
  print("vida", 55, 1, 6)
  rectfill(55, 8, 55 + (vida/2.5), 9, 11)
  print("oro:"    .. oro,          2,   11, 14)
  print("zafiro:" .. zafiro,       42,  11, 12)
  print("nv:"     .. nivel_actual, 100, 10,  6)

  if timer_chispa == 0 and combustible > 5 then
    print("z", 92, 10, 10)
  end

  if timer_tutorial > 0 and texto_tutorial != "" then
    print(texto_tutorial, 20, 40, 7)
  end
end

function dibujar_juego()
  cls(0)

  local cx    = px + 4
  local cy    = py + 4
  local cam_x = mid(0, cx - 64, 256 - 128)
  local cam_y = mid(0, cy - 64, 256 - 128)

  camera(cam_x, cam_y)
  local scx = cx - cam_x
  local scy = cy - cam_y

  map(0, 0, 0, 0, 32, 32)

  for m in all(minerales) do
    if m.activo then spr(m.spr, m.x, m.y) end
  end

  for e in all(enemigos) do
    spr(e.spr, e.x, e.y)
    if e.confundido then
      spr(SPR_CONFUSION, e.x, e.y - 6)
    end
  end

  spr(antorcha.spr,    antorcha.x,    antorcha.y)
  spr(item_salida.spr, item_salida.x, item_salida.y)

  local mostrar_jugador = true
  if timer_inmunidad > 0 and flr(t()*15) % 2 == 0 then
    mostrar_jugador = false
  end

  if mostrar_jugador then
    palt(0, true)
    spr(SPR_JUGADOR, px, py, 1, 1, mirando_izq)
    if mirando_izq then
      spr(SPR_BRAZO, px - 5, py + 2, 1, 1, true)
    else
      spr(SPR_BRAZO, px + 5, py + 2, 1, 1, false)
    end
    palt()
  end

  if envenenado then
    palt(0, true)
    for b in all(burbujas_veneno) do
      spr(b.spr, b.x, b.y)
    end
    palt()
  end

  camera()

  dibujar_luz_personaje(scx, scy)

  if not antorcha.encendida then
    local adx = abs((px+4) - (antorcha.x+4))
    local ady = abs((py+4) - (antorcha.y+4))
    if adx < 14 and ady < 14 then
      print("z: encender antorcha", 24, 100, 10)
    end
  end

  dibujar_hud()
end

function _draw()
  if escena_actual == 0 then dibujar_titulo()   return end
  if vida <= 0         then dibujar_game_over() return end
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
00577500330000350d000dd00dddd7d0000000000000000000000000000000000000000000000000000000000000000000000000000000000730373500000000
00055000503003050d00d00d0dddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000003007565700000000
00055000300030030d00000d00dddd00000000000000000000000000000000000000000000000000000000000000000000000000000000005053503600000000
000550005000000500d000d0000dd000000000000000000000000000000000000000000000000000000000000000000000000000000000007375675300000000
0005500050000005000ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000565367500000000
00000000300000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003057553500000000
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
__music__
01 41424344