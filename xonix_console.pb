; Xonix terminal game in PureBasic 6.x
; Console UI inspired by xonix_terminal.py, rules taken from xonix.pb.

EnableExplicit

#DEFAULT_TARGET_PERCENT = 75
#DEFAULT_START_LIVES = 3
#DEFAULT_START_ENEMIES = 2
#DEFAULT_START_HUNTERS = 1
#DEFAULT_MAX_FPS = 30
#DEFAULT_BASE_SPEED = 1.2
#DEFAULT_SPEED_GROWTH = 0.15
#DEFAULT_SPEED_CHANGE = 0.1

#DEFAULT_GRID_WIDTH = 119
#DEFAULT_GRID_HEIGHT = 34
#PLAYER_STEP_MS = 45
#HUNTER_STEP_MS = 120
#STD_INPUT_HANDLE = -10
#STD_OUTPUT_HANDLE = -11

#VK_LEFT = $25
#VK_UP = $26
#VK_RIGHT = $27
#VK_DOWN = $28
#VK_ESCAPE = $1B
#VK_F1 = $70
#VK_ADD = $6B
#VK_SUBTRACT = $6D
#VK_OEM_PLUS = $BB
#VK_OEM_MINUS = $BD

Enumeration
  #SEA
  #LAND
  #TRAIL
EndEnumeration

Structure Enemy
  x.f
  y.f
  vx.f
  vy.f
EndStructure

Structure Hunter
  x.i
  y.i
  vx.i
  vy.i
  move_accumulator.f
EndStructure

Structure GameStats
  level.i
  lives.i
  filled.f
EndStructure

Global TARGET_PERCENT.i = #DEFAULT_TARGET_PERCENT
Global START_LIVES.i = #DEFAULT_START_LIVES
Global START_ENEMIES.i = #DEFAULT_START_ENEMIES
Global MAX_FPS.i = #DEFAULT_MAX_FPS
Global BASE_SPEED.f = #DEFAULT_BASE_SPEED
Global SPEED_GROWTH.f = #DEFAULT_SPEED_GROWTH
Global SPEED_CHANGE.f = #DEFAULT_SPEED_CHANGE

Global Dim grid.i(0, 0)
Global player_x.i, player_y.i
Global player_vx.i, player_vy.i
Global player_moving.i
Global NewList enemies.Enemy()
Global NewList hunters.Hunter()
Global game_stats.GameStats
Global enemy_speed.f
Global current_enemy_count.i
Global current_hunter_count.i
Global level_complete.i
Global game_over.i
Global game_paused.i
Global show_help.i
Global exit_confirmation.i
Global restart_game.i
Global quit_game.i
Global player_step_allowed.i
Global console_window.i
Global console_input.i
Global grid_width.i = #DEFAULT_GRID_WIDTH
Global grid_height.i = #DEFAULT_GRID_HEIGHT
Global hud_row.i = #DEFAULT_GRID_HEIGHT
Global force_full_redraw.i = #True
Global Dim previous_lines.s(0)

Global land_ch.s = Chr($2588)
Global sea_ch.s = " "
Global trail_ch.s = Chr($2591)
Global enemy_ch.s = Chr($25CF)
; Keep the hunter glyph in ASCII: some Windows console fonts render ◆ as a
; broken double-width character.
Global hunter_ch.s = "X"
Global player_ch.s = Chr($2593)
Global shadow_ch.s = Chr($2592)
Global box_tl.s = Chr($250C)
Global box_tr.s = Chr($2510)
Global box_bl.s = Chr($2514)
Global box_br.s = Chr($2518)
Global box_h.s = Chr($2500)
Global box_v.s = Chr($2502)
Global box_lt.s = Chr($251C)
Global box_rt.s = Chr($2524)

Structure XonixCoord
  X.w
  Y.w
EndStructure

Structure XonixSmallRect
  Left.w
  Top.w
  Right.w
  Bottom.w
EndStructure

Structure XonixConsoleScreenBufferInfo
  dwSize.XonixCoord
  dwCursorPosition.XonixCoord
  wAttributes.w
  srWindow.XonixSmallRect
  dwMaximumWindowSize.XonixCoord
EndStructure

Procedure LoadConfigFromINI()
  If OpenPreferences("xonix.ini")
    TARGET_PERCENT = ReadPreferenceInteger("TargetPercent", #DEFAULT_TARGET_PERCENT)
    START_LIVES = ReadPreferenceInteger("StartLives", #DEFAULT_START_LIVES)
    START_ENEMIES = ReadPreferenceInteger("StartEnemies", #DEFAULT_START_ENEMIES)
    MAX_FPS = ReadPreferenceInteger("MaxFPS", #DEFAULT_MAX_FPS)
    BASE_SPEED = ReadPreferenceFloat("BaseSpeed", #DEFAULT_BASE_SPEED)
    SPEED_GROWTH = ReadPreferenceFloat("SpeedGrowth", #DEFAULT_SPEED_GROWTH)
    SPEED_CHANGE = ReadPreferenceFloat("SpeedChange", #DEFAULT_SPEED_CHANGE)
    ClosePreferences()
  EndIf
EndProcedure

Procedure SaveConfigToINI()
  If CreatePreferences("xonix.ini")
    WritePreferenceInteger("TargetPercent", TARGET_PERCENT)
    WritePreferenceInteger("StartLives", START_LIVES)
    WritePreferenceInteger("StartEnemies", START_ENEMIES)
    WritePreferenceInteger("MaxFPS", MAX_FPS)
    WritePreferenceFloat("BaseSpeed", BASE_SPEED)
    WritePreferenceFloat("SpeedGrowth", SPEED_GROWTH)
    WritePreferenceFloat("SpeedChange", SPEED_CHANGE)
    ClosePreferences()
  EndIf
EndProcedure

Procedure.i Clamp(n.i, lo.i, hi.i)
  If n < lo
    ProcedureReturn lo
  ElseIf n > hi
    ProcedureReturn hi
  EndIf
  ProcedureReturn n
EndProcedure

Procedure.f RandomFloat(min.f, max.f)
  ProcedureReturn min + (max - min) * Random(1000) / 1000.0
EndProcedure

Procedure DetectConsoleSize()
  Protected output_handle.i
  Protected info.XonixConsoleScreenBufferInfo
  Protected console_width.i
  Protected console_height.i
  
  output_handle = GetStdHandle_(#STD_OUTPUT_HANDLE)
  If GetConsoleScreenBufferInfo_(output_handle, @info)
    console_width = info\srWindow\Right - info\srWindow\Left + 1
    console_height = info\srWindow\Bottom - info\srWindow\Top + 1
    
    grid_width = console_width - 1
    If grid_width < 40
      grid_width = 40
    EndIf
    
    grid_height = console_height - 2
    If grid_height > 80
      grid_height = 80
    EndIf
    If grid_height < 20
      grid_height = 20
    EndIf
  Else
    grid_width = #DEFAULT_GRID_WIDTH
    grid_height = #DEFAULT_GRID_HEIGHT
  EndIf
  
  hud_row = grid_height
  Dim previous_lines.s(hud_row)
  force_full_redraw = #True
EndProcedure

Procedure.i ConsoleFocused()
  ProcedureReturn Bool(GetForegroundWindow_() = console_window)
EndProcedure

Procedure FlushInput()
  If console_input
    FlushConsoleInputBuffer_(console_input)
  EndIf
EndProcedure

Procedure.i KeyDown(vk.i)
  If Not ConsoleFocused()
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(GetAsyncKeyState_(vk) & $8000)
EndProcedure

Procedure.i KeyPressedOnce(vk.i)
  Static Dim previous.i(255)
  Protected down.i
  Protected pressed.i
  Protected i.i
  
  If Not ConsoleFocused()
    For i = 0 To 255
      previous(i) = #False
    Next
    ProcedureReturn #False
  EndIf
  
  down = KeyDown(vk)
  pressed = Bool(down And Not previous(vk))
  previous(vk) = down
  ProcedureReturn pressed
EndProcedure

Procedure.i IsPassable(x.i, y.i)
  If x < 0 Or x >= grid_width Or y < 0 Or y >= grid_height
    ProcedureReturn #False
  EndIf
  ProcedureReturn Bool(grid(y, x) <> #LAND)
EndProcedure

Procedure InitGrid()
  Protected x.i, y.i
  Dim grid(grid_height - 1, grid_width - 1)
  
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      grid(y, x) = #SEA
    Next
  Next
  
  For x = 0 To grid_width - 1
    grid(0, x) = #LAND
    grid(grid_height - 1, x) = #LAND
  Next
  
  For y = 0 To grid_height - 1
    grid(y, 0) = #LAND
    grid(y, grid_width - 1) = #LAND
  Next
EndProcedure

Procedure.f PercentLand()
  Protected x.i, y.i, land_count.i
  
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #LAND
        land_count + 1
      EndIf
    Next
  Next
  
  ProcedureReturn 100.0 * land_count / (grid_width * grid_height)
EndProcedure

Procedure FloodFromEnemies(Array visited.a(2))
  Protected x.i, y.i, nx.i, ny.i, dx.i, dy.i
  Protected NewList queue.i()
  
  Dim visited(grid_height - 1, grid_width - 1)
  
  ForEach enemies()
    Protected sx.i = Clamp(Round(enemies()\x, #PB_Round_Nearest), 0, grid_width - 1)
    Protected sy.i = Clamp(Round(enemies()\y, #PB_Round_Nearest), 0, grid_height - 1)
    
    If grid(sy, sx) = #LAND
      For dx = -1 To 1 Step 2
        nx = sx + dx
        If nx >= 0 And nx < grid_width And grid(sy, nx) <> #LAND And Not visited(sy, nx)
          visited(sy, nx) = #True
          AddElement(queue())
          queue() = nx << 16 | sy
        EndIf
      Next
      
      For dy = -1 To 1 Step 2
        ny = sy + dy
        If ny >= 0 And ny < grid_height And grid(ny, sx) <> #LAND And Not visited(ny, sx)
          visited(ny, sx) = #True
          AddElement(queue())
          queue() = sx << 16 | ny
        EndIf
      Next
    Else
      visited(sy, sx) = #True
      AddElement(queue())
      queue() = sx << 16 | sy
    EndIf
  Next
  
  While FirstElement(queue())
    Protected current.i = queue()
    x = current >> 16
    y = current & $FFFF
    DeleteElement(queue())
    
    For dx = -1 To 1 Step 2
      nx = x + dx
      If nx >= 0 And nx < grid_width And Not visited(y, nx) And grid(y, nx) <> #LAND
        visited(y, nx) = #True
        AddElement(queue())
        queue() = nx << 16 | y
      EndIf
    Next
    
    For dy = -1 To 1 Step 2
      ny = y + dy
      If ny >= 0 And ny < grid_height And Not visited(ny, x) And grid(ny, x) <> #LAND
        visited(ny, x) = #True
        AddElement(queue())
        queue() = x << 16 | ny
      EndIf
    Next
  Wend
EndProcedure

Procedure CommitTrail()
  Protected x.i, y.i, captured.i
  Dim visited.a(0, 0)
  
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #TRAIL
        grid(y, x) = #LAND
      EndIf
    Next
  Next
  
  FloodFromEnemies(visited())
  
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) <> #LAND And Not visited(y, x)
        grid(y, x) = #LAND
        captured + 1
      EndIf
    Next
  Next
  
  ProcedureReturn captured
EndProcedure

Procedure ClearTrail()
  Protected x.i, y.i
  For y = 0 To grid_height - 1
    For x = 0 To grid_width - 1
      If grid(y, x) = #TRAIL
        grid(y, x) = #SEA
      EndIf
    Next
  Next
EndProcedure

Procedure ResetPlayer()
  player_x = grid_width / 2
  player_y = grid_height - 1
  player_vx = 0
  player_vy = 0
  player_moving = #False
EndProcedure

Procedure AddRandomHunter()
  Protected x.i, tries.i, occupied.i

  Repeat
    x = Random(grid_width - 2, 1)
    occupied = #False
    ForEach hunters()
      If hunters()\x = x And hunters()\y = 0
        occupied = #True
        Break
      EndIf
    Next
    tries + 1
  Until Not occupied Or tries >= 100

  AddElement(hunters())
  hunters()\x = x
  hunters()\y = 0
  hunters()\vx = 1 - 2 * Random(1)
  hunters()\vy = 1 - 2 * Random(1)
  hunters()\move_accumulator = 0
EndProcedure

Procedure ResetHunters()
  Protected index.i, count.i = ListSize(hunters())

  ForEach hunters()
    index + 1
    hunters()\x = index * (grid_width - 1) / (count + 1)
    hunters()\y = 0
    hunters()\vx = 1 - 2 * Random(1)
    hunters()\vy = 1 - 2 * Random(1)
    hunters()\move_accumulator = 0
  Next
EndProcedure

Procedure LoseLife()
  game_stats\lives - 1
  ClearTrail()
  ResetPlayer()
  ResetHunters()
  Delay(600)
  If game_stats\lives <= 0
    game_over = #True
  EndIf
EndProcedure

Procedure AddRandomEnemy(speed.f)
  Protected tries.i, ex.i, ey.i
  
  Repeat
    ex = Random(grid_width - 3, 2)
    ey = Random(grid_height - 3, 2)
    tries + 1
  Until grid(ey, ex) <> #LAND Or tries > 100
  
  AddElement(enemies())
  enemies()\x = ex
  enemies()\y = ey
  enemies()\vx = speed * (1 - 2 * Random(1)) * RandomFloat(0.6, 1.0)
  enemies()\vy = speed * (1 - 2 * Random(1)) * RandomFloat(0.6, 1.0)
EndProcedure

Procedure SetEnemySpeed(speed.f)
  Protected magnitude.f
  enemy_speed = speed
  
  ForEach enemies()
    magnitude = Sqr(enemies()\vx * enemies()\vx + enemies()\vy * enemies()\vy)
    If magnitude > 0
      enemies()\vx = enemies()\vx / magnitude * enemy_speed
      enemies()\vy = enemies()\vy / magnitude * enemy_speed
    EndIf
  Next
EndProcedure

Procedure StartLevel(level.i, enemy_count.i, hunter_count.i, speed.f)
  Protected i.i
  
  InitGrid()
  ResetPlayer()
  ClearList(enemies())
  ClearList(hunters())
  
  For i = 1 To enemy_count
    AddRandomEnemy(speed)
  Next

  For i = 1 To hunter_count
    AddRandomHunter()
  Next
  ResetHunters()
  
  game_stats\level = level
  game_stats\filled = PercentLand()
  level_complete = #False
  game_over = #False
  game_paused = #False
  show_help = #False
  exit_confirmation = #False
EndProcedure

Procedure CenterText(line1.s, line2.s = "", pause_ms.i = 1200)
  ClearConsole()
  force_full_redraw = #True
  ConsoleColor(10, 0)
  ConsoleLocate((grid_width - Len(line1)) / 2, grid_height / 2 - 1)
  Print(LSet(line1, grid_width - (grid_width - Len(line1)) / 2, " "))
  If line2 <> ""
    ConsoleLocate((grid_width - Len(line2)) / 2, grid_height / 2 + 1)
    Print(LSet(line2, grid_width - (grid_width - Len(line2)) / 2, " "))
  EndIf
  Delay(pause_ms)
  ClearConsole()
  force_full_redraw = #True
EndProcedure

Procedure.s LetterPattern(letter.s, row.i)
  Select letter
    Case "X"
      Select row
        Case 0 : ProcedureReturn "10001"
        Case 1 : ProcedureReturn "01010"
        Case 2 : ProcedureReturn "00100"
        Case 3 : ProcedureReturn "01010"
        Case 4 : ProcedureReturn "10001"
      EndSelect
    Case "O"
      Select row
        Case 0 : ProcedureReturn "01110"
        Case 1 : ProcedureReturn "10001"
        Case 2 : ProcedureReturn "10001"
        Case 3 : ProcedureReturn "10001"
        Case 4 : ProcedureReturn "01110"
      EndSelect
    Case "N"
      Select row
        Case 0 : ProcedureReturn "10001"
        Case 1 : ProcedureReturn "11001"
        Case 2 : ProcedureReturn "10101"
        Case 3 : ProcedureReturn "10011"
        Case 4 : ProcedureReturn "10001"
      EndSelect
    Case "I"
      Select row
        Case 0 : ProcedureReturn "11111"
        Case 1 : ProcedureReturn "00100"
        Case 2 : ProcedureReturn "00100"
        Case 3 : ProcedureReturn "00100"
        Case 4 : ProcedureReturn "11111"
      EndSelect
  EndSelect
  
  ProcedureReturn "00000"
EndProcedure

Procedure.s BuildTitleRow(row.i, scale_x.i)
  Protected title.s = "XONIX"
  Protected result.s
  Protected pattern.s
  Protected i.i, col.i, sx.i
  
  For i = 1 To Len(title)
    pattern = LetterPattern(Mid(title, i, 1), row)
    For col = 1 To Len(pattern)
      For sx = 1 To scale_x
        If Mid(pattern, col, 1) = "1"
          result + land_ch
        Else
          result + " "
        EndIf
      Next
    Next
    
    If i < Len(title)
      result + Space(scale_x * 2)
    EndIf
  Next
  
  ProcedureReturn result
EndProcedure

Procedure ShowSplashScreen()
  Protected scale_x.i = grid_width / 34
  Protected scale_y.i = grid_height / 12
  Protected row.i, sy.i
  Protected line.s
  Protected y.i
  Protected copyright.s = "(C) CheshirCa 2026"
  
  If scale_x < 1 : scale_x = 1 : EndIf
  If scale_y < 1 : scale_y = 1 : EndIf
  If scale_x > 5 : scale_x = 5 : EndIf
  If scale_y > 4 : scale_y = 4 : EndIf
  
  ClearConsole()
  ConsoleColor(10, 0)
  
  y = (grid_height - 5 * scale_y) / 2 - 1
  If y < 1 : y = 1 : EndIf
  
  For row = 0 To 4
    line = BuildTitleRow(row, scale_x)
    For sy = 1 To scale_y
      ConsoleLocate((grid_width - Len(line)) / 2, y)
      Print(line)
      y + 1
    Next
  Next
  
  ConsoleLocate((grid_width - Len(copyright)) / 2, hud_row)
  Print(copyright)
  Delay(1800)
  ClearConsole()
  force_full_redraw = #True
EndProcedure

Procedure.s PutText(line.s, x.i, text.s)
  Protected visible.s
  
  If x < 0
    text = Mid(text, -x + 1)
    x = 0
  EndIf
  
  If x >= grid_width Or Len(text) = 0
    ProcedureReturn line
  EndIf
  
  visible = Left(text, grid_width - x)
  ProcedureReturn Left(line, x) + visible + Mid(line, x + Len(visible) + 1)
EndProcedure

Procedure.s RepeatText(text.s, count.i)
  Protected result.s
  Protected i.i
  
  For i = 1 To count
    result + text
  Next
  
  ProcedureReturn result
EndProcedure

Procedure DrawShadowBox(Array lines.s(1), x.i, y.i, w.i, h.i, title.s = "")
  Protected i.i
  Protected top.s, middle.s, bottom.s
  
  If w < 4 Or h < 3
    ProcedureReturn
  EndIf
  
  For i = 1 To h
    If y + i >= 0 And y + i <= hud_row
      lines(y + i) = PutText(lines(y + i), x + 2, RepeatText(shadow_ch, w))
    EndIf
  Next
  If y + h >= 0 And y + h <= hud_row
    lines(y + h) = PutText(lines(y + h), x + 2, RepeatText(shadow_ch, w))
  EndIf
  
  top = box_tl + RepeatText(box_h, w - 2) + box_tr
  If title <> "" And Len(title) < w - 4
    top = box_tl + box_h + " " + title + " " + RepeatText(box_h, w - Len(title) - 4) + box_tr
  EndIf
  middle = box_v + Space(w - 2) + box_v
  bottom = box_bl + RepeatText(box_h, w - 2) + box_br
  
  lines(y) = PutText(lines(y), x, top)
  For i = 1 To h - 2
    lines(y + i) = PutText(lines(y + i), x, middle)
  Next
  lines(y + h - 1) = PutText(lines(y + h - 1), x, bottom)
EndProcedure

Procedure DrawScreen()
  Protected x.i, y.i, ex.i, ey.i, enemy_here.i, hunter_here.i
  Protected line.s, ch.s, hud.s
  Dim lines.s(hud_row)
  
  For y = 0 To grid_height - 1
    line = ""
    For x = 0 To grid_width - 1
      If x = player_x And y = player_y
        ch = player_ch
      Else
        hunter_here = #False
        ForEach hunters()
          If hunters()\x = x And hunters()\y = y
            hunter_here = #True
            Break
          EndIf
        Next

        enemy_here = #False
        ForEach enemies()
          ex = Round(enemies()\x, #PB_Round_Nearest)
          ey = Round(enemies()\y, #PB_Round_Nearest)
          If ex = x And ey = y
            enemy_here = #True
            Break
          EndIf
        Next
        
        If hunter_here
          ch = hunter_ch
        ElseIf enemy_here
          ch = enemy_ch
        ElseIf grid(y, x) = #LAND
          ch = land_ch
        ElseIf grid(y, x) = #TRAIL
          ch = trail_ch
        Else
          ch = sea_ch
        EndIf
      EndIf
      line + ch
    Next
    lines(y) = line
  Next
  
  hud = " Lvl " + Str(game_stats\level) +
        "  Lives " + Str(game_stats\lives) +
        "  Fill " + StrF(game_stats\filled, 1) + "%" +
        "  Goal " + Str(TARGET_PERCENT) + "%" +
        "  En " + Str(ListSize(enemies())) +
        "  Hun " + Str(ListSize(hunters())) +
        "  Spd " + StrF(enemy_speed, 1) +
        "  Esc/Q Quit  P Pause  F1 Help  +/- Speed  N Enemy  H Hunter "
  lines(hud_row) = box_lt + Left(LSet(hud, grid_width - 2, " "), grid_width - 2) + box_rt
  
  If game_paused And Not show_help And Not exit_confirmation
    DrawShadowBox(lines(), (grid_width - 30) / 2, grid_height / 2 - 3, 30, 6, " Paused ")
    lines(grid_height / 2 - 1) = PutText(lines(grid_height / 2 - 1), (grid_width - 18) / 2, "Press P to continue")
  EndIf
  
  If show_help
    DrawShadowBox(lines(), 28, 9, 62, 13, " XONIX TERMINAL ")
    lines(11) = PutText(lines(11), 32, "W/A/S/D or arrows  - move player")
    lines(12) = PutText(lines(12), 32, "P                  - pause/resume")
    lines(13) = PutText(lines(13), 32, "F1                 - show or hide help")
    lines(14) = PutText(lines(14), 32, "Esc or Q           - quit with confirmation")
    lines(15) = PutText(lines(15), 32, "+/-                - change enemy speed")
    lines(16) = PutText(lines(16), 32, "N                  - add new enemy")
    lines(17) = PutText(lines(17), 32, "H                  - add new hunter " + hunter_ch)
    lines(18) = PutText(lines(18), 32, hunter_ch + "                  - bounces on filled land")
    lines(19) = PutText(lines(19), 32, "Press F1 or P to close")
  EndIf
  
  If exit_confirmation
    DrawShadowBox(lines(), (grid_width - 50) / 2, grid_height / 2 - 4, 50, 8, "")
    lines(grid_height / 2 - 2) = PutText(lines(grid_height / 2 - 2), (grid_width - 38) / 2, "Are you sure you want to quit?")
    lines(grid_height / 2 + 1) = PutText(lines(grid_height / 2 + 1), (grid_width - 15) / 2, "Y - yes, N - no")
  EndIf
  
  ConsoleColor(10, 0)
  For y = 0 To hud_row
    lines(y) = LSet(Left(lines(y), grid_width), grid_width, " ")
    If force_full_redraw Or lines(y) <> previous_lines(y)
      ConsoleLocate(0, y)
      Print(lines(y))
      previous_lines(y) = lines(y)
    EndIf
  Next
  force_full_redraw = #False
EndProcedure

Procedure ProcessInput()
  If exit_confirmation
    If KeyPressedOnce(Asc("Y"))
      FlushInput()
      quit_game = #True
      game_over = #True
    ElseIf KeyPressedOnce(Asc("N")) Or KeyPressedOnce(#VK_ESCAPE)
      FlushInput()
      exit_confirmation = #False
    EndIf
    ProcedureReturn
  EndIf
  
  If KeyPressedOnce(#VK_ESCAPE) Or KeyPressedOnce(Asc("Q"))
    exit_confirmation = #True
    ProcedureReturn
  EndIf
  
  If KeyPressedOnce(Asc("P"))
    game_paused = Bool(Not game_paused)
    show_help = #False
  EndIf
  
  If KeyPressedOnce(#VK_F1)
    show_help = Bool(Not show_help)
    game_paused = show_help
  EndIf
  
  If KeyPressedOnce(#VK_ADD) Or KeyPressedOnce(#VK_OEM_PLUS)
    SetEnemySpeed(enemy_speed + SPEED_CHANGE)
  EndIf
  
  If (KeyPressedOnce(#VK_SUBTRACT) Or KeyPressedOnce(#VK_OEM_MINUS)) And enemy_speed > SPEED_CHANGE
    SetEnemySpeed(enemy_speed - SPEED_CHANGE)
  EndIf
  
  If KeyPressedOnce(Asc("N"))
    AddRandomEnemy(enemy_speed)
    current_enemy_count + 1
  EndIf

  If KeyPressedOnce(Asc("H"))
    AddRandomHunter()
    current_hunter_count + 1
  EndIf
  
  If Not game_paused And Not show_help
    If KeyDown(#VK_UP) Or KeyDown(Asc("W"))
      player_vx = 0
      player_vy = -1
      player_moving = #True
    ElseIf KeyDown(#VK_DOWN) Or KeyDown(Asc("S"))
      player_vx = 0
      player_vy = 1
      player_moving = #True
    ElseIf KeyDown(#VK_RIGHT) Or KeyDown(Asc("D"))
      player_vx = 1
      player_vy = 0
      player_moving = #True
    ElseIf KeyDown(#VK_LEFT) Or KeyDown(Asc("A"))
      player_vx = -1
      player_vy = 0
      player_moving = #True
    EndIf
  EndIf
EndProcedure

Procedure UpdateEnemies(dt.f)
  Protected nx.i, ny.i
  
  ForEach enemies()
    nx = Round(enemies()\x + enemies()\vx * dt, #PB_Round_Nearest)
    If Not IsPassable(nx, Round(enemies()\y, #PB_Round_Nearest))
      enemies()\vx = -enemies()\vx
    EndIf
    
    ny = Round(enemies()\y + enemies()\vy * dt, #PB_Round_Nearest)
    If Not IsPassable(Round(enemies()\x, #PB_Round_Nearest), ny)
      enemies()\vy = -enemies()\vy
    EndIf
    
    enemies()\x + enemies()\vx * dt
    enemies()\y + enemies()\vy * dt
    
    If enemies()\x < 1
      enemies()\x = 1
      enemies()\vx = Abs(enemies()\vx)
    ElseIf enemies()\x > grid_width - 2
      enemies()\x = grid_width - 2
      enemies()\vx = -Abs(enemies()\vx)
    EndIf
    
    If enemies()\y < 1
      enemies()\y = 1
      enemies()\vy = Abs(enemies()\vy)
    ElseIf enemies()\y > grid_height - 2
      enemies()\y = grid_height - 2
      enemies()\vy = -Abs(enemies()\vy)
    EndIf
  Next
EndProcedure

Procedure.i UpdateHunters(dt.f)
  Protected nx.i, ny.i

  ForEach hunters()
    hunters()\move_accumulator + dt * 1000.0
    While hunters()\move_accumulator >= #HUNTER_STEP_MS
      hunters()\move_accumulator - #HUNTER_STEP_MS

      ; Reflect independently from vertical and horizontal land boundaries.
      ; Checking Y after the possible X move also keeps the hunter out of
      ; concave sea corners.
      nx = hunters()\x + hunters()\vx
      If nx < 0 Or nx >= grid_width Or grid(hunters()\y, nx) <> #LAND
        hunters()\vx = -hunters()\vx
        nx = hunters()\x + hunters()\vx
      EndIf
      If nx >= 0 And nx < grid_width And grid(hunters()\y, nx) = #LAND
        hunters()\x = nx
      EndIf

      ny = hunters()\y + hunters()\vy
      If ny < 0 Or ny >= grid_height Or grid(ny, hunters()\x) <> #LAND
        hunters()\vy = -hunters()\vy
        ny = hunters()\y + hunters()\vy
      EndIf
      If ny >= 0 And ny < grid_height And grid(ny, hunters()\x) = #LAND
        hunters()\y = ny
      EndIf

      If hunters()\x = player_x And hunters()\y = player_y
        ProcedureReturn #True
      EndIf
    Wend
  Next

  ProcedureReturn #False
EndProcedure

Procedure UpdatePlayer()
  Protected nx.i, ny.i
  
  If Not player_moving
    ProcedureReturn
  EndIf
  
  nx = Clamp(player_x + player_vx, 0, grid_width - 1)
  ny = Clamp(player_y + player_vy, 0, grid_height - 1)
  
  If grid(ny, nx) = #TRAIL
    LoseLife()
    ProcedureReturn
  EndIf
  
  If grid(ny, nx) = #SEA
    grid(ny, nx) = #TRAIL
  ElseIf grid(ny, nx) = #LAND And grid(player_y, player_x) = #TRAIL
    CommitTrail()
    player_moving = #False
  EndIf
  
  player_x = nx
  player_y = ny
EndProcedure

Procedure UpdateGame(dt.f)
  Protected ex.i, ey.i
  
  If game_paused Or show_help Or exit_confirmation
    ProcedureReturn
  EndIf
  
  UpdateEnemies(dt)
  
  ForEach enemies()
    ex = Clamp(Round(enemies()\x, #PB_Round_Nearest), 0, grid_width - 1)
    ey = Clamp(Round(enemies()\y, #PB_Round_Nearest), 0, grid_height - 1)
    If grid(ey, ex) = #TRAIL
      LoseLife()
      ProcedureReturn
    EndIf
  Next

  If UpdateHunters(dt)
    LoseLife()
    ProcedureReturn
  EndIf
  
  If player_step_allowed
    UpdatePlayer()
  EndIf
  If game_over
    ProcedureReturn
  EndIf

  ForEach hunters()
    If hunters()\x = player_x And hunters()\y = player_y
      LoseLife()
      ProcedureReturn
    EndIf
  Next
  
  ForEach enemies()
    ex = Round(enemies()\x, #PB_Round_Nearest)
    ey = Round(enemies()\y, #PB_Round_Nearest)
    If ex = player_x And ey = player_y
      LoseLife()
      ProcedureReturn
    EndIf
  Next
  
  game_stats\filled = PercentLand()
  If game_stats\filled >= TARGET_PERCENT
    level_complete = #True
  EndIf
EndProcedure

Procedure GameOverScreen()
  ClearConsole()
  force_full_redraw = #True
  ConsoleColor(10, 0)
  ConsoleLocate((grid_width - 9) / 2, grid_height / 2 - 2)
  Print("GAME OVER")
  ConsoleLocate((grid_width - 37) / 2, grid_height / 2)
  Print("Press R to play again or Esc to quit")
  FlushInput()
  
  Repeat
    Delay(50)
    If KeyPressedOnce(Asc("R"))
      restart_game = #True
      ProcedureReturn
    ElseIf KeyPressedOnce(#VK_ESCAPE)
      restart_game = #False
      quit_game = #True
      ProcedureReturn
    EndIf
  ForEver
EndProcedure

Procedure MainGameLoop()
  Protected last_time.i, now.i, frame_time.i, frame_delay.i
  Protected dt.f
  Protected last_player_step.i
  
  restart_game = #False
  quit_game = #False
  enemy_speed = BASE_SPEED
  current_enemy_count = START_ENEMIES
  current_hunter_count = #DEFAULT_START_HUNTERS
  game_stats\lives = START_LIVES
  
  StartLevel(1, current_enemy_count, current_hunter_count, enemy_speed)
  CenterText("LEVEL 1", "get ready...", 1000)
  
  last_time = ElapsedMilliseconds()
  last_player_step = last_time
  
  Repeat
    now = ElapsedMilliseconds()
    frame_time = now - last_time
    last_time = now
    dt = frame_time / 1000.0
    
    ProcessInput()
    
    If Not game_paused And Not show_help And Not exit_confirmation
      If ElapsedMilliseconds() - last_player_step >= #PLAYER_STEP_MS
        player_step_allowed = #True
        UpdateGame(dt)
        last_player_step = ElapsedMilliseconds()
      Else
        player_step_allowed = #False
        UpdateGame(dt)
      EndIf
    EndIf
    
    DrawScreen()
    
    If level_complete
      CenterText("LEVEL " + Str(game_stats\level) + " COMPLETE!", "Moving to next level...", 1500)
      enemy_speed + SPEED_GROWTH
      current_enemy_count + 1
      current_hunter_count + 1
      StartLevel(game_stats\level + 1, current_enemy_count, current_hunter_count, enemy_speed)
      CenterText("LEVEL " + Str(game_stats\level), "get ready...", 1000)
      last_time = ElapsedMilliseconds()
      last_player_step = last_time
    EndIf
    
    If game_over
      If quit_game
        Break
      EndIf
      GameOverScreen()
      If restart_game
        enemy_speed = BASE_SPEED
        current_enemy_count = START_ENEMIES
        current_hunter_count = #DEFAULT_START_HUNTERS
        game_stats\lives = START_LIVES
        StartLevel(1, current_enemy_count, current_hunter_count, enemy_speed)
        CenterText("LEVEL 1", "get ready...", 1000)
        last_time = ElapsedMilliseconds()
        last_player_step = last_time
      Else
        Break
      EndIf
    EndIf
    
    frame_delay = 1000 / MAX_FPS - (ElapsedMilliseconds() - now)
    If frame_delay > 0
      Delay(frame_delay)
    EndIf
  Until quit_game
EndProcedure

LoadConfigFromINI()
EnableGraphicalConsole(#True)
RunProgram("chcp", "65001", "", #PB_Program_Hide | #PB_Program_Wait)
OpenConsole()
ConsoleTitle("Xonix Terminal")
console_window = GetForegroundWindow_()
console_input = GetStdHandle_(#STD_INPUT_HANDLE)
DetectConsoleSize()
ConsoleCursor(#False)
ClearConsole()
RandomSeed(ElapsedMilliseconds())

ShowSplashScreen()
MainGameLoop()

SaveConfigToINI()
FlushInput()
ConsoleColor(7, 0)
ConsoleCursor(#True)
ClearConsole()
CloseConsole()
End
