pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- the last light
-- version procedimental pulida (con pasillos anchos y musgo)

function _init()
  escena_actual = 0 
  oro = 0
  zafiro = 0
  nivel_actual = 1
  timer_tutorial = 300

  antorcha = {x=60, y=60, spr=16, encendida=false}
  item_salida = {x=90, y=40, spr=17, activo=false}

  px = 24
  py = 24
  velocidad = 1.1
  mirando_izq = false
  vida = 100

  radio_base = 18
  radio_luz  = 18
  chispa_efecto = 0
  timer_chispa  = 0

  minerales = {}
end

function generar_cueva_aleatoria()
  -- 1. llenar el mapa con una mezcla de muros normales (14) y con musgo (30)
  for x=0,31 do
    for y=0,31 do
      if rnd(1) > 0.25 then
        mset(x, y, 14)
      else
        mset(x, y, 30) -- variedad visual con musgo
      end
    end
  end

  -- 2. el excavador inicia en la zona del jugador
  local wx = 3
  local wy = 3
  
  -- despejar un れくrea inicial amplia y segura de 4x4 tiles alrededor del spawn
  for x=1,4 do
    for y=1,4 do
      mset(x,y,0)
    end
  end

  -- tallar pasillos usando una brocha de 2x2 (cuevas mas anchas y fluidas)
  local suelo_objetivo = 280 
  local suelo_tallado = 16

  while suelo_tallado < suelo_objetivo do
    local dir = flr(rnd(4))
    if     dir == 0 and wx > 2  then wx -= 1
    elseif dir == 1 and wx < 29 then wx += 1
    elseif dir == 2 and wy > 2  then wy -= 1
    elseif dir == 3 and wy < 29 then wy += 1
    end

    -- limpiamos en bloque de 2x2 para evitar pasillos de un solo tile de ancho
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

function cargar_nivel(n)
  nivel_actual = n
  timer_tutorial = (n == 1) and 300 or 0

  if n == 1 then
    -- restaura el mapa guardado en el cartucho para el tutorial
    reload(0x2000, 0x2000, 0x1000)
    combustible  = 100
    texto_tutorial  = "enciende la antorcha\ncon z para abrir salida."
  else
    -- generar cueva procedimental mejorada para niveles superiores
    generar_cueva_aleatoria()
    combustible  = mid(40, 95 - (n * 3), 100) 
    texto_tutorial  = ""
  end

  -- spawn seguro del jugador
  px = 24
  py = 24

  antorcha.encendida = false
  antorcha.spr = 16

  local dist_minima = 65  
  local intentos = 0

  repeat
    if n == 1 then
      antorcha.x = 60 + rnd(50)
      antorcha.y = 24 + rnd(70)
      item_salida.x = 16 + rnd(35)
      item_salida.y = 24 + rnd(70)
    else
      -- coordenadas libres por los pasillos excavados
      antorcha.x = 16 + rnd(200)
      antorcha.y = 16 + rnd(200)
      item_salida.x = 16 + rnd(200)
      item_salida.y = 16 + rnd(200)
    end

    local dx = antorcha.x - item_salida.x
    local dy = antorcha.y - item_salida.y
    local dist_ok = (dx*dx + dy*dy > dist_minima*dist_minima)

    local ant_libre = not solido(antorcha.x, antorcha.y)
                  and not solido(antorcha.x+7, antorcha.y+7)
    local sal_libre = not solido(item_salida.x, item_salida.y)
                  and not solido(item_salida.x+7, item_salida.y+7)

    intentos += 1
  until (dist_ok and ant_libre and sal_libre) or intentos > 500

  item_salida.activo = false
  item_salida.spr = 17

  iniciar_minerales_nivel()
end

function iniciar_minerales_nivel()
  minerales = {} 
  local cantidad = mid(3, 2 + nivel_actual, 7)
  for i=1, cantidad do 
    local m = {
      tipo = "carbon",
      spr = 10,
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
  until (not solido(m.x, m.y) and not solido(m.x+7, m.y+7) and (dist_x > 25 or dist_y > 25)) or intentos > 100
  
  m.activo = true
end

function obtener_mineral_aleatorio(m)
  local suerte = rnd(1)
  if suerte > 0.9 then
    m.tipo = "zafiro"
    m.spr = 9
  elseif suerte > 0.7 then
    m.tipo = "oro"
    m.spr = 8
  else
    m.tipo = "carbon"
    m.spr = 10
  end
end

function solido(x, y)
  return fget(mget(flr(x/8), flr(y/8)), 0)
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

  local dx, dy = 0, 0
  if btn(0) then dx -= velocidad  mirando_izq = true  end
  if btn(1) then dx += velocidad  mirando_izq = false end
  if btn(2) then dy -= velocidad end
  if btn(3) then dy += velocidad end

  if dx ~= 0 then
    local nx = px + dx
    if not solido(nx,py) and not solido(nx+7,py) and
       not solido(nx,py+7) and not solido(nx+7,py+7) then
      px = nx
    end
  end
  if dy ~= 0 then
    local ny = py + dy
    if not solido(px,ny) and not solido(px+7,ny) and
       not solido(px,ny+7) and not solido(px+7,ny+7) then
      py = ny
    end
  end

  if timer_chispa > 0 then timer_chispa -= 1 end
  if chispa_efecto > 0 then chispa_efecto -= 0.5 end

  if btnp(4) and combustible > 5 and timer_chispa == 0 then
    chispa_efecto = 15
    combustible  -= 10
    timer_chispa  = 100

    if not antorcha.encendida then
      local adx = abs((px+4) - (antorcha.x+4))
      local ady = abs((py+4) - (antorcha.y+4))
      if adx < 12 and ady < 12 then
        antorcha.encendida = true
        antorcha.spr = 6     
        item_salida.activo = true
        item_salida.spr = 15 
      end
    end
  end

  if combustible > 0 then
    combustible -= 0.04
    radio_luz = radio_base + chispa_efecto
  else
    combustible = 0
    radio_luz = mid(0, radio_luz - 0.4, 100)
    if radio_luz <= 0 then vida -= 0.5 end
  end

  chequea_recoleccion()

  if item_salida.activo
     and abs((px+4) - (item_salida.x+4)) < 8
     and abs((py+4) - (item_salida.y+4)) < 8 then
    cargar_nivel(nivel_actual + 1)
  end

  if timer_tutorial > 0 then timer_tutorial -= 1 end
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
  
  local radio_penumbra = radio_luz + 14
  
  for x = 0, 128, 4 do
    for y = 16, 128, 4 do
      local dx = abs(scx - x)
      local dy = abs(scy - y)
      local dist_cuadrado = dx * dx + dy * dy
      
      if dist_cuadrado >= radio_penumbra * radio_penumbra then
        rectfill(x, y, x + 3, y + 3, 0) 
      elseif dist_cuadrado > radio_luz * radio_luz then
        fillp(0x5a5a) 
        rectfill(x, y, x + 3, y + 3, 0) 
      end
    end
  end
  fillp() 
  
  circ(scx, scy, radio_luz, 6)
end

function _draw()
  if escena_actual == 0 then
    cls(0)
    local offset_x = cos(t()*0.5) * 4
    local pulso_luz = 25 + sin(t()*2)*2
    circfill(63 + offset_x, 61, pulso_luz, 10) 

    spr(1, 60, 58)  

    print("the last light", 37, 50, 1) 
    local col_titulo = 7
    if (rnd(1) > 0.9) col_titulo = 6 
    print("the last light", 36, 49, col_titulo)

    if (flr(t()*2)%2==0) then
      print("presiona z para comenzar", 16, 90, 6)
    end
    return
  end

  if vida <= 0 then
    cls(0)
    print("la oscuridad te ha consumido", 10, 60, 7)
    print("pulsa x para reintentar", 20, 70, 6)
    return
  end

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

  spr(antorcha.spr, antorcha.x, antorcha.y)
  spr(item_salida.spr, item_salida.x, item_salida.y)

  palt(0, true)
  spr(1, px, py, 1, 1, mirando_izq)
  
  local ex = px
  local ey = py + 2
  if mirando_izq then
    spr(2, px - 5, ey, 1, 1, true)
  else
    spr(2, px + 5, ey, 1, 1, false)
  end
  palt()

  camera()

  dibujar_luz_personaje(scx, scy)

  if not antorcha.encendida then
    local adx = abs((px+4) - (antorcha.x+4))
    local ady = abs((py+4) - (antorcha.y+4))
    if adx < 14 and ady < 14 then
      print("z: encender antorcha", 24, 100, 10)
    end
  end

  rectfill(0, 0, 127, 15, 0)
  line(0, 15, 127, 15, 5)
  print("combustible", 4, 1, 6)
  rectfill(4, 8, 4 + (combustible/2.5), 9, 10)
  print("vida", 55, 1, 6)
  rectfill(55, 8, 55 + (vida/2.5), 9, 11)
  print("oro:"    .. oro,          2, 11, 14)
  print("zafiro:" .. zafiro,      42, 11, 12)
  print("nv:"     .. nivel_actual,100, 10,  6)

  if timer_chispa == 0 and combustible > 5 then
    print("z", 92, 10, 10)
  end

  if timer_tutorial > 0 and texto_tutorial != "" then
    print(texto_tutorial, 20, 40, 7)
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

