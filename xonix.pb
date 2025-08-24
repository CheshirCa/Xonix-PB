; Xonix / Qix-like game in PureBasic 6.21
; Windows version with graphical console

EnableExplicit

; --- Конфигурация игры ----------------------------------------------------
#TARGET_PERCENT = 75   ; Процент заполнения для завершения уровня
#START_LIVES = 3       ; Начальное количество жизней
#START_ENEMIES = 2     ; Начальное количество врагов
#MAX_FPS = 30          ; Максимальный FPS
#BASE_SPEED = 0.6      ; Базовая скорость врагов (ячеек/секунду)
#SPEED_GROWTH = 0.15   ; Увеличение скорости врагов за уровень
#SPEED_CHANGE = 0.1    ; Изменение скорости при нажатии +/-

; Типы ячеек игрового поля
Enumeration
  #SEA    ; Море - свободное пространство
  #LAND   ; Земля - захваченная территория
  #TRAIL  ; След - временная траектория игрока
EndEnumeration

; Цвета игры
#COLOR_SEA = $000000      ; Черный - море
#COLOR_LAND = $00FF00     ; Зеленый - земля
#COLOR_TRAIL = $00AA00    ; Темно-зеленый - след
#COLOR_ENEMY = $FFFF00    ; Желтый - враги
#COLOR_PLAYER = $FFFFFF   ; Белый - игрок
#COLOR_TEXT = $00FF00     ; Зеленый - текст HUD
#COLOR_HUD_BG = $000000   ; Черный - фон HUD
#COLOR_WHITE = $FFFFFF    ; Белый - текст паузы и помощи

Structure Enemy
  x.f    ; X координата врага
  y.f    ; Y координата врага
  vx.f   ; Скорость по X
  vy.f   ; Скорость по Y
EndStructure

Structure GameStats
  level.i    ; Текущий уровень
  lives.i    ; Количество жизней
  filled.f   ; Процент заполнения
EndStructure

; Глобальные переменные
Global Dim grid.i(0, 0)          ; Игровое поле
Global player_x.i, player_y.i    ; Позиция игрока
Global player_vx.i, player_vy.i  ; Направление движения игрока
Global player_moving.i           ; Флаг движения игрока
Global NewList enemies.Enemy()   ; Список врагов
Global game_stats.GameStats      ; Статистика игры
Global screen_width.i = 800      ; Ширина экрана
Global screen_height.i = 600     ; Высота экрана
Global grid_width.i = 80         ; Ширина сетки
Global grid_height.i = 55        ; Высота сетки
Global cell_size.i = 10          ; Размер ячейки
Global level_complete.i          ; Флаг завершения уровня
Global game_over.i               ; Флаг окончания игры
Global game_paused.i = #False    ; Флаг паузы
Global show_help.i = #False      ; Флаг показа справки
Global enemy_speed.f = #BASE_SPEED ; Текущая скорость врагов
Global any_key_pressed.i = #False ; Флаг нажатия любой клавиши

; Глобальные шрифты
Global pause_font.i = #PB_Any    
Global help_font.i = #PB_Any     
Global help_small_font.i = #PB_Any 
Global big_font.i = #PB_Any      
Global medium_font.i = #PB_Any   

Procedure.f RandomFloat(min.f, max.f)
  ; Генерация случайного числа в диапазоне
  ProcedureReturn min + (max - min) * Random(1000) / 1000.0
EndProcedure

Procedure Clamp(n.i, lo.i, hi.i)
  ; Ограничение числа в диапазоне
  If n < lo
    ProcedureReturn lo
  ElseIf n > hi
    ProcedureReturn hi
  Else
    ProcedureReturn n
  EndIf
EndProcedure

Procedure IsPassable(x.i, y.i, grid_width.i, grid_height.i)
  ; Проверка, можно ли пройти через ячейку
  If x < 0 Or x >= grid_width Or y < 0 Or y >= grid_height
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(grid(y, x) <> #LAND)
EndProcedure

Procedure InitGrid(grid_width.i, grid_height.i)
  ; Инициализация игрового поля
  Protected y.i, x.i
  
  Dim grid(grid_height - 1, grid_width - 1)
  
  ; Заполнение морем
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      grid(y, x) = #SEA
    Next
  Next
  
  ; Создание границы из земли
  For x = 0 To grid_width - 1
    grid(0, x) = #LAND
    grid(grid_height - 1, x) = #LAND
  Next
  
  For y = 0 To grid_height - 1
    grid(y, 0) = #LAND
    grid(y, grid_width - 1) = #LAND
  Next
EndProcedure

Procedure.f PercentLand(grid_width.i, grid_height.i)
  ; Расчет процента заполнения земли
  Protected y.i, x.i, land_count.i = 0
  
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #LAND
        land_count + 1
      EndIf
    Next
  Next
  
  ProcedureReturn 100.0 * land_count / (grid_width * grid_height)
EndProcedure

Procedure FloodFromEnemies(grid_width.i, grid_height.i, Array visited.a(2))
  ; Заполнение области от врагов (для определения захваченных зон)
  Protected x.i, y.i, nx.i, ny.i, dx.i, dy.i
  Protected NewList queue.i()
  
  ; Инициализация массива посещенных ячеек
  Dim visited(grid_height - 1, grid_width - 1)
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      visited(y, x) = #False
    Next
  Next
  
  ; Старт от каждой позиции врага
  ForEach enemies()
    Protected sx.i = Clamp(Round(enemies()\x, #PB_Round_Nearest), 0, grid_width - 1)
    Protected sy.i = Clamp(Round(enemies()\y, #PB_Round_Nearest), 0, grid_height - 1)
    
    If grid(sy, sx) = #LAND
      ; Если враг на земле, проверяем соседей
      For dx = -1 To 1 Step 2
        nx = sx + dx
        If nx >= 0 And nx < grid_width And grid(sy, nx) <> #LAND And Not visited(sy, nx)
          visited(sy, nx) = #True
          AddElement(queue()): queue() = nx << 16 | sy
        EndIf
      Next
      
      For dy = -1 To 1 Step 2
        ny = sy + dy
        If ny >= 0 And ny < grid_height And grid(ny, sx) <> #LAND And Not visited(ny, sx)
          visited(ny, sx) = #True
          AddElement(queue()): queue() = sx << 16 | ny
        EndIf
      Next
    Else
      visited(sy, sx) = #True
      AddElement(queue()): queue() = sx << 16 | sy
    EndIf
  Next
  
  ; BFS заполнение
  While FirstElement(queue())
    Protected current.i = queue()
    x = current >> 16
    y = current & $FFFF
    DeleteElement(queue())
    
    For dx = -1 To 1 Step 2
      nx = x + dx
      If nx >= 0 And nx < grid_width And Not visited(y, nx) And grid(y, nx) <> #LAND
        visited(y, nx) = #True
        AddElement(queue()): queue() = nx << 16 | y
        EndIf
    Next
    
    For dy = -1 To 1 Step 2
      ny = y + dy
      If ny >= 0 And ny < grid_height And Not visited(ny, x) And grid(ny, x) <> #LAND
        visited(ny, x) = #True
        AddElement(queue()): queue() = x << 16 | ny
      EndIf
    Next
  Wend
EndProcedure

Procedure CommitTrail(grid_width.i, grid_height.i)
  ; Преобразование следа в землю и захват областей
  Protected y.i, x.i, captured.i = 0
  Dim visited.a(0, 0)
  
  ; Конвертация следа в землю
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #TRAIL
        grid(y, x) = #LAND
      EndIf
    Next
  Next
  
  ; Поиск областей, достижимых от врагов
  FloodFromEnemies(grid_width, grid_height, visited())
  
  ; Захват недостижимых областей
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) <> #LAND And Not visited(y, x)
        grid(y, x) = #LAND
        captured + 1
        player_moving = #False
      EndIf
    Next
  Next
  
  ProcedureReturn captured
EndProcedure

Procedure AddRandomEnemy(grid_width.i, grid_height.i, speed.f)
  ; Добавление случайного врага
  Protected e.Enemy
  Protected tries.i = 0
  Protected ex.i, ey.i
  
  Repeat
    ex = Random(grid_width - 3, 2)
    ey = Random(grid_height - 3, 2)
    tries + 1
  Until grid(ey, ex) <> #LAND Or tries > 100
  
  e\x = ex
  e\y = ey
  
  e\vx = speed * (1 - 2 * Random(1)) * RandomFloat(0.6, 1.0)
  e\vy = speed * (1 - 2 * Random(1)) * RandomFloat(0.6, 1.0)
  
  AddElement(enemies())
  enemies()\x = e\x
  enemies()\y = e\y
  enemies()\vx = e\vx
  enemies()\vy = e\vy
EndProcedure

Procedure LoadGameFonts()
  ; Загрузка шрифтов для игры (вызывается один раз при старте)
  If pause_font = #PB_Any
    pause_font = LoadFont(#PB_Any, "Arial", 48, #PB_Font_Bold)
  EndIf
  If help_font = #PB_Any
    help_font = LoadFont(#PB_Any, "Arial", 24, #PB_Font_Bold)
  EndIf
  If help_small_font = #PB_Any
    help_small_font = LoadFont(#PB_Any, "Arial", 16)
  EndIf
  If big_font = #PB_Any
    big_font = LoadFont(#PB_Any, "Arial", 36, #PB_Font_Bold)
  EndIf
  If medium_font = #PB_Any
    medium_font = LoadFont(#PB_Any, "Arial", 24, #PB_Font_Bold)
  EndIf
EndProcedure

Procedure FreeGameFonts()
  ; Освобождение шрифтов игры
  If IsFont(pause_font) : FreeFont(pause_font) : pause_font = #PB_Any : EndIf
  If IsFont(help_font) : FreeFont(help_font) : help_font = #PB_Any : EndIf
  If IsFont(help_small_font) : FreeFont(help_small_font) : help_small_font = #PB_Any : EndIf
  If IsFont(big_font) : FreeFont(big_font) : big_font = #PB_Any : EndIf
  If IsFont(medium_font) : FreeFont(medium_font) : medium_font = #PB_Any : EndIf
EndProcedure

Procedure DrawScreen()
  ; Отрисовка игрового экрана
  Protected y.i, x.i
  Protected enemy_at_pos.i
  Protected hud_height.i = 40
  Protected game_field_height.i = grid_height * cell_size
  Protected hud_y.i = game_field_height + 10
  
  ; Очистка экрана
  ClearScreen(#COLOR_SEA)
  
  ; Начало рисования
  StartDrawing(ScreenOutput())
  
  ; Отрисовка игрового поля
  DrawingMode(#PB_2DDrawing_Default)
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      Select grid(y, x)
        Case #LAND
          Box(x * cell_size, y * cell_size, cell_size, cell_size, #COLOR_LAND)
        Case #TRAIL
          Box(x * cell_size, y * cell_size, cell_size, cell_size, #COLOR_TRAIL)
      EndSelect
    Next
  Next
  
  ; Отрисовка врагов
  ForEach enemies()
    Circle(Round(enemies()\x * cell_size + cell_size/2, #PB_Round_Nearest), 
           Round(enemies()\y * cell_size + cell_size/2, #PB_Round_Nearest), 
           cell_size/2, #COLOR_ENEMY)
  Next
  
  ; Отрисовка игрока
  Circle(player_x * cell_size + cell_size/2, player_y * cell_size + cell_size/2, cell_size/2, #COLOR_PLAYER)
  
  ; Очистка области HUD
  Box(0, game_field_height, screen_width, hud_height, #COLOR_HUD_BG)
  
  ; Разделительная линия
  Box(0, game_field_height - 2, screen_width, 2, #COLOR_TEXT)
  
  ; Текст HUD
  DrawingFont(GetStockObject_(#ANSI_FIXED_FONT))
  DrawingMode(#PB_2DDrawing_Transparent)
  
  DrawText(10, hud_y, "Lvl:" + Str(game_stats\level), #COLOR_TEXT)
  DrawText(80, hud_y, "Lives:" + Str(game_stats\lives), #COLOR_TEXT)
  DrawText(150, hud_y, "Filled:" + StrF(game_stats\filled, 1) + "%", #COLOR_TEXT)
  DrawText(250, hud_y, "Target:" + Str(#TARGET_PERCENT) + "%", #COLOR_TEXT)
  DrawText(350, hud_y, "Enemies:" + ListSize(enemies()), #COLOR_TEXT)
  DrawText(450, hud_y, "Speed:" + StrF(enemy_speed, 1), #COLOR_TEXT)
  DrawText(550, hud_y, "Esc=Quit", #COLOR_TEXT)
  DrawText(630, hud_y, "F1=Help", #COLOR_TEXT)
  
  ; Сообщение паузы
  If game_paused And Not show_help
    If IsFont(pause_font)
      DrawingFont(FontID(pause_font))
    EndIf
    Protected paused_text.s = "PAUSED"
    Protected paused_width.i = TextWidth(paused_text)
    DrawText(screen_width/2 - paused_width/2, screen_height/2 - 40, paused_text, #COLOR_WHITE)
    
    DrawingFont(GetStockObject_(#ANSI_VAR_FONT))
    Protected continue_text.s = "Press P to continue"
    Protected continue_width.i = TextWidth(continue_text)
    DrawText(screen_width/2 - continue_width/2, screen_height/2 + 20, continue_text, #COLOR_WHITE)
  EndIf
  
  ; Окно справки
  If show_help
    Protected help_width.i = 550
    Protected help_height.i = 350
    Protected help_x.i = (screen_width - help_width) / 2
    Protected help_y.i = (screen_height - help_height) / 2
    
    ; Фон окна справки
    Box(help_x, help_y, help_width, help_height, #COLOR_HUD_BG)
    Box(help_x, help_y, help_width, help_height, #COLOR_WHITE)
    Box(help_x + 2, help_y + 2, help_width - 4, help_height - 4, #COLOR_HUD_BG)
    
    ; Заголовок справки
    If IsFont(help_font)
      DrawingFont(FontID(help_font))
    EndIf
    Protected title_text.s = "XONIX GAME - CONTROLS"
    Protected title_width.i = TextWidth(title_text)
    DrawText(help_x + (help_width - title_width) / 2, help_y + 20, title_text, #COLOR_WHITE)
    
    ; Содержание справки
    If IsFont(help_small_font)
      DrawingFont(FontID(help_small_font))
    EndIf
    
    Protected controls.s = "Movement:"
    Protected control1.s = "W/A/S/D or Arrows - Move player"
    Protected control2.s = "P - Pause/Resume game"
    Protected control3.s = "F1 - Show this help screen"
    Protected control4.s = "Esc - Quit game"
    Protected control5.s = "+/- - Increase/decrease enemy speed"
    Protected control6.s = "N - Add new enemy"
    Protected footer.s = "Press any key to close help"
    
    DrawText(help_x + (help_width - TextWidth(controls)) / 2, help_y + 60, controls, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control1)) / 2, help_y + 90, control1, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control2)) / 2, help_y + 120, control2, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control3)) / 2, help_y + 150, control3, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control4)) / 2, help_y + 180, control4, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control5)) / 2, help_y + 210, control5, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(control6)) / 2, help_y + 240, control6, #COLOR_WHITE)
    DrawText(help_x + (help_width - TextWidth(footer)) / 2, help_y + 290, footer, #COLOR_WHITE)
  EndIf
  
  StopDrawing()
  
  FlipBuffers()
EndProcedure

Procedure LevelBanner(level.i)
  ; Баннер начала уровня
  ClearScreen(#COLOR_SEA)
  StartDrawing(ScreenOutput())
  
  ; Заголовок уровня
  If IsFont(big_font)
    DrawingFont(FontID(big_font))
  EndIf
  DrawingMode(#PB_2DDrawing_Transparent)
  
  Protected level_text.s = "LEVEL " + Str(level)
  Protected level_width.i = TextWidth(level_text)
  DrawText(screen_width/2 - level_width/2, screen_height/2 - 50, level_text, #COLOR_TEXT)
  
  ; Подзаголовок
  If IsFont(medium_font)
    DrawingFont(FontID(medium_font))
  EndIf
  
  Protected ready_text.s = "get ready..."
  Protected ready_width.i = TextWidth(ready_text)
  DrawText(screen_width/2 - ready_width/2, screen_height/2, ready_text, #COLOR_TEXT)
  
  StopDrawing()
  FlipBuffers()
  Delay(1000)
EndProcedure

Procedure GameOverScreen()
  ; Экран окончания игры
  ClearScreen(#COLOR_SEA)
  StartDrawing(ScreenOutput())
  
  ; Заголовок
  If IsFont(big_font)
    DrawingFont(FontID(big_font))
  EndIf
  DrawingMode(#PB_2DDrawing_Transparent)
  
  Protected gameover_text.s = "GAME OVER"
  Protected gameover_width.i = TextWidth(gameover_text)
  DrawText(screen_width/2 - gameover_width/2, screen_height/2 - 40, gameover_text, #COLOR_TEXT)
  
  ; Инструкция
  If IsFont(medium_font)
    DrawingFont(FontID(medium_font))
  EndIf
  
  Protected exit_text.s = "press any key to exit"
  Protected exit_width.i = TextWidth(exit_text)
  DrawText(screen_width/2 - exit_width/2, screen_height/2 + 20, exit_text, #COLOR_TEXT)
  
  StopDrawing()
  FlipBuffers()
  
  ; Ждем нажатия любой клавиши
  Repeat
    Delay(50)
    ExamineKeyboard()
  Until KeyboardReleased(#PB_Key_All)
EndProcedure

Procedure LevelCompleteScreen(level.i)
  ; Экран завершения уровня
  ClearScreen(#COLOR_SEA)
  StartDrawing(ScreenOutput())
  
  ; Заголовок
  If IsFont(big_font)
    DrawingFont(FontID(big_font))
  EndIf
  DrawingMode(#PB_2DDrawing_Transparent)
  
  Protected complete_text.s = "LEVEL " + Str(level) + " COMPLETE!"
  Protected complete_width.i = TextWidth(complete_text)
  DrawText(screen_width/2 - complete_width/2, screen_height/2 - 40, complete_text, #COLOR_TEXT)
  
  ; Подзаголовок
  If IsFont(medium_font)
    DrawingFont(FontID(medium_font))
  EndIf
  
  Protected next_text.s = "Moving to next level..."
  Protected next_width.i = TextWidth(next_text)
  DrawText(screen_width/2 - next_width/2, screen_height/2 + 20, next_text, #COLOR_TEXT)
  
  StopDrawing()
  FlipBuffers()
  Delay(1500)
EndProcedure

Procedure ShowSplashScreen()
  ; Заставка при запуске игры
  Protected title_font.i, copyright_font.i
  Protected title_height.i = screen_height / 10
  Protected title_x.i, title_y.i, copyright_x.i, copyright_y.i
  Protected y.i, x.i
  
  ; Создание шрифтов
  title_font = LoadFont(#PB_Any, "Arial", title_height, #PB_Font_Bold)
  copyright_font = LoadFont(#PB_Any, "Arial", 16)
  
  ; Инициализация сетки для отображения границы
  InitGrid(grid_width, grid_height)
  
  ClearScreen(#COLOR_SEA)
  StartDrawing(ScreenOutput())
  
  ; Отрисовка игровой границы
  DrawingMode(#PB_2DDrawing_Default)
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #LAND
        Box(x * cell_size, y * cell_size, cell_size, cell_size, #COLOR_LAND)
      EndIf
    Next
  Next
  
  ; Отрисовка заголовка
  If title_font
    DrawingFont(FontID(title_font))
  EndIf
  DrawingMode(#PB_2DDrawing_Transparent)
  
  Protected title_text.s = "XONIX"
  Protected title_width.i = TextWidth(title_text)
  title_x = (screen_width - title_width) / 2
  title_y = (screen_height - title_height) / 3
  DrawText(title_x, title_y, title_text, #COLOR_LAND)
  
  ; Отрисовка копирайта (центрирован относительно XONIX)
  If copyright_font
    DrawingFont(FontID(copyright_font))
  EndIf
  
  Protected copyright_text.s = "(C) CheshirCa 2025"
  Protected copyright_width.i = TextWidth(copyright_text)
  copyright_x = title_x + (title_width - copyright_width) / 2
  copyright_y = title_y + title_height + 20
  DrawText(copyright_x, copyright_y, copyright_text, #COLOR_LAND)
  
  StopDrawing()
  FlipBuffers()
  
  ; Отображение в течение 3 секунд
  Delay(3000)
  
  ; Очистка шрифтов
  If title_font : FreeFont(title_font) : EndIf
  If copyright_font : FreeFont(copyright_font) : EndIf
EndProcedure

Procedure ProcessInput()
  ; Обработка ввода пользователя
  Static last_p_key.i = #False
  Static last_f1_key.i = #False
  Static last_plus_key.i = #False
  Static last_minus_key.i = #False
  Static last_n_key.i = #False
  
  ; Выход по Esc
  If KeyboardPushed(#PB_Key_Escape)
    game_over = #True
    ProcedureReturn
  EndIf
  
  ; Переключение паузы клавишей P
  If KeyboardPushed(#PB_Key_P) And Not last_p_key
    game_paused = ~game_paused
    show_help = #False
  EndIf
  last_p_key = KeyboardPushed(#PB_Key_P)
  
  ; Обработка F1 - ставит игру на паузу и показывает справку
  If KeyboardPushed(#PB_Key_F1) And Not last_f1_key
    show_help = #True
    game_paused = #True
    any_key_pressed = #False
  EndIf
  last_f1_key = KeyboardPushed(#PB_Key_F1)
  
  ; Закрыть справку при нажатии любой клавиши (кроме F1)
  If show_help
    ; Простая проверка: если нажата любая клавиша кроме F1
    If KeyboardReleased(#PB_Key_All) And Not KeyboardPushed(#PB_Key_F1)
      show_help = #False
      game_paused = #False
    EndIf
  EndIf
  
  ; Увеличение скорости врагов клавишей +
  If KeyboardPushed(#PB_Key_Add) And Not last_plus_key
    enemy_speed + #SPEED_CHANGE
    ; Обновляем скорость всех врагов
    ForEach enemies()
      Protected magnitude.f = Sqr(enemies()\vx * enemies()\vx + enemies()\vy * enemies()\vy)
      If magnitude > 0
        enemies()\vx = enemies()\vx / magnitude * enemy_speed
        enemies()\vy = enemies()\vy / magnitude * enemy_speed
      EndIf
    Next
  EndIf
  last_plus_key = KeyboardPushed(#PB_Key_Add)
  
  ; Уменьшение скорости врагов клавишей -
  If KeyboardPushed(#PB_Key_Subtract) And Not last_minus_key And enemy_speed > #SPEED_CHANGE
    enemy_speed - #SPEED_CHANGE
    ; Обновляем скорость всех врагов
    ForEach enemies()
      magnitude.f = Sqr(enemies()\vx * enemies()\vx + enemies()\vy * enemies()\vy)
      If magnitude > 0
        enemies()\vx = enemies()\vx / magnitude * enemy_speed
        enemies()\vy = enemies()\vy / magnitude * enemy_speed
      EndIf
    Next
  EndIf
  last_minus_key = KeyboardPushed(#PB_Key_Subtract)
  
  ; Добавление нового врага клавишей N
  If KeyboardPushed(#PB_Key_N) And Not last_n_key
    AddRandomEnemy(grid_width, grid_height, enemy_speed)
  EndIf
  last_n_key = KeyboardPushed(#PB_Key_N)
  
  ; Обработка клавиш движения только если нет паузы и справки
  If Not game_paused And Not show_help
    If KeyboardPushed(#PB_Key_W) Or KeyboardPushed(#PB_Key_Up)
      player_vx = 0
      player_vy = -1
      player_moving = #True
    ElseIf KeyboardPushed(#PB_Key_S) Or KeyboardPushed(#PB_Key_Down)
      player_vx = 0
      player_vy = 1
      player_moving = #True
    ElseIf KeyboardPushed(#PB_Key_D) Or KeyboardPushed(#PB_Key_Right)
      player_vx = 1
      player_vy = 0
      player_moving = #True
    ElseIf KeyboardPushed(#PB_Key_A) Or KeyboardPushed(#PB_Key_Left)
      player_vx = -1
      player_vy = 0
      player_moving = #True
    EndIf
  EndIf
EndProcedure


Procedure UpdateGame(dt.f)
  ; Обновление игровой логики
  Protected nx.i, ny.i, e.Enemy
  
  ; Не обновлять игру если пауза или показана справки
  If game_paused Or show_help
    ProcedureReturn
  EndIf
  
  ; Движение врагов
  ForEach enemies()
    e\x = enemies()\x
    e\y = enemies()\y
    e\vx = enemies()\vx
    e\vy = enemies()\vy
    
    ; Попытка движения по горизонтали
    nx = Round(e\x + e\vx * dt, #PB_Round_Nearest)
    If Not IsPassable(nx, Round(e\y, #PB_Round_Nearest), grid_width, grid_height)
      e\vx = -e\vx
      nx = Round(e\x + e\vx * dt, #PB_Round_Nearest)
    EndIf
    
    ; Попытка движения по вертикали
    ny = Round(e\y + e\vy * dt, #PB_Round_Nearest)
    If Not IsPassable(Round(e\x, #PB_Round_Nearest), ny, grid_width, grid_height)
      e\vy = -e\vy
      ny = Round(e\y + e\vy * dt, #PB_Round_Nearest)
    EndIf
    
    e\x + e\vx * dt
    e\y + e\vy * dt
    
    enemies()\x = e\x
    enemies()\y = e\y
    enemies()\vx = e\vx
    enemies()\vy = e\vy
  Next
  
  ; Проверка столкновения врага со следом
  ForEach enemies()
    Protected ex.i = Round(enemies()\x, #PB_Round_Nearest)
    Protected ey.i = Round(enemies()\y, #PB_Round_Nearest)
    
    If grid(ey, ex) = #TRAIL
      game_stats\lives - 1
      
      ; Очистка следа и сброс игрока к безопасной границе
      For ny = 0 To grid_height - 1
        For nx = 0 To grid_width - 1
          If grid(ny, nx) = #TRAIL
            grid(ny, nx) = #SEA
          EndIf
        Next
      Next
      
      player_x = grid_width / 2
      player_y = grid_height - 1
      player_vx = 0
      player_vy = 0
      player_moving = #False
      
      ; Краткая пауза при смерти
      Delay(600)
      Break
    EndIf
  Next
  
  If game_stats\lives <= 0
    game_over = #True
    ProcedureReturn
  EndIf
  
  ; Движение игрока
  If player_moving
    nx = Clamp(player_x + player_vx, 0, grid_width - 1)
    ny = Clamp(player_y + player_vy, 0, grid_height - 1)
    
    ; Проверка столкновения с собственным следом
    If grid(ny, nx) = #TRAIL
      game_stats\lives - 1
      
      ; Очистка следа
      For ny = 0 To grid_height - 1
        For nx = 0 To grid_width - 1
          If grid(ny, nx) = #TRAIL
            grid(ny, nx) = #SEA
          EndIf
        Next
      Next
      
      player_x = grid_width / 2
      player_y = grid_height - 1
      player_vx = 0
      player_vy = 0
      player_moving = #False
      
      Delay(600)
      ProcedureReturn
    EndIf
    
    ; Если движение из земли в море - оставляем след
    If grid(ny, nx) = #SEA
      grid(ny, nx) = #TRAIL
    ElseIf grid(ny, nx) = #LAND And grid(player_y, player_x) = #TRAIL
      ; Замкнули фигуру - преобразуем след и захватываем область
      CommitTrail(grid_width, grid_height)
      player_moving = #False
    EndIf
    player_x = nx
    player_y = ny
  EndIf
  
  ; Столкновение врага с игроком
  ForEach enemies()
    If Round(enemies()\x, #PB_Round_Nearest) = player_x And Round(enemies()\y, #PB_Round_Nearest) = player_y
      game_stats\lives - 1
      
      ; Очистка следа и сброс
      For ny = 0 To grid_height - 1
        For nx = 0 To grid_width - 1
          If grid(ny, nx) = #TRAIL
            grid(ny, nx) = #SEA
            player_moving = #False
            EndIf
        Next
      Next
      
      player_x = grid_width / 2
      player_y = grid_height - 1
      player_vx = 0
      player_vy = 0
      
      Delay(600)
      Break
    EndIf
  Next
  
  If game_stats\lives <= 0
    game_over = #True
    ProcedureReturn
  EndIf
  
  ; Проверка завершения уровня
  game_stats\filled = PercentLand(grid_width, grid_height)
  If game_stats\filled >= #TARGET_PERCENT
    level_complete = #True
  EndIf
EndProcedure

Procedure Main()
  ; Главная процедура игры
  Protected level.i = 1
  Protected last_time.i, current_time.i, dt.f
  Protected frame_time.i = 1000 / #MAX_FPS
  Protected speed.f
  Protected i.i
  Protected sleep_time.i
  Protected event.i
  
  ; Инициализация графического экрана
  InitSprite()
  InitKeyboard()
  OpenWindow(0, 0, 0, screen_width, screen_height, "Xonix Game", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
  OpenWindowedScreen(WindowID(0), 0, 0, screen_width, screen_height)
  
  ; Загрузка шрифтов
  LoadGameFonts()
  
  ; Показ заставки
  ShowSplashScreen()
  
  ; Главный игровой цикл
  Repeat
    ; Инициализация уровня
    game_over = #False
    level_complete = #False
    player_moving = #False
    player_x = grid_width / 2
    player_y = grid_height - 1
    player_vx = 0
    player_vy = 0
    
    ; Настройка скорости врагов в зависимости от уровня
    speed = #BASE_SPEED + (level - 1) * #SPEED_GROWTH
    enemy_speed = speed
    
    ; Инициализация сетки
    InitGrid(grid_width, grid_height)
    
    ; Инициализация врагов
    ClearList(enemies())
    For i = 1 To #START_ENEMIES + level - 1
      AddRandomEnemy(grid_width, grid_height, speed)
    Next
    
    ; Инициализация статистики
    game_stats\level = level
    game_stats\lives = #START_LIVES
    game_stats\filled = PercentLand(grid_width, grid_height)
    
    ; Баннер уровня
    LevelBanner(level)
    
    ; Игровой цикл уровня
    last_time = ElapsedMilliseconds()
    Repeat
      current_time = ElapsedMilliseconds()
      dt = (current_time - last_time) / 1000.0
      last_time = current_time
      
      ; Ограничение FPS
      sleep_time = frame_time - (ElapsedMilliseconds() - current_time)
      If sleep_time > 0
        Delay(sleep_time)
      EndIf
      
      ; Обработка событий
      Repeat
        event = WindowEvent()
        If event = #PB_Event_CloseWindow
          game_over = #True
          Break 2
        EndIf
      Until event = 0
      
      ; Обработка ввода
      ExamineKeyboard()
      ProcessInput()
      
      ; Обновление игры
      UpdateGame(dt)
      
      ; Отрисовка
      DrawScreen()
      
    Until level_complete Or game_over
    
    If level_complete
      LevelCompleteScreen(level)
      level + 1
    EndIf
    
  Until game_over
  
  ; Экран окончания игры
  If game_stats\lives <= 0
    GameOverScreen()
  EndIf
  
  ; Освобождение ресурсов
  FreeGameFonts()
EndProcedure

; Запуск игры
Main()
End
; IDE Options = PureBasic 6.21 (Windows - x86)
; CursorPosition = 629
; Folding = ----
; Optimizer
; EnableThread
; EnableXP
; UseIcon = Xonix_Hi.ico
; Executable = xonix.exe