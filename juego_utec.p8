pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function respawn_mineral(m)
  -- m es la tabla del mineral que queremos mover
  m.x = 8 + rnd(112)
  -- el limite superior es 20 para no aparecer en el hud
  m.y = 20 + rnd(100)
  m.activo = true
end

function _init()
  -- variables de estado
  combustible = 100
  vida = 100        
  radio_base = 15   -- el radio ahora es constante
  radio_luz = 15    
  nivel_actual = 1
  
  chispa_efecto = 0  -- la expansion visual
  timer_chispa = 0   -- el tiempo de espera (cooldown)
  
  -- posicion inicial
  px = 64 
  py = 64
  velocidad = 1.2
  mirando_izq = false
  
  -- minerales
  carbon = 0
  oro = 0
  zafiro = 0
  
  item_carb = {x=0, y=0, spr=10, tipo="carbon"}
  item_oro = {x=0, y=0, spr=8, tipo="oro"}
  item_zafiro = {x=0, y=0, spr=9, tipo="zafiro"}

		respawn_mineral(item_carb)
  respawn_mineral(item_oro)
  respawn_mineral(item_zafiro)
end

function chequea_recoleccion(m)
  -- calculamos distancia entre jugador y el mineral m
  if abs(px - m.x) < 6 and abs(py - m.y) < 6 then
    
    if m.tipo == "carbon" then
      combustible = mid(0, combustible + 25, 100)
    elseif m.tipo == "oro" then
      oro += 1
    elseif m.tipo == "zafiro" then
      zafiro += 1
    end
    
    -- una vez recolectado, lo mandamos a otro lado
    respawn_mineral(m)
    -- sfx(1) -- sonido de recolectar
  end
end

function _update()
  -- movimiento
  if btn(⬅️) then px -= velocidad mirando_izq = true end
  if btn(➡️) then px += velocidad mirando_izq = false end
  if btn(⬆️) then py -= velocidad end
  if btn(⬇️) then py += velocidad end
  
  px = mid(0, px, 120)
  py = mid(16, py, 120) 
  
  -- manejo del temporizador de la chispa
  if timer_chispa > 0 then
    timer_chispa -= 1
  end

  -- desvanecimiento de la chispa
  if chispa_efecto > 0 then
    chispa_efecto -= 1 -- cae mas lento para que se vea mejor
  end
  
  -- mecanica de chispa corregida
  if btnp(4) and combustible > 5 and timer_chispa == 0 then
    chispa_efecto = 20  -- expansion mas moderada
    combustible -= 5    
    timer_chispa = 60   -- espera de 2 segundos (60 frames)
  end

  -- logica de combustible y radio
  if combustible > 0 then
    combustible -= 0.05 
    -- el radio ya no se achica, se mantiene fijo + el efecto
    radio_luz = radio_base + chispa_efecto
  else
    combustible = 0
    radio_luz = 0
  end
  
  chequea_recoleccion(item_carb)
		chequea_recoleccion(item_oro)
		chequea_recoleccion(item_zafiro)
end

function _draw()
  cls(0)
  
  -- 1. mundo y minerales
  spr(1, px, py, 1, 1, mirando_izq, false)
  spr(item_carb.spr, item_carb.x, item_carb.y)
  spr(item_oro.spr, item_oro.x, item_oro.y)
  spr(item_zafiro.spr, item_zafiro.x, item_zafiro.y)
  
  -- luz
  if radio_luz > 0 then
    circ(px+4, py+4, radio_luz, 6)
  end

  -- 2. interfaz (hud)
  rectfill(0, 0, 127, 15, 0) -- fondo negro
  line(0, 15, 127, 15, 5)    -- la barra gris divisoria

  -- barras superiores (combustible y vida)
  print("combustible", 4, 1, 6)
  rectfill(4, 8, 4 + (combustible / 2.5), 9, 10) 
  
  print("vida", 55, 1, 6)
  rectfill(55, 8, 55 + (vida / 2.5), 9, 11) 

  -- indicadores de minerales (justo arriba de la linea gris)
  -- usamos y=10 para que esten pegados a la barra divisoria
  
  -- icono de oro (podes usar spr si tenes uno, o un punto de color)
  print("oro:", 2, 11, 14) 
  print(oro, 20, 11, 7)
  
  -- icono de zafiro
  print("zafiro:", 42, 11, 12)
  print(zafiro, 72, 11, 7)

  -- nivel (esquina derecha)
  print("nv:"..nivel_actual, 100, 10, 6)
  
  -- aviso de chispa lista
  if timer_chispa == 0 then print("!", 92, 10, 10) end
end
__gfx__
00000000005555000000000000600600000004400000000000000000000000000000000000000000000000000000000000076000000000050000000000000000
000000000555555000000000065555600000440000000730000440000005500000aaaa00000cc000005555000000000000076000000000550000000000000000
00700700056ff650000a4000605445060000400000000334005aa500005555000a7aaa9000c7cc00056755500066600000076000000005500000000000000000
0007700000ffff00006556000654456000555500000033000005500005aaaa500aaaaa900ccc7cc0057655500055550000076000000055000000000000000000
0007700001111110006556000055550005655650000330000005500005aa4a500aaaaa900c1c11c0055555500005900000076000000550000000000000000000
0070070001111110006556000055550005555559003300000005500005a4aa500099990000c1cc00055555500005000000555500055500000000000000000000
000000000001100000655600065555609555555903300000000550000055550000000000000cc000005555000005000000055000050500000000000000000000
00000000044004400000000060000006090000903300000000000000000000000000000000000000000000000000000000055000055500000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 41424344

