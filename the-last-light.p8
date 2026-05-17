pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
function respawn_mineral(m)
  -- posicion inical separad de pared y hud
  m.x = 4 + rnd(120)
  m.y = 24 + rnd(95)
  
  -- mantenemos una distancia minima del jugador (px, py)
  -- para que no te aparezca uno en la cara apenas lo agarras
  local dist_x = abs(m.x - px)
  local dist_y = abs(m.y - py)
  
  if dist_x < 30 and dist_y < 30 then
    -- si cayo muy cerca, reintentamos la funcion
    return respawn_mineral(m)
  end
  
  m.activo = true
end


function iniciar_nivel()
		minerales = {} 
		
		for i=1, 2 do
    local m = {
      tipo = "carbon",
      spr = 10,
      activo = true
    }
    respawn_mineral(m)
    add(minerales, m)
  end
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

function chequea_recoleccion()
  -- recorremos toda la tabla de minerales generada proceduralmente
  for m in all(minerales) do
    -- chequeamos distancia entre jugador (px, py) y cada mineral m
    if abs(px - m.x) < 6 and abs(py - m.y) < 6 then
      
      -- logica segun el tipo de item
      if m.tipo == "carbon" then
        -- mid asegura que el combustible no pase de 100
        oxigeno = mid(0, oxigeno + 25, 100)
      elseif m.tipo == "oro" then
        oro += 1
      elseif m.tipo == "zafiro" then
        zafiro += 1
      end
      
      -- genera un nuevo mineral (aleatoriamente entre los 3)
      obtener_mineral_aleatorio(m)
      respawn_mineral(m)
      
      -- sfx(1) -- sonido de recolectar
    end
  end
end

function _init()
  -- variables de estado
  oxigeno = 100
  vida = 100        
  radio_base = 15   -- el radio ahora es constante
  radio_luz = 15    
  nivel_actual = 1
  
  chispa_efecto = 0  -- la expansion visual
  timer_chispa = 0   -- el tiempo de espera (cooldown)
  
  -- escenas 
  
  escena_actual = 0
  
  -- posicion inicial
  px = 64 
  py = 64
  velocidad = 1.2
  mirando_izq = false
  
  -- minerales
  carbon = 0
  oro = 0
  zafiro = 0
  
  minerales = {}
end

function _update()

		if escena_actual == 0 then
			if btnp(4) or btnp(5) then -- presionar z o x para empezar
      iniciar_nivel()
      escena_actual = 1
   end
		else if escena_actual  == 1 then
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
	  if btnp(4) and oxigeno > 5 and timer_chispa == 0 then
	    chispa_efecto = 20  -- expansion mas moderada
	    oxigeno -= 5    
	    timer_chispa = 60   -- espera de 2 segundos (60 frames)
	  end
	
	  -- logica de combustible y radio
	  if oxigeno > 0 then
	    oxigeno -= 0.05 
	    -- el radio ya no se achica, se mantiene fijo + el efecto
	    radio_luz = radio_base + chispa_efecto
	  else
	    oxigeno = 0
	    radio_luz = 0
	  end
	  
		 chequea_recoleccion(item_carb)
			chequea_recoleccion(item_oro)
			chequea_recoleccion(item_zafiro)
		end
end
end

function dibujar_luz_personaje()
		fillp()
		
		-- si esta fuera del radio no mostrar
		if radio_luz <= 0 then
    rectfill(0, 0, 128, 128, 0)
    return
  end
  
		local radio_penumbra = radio_luz + 18
		
		for x = 0, 128, 4 do
    for y = 0, 128, 4 do
      -- calculamos la distancia entre el pixel actual y el centro del minero
      local dx = abs((px + 4) - x)
      local dy = abs((py + 4) - y)
      local dist_cuadrado = dx * dx + dy * dy
      
      -- oscuridad total
      if dist_cuadrado >= radio_penumbra * radio_penumbra then
        rectfill(x, y, x + 3, y + 3, 0)
        
      -- penumbra con dithering 
      elseif dist_cuadrado > radio_luz * radio_luz then
        fillp(0x5a5a) -- patron de tablero de ajedrez
        rectfill(x, y, x + 3, y + 3, 0.5) -- el .5 lo hace transparente
      end
    end
  end
		
  -- limpiar patron
  fillp()
  
  circ(px + 4, py + 4, radio_luz, 6)
end

function _draw()
  cls(0)
  
  if escena_actual == 0 then
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
  
  elseif escena_actual == 1 then
  
	  -- minerales
	 	for m in all(minerales) do
    if m.activo then
      spr(m.spr, m.x, m.y)
    end
  	end
	  
	  -- radio de luz
	  dibujar_luz_personaje()
	  
	  -- minero
	  spr(1, px, py, 1, 1, mirando_izq, false)
	
			local ex = px -- coordenada x del encendedor
			local ey = py + 2 -- coordenada y (un poquito mれくs abajo de la cabeza)
			
			if mirando_izq then
					ex = px - 5
			  spr(2, ex, ey, 1, 1, true)
			else
			   ex = px + 5
			  spr(2, ex, ey, 1, 1, false)
			end
	
	  -- 2. interfaz (hud)
	  rectfill(0, 0, 127, 15, 0) -- fondo negro
	  line(0, 15, 127, 15, 5)    -- la barra gris divisoria
	
	  -- barras superiores (combustible y vida)
	  print("oxigeno", 4, 1, 6)
	  rectfill(4, 8, 4 + (oxigeno / 2.5), 9, 10) 
	  
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

