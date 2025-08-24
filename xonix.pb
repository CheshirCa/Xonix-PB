; Xonix Qix-like game in PureBasic 6.21
; Version 1.1
; (c) CheshirCa 2025 https://github.com/CheshirCa/Xonix-PB
; Windows version with graphical console

EnableExplicit

; --- Конфигурация игры ----------------------------------------------------
; Значения по умолчанию
#DEFAULT_TARGET_PERCENT = 75   ; Процент заполнения для завершения уровня
#DEFAULT_START_LIVES = 3       ; Начальное количество жизней
#DEFAULT_START_ENEMIES = 2     ; Начальное количество врагов
#DEFAULT_MAX_FPS = 30          ; Максимальный FPS
#DEFAULT_BASE_SPEED = 0.6      ; Базовая скорость врагов (ячеек/секунду)
#DEFAULT_SPEED_GROWTH = 0.15   ; Увеличение скорости врагов за уровень
#DEFAULT_SPEED_CHANGE = 0.1    ; Изменение скорости при нажатии +/-

; Глобальные переменные для конфигурации
Global TARGET_PERCENT.i = #DEFAULT_TARGET_PERCENT
Global START_LIVES.i = #DEFAULT_START_LIVES
Global START_ENEMIES.i = #DEFAULT_START_ENEMIES
Global MAX_FPS.i = #DEFAULT_MAX_FPS
Global BASE_SPEED.f = #DEFAULT_BASE_SPEED
Global SPEED_GROWTH.f = #DEFAULT_SPEED_GROWTH
Global SPEED_CHANGE.f = #DEFAULT_SPEED_CHANGE

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
#COLOR_RED = $FF0000      ; Красный - для диалогов

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
Global enemy_speed.f = #DEFAULT_BASE_SPEED ; Текущая скорость врагов
Global any_key_pressed.i = #False ; Флаг нажатия любой клавиши
Global exit_confirmation.i = #False ; Флаг подтверждения выхода
Global restart_game.i = #False   ; Флаг перезапуска игры
Global current_enemy_count.i = #DEFAULT_START_ENEMIES ; Текущее количество врагов

; Глобальные шрифты
Global pause_font.i = #PB_Any    
Global help_font.i = #PB_Any     
Global help_small_font.i = #PB_Any 
Global big_font.i = #PB_Any      
Global medium_font.i = #PB_Any   
Global dialog_font.i = #PB_Any

Procedure LoadConfigFromINI()
  ; Загрузка конфигурации из INI файла
  If OpenPreferences("xonix.ini")
    TARGET_PERCENT = ReadPreferenceInteger("TargetPercent", #DEFAULT_TARGET_PERCENT)
    START_LIVES = ReadPreferenceInteger("StartLives", #DEFAULT_START_LIVES)
    START_ENEMIES = ReadPreferenceInteger("StartEnemies", #DEFAULT_START_ENEMIES)
    MAX_FPS = ReadPreferenceInteger("MaxFPS", #DEFAULT_MAX_FPS)
    BASE_SPEED = ReadPreferenceFloat("BaseSpeed", #DEFAULT_BASE_SPEED)
    SPEED_GROWTH = ReadPreferenceFloat("SpeedGrowth", #DEFAULT_SPEED_GROWTH)
    SPEED_CHANGE = ReadPreferenceFloat("SpeedChange", #DEFAULT_SPEED_CHANGE)
    
    ClosePreferences()
    ProcedureReturn #True
  Else
    ; Файл не существует, используем значения по умолчанию
    TARGET_PERCENT = #DEFAULT_TARGET_PERCENT
    START_LIVES = #DEFAULT_START_LIVES
    START_ENEMIES = #DEFAULT_START_ENEMIES
    MAX_FPS = #DEFAULT_MAX_FPS
    BASE_SPEED = #DEFAULT_BASE_SPEED
    SPEED_GROWTH = #DEFAULT_SPEED_GROWTH
    SPEED_CHANGE = #DEFAULT_SPEED_CHANGE
    ProcedureReturn #False
  EndIf
EndProcedure

Procedure SaveConfigToINI()
  ; Сохранение конфигурации в INI файл
  If CreatePreferences("xonix.ini")
    WritePreferenceInteger("TargetPercent", TARGET_PERCENT)
    WritePreferenceInteger("StartLives", START_LIVES)
    WritePreferenceInteger("StartEnemies", START_ENEMIES)
    WritePreferenceInteger("MaxFPS", MAX_FPS)
    WritePreferenceFloat("BaseSpeed", BASE_SPEED)
    WritePreferenceFloat("SpeedGrowth", SPEED_GROWTH)
    WritePreferenceFloat("SpeedChange", SPEED_CHANGE)
    
    ClosePreferences()
    ProcedureReturn #True
  Else
    ProcedureReturn #False
  EndIf
EndProcedure

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
  If dialog_font = #PB_Any
    dialog_font = LoadFont(#PB_Any, "Arial", 18, #PB_Font_Bold)
  EndIf
EndProcedure

Procedure FreeGameFonts()
  ; Освобождение шрифтов игры
  If IsFont(pause_font) : FreeFont(pause_font) : pause_font = #PB_Any : EndIf
  If IsFont(help_font) : FreeFont(help_font) : help_font = #PB_Any : EndIf
  If IsFont(help_small_font) : FreeFont(help_small_font) : help_small_font = #PB_Any : EndIf
  If IsFont(big_font) : FreeFont(big_font) : big_font = #PB_Any : EndIf
  If IsFont(medium_font) : FreeFont(medium_font) : medium_font = #PB_Any : EndIf
  If IsFont(dialog_font) : FreeFont(dialog_font) : dialog_font = #PB_Any : EndIf
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
  DrawText(250, hud_y, "Target:" + Str(TARGET_PERCENT) + "%", #COLOR_TEXT)
  DrawText(350, hud_y, "Enemies:" + ListSize(enemies()), #COLOR_TEXT)
  DrawText(450, hud_y, "Speed:" + StrF(enemy_speed, 1), #COLOR_TEXT)
  DrawText(550, hud_y, "Esc=Quit", #COLOR_TEXT)
  DrawText(630, hud_y, "F1=Help", #COLOR_TEXT)
  
  ; Сообщение паузы
  If game_paused And Not show_help And Not exit_confirmation
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
  
  ; Диалог подтверждения выхода
  If exit_confirmation
    Protected dialog_width.i = 400
    Protected dialog_height.i = 150
    Protected dialog_x.i = (screen_width - dialog_width) / 2
    Protected dialog_y.i = (screen_height - dialog_height) / 2
    
    ; Фон диалога
    Box(dialog_x, dialog_y, dialog_width, dialog_height, #COLOR_HUD_BG)
    Box(dialog_x, dialog_y, dialog_width, dialog_height, #COLOR_WHITE)
    Box(dialog_x + 2, dialog_y + 2, dialog_width - 4, dialog_height - 4, #COLOR_HUD_BG)
    
    ; Текст диалога
    If IsFont(dialog_font)
      DrawingFont(FontID(dialog_font))
    EndIf
    DrawingMode(#PB_2DDrawing_Transparent)
    
    Protected exit_text.s = "Are you sure you want to quit?"
    Protected exit_width.i = TextWidth(exit_text)
    DrawText(dialog_x + (dialog_width - exit_width) / 2, dialog_y + 30, exit_text, #COLOR_WHITE)
    
    Protected choice_text.s = "Y - Yes, N - No"
    Protected choice_width.i = TextWidth(choice_text)
    DrawText(dialog_x + (dialog_width - choice_width) / 2, dialog_y + 80, choice_text, #COLOR_WHITE)
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
  ; Экран окончания игры с предложением сыграть еще раз
  ClearScreen(#COLOR_SEA)
  StartDrawing(ScreenOutput())
  
  ; Заголовок
  If IsFont(big_font)
    DrawingFont(FontID(big_font))
  EndIf
  DrawingMode(#PB_2DDrawing_Transparent)
  
  Protected gameover_text.s = "GAME OVER"
  Protected gameover_width.i = TextWidth(gameover_text)
  DrawText(screen_width/2 - gameover_width/2, screen_height/2 - 60, gameover_text, #COLOR_TEXT)
  
  ; Статистика
  If IsFont(medium_font)
    DrawingFont(FontID(medium_font))
  EndIf
  
  Protected level_text.s = "Level reached: " + Str(game_stats\level)
  Protected level_width.i = TextWidth(level_text)
  DrawText(screen_width/2 - level_width/2, screen_height/2 - 10, level_text, #COLOR_TEXT)
  
  ; Инструкция
  Protected restart_text.s = "Press R to play again or ESC to quit"
  Protected restart_width.i = TextWidth(restart_text)
  DrawText(screen_width/2 - restart_width/2, screen_height/2 + 40, restart_text, #COLOR_TEXT)
  
  StopDrawing()
  FlipBuffers()
  
  ; Ждем нажатия клавиши R или ESC
  Repeat
    Delay(50)
    ExamineKeyboard()
    If KeyboardPushed(#PB_Key_R)
      restart_game = #True
      Break
    ElseIf KeyboardPushed(#PB_Key_Escape)
      restart_game = #False
      Break
    EndIf
  ForEver
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
  Static last_esc_key.i = #False
  Static last_y_key.i = #False
  Static last_n_confirm_key.i = #False
  
  ; Если показан диалог подтверждения выхода
  If exit_confirmation
    If KeyboardPushed(#PB_Key_Y) And Not last_y_key
      game_over = #True
      exit_confirmation = #False
    ElseIf KeyboardPushed(#PB_Key_N) And Not last_n_confirm_key
      exit_confirmation = #False
    EndIf
    last_y_key = KeyboardPushed(#PB_Key_Y)
    last_n_confirm_key = KeyboardPushed(#PB_Key_N)
    ProcedureReturn
  EndIf
  
  ; Выход по Esc с подтверждением
  If KeyboardPushed(#PB_Key_Escape) And Not last_esc_key
    exit_confirmation = #True
  EndIf
  last_esc_key = KeyboardPushed(#PB_Key_Escape)
  
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
    enemy_speed + SPEED_CHANGE
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
  If KeyboardPushed(#PB_Key_Subtract) And Not last_minus_key And enemy_speed > SPEED_CHANGE
    enemy_speed - SPEED_CHANGE
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
    current_enemy_count + 1
  EndIf
  last_n_key = KeyboardPushed(#PB_Key_N)
  
  ; Обработка клавиш движения только если нет паузы и справки
  If Not game_paused And Not show_help And Not exit_confirmation
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
  
  ; Не обновлять игру если пауза или показана справки или диалог выхода
  If game_paused Or show_help Or exit_confirmation
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
  If game_stats\filled >= TARGET_PERCENT
    level_complete = #True
  EndIf
EndProcedure

Procedure StartLevel(level.i, enemy_count.i, speed.f)
  ; Инициализация нового уровня
  InitGrid(grid_width, grid_height)
  
  ; Сброс позиции игрока
  player_x = grid_width / 2
  player_y = grid_height - 1
  player_vx = 0
  player_vy = 0
  player_moving = #False
  
  ; Очистка врагов
  ClearList(enemies())
  
  ; Создание врагов
  Protected i.i
  For i = 1 To enemy_count
    AddRandomEnemy(grid_width, grid_height, speed)
  Next
  
  ; Обновление статистики
  game_stats\level = level
  game_stats\filled = PercentLand(grid_width, grid_height)
  
  level_complete = #False
  game_over = #False
EndProcedure

; --- Основной игровой цикл ---
Procedure MainGameLoop()
  Protected last_time.i = ElapsedMilliseconds()
  Protected frame_time.i, dt.f
  
  ; Загрузка шрифтов
  LoadGameFonts()
  
  ; Показ заставки
  ShowSplashScreen()
  
  ; Инициализация игры
  StartLevel(1, START_ENEMIES, BASE_SPEED)
  game_stats\lives = START_LIVES
  LevelBanner(1)
  
  ; Основной игровой цикл
  Repeat
    frame_time = ElapsedMilliseconds() - last_time
    last_time = ElapsedMilliseconds()
    dt = frame_time / 1000.0
    
    ; Ограничение FPS
    If dt < 1.0 / MAX_FPS
      Delay((1.0 / MAX_FPS - dt) * 1000)
      dt = 1.0 / MAX_FPS
    EndIf
    
    ; Обработка событий окна
    Repeat
      Define event = WindowEvent()
      If event = #PB_Event_CloseWindow
        game_over = #True
        Break 2
      EndIf
    Until event = 0
    
    ExamineKeyboard()
    ProcessInput()
    UpdateGame(dt)
    DrawScreen()
    
    ; Проверка завершения уровня
    If level_complete
      LevelCompleteScreen(game_stats\level)
      enemy_speed + SPEED_GROWTH
      current_enemy_count + 1
      
      ; Переход на следующий уровень с сохранением пользовательских параметров
      StartLevel(game_stats\level + 1, current_enemy_count, enemy_speed)
      LevelBanner(game_stats\level)
    EndIf
    
    ; Проверка окончания игры
    If game_over
      GameOverScreen()
      If restart_game
        ; Перезапуск игры с начальными параметрами
        enemy_speed = BASE_SPEED
        current_enemy_count = START_ENEMIES
        game_stats\lives = START_LIVES
        StartLevel(1, START_ENEMIES, BASE_SPEED)
        LevelBanner(1)
        game_over = #False
      Else
        Break
      EndIf
    EndIf
    
  Until KeyboardPushed(#PB_Key_Escape) And Not exit_confirmation
  
  ; Освобождение ресурсов
  FreeGameFonts()
EndProcedure

; --- Точка входа программы ---
; Загрузка конфигурации перед инициализацией игры
LoadConfigFromINI()

InitSprite()
InitKeyboard()

OpenWindow(0, 0, 0, screen_width, screen_height, "Xonix Game v1.1", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
OpenWindowedScreen(WindowID(0), 0, 0, screen_width, screen_height)

Repeat
  MainGameLoop()
  ; Сохранение конфигурации при выходе из игры
  SaveConfigToINI()
Until Not restart_game

End
; IDE Options = PureBasic 6.21 (Windows - x86)
; CursorPosition = 2
; Folding = ----
; EnableXP
; UseIcon = Xonix_Hi.ico
; Executable = xonix.exe