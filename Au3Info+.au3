#Region ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Icon=info.ico
#AutoIt3Wrapper_Compression=4
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Res_Comment=Au3Info+ - 視窗資訊工具
#AutoIt3Wrapper_Res_Description=Au3Info+ - 視窗資訊工具
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_ProductName=Au3Info+ - 視窗資訊工具
#AutoIt3Wrapper_Res_ProductVersion=2026.10.13
#AutoIt3Wrapper_Res_CompanyName=格雷資訊
#AutoIt3Wrapper_Res_LegalCopyright=grayfree.tw 2026 Unlicense.
#AutoIt3Wrapper_Res_LegalTradeMarks=grayfree.tw
#AutoIt3Wrapper_Res_Language=1028
#AutoIt3Wrapper_Res_requestedExecutionLevel=highestAvailable
#AutoIt3Wrapper_Res_CLASS=gWinUI
#AutoIt3Wrapper_Res_HiDpi=y
#EndRegion ;**** 由 AutoIt3Wrapper_GUI 建立的指令 ****

; ============================================================================
; Au3Info+ － 視窗資訊工具（AutoIt Window Info 的 AUI 重製版）
;
; 作者　：格雷資訊 grayfree.tw
; 授權　：Unlicense（公眾領域）
; 介面　：AUI（AutoIt 使用者介面程式庫）
; 限制　：只能以 32 位元 AutoIt 執行（啟動時檢查）
;
; 操作：
;   拖曳左上角的準星到目標視窗後放開 → 選取目標
;   「開始偵測」或 Ctrl+Alt+F          → 跟隨滑鼠即時偵測
;   Ctrl+Alt+T                          → 切換視窗置頂
;   點標籤或數值                        → 複製該欄位
;
; 選用檔案（與程式同資料夾）：
;   info.ico     視窗圖示
;   finder.cur   拖曳時的游標；不存在時使用系統十字游標
; ============================================================================

#NoTrayIcon     ; 不顯示系統匣圖示
#RequireAdmin   ; 請求管理員權限（才能讀取以管理員身分執行的視窗與程序路徑）

#include "AUI.au3"

#Region ;===== 常數與全域變數 =====

; ---- 外觀 ----
Global Const $UI_FONT = "Microsoft JhengHei", $COMBO_FONT_SIZE = 14
Global $UI_FONT_SIZE = 18 ; 可由「字級」選單變更
Global Const $WIN_FLAGS = BitOR($AUI_WIN_ACRYLIC, $AUI_WIN_NO_MINMAX, $AUI_WIN_FIXED)
Global Const $PRODUCT_NAME = "Au3Info+ - 視窗資訊工具", $PRODUCT_AUTHOR = "grayfree 2026 Unlicense."
Global Const $BLUE = 0xFF0078D7 ; 主題取不到強調色時的預設色

; ---- 上限 ----
Global Const $THICK = 4 ; 藍色外框粗細（像素）
Global Const $MAX_CHILDREN = 20000 ; 子控制項列舉上限
Global Const $CHILD_PAGE_SIZE = 8 ; 子控制項下拉選單每頁筆數

; ---- 資訊欄位（27 欄，索引對應 Put() 的第一個參數） ----
Global $names[27] = ["視窗類別", "控制項類別", "ClassNN", "視窗 HWND", "控制項 HWND", "父視窗 HWND", _
    "視窗 Style", "控制項 Style", "控制項 ID", "視窗 ExStyle", "控制項 ExStyle", "程序 ID", _
    "視窗位置", "控制項螢幕座標", "控制項用戶端座標", "視窗大小", "控制項大小", "用戶端大小", _
    "滑鼠目前座標", "滑鼠螢幕座標", "像素色彩", "標題列估算高度", "邊框寬／高", "子控制項數量", _
    "父視窗類別", "控制項狀態", "目標 DPI"]
Global $values[27], $fields[27], $labels[27]
Global $map[40][2], $mapCount = 0 ; 可點擊標籤 → 對應的數值控制項
Global $textCache = ObjCreate("Scripting.Dictionary") ; 控制項 ID → 目前文字（避免重複重繪）

; ---- 主視窗控制項 ----
Global $main = 0, $panel = 0, $grid = 0, $finder = 0, $state = 0, $footer = 0, $note = 0, $bAbout = 0
Global $bFreeze = 0, $bCopy = 0, $bFrame = 0, $bTree = 0, $bTop = 0, $bCompact = 0, $bRefresh = 0
Global $themeCombo = 0, $fontCombo = 0, $comboChild = 0, $comboMode = 0, $childLabel = 0
Global $titleEdit = 0, $titleLabel = 0, $textEdit = 0, $textLabel = 0, $pathEdit = 0, $pathLabel = 0
Global $childPrev = 0, $childNext = 0, $childPageInput = 0, $childGo = 0
Global $sampleLabel = 0, $sampleSwatch = 0, $sampleHexText = 0, $sampleHex8Text = 0, $sampleRGBText = 0
Global $alphaLabel = 0, $alphaInput = 0, $alphaParse = 0, $alphaSample = 0, $alphaText = 0

; ---- 父子階層視窗 ----
Global $treeWin = 0, $treeViewport = 0, $treeContent = 0, $tree = 0, $treeClose = 0
Global $treeVisible = False, $treeLastVisible = -1, $treeClock = TimerInit()
Global $nodes[1], $rootNode = -1 ; $nodes[i]＝第 i 個子控制項的樹狀節點

; ---- 執行狀態 ----
Global $uiReady = False, $done = False
Global $frozen = True, $wasFrozen = True ; True＝停止偵測（鎖定目前目標）
Global $drag = False, $dragVisualPending = False, $downPrev = False
Global $compact = True, $top = True, $blueEnabled = True
Global $pending = False ; 需要更新完整資訊
Global $action = "", $selectHW = 0 ; 延後到主迴圈執行的動作
Global $mode = 0 ; 座標模式：0 螢幕 1 視窗 2 用戶端
Global $lastMouse[2] = [0, 0]
Global $clock = TimerInit(), $fast = TimerInit(), $slow = TimerInit(), $frameUntil = 0

; ---- 目前目標 ----
Global $target = 0, $root = 0 ; 滑鼠下的控制項與其頂層視窗
Global $report = "", $titleValue = "", $textValue = "", $pathValue = ""
Global $pathRoot = 0, $pathPID = -1 ; 執行檔路徑快取

; ---- 子控制項列舉 ----
Global $children[257][4], $childCount = 0 ; [HWND, 父 HWND, 類別, ClassNN]，從 1 起算
Global $childIndex = ObjCreate("Scripting.Dictionary") ; HWND 字串 → $children 索引
Global $listRoot = 0, $building = False
Global $childPage = 0, $childPageRequest = -1, $childComboLastTarget = 0
Global $childPageMap[9], $childPageMapCount = 0 ; 下拉選單索引 → $children 索引（0＝頂層視窗）

; ---- 色彩取樣 ----
Global $sampleColor = -1, $sampleHex = "", $sampleHex8 = "", $sampleRGB = ""
Global $parsedARGB = "", $alphaDescription = ""

; ---- Win32 資源（回呼、外框視窗、游標） ----
Global $enumCB = 0, $enumPtr = 0
Global $frameHW[4], $frameShown = False, $frameKey = "", $frameClass = "Au3InfoAUIBlueFrame_" & @AutoItPID
Global $frameBrush = 0, $frameCB = 0, $instance = 0
Global $finderScale = 1, $dragCursor = 0, $cursorSubclass = 0, $cursorInstalled = False

#EndRegion

#Region ;===== 程式進入點 =====

If @AutoItX64 Then
    MsgBox(16, "執行架構錯誤", "請使用32位元 AutoIt3.exe。")
    Exit
EndIf

Opt("PixelCoordMode", 1) ; PixelGetColor 使用螢幕座標

If _UI_Init() = 0 Then
    MsgBox(16, "AUI初始化失敗", _UI_GetLastErrorText())
    Exit
EndIf

BuildMainWindow()
BuildTreeWindow()
InitWin32()

$uiReady = True
ApplyTypography()
ApplyValueColors(_UI_ThemeGetMode($main) = $AUI_THEME_DARK)
Layout()
DrawSampleSwatch()
ParseARGB(0)
DrawFinder(False)
DrawAboutIcon()

HotKeySet("^!f", "ToggleFreeze")
HotKeySet("^!t", "ToggleTop")

_UI_WindowShow($main)
WinSetOnTop($main, "", 1)

MainLoop()
Cleanup()
Exit

#EndRegion

#Region ;===== 建立視窗與控制項 =====

; ----------------------------------------------------------------------------
; 建立主視窗與所有控制項；欄位的實際位置由 Layout() 依字級與收合狀態重新排列。
; ----------------------------------------------------------------------------
Func BuildMainWindow()
    $main = _UI_WindowCreateEx($PRODUCT_NAME, -1, -1, 1120, 370, $WIN_FLAGS)
    If $main = 0 Then Exit
    _UI_OnClose($main, "MainClose")
    _UI_OnThemeChange($main, "ThemeChanged")
    _UI_BeginUpdate($main)
    _UI_WindowSetIcon($main, @ScriptDir & '\info.ico')

    ; ---- 第 1 列：準星、功能按鈕、主題與字級 ----
    $finder = _UI_Canvas($main, 0, 14, 52, 48, 44)
    _UI_SetColorEx($main, $finder, 0, 0, $AUI_COLOR_OVERRIDE_BACKGROUND)
    $bFreeze = MakeButton("開始偵測", 72, 58, 96)
    $bCopy = MakeButton("複製全部", 176, 58, 96)
    $bFrame = MakeButton("藍框：開", 280, 58, 96)
    $bTree = MakeButton("父子階層", 384, 58, 96)
    $bTop = MakeButton("置頂：開", 488, 58, 96)
    $bCompact = MakeButton("▼ 展開資訊", 592, 58, 128)
    $themeCombo = _UI_Combo($main, 0, "跟隨系統|淺色|深色", 0, 780, 58, 180, 34)
    $fontCombo = _UI_Combo($main, 0, "字級 14|字級 16|字級 18|字級 20", 2, 968, 58, 128, 34)
    _UI_OnValue($main, $fontCombo, "FontSizeChanged")
    _UI_OnValue($main, $themeCombo, "ThemeModeChanged")
    $state = _UI_Text($main, 0, "待命", 16, 310, 150, 30)
    $bAbout = _UI_Canvas($main, 0, 1040, 304, 48, 40)
    _UI_SetColorEx($main, $bAbout, 0, 0, $AUI_COLOR_OVERRIDE_BACKGROUND)
    _UI_OnClick($main, $bAbout, "ShowAbout")

    ; ---- 第 2、3 列：視窗標題、子控制項選單與座標模式 ----
    $titleEdit = InfoInput(0, 112, 105, 985, 36)
    $titleLabel = CopyLabel("視窗標題", 0, 16, 109, 92, $titleEdit)
    $childLabel = _UI_Heading($main, 0, "子控制項", 6, 16, 151, 92, 28)
    $comboChild = _UI_Combo($main, 0, "請先選取目標", 0, 112, 146, 665, 36)
    $bRefresh = MakeButton("重新列舉", 785, 146, 96)
    $comboMode = _UI_Combo($main, 0, "相對於螢幕|相對於視窗|相對於用戶端區域", 0, 889, 146, 208, 36)
    _UI_OnValue($main, $comboChild, "ComboValue")
    _UI_OnValue($main, $comboMode, "ComboValue")

    ; ---- 資訊面板：27 個欄位（3 欄排列，實際位置由 Layout() 決定） ----
    $panel = _UI_Panel($main, 0, 12, 192, 1096, 456)
    _UI_PanelSetBordered($main, $panel, False)
    $grid = _UI_Canvas($main, $panel, 0, 0, 1076, 350)
    _UI_SetColorEx($main, $grid, 0, 0, $AUI_COLOR_OVERRIDE_BACKGROUND)
    For $i = 0 To 26
        Local $x = 4 + Mod($i, 3) * 356, $y = 8 + Int($i / 3) * 38
        $fields[$i] = ValueText($panel, $x + 174, $y + 3, 174, 28)
        $labels[$i] = CopyLabel($names[$i], $panel, $x, $y + 3, 166, $fields[$i])
    Next

    ; ---- 目前座標色彩 ----
    $sampleLabel = _UI_Heading($main, $panel, "目前座標色彩", 6, 4, 50, 166, 28)
    $sampleSwatch = _UI_Canvas($main, $panel, 178, 50, 42, 28)
    $sampleHexText = _UI_Text($main, $panel, "", 230, 50, 180, 28)
    $sampleHex8Text = _UI_Text($main, $panel, "", 430, 50, 200, 28)
    $sampleRGBText = _UI_Text($main, $panel, "", 660, 50, 400, 28)
    _UI_OnClick($main, $sampleLabel, "CopySampleHex")
    _UI_OnClick($main, $sampleSwatch, "CopySampleHex")
    _UI_OnClick($main, $sampleHexText, "CopySampleHex")
    _UI_OnClick($main, $sampleHex8Text, "CopySampleHex8")
    _UI_OnClick($main, $sampleRGBText, "CopySampleRGB")

    ; ---- ARGB 色碼解析 ----
    $alphaLabel = _UI_Heading($main, $panel, "ARGB 解析", 6, 4, 88, 166, 28)
    $alphaInput = _UI_Input($main, $panel, "0x80FFFFFF", "0xAARRGGBB", 178, 88, 210, 30)
    $alphaParse = _UI_Button($main, $panel, "解析", $AUI_VAR_DEFAULT, 396, 88, 72, 30)
    $alphaSample = _UI_Button($main, $panel, "帶入", $AUI_VAR_DEFAULT, 476, 88, 72, 30)
    $alphaText = _UI_Text($main, $panel, "", 564, 88, 500, 28)
    _UI_OnClick($main, $alphaLabel, "CopyParsedARGB")
    _UI_OnClick($main, $alphaParse, "ParseARGB")
    _UI_OnClick($main, $alphaSample, "LoadSampleARGB")
    _UI_OnClick($main, $alphaText, "CopyAlphaDescription")
    _UI_TooltipSetText($main, $alphaInput, "解析輸入的ARGB色碼；不是螢幕像素的原始Alpha。")
    _UI_TooltipSetText($main, $alphaSample, "帶入0x00RRGGBB；00為格式補位，並非量測到的透明度。")

    ; ---- 子控制項分頁按鈕 ----
    $childPrev = _UI_Button($main, 0, "◀", $AUI_VAR_DEFAULT, 555, 146, 36, 34)
    $childNext = _UI_Button($main, 0, "▶", $AUI_VAR_DEFAULT, 599, 146, 36, 34)
    $childPageInput = _UI_Input($main, 0, "1", "頁碼", 643, 146, 52, 34)
    $childGo = _UI_Button($main, 0, "跳頁", $AUI_VAR_DEFAULT, 703, 146, 74, 34)
    _UI_OnClick($main, $childPrev, "ChildPageClick")
    _UI_OnClick($main, $childNext, "ChildPageClick")
    _UI_OnClick($main, $childGo, "ChildPageClick")

    ; ---- 控制項文字與執行檔路徑 ----
    $textEdit = InfoInput($panel, 104, 365, 960, 36)
    $textLabel = CopyLabel("控制項文字", $panel, 4, 368, 100, $textEdit)
    $pathEdit = InfoInput($panel, 104, 407, 960, 36)
    $pathLabel = CopyLabel("執行檔路徑", $panel, 4, 410, 100, $pathEdit)
    $note = _UI_Text($main, 0, "", 16, 650, 1078, 20)
    _UI_SetVisible($main, $note, False)

    $footer = _UI_Text($main, 0, "Ctrl+Alt+F：偵測　Ctrl+Alt+T：置頂", 184, 310, 780, 30)
    _UI_EndUpdate($main)
EndFunc

; ----------------------------------------------------------------------------
; 建立「控制項父子階層」視窗（可捲動的樹狀檢視），平常隱藏。
; ----------------------------------------------------------------------------
Func BuildTreeWindow()
    $treeWin = _UI_WindowCreateEx("控制項父子階層", -1, -1, 760, 600, $WIN_FLAGS)
    $treeViewport = _UI_ScrollView($treeWin, 0, 12, 50, 736, 454)
    $treeContent = _UI_ScrollGetContent($treeWin, $treeViewport)
    _UI_SetPadding($treeWin, $treeContent, 0)
    _UI_SetGap($treeWin, $treeContent, 0)
    $tree = _UI_Tree($treeWin, $treeContent, 0, 0, 712, 454)
    $treeClose = _UI_Button($treeWin, 0, "關閉", $AUI_VAR_DEFAULT, 12, 526, 100, 32)
    _UI_OnClick($treeWin, $treeClose, "HideTree")
    _UI_OnBeforeClose($treeWin, "TreeBeforeClose")
    _UI_TreeOnSelect($treeWin, $tree, "TreeSelect")
EndFunc

; ----------------------------------------------------------------------------
; 初始化 Win32 資源：列舉回呼、藍色外框視窗、拖曳游標與主視窗子類別化。
; ----------------------------------------------------------------------------
Func InitWin32()
    ; EnumChildWindows 回呼
    $enumCB = DllCallbackRegister("EnumChild", "bool", "hwnd;lparam")
    If $enumCB = 0 Then Exit
    $enumPtr = DllCallbackGetPtr($enumCB)

    CreateFrames()

    ; 拖曳游標與 DPI 縮放（準星的命中範圍以 DPI 換算）
    $dragCursor = LoadFinderCursor()
    $finderScale = _UI_GetDpiScale($main)
    If $finderScale <= 0 Then $finderScale = 1

    ; 子類別化主視窗：在 AUI 處理前攔截按下準星與游標訊息
    $cursorSubclass = DllCallbackRegister("CursorProc", "lresult", "hwnd;uint;wparam;lparam;ulong_ptr;dword_ptr")
    If $cursorSubclass <> 0 Then
        Local $ah = DllCall("comctl32.dll", "bool", "SetWindowSubclass", "hwnd", $main, "ptr", DllCallbackGetPtr($cursorSubclass), "ulong_ptr", 7201, "dword_ptr", 0)
        If Not @error And IsArray($ah) Then $cursorInstalled = $ah[0] <> 0
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 在主視窗建立按鈕，並統一由 ButtonClick() 處理點擊。
; ----------------------------------------------------------------------------
Func MakeButton($s, $x, $y, $w)
    Local $id = _UI_Button($main, 0, $s, $AUI_VAR_DEFAULT, $x, $y, $w, 32)
    _UI_OnClick($main, $id, "ButtonClick")
    Return $id
EndFunc

; ----------------------------------------------------------------------------
; 建立唯讀的資訊輸入框（視窗標題、控制項文字、執行檔路徑）。
; ----------------------------------------------------------------------------
Func InfoInput($parent, $x, $y, $w, $h)
    Local $id = _UI_Input($main, $parent, "", "", $x, $y, $w, $h)
    _UI_SetFont($main, $id, $UI_FONT, $UI_FONT_SIZE)
    _UI_EditSetReadOnly($main, $id, True)
    _UI_EditSetSelectAllOnFocus($main, $id, False)
    Return $id
EndFunc

; ----------------------------------------------------------------------------
; 建立可點擊的欄位標籤，點擊時複製 $valueID 控制項的內容。
; 回傳：標籤控制項 ID
; ----------------------------------------------------------------------------
Func CopyLabel($s, $parent, $x, $y, $w, $valueID)
    Local $id = _UI_Heading($main, $parent, $s, 6, $x, $y, $w, 28)
    _UI_SetFont($main, $id, $UI_FONT, $UI_FONT_SIZE)
    _UI_OnClick($main, $id, "CopyValue")
    $mapCount += 1
    $map[$mapCount][0] = $id
    $map[$mapCount][1] = $valueID
    Return $id
EndFunc

; ----------------------------------------------------------------------------
; 建立資訊欄位的數值文字，點擊時複製該值。
; ----------------------------------------------------------------------------
Func ValueText($parent, $x, $y, $w, $h)
    Local $id = _UI_Text($main, $parent, "", $x, $y, $w, $h)
    _UI_SetFont($main, $id, $UI_FONT, $UI_FONT_SIZE)
    _UI_OnClick($main, $id, "CopyField")
    Return $id
EndFunc

#EndRegion

#Region ;===== 主迴圈 =====

; ----------------------------------------------------------------------------
; 主迴圈：手動驅動 AUI 訊息（_UI_PumpOnce），並處理拖曳、偵測、延後動作與定時更新。
; 週期：滑鼠偵測 40 ms、完整資訊 350 ms、樹狀檢視高度 120 ms。
; ----------------------------------------------------------------------------
Func MainLoop()
    While Not $done And _UI_IsAlive($main)
        If _UI_PumpOnce() < 0 Then ExitLoop

        ; ---- 按下準星開始拖曳（子類別化失敗時的備援偵測） ----
        Local $point = MouseGetPos(), $down = KeyDown(1)
        If $down And Not $downPrev And Not $drag Then
            Local $cp = ClientPoint($main, $point[0], $point[1])
            If InFinder($cp[0], $cp[1]) Then BeginDragImmediate()
        EndIf
        If $dragVisualPending Then
            $dragVisualPending = False
            HideFrame()
            DrawFinder(True)
            _UI_SetText($main, $state, "選取中")
        EndIf

        ; ---- 拖曳中：Esc 取消、放開滑鼠則選取 ----
        If $drag Then
            SetDragCursor()
            If KeyDown(27) Then
                EndDrag(False)
            ElseIf Not $down Then
                Probe()
                EndDrag(True)
            EndIf
        EndIf
        $downPrev = $down

        ; ---- 每 40 ms：偵測滑鼠下的視窗、顯示／隱藏藍框 ----
        If TimerDiff($fast) >= 40 Then
            If Not $frozen Then Probe()
            If $drag Or TimerDiff($clock) < $frameUntil Then
                If Alive($target) Then ShowFrame($target)
            Else
                HideFrame()
            EndIf
            $fast = TimerInit()
        EndIf

        If Not $drag Then
            ; ---- 延後執行的動作（避免在 AUI 事件回呼中做耗時工作） ----
            If $childPageRequest >= 0 And Not $building Then
                Local $requestedPage = $childPageRequest
                $childPageRequest = -1
                BuildChildPage($requestedPage)
            EndIf
            If $action <> "" Then
                Local $cmd = $action
                $action = ""
                Switch $cmd
                    Case "refresh"
                        If Alive($root) Then
                            Enumerate()
                            $pending = True
                        EndIf
                    Case "tree"
                        ToggleHierarchy()
                EndSwitch
            EndIf
            If $selectHW <> 0 Then
                Local $selected = $selectHW
                $selectHW = 0
                SelectTarget($selected)
            EndIf

            ; ---- 每 350 ms：更新完整資訊與 DPI ----
            If TimerDiff($slow) >= 350 Then
                If $pending Then
                    Details()
                ElseIf Not $frozen Then
                    Details(False)
                EndIf
                $finderScale = _UI_GetDpiScale($main)
                If $finderScale <= 0 Then $finderScale = 1
                $slow = TimerInit()
            EndIf

            ; ---- 每 120 ms：依展開的節點數調整樹狀檢視高度 ----
            If $treeVisible And TimerDiff($treeClock) >= 120 Then
                UpdateTreeViewport()
                $treeClock = TimerInit()
            EndIf
        EndIf
        If $drag Then SetDragCursor()
        Sleep(8)
    WEnd
EndFunc

; ----------------------------------------------------------------------------
; 結束前釋放游標、熱鍵、子類別化、DLL 回呼、外框視窗與 AUI。
; ----------------------------------------------------------------------------
Func Cleanup()
    DllCall("user32.dll", "bool", "ReleaseCapture")
    ResetCursor()
    HotKeySet("^!f")
    HotKeySet("^!t")
    If $cursorInstalled Then DllCall("comctl32.dll", "bool", "RemoveWindowSubclass", "hwnd", $main, "ptr", DllCallbackGetPtr($cursorSubclass), "ulong_ptr", 7201)
    If $cursorSubclass <> 0 Then DllCallbackFree($cursorSubclass)
    If $dragCursor <> 0 Then DllCall("user32.dll", "bool", "DestroyCursor", "handle", $dragCursor)
    DestroyFrames()
    DllCallbackFree($enumCB)
    _UI_Shutdown()
EndFunc

; ----------------------------------------------------------------------------
; 判斷主視窗用戶端座標 ($x, $y) 是否落在左上角的準星圖示範圍內（已乘上 DPI 縮放）。
; ----------------------------------------------------------------------------
Func InFinder($x, $y)
    Return $x >= 14 * $finderScale And $x < 62 * $finderScale And $y >= 52 * $finderScale And $y < 96 * $finderScale
EndFunc

; ----------------------------------------------------------------------------
; 以 GetAsyncKeyState 判斷按鍵（或滑鼠鍵）目前是否按下。
; $key：虛擬鍵碼，例如 1＝滑鼠左鍵、27＝Esc
; ----------------------------------------------------------------------------
Func KeyDown($key)
    Local $a = DllCall("user32.dll", "short", "GetAsyncKeyState", "int", $key)
    If @error Or Not IsArray($a) Then Return False
    Return BitAND($a[0], 0x8000) <> 0
EndFunc

#EndRegion

#Region ;===== 介面事件 =====

; ----------------------------------------------------------------------------
; 主視窗按鈕的共用點擊事件；耗時動作（重新列舉、階層）設定 $action 交由主迴圈執行。
; ----------------------------------------------------------------------------
Func ButtonClick($id)
    Switch $id
        Case $bFreeze
            ToggleFreeze()
        Case $bCopy
            If $report <> "" Then
                CopyNotify($report)
            EndIf
        Case $bFrame
            $blueEnabled = Not $blueEnabled
            If $blueEnabled Then
                _UI_SetText($main, $bFrame, "藍框：開")
            Else
                _UI_SetText($main, $bFrame, "藍框：關")
                HideFrame()
            EndIf
        Case $bTree
            $action = "tree"
        Case $bRefresh
            $action = "refresh"
        Case $bTop
            ToggleTop()
        Case $bCompact
            $compact = Not $compact
            Layout()
    EndSwitch
EndFunc

; ----------------------------------------------------------------------------
; 下拉選單事件：座標模式切換，或從子控制項清單選取目標（交由主迴圈選取）。
; ----------------------------------------------------------------------------
Func ComboValue($id, $value)
    If $building Then Return
    If $id = $comboMode Then
        If $value < 0 Or $value > 2 Then Return
        $mode = $value
        If Alive($target) Then
            FastData($lastMouse[0], $lastMouse[1])
            MakeReport()
        EndIf
    ElseIf $id = $comboChild Then
        If $value < 0 Or $value >= $childPageMapCount Then Return
        Local $globalIndex = $childPageMap[$value], $hw = 0
        If $globalIndex = 0 Then
            $hw = $root
        ElseIf $globalIndex > 0 And $globalIndex <= $childCount Then
            $hw = $children[$globalIndex][0]
        EndIf
        If $hw = 0 Or $hw = $target Then Return
        _UI_ComboClose($main, $comboChild)
        $selectHW = $hw
    EndIf
EndFunc

; ----------------------------------------------------------------------------
; 主視窗關閉：通知主迴圈結束。
; ----------------------------------------------------------------------------
Func MainClose($hw)
    $done = True
EndFunc

; ----------------------------------------------------------------------------
; 階層視窗「關閉」按鈕。
; ----------------------------------------------------------------------------
Func HideTree($id)
    CloseHierarchy()
EndFunc

; ----------------------------------------------------------------------------
; 階層視窗關閉前：改為隱藏，不真的銷毀視窗。
; 回傳：False＝取消關閉
; ----------------------------------------------------------------------------
Func TreeBeforeClose($hw, $act)
    CloseHierarchy()
    Return False
EndFunc

; ----------------------------------------------------------------------------
; 點選樹狀節點：找出對應的 HWND，交由主迴圈選取為目標。
; ----------------------------------------------------------------------------
Func TreeSelect($node)
    If $building Then Return
    If $node = $rootNode Then
        $selectHW = $root
        Return
    EndIf
    For $j = 1 To $childCount
        If $nodes[$j] = $node Then
            $selectHW = $children[$j][0]
            Return
        EndIf
    Next
EndFunc

; ----------------------------------------------------------------------------
; 主題變更（淺色／深色）：重繪準星、關於圖示、格線、色塊並更新數值顏色。
; ----------------------------------------------------------------------------
Func ThemeChanged($hw, $theme)
    If Not $uiReady Then Return
    DrawFinder($drag)
    DrawAboutIcon()
    DrawGrid()
    DrawSampleSwatch()
    ApplyValueColors($theme = $AUI_THEME_DARK)
EndFunc

; ----------------------------------------------------------------------------
; 「跟隨系統／淺色／深色」選單：同時套用到主視窗與階層視窗。
; ----------------------------------------------------------------------------
Func ThemeModeChanged($id, $value)
    Local $modeValue = $AUI_THEME_AUTO
    Switch $value
        Case 1
            $modeValue = $AUI_THEME_LIGHT
        Case 2
            $modeValue = $AUI_THEME_DARK
    EndSwitch
    _UI_ThemeSetMode($main, $modeValue)
    _UI_ThemeSetMode($treeWin, $modeValue)
EndFunc

; ----------------------------------------------------------------------------
; 「字級」選單：套用 14／16／18／20 字級並重新排版。
; ----------------------------------------------------------------------------
Func FontSizeChanged($id, $value)
    Local $sizes[4] = [14, 16, 18, 20]
    If $value < 0 Or $value > 3 Then Return
    $UI_FONT_SIZE = $sizes[$value]
    _UI_BeginUpdate($main)
    ApplyTypography()
    Layout()
    _UI_EndUpdate($main)
    $treeLastVisible = -1
    UpdateTreeViewport()
EndFunc

; ----------------------------------------------------------------------------
; 關於對話框：顯示作者、AUI 與 AutoIt 版本。
; ----------------------------------------------------------------------------
Func ShowAbout($id)
    Local $body = $PRODUCT_NAME & @CRLF & @CRLF & _
        $PRODUCT_AUTHOR & @CRLF & _
        "https://www.grayfree.tw/" & @CRLF & @CRLF & _
        "ＡＩ　　　 ：Perplexity" & @CRLF & _
        "ＡＵＩ 版本：" & _UI_Version() & @CRLF & _
        "ＡＵ３ 版本：" & @AutoItVersion
    _UI_Dialog($main, "關於 Au3Info+", $body, "確定")
EndFunc

; ----------------------------------------------------------------------------
; 切換「開始偵測／停止偵測」（Ctrl+Alt+F）。
; ----------------------------------------------------------------------------
Func ToggleFreeze()
    If $drag Then Return
    $frozen = Not $frozen
    $frameUntil = 0
    HideFrame()
    UpdateState()
    If $frozen Then $pending = True
EndFunc

; ----------------------------------------------------------------------------
; 切換主視窗與階層視窗置頂（Ctrl+Alt+T）。
; ----------------------------------------------------------------------------
Func ToggleTop()
    $top = Not $top
    WinSetOnTop($main, "", Int($top))
    If $treeVisible Then WinSetOnTop($treeWin, "", Int($top))
    If $top Then
        _UI_SetText($main, $bTop, "置頂：開")
    Else
        _UI_SetText($main, $bTop, "置頂：關")
    EndIf
    If $treeVisible Then RaiseOwned($treeWin)
EndFunc

; ----------------------------------------------------------------------------
; 依偵測狀態更新按鈕文字與狀態列。
; ----------------------------------------------------------------------------
Func UpdateState()
    If $frozen Then
        _UI_SetText($main, $bFreeze, "開始偵測")
        _UI_SetText($main, $state, "已停止")
    Else
        _UI_SetText($main, $bFreeze, "停止偵測")
        _UI_SetText($main, $state, "偵測中")
    EndIf
EndFunc

#EndRegion

#Region ;===== 版面與繪圖 =====

; ----------------------------------------------------------------------------
; 依字級與「展開／收合」狀態重新排列所有欄位、按鈕，並調整視窗高度。
; 收合時只顯示控制項類別、ClassNN 與滑鼠目前座標三欄。
; ----------------------------------------------------------------------------
Func Layout()
    _UI_BeginUpdate($main)
    Local $x, $y
    Local $rowH = $UI_FONT_SIZE + 20
    If $rowH < 38 Then $rowH = 38
    Local $nameW = $UI_FONT_SIZE * 9 + 4
    If $nameW < 148 Then $nameW = 148
    Local $valueW = 348 - $nameW - 8, $rows = 11
    If $compact Then $rows = 3
    For $j = 0 To 26
        _UI_SetVisible($main, $labels[$j], False)
        _UI_SetVisible($main, $fields[$j], False)
    Next
    If $compact Then
        Local $keep[3] = [1, 2, 18]
        For $k = 0 To 2
            $j = $keep[$k]
            $x = 4 + $k * 356
            _UI_SetBounds($main, $labels[$j], $x, 10, $nameW, 28)
            _UI_SetBounds($main, $fields[$j], $x + $nameW + 8, 10, $valueW, 28)
            _UI_SetVisible($main, $labels[$j], True)
            _UI_SetVisible($main, $fields[$j], True)
        Next
        _UI_SetVisible($main, $pathLabel, False)
        _UI_SetVisible($main, $pathEdit, False)
        _UI_SetText($main, $bCompact, "▼ 展開資訊")
    Else
        For $j = 0 To 26
            $x = 4 + Mod($j, 3) * 356
            $y = 10 + Int($j / 3) * $rowH
            If Int($j / 3) >= 5 Then $y += 2 * $rowH ; 第 5 列之後空出兩列給色彩取樣區
            _UI_SetBounds($main, $labels[$j], $x, $y, $nameW, 28)
            _UI_SetBounds($main, $fields[$j], $x + $nameW + 8, $y, $valueW, 28)
            _UI_SetVisible($main, $labels[$j], True)
            _UI_SetVisible($main, $fields[$j], True)
        Next
        _UI_SetVisible($main, $pathLabel, True)
        _UI_SetVisible($main, $pathEdit, True)
        _UI_SetText($main, $bCompact, "▲ 收合資訊")
    EndIf
    ; ---- 色彩取樣與 ARGB 解析 ----
    Local $colorY = 5 * $rowH + 10
    If $compact Then $colorY = $rowH + 10
    _UI_SetBounds($main, $sampleLabel, 4, $colorY, $nameW, 28)
    _UI_SetBounds($main, $sampleSwatch, $nameW + 12, $colorY, 42, 28)
    _UI_SetBounds($main, $sampleHexText, $nameW + 66, $colorY, 180, 28)
    _UI_SetBounds($main, $sampleHex8Text, $nameW + 266, $colorY, 200, 28)
    _UI_SetBounds($main, $sampleRGBText, 660, $colorY, 400, 28)
    Local $alphaY = $colorY + $rowH
    _UI_SetBounds($main, $alphaLabel, 4, $alphaY, $nameW, 28)
    _UI_SetBounds($main, $alphaInput, $nameW + 12, $alphaY - 1, 210, 30)
    _UI_SetBounds($main, $alphaParse, $nameW + 230, $alphaY - 1, 72, 30)
    _UI_SetBounds($main, $alphaSample, $nameW + 310, $alphaY - 1, 72, 30)
    _UI_SetBounds($main, $alphaText, $nameW + 398, $alphaY, 1068 - $nameW - 398, 28)
    ; ---- 控制項文字、執行檔路徑與面板高度 ----
    Local $textY = $rows * $rowH + 20, $inputH = $UI_FONT_SIZE + 18
    _UI_SetBounds($main, $textLabel, 4, $textY + 3, 100, 28)
    _UI_SetBounds($main, $textEdit, 108, $textY, 956, $inputH)
    Local $panelH = $textY + $inputH + 12
    If Not $compact Then
        _UI_SetBounds($main, $pathLabel, 4, $textY + $inputH + 13, 100, 28)
        _UI_SetBounds($main, $pathEdit, 108, $textY + $inputH + 10, 956, $inputH)
        $panelH = $textY + $inputH * 2 + 22
    EndIf
    _UI_SetBounds($main, $grid, 0, 0, 1076, $rows * $rowH + 8)
    _UI_SetBounds($main, $panel, 12, 192, 1096, $panelH)
    Local $footerY = 192 + $panelH + 24
    _UI_SetBounds($main, $state, 16, $footerY, 150, 30)
    _UI_SetBounds($main, $footer, 184, $footerY, 780, 30)
    _UI_SetBounds($main, $bAbout, 1040, $footerY - 6, 48, 40)
    ; ---- 上方按鈕列（寬度隨字級調整） ----
    Local $buttons[5] = [$bFreeze, $bCopy, $bFrame, $bTree, $bTop]
    Local $bw = $UI_FONT_SIZE * 4 + 24, $bx = 72
    If $bw < 96 Then $bw = 96
    For $k = 0 To 4
        _UI_SetBounds($main, $buttons[$k], $bx, 58, $bw, 34)
        $bx += $bw + 8
    Next
    Local $cw = $UI_FONT_SIZE * 6 + 20
    If $cw < 120 Then $cw = 120
    _UI_SetBounds($main, $bCompact, $bx, 58, $cw, 34)
    _UI_SetBounds($main, $themeCombo, 780, 58, 180, 34)
    _UI_SetBounds($main, $fontCombo, 968, 58, 128, 34)
    Local $rw = $UI_FONT_SIZE * 4 + 24
    If $rw < 96 Then $rw = 96
    _UI_SetBounds($main, $comboMode, 889, 146, 208, 36)
    _UI_SetBounds($main, $bRefresh, 889 - $rw - 8, 146, $rw, 34)
    Local $childWidth = 889 - $rw - 128 - 230
    _UI_SetBounds($main, $comboChild, 112, 146, $childWidth, 36)
    Local $navX = 112 + $childWidth + 8
    _UI_SetBounds($main, $childPrev, $navX, 146, 36, 34)
    _UI_SetBounds($main, $childNext, $navX + 44, 146, 36, 34)
    _UI_SetBounds($main, $childPageInput, $navX + 88, 146, 52, 34)
    _UI_SetBounds($main, $childGo, $navX + 148, 146, 74, 34)
    _UI_SetBounds($main, $titleEdit, 112, 105, 985, $inputH)
    DrawGrid()
    _UI_EndUpdate($main)
    ; 視窗高度隨面板高度調整
    Local $wp = _UI_WindowGetBounds($main)
    If IsArray($wp) Then _UI_WindowSetBounds($main, $wp[0], $wp[1], 1120, $footerY + 68)
EndFunc

; ----------------------------------------------------------------------------
; 把目前字級套用到所有文字控制項（下拉選單與小按鈕固定使用 $COMBO_FONT_SIZE）。
; ----------------------------------------------------------------------------
Func ApplyTypography()
    Local $ids[12] = [$bFreeze, $bCopy, $bFrame, $bTree, $bTop, $bCompact, $state, $titleEdit, $bRefresh, $footer, $textEdit, $pathEdit]
    For $j = 0 To UBound($ids) - 1
        _UI_SetFont($main, $ids[$j], $UI_FONT, $UI_FONT_SIZE)
    Next
    Local $combos[4] = [$comboChild, $comboMode, $fontCombo, $themeCombo]
    For $j = 0 To 3
        _UI_SetFont($main, $combos[$j], $UI_FONT, $COMBO_FONT_SIZE)
    Next
    _UI_SetFont($main, $childLabel, $UI_FONT, $UI_FONT_SIZE)
    For $j = 0 To 26
        _UI_SetFont($main, $labels[$j], $UI_FONT, $UI_FONT_SIZE)
        _UI_SetFont($main, $fields[$j], $UI_FONT, $UI_FONT_SIZE)
    Next
    _UI_SetFont($main, $titleLabel, $UI_FONT, $UI_FONT_SIZE)
    _UI_SetFont($main, $textLabel, $UI_FONT, $UI_FONT_SIZE)
    _UI_SetFont($main, $pathLabel, $UI_FONT, $UI_FONT_SIZE)
    _UI_SetFont($treeWin, $tree, $UI_FONT, $UI_FONT_SIZE)
    _UI_SetFont($treeWin, $treeClose, $UI_FONT, $UI_FONT_SIZE)
    Local $extraText[5] = [$sampleLabel, $sampleHexText, $sampleHex8Text, $sampleRGBText, $alphaLabel]
    For $j = 0 To UBound($extraText) - 1
        _UI_SetFont($main, $extraText[$j], $UI_FONT, $UI_FONT_SIZE)
    Next
    Local $extraSmall[8] = [$alphaInput, $alphaParse, $alphaSample, $alphaText, $childPrev, $childNext, $childPageInput, $childGo]
    For $j = 0 To UBound($extraSmall) - 1
        _UI_SetFont($main, $extraSmall[$j], $UI_FONT, $COMBO_FONT_SIZE)
    Next
EndFunc

; ----------------------------------------------------------------------------
; 依欄位類型設定數值顏色：藍＝一般、紫＝Style、綠＝座標與尺寸、橘＝ID 與數量。
; $dark：是否使用深色主題配色
; ----------------------------------------------------------------------------
Func ApplyValueColors($dark = False)
    Local $blue = 0xFF0067C0, $green = 0xFF147D40, $purple = 0xFF7446A5, $orange = 0xFF9A5200
    If $dark Then
        $blue = 0xFF75BEFF
        $green = 0xFF7AD9A3
        $purple = 0xFFC7A3F5
        $orange = 0xFFFFC078
    EndIf
    For $j = 0 To 26
        Local $c = $blue
        Switch $j
            Case 6, 7, 9, 10
                $c = $purple
            Case 12 To 19, 21, 22
                $c = $green
            Case 8, 11, 23, 26
                $c = $orange
        EndSwitch
        _UI_SetColorEx($main, $fields[$j], 0, $c, $AUI_COLOR_OVERRIDE_FOREGROUND)
    Next
    _UI_SetColorEx($main, $titleEdit, 0, $blue, $AUI_COLOR_OVERRIDE_FOREGROUND)
    _UI_SetColorEx($main, $textEdit, 0, $purple, $AUI_COLOR_OVERRIDE_FOREGROUND)
    _UI_SetColorEx($main, $pathEdit, 0, $green, $AUI_COLOR_OVERRIDE_FOREGROUND)
EndFunc

; ----------------------------------------------------------------------------
; 在畫布上繪製「i」關於圖示（使用主題強調色）。
; ----------------------------------------------------------------------------
Func DrawAboutIcon()
    Local $c = _UI_ThemeGetColor($main, "accent")
    If @error Or $c = 0 Then $c = $BLUE
    _UI_CanvasBeginUpdate($main, $bAbout)
    _UI_CanvasClear($main, $bAbout, 0)
    _UI_CanvasDrawEllipse($main, $bAbout, 24, 20, 14, 14, $c, 2.5)
    _UI_CanvasFillEllipse($main, $bAbout, 24, 13, 2, 2, $c)
    _UI_CanvasFillRect($main, $bAbout, 22.5, 19, 3, 11, $c)
    _UI_CanvasEndUpdate($main, $bAbout)
EndFunc

; ----------------------------------------------------------------------------
; 繪製準星圖示。
; $active：拖曳中時加上半透明圓形底色
; ----------------------------------------------------------------------------
Func DrawFinder($active)
    Local $c = _UI_ThemeGetColor($main, "accent")
    If @error Or $c = 0 Then $c = $BLUE
    _UI_CanvasBeginUpdate($main, $finder)
    _UI_CanvasClear($main, $finder, 0)
    If $active Then _UI_CanvasFillEllipse($main, $finder, 24, 22, 20, 20, BitOR(BitAND($c, 0x00FFFFFF), 0x30000000))
    _UI_CanvasDrawEllipse($main, $finder, 24, 22, 11, 11, $c, 2)
    _UI_CanvasDrawLine($main, $finder, 24, 4, 24, 15, $c, 2)
    _UI_CanvasDrawLine($main, $finder, 24, 29, 24, 40, $c, 2)
    _UI_CanvasDrawLine($main, $finder, 6, 22, 17, 22, $c, 2)
    _UI_CanvasDrawLine($main, $finder, 31, 22, 42, 22, $c, 2)
    _UI_CanvasFillEllipse($main, $finder, 24, 22, 2, 2, $c)
    _UI_CanvasEndUpdate($main, $finder)
EndFunc

; ----------------------------------------------------------------------------
; 在資訊面板繪製欄位格線（色彩取樣區兩列不畫直線）。
; ----------------------------------------------------------------------------
Func DrawGrid()
    Local $c = _UI_ThemeGetColor($main, "accent")
    If @error Or $c = 0 Then $c = $BLUE
    $c = BitOR(BitAND($c, 0x00FFFFFF), 0x50000000)
    Local $rows = 11, $colorRow = 5, $rowH = $UI_FONT_SIZE + 20, $nameW = $UI_FONT_SIZE * 9 + 4
    If $compact Then
        $rows = 3
        $colorRow = 1
    EndIf
    If $rowH < 38 Then $rowH = 38
    If $nameW < 148 Then $nameW = 148
    Local $bottom = 4 + $rows * $rowH
    Local $colorTop = 4 + $colorRow * $rowH, $colorBottom = $colorTop + 2 * $rowH
    _UI_CanvasBeginUpdate($main, $grid)
    _UI_CanvasClear($main, $grid, 0)
    For $r = 0 To $rows
        _UI_CanvasDrawLine($main, $grid, 0, 4 + $r * $rowH, 1068, 4 + $r * $rowH, $c, 1)
    Next
    Local $vx[7] = [0, $nameW, 356, 356 + $nameW, 712, 712 + $nameW, 1068]
    For $j = 0 To 6
        If $j = 0 Or $j = 6 Then
            _UI_CanvasDrawLine($main, $grid, $vx[$j], 4, $vx[$j], $bottom, $c, 1)
        Else
            _UI_CanvasDrawLine($main, $grid, $vx[$j], 4, $vx[$j], $colorTop, $c, 1)
            If $colorBottom < $bottom Then _UI_CanvasDrawLine($main, $grid, $vx[$j], $colorBottom, $vx[$j], $bottom, $c, 1)
        EndIf
    Next
    _UI_CanvasEndUpdate($main, $grid)
EndFunc

#EndRegion

#Region ;===== 拖曳準星與游標 =====

; ----------------------------------------------------------------------------
; 開始拖曳準星：記住原偵測狀態、捕捉滑鼠並切換游標。
; ----------------------------------------------------------------------------
Func BeginDragImmediate()
    If $drag Then Return
    $wasFrozen = $frozen
    $frozen = False
    $drag = True
    $dragVisualPending = True
    DllCall("user32.dll", "hwnd", "SetCapture", "hwnd", $main)
    SetDragCursor()
EndFunc

; ----------------------------------------------------------------------------
; 結束拖曳。
; $accept：True＝選取目前目標並鎖定、顯示藍框 1.5 秒；False＝取消（Esc），恢復原狀態
; ----------------------------------------------------------------------------
Func EndDrag($accept)
    DllCall("user32.dll", "bool", "ReleaseCapture")
    $drag = False
    $dragVisualPending = False
    ResetCursor()
    DrawFinder(False)
    If $accept Then
        $frozen = True
        $frameUntil = TimerDiff($clock) + 1500
    Else
        $frozen = $wasFrozen
        $frameUntil = 0
        HideFrame()
    EndIf
    UpdateState()
    $pending = True
EndFunc

; ----------------------------------------------------------------------------
; 拖曳中維持滑鼠捕捉並設定拖曳游標（finder.cur，沒有則用十字游標）。
; ----------------------------------------------------------------------------
Func SetDragCursor()
    If Not $drag Then Return
    Local $a = DllCall("user32.dll", "hwnd", "GetCapture")
    If Not @error And IsArray($a) Then
        If $a[0] <> $main Then DllCall("user32.dll", "hwnd", "SetCapture", "hwnd", $main)
    EndIf
    Local $cursor = $dragCursor
    If $cursor = 0 Then
        $a = DllCall("user32.dll", "handle", "LoadCursorW", "handle", 0, "ptr", 32515) ; IDC_CROSS
        If Not @error And IsArray($a) Then $cursor = $a[0]
    EndIf
    If $cursor <> 0 Then DllCall("user32.dll", "handle", "SetCursor", "handle", $cursor)
EndFunc

; ----------------------------------------------------------------------------
; 恢復成一般箭頭游標。
; ----------------------------------------------------------------------------
Func ResetCursor()
    Local $a = DllCall("user32.dll", "handle", "LoadCursorW", "handle", 0, "ptr", 32512) ; IDC_ARROW
    If Not @error And IsArray($a) Then DllCall("user32.dll", "handle", "SetCursor", "handle", $a[0])
EndFunc

; ----------------------------------------------------------------------------
; 主視窗子類別化程序：
;   - 擋掉雙擊標題列／系統選單的最大化
;   - 在準星上按下左鍵時立即開始拖曳
;   - 拖曳中由 WM_SETCURSOR／WM_MOUSEMOVE 維持拖曳游標
; ----------------------------------------------------------------------------
Func CursorProc($hw, $msg, $wp, $lp, $id, $ref)
    ; WM_SYSCOMMAND + SC_MAXIMIZE、WM_NCLBUTTONDBLCLK：禁止最大化
    If $msg = 0x0112 And BitAND($wp, 0xFFF0) = 0xF030 Then Return 0
    If $msg = 0x00A3 Then Return 0
    ; WM_LBUTTONDOWN：在準星上按下立即開始拖曳（座標為有號 16 位元）
    If $msg = 0x0201 And Not $drag Then
        Local $x = BitAND($lp, 0xFFFF), $y = BitAND(BitShift($lp, 16), 0xFFFF)
        If $x >= 0x8000 Then $x -= 0x10000
        If $y >= 0x8000 Then $y -= 0x10000
        If InFinder($x, $y) Then
            BeginDragImmediate()
            Return 0
        EndIf
    EndIf
    ; WM_SETCURSOR：拖曳中維持拖曳游標
    If $msg = 0x0020 And $drag Then
        SetDragCursor()
        Return 1
    EndIf
    Local $a = DllCall("comctl32.dll", "lresult", "DefSubclassProc", "hwnd", $hw, "uint", $msg, "wparam", $wp, "lparam", $lp)
    If @error Or Not IsArray($a) Then Return 0
    ; WM_MOUSEMOVE
    If $msg = 0x0200 And $drag Then SetDragCursor()
    Return $a[0]
EndFunc

; ----------------------------------------------------------------------------
; 從程式資料夾載入 finder.cur。
; 回傳：游標代碼；檔案不存在時回傳 0
; ----------------------------------------------------------------------------
Func LoadFinderCursor()
    Local $a = DllCall("user32.dll", "handle", "LoadImageW", "handle", 0, "wstr", @ScriptDir & "\finder.cur", _
        "uint", 2, "int", 32, "int", 32, "uint", 0x0010)
    If @error Or Not IsArray($a) Then Return 0
    Return $a[0]
EndFunc

#EndRegion

#Region ;===== 視窗偵測與資訊 =====

; ----------------------------------------------------------------------------
; 取得滑鼠下的控制項與其頂層視窗（略過本程式自己的視窗），並更新快速資訊。
; ----------------------------------------------------------------------------
Func Probe()
    Local $pt = DllStructCreate("long X;long Y")
    Local $a = DllCall("user32.dll", "bool", "GetCursorPos", "ptr", DllStructGetPtr($pt))
    If @error Or Not IsArray($a) Then Return
    If Not $a[0] Then Return
    ; WindowFromPoint 的 POINT 以傳值方式傳入，打包成 int64
    Local $x = DllStructGetData($pt, 1), $y = DllStructGetData($pt, 2), $pack = DllStructCreate("int64", DllStructGetPtr($pt))
    $a = DllCall("user32.dll", "hwnd", "WindowFromPoint", "int64", DllStructGetData($pack, 1))
    If @error Or Not IsArray($a) Then Return
    Local $h = $a[0], $w = Ancestor($h, 2)
    If $h = 0 Or $w = 0 Then Return
    ; 滑鼠在本程式視窗上：不更新目標
    If $w = $main Or $w = $treeWin Then
        If Not $drag Then
            $frameUntil = 0
            HideFrame()
        EndIf
        Return
    EndIf
    If $h <> $target Or $w <> $root Then
        $target = $h
        $root = $w
        $pending = True
        If Not $drag Then $frameUntil = TimerDiff($clock) + 650
    EndIf
    $lastMouse[0] = $x
    $lastMouse[1] = $y
    FastData($x, $y)
EndFunc

; ----------------------------------------------------------------------------
; 更新需即時反應的欄位：類別、HWND、位置、大小、滑鼠座標與像素色彩。
; ----------------------------------------------------------------------------
Func FastData($x, $y)
    If Not Alive($target) Then Return
    Local $rw = Rect($root), $rc = Rect($target), $cl = Rect($root, True), $cp = ClientPoint($root, $rc[0], $rc[1])
    Local $mp = ClientPoint($root, $x, $y), $rx = $x, $ry = $y
    If $mode = 1 Then
        $rx -= $rw[0]
        $ry -= $rw[1]
    ElseIf $mode = 2 Then
        $rx = $mp[0]
        $ry = $mp[1]
    EndIf
    Put(0, ClassOf($root))
    Put(1, ClassOf($target))
    Put(3, String($root))
    Put(4, String($target))
    Put(12, $rw[0] & ",  " & $rw[1])
    Put(13, $rc[0] & ",  " & $rc[1])
    Put(14, $cp[0] & ",  " & $cp[1])
    Put(15, $rw[2] & " × " & $rw[3])
    Put(16, $rc[2] & " × " & $rc[3])
    Put(17, $cl[2] & " × " & $cl[3])
    Put(18, $rx & ",  " & $ry)
    Put(19, $x & ",  " & $y)
    If $drag Then Put(2, "")
    UpdateCurrentColor($x, $y)
EndFunc

; ----------------------------------------------------------------------------
; 更新完整資訊：標題、文字、執行檔路徑、Style、ID、狀態、標題列高度、邊框、DPI 等。
; $full：False 時若視窗尚未列舉則略過（偵測中的輕量更新）
; ----------------------------------------------------------------------------
Func Details($full = True)
    If Not Alive($target) Or Not Alive($root) Then
        $pending = False
        HideFrame()
        Return
    EndIf
    If $listRoot <> $root Then
        If Not $full Then Return
        Enumerate()
    EndIf
    ; 執行檔路徑只在頂層視窗或程序變更時重新查詢
    Local $pid = WinGetProcess($root)
    If $pathRoot <> $root Or $pathPID <> $pid Then
        $pathValue = PathOf($pid)
        $pathRoot = $root
        $pathPID = $pid
    EndIf
    $titleValue = TextOf($root)
    $textValue = TextOf($target)
    SetText($titleEdit, $titleValue)
    SetText($textEdit, $textValue)
    SetText($pathEdit, $pathValue)
    Local $nn = "[頂層視窗]"
    If $target <> $root Then
        $nn = "[未列舉]"
        If $childIndex.Exists(String($target)) Then $nn = $children[$childIndex.Item(String($target))][3]
    EndIf
    Put(2, $nn)
    SyncCombo()
    Local $parent = Ancestor($target, 1)
    Put(5, String($parent))
    Put(24, ClassOf($parent))
    Put(6, StyleOf($root, -16))
    Put(7, StyleOf($target, -16))
    Put(9, StyleOf($root, -20))
    Put(10, StyleOf($target, -20))
    Put(11, $pid)
    Local $a = DllCall("user32.dll", "int", "GetDlgCtrlID", "hwnd", $target)
    If Not @error And IsArray($a) Then Put(8, $a[0])
    Local $vi = DllCall("user32.dll", "bool", "IsWindowVisible", "hwnd", $target)
    Local $en = DllCall("user32.dll", "bool", "IsWindowEnabled", "hwnd", $target)
    If IsArray($vi) And IsArray($en) Then Put(25, "Visible = " & $vi[0] & " / Enabled = " & $en[0])
    ; WINDOWINFO：以視窗與用戶端頂端差估算標題列高度
    Local $wi = DllStructCreate("uint Size;long WL;long WT;long WR;long WB;long CL;long CT;long CR;long CB;dword Style;dword ExStyle;dword Status;uint BX;uint BY;ushort Atom;ushort Version")
    DllStructSetData($wi, "Size", DllStructGetSize($wi))
    $a = DllCall("user32.dll", "bool", "GetWindowInfo", "hwnd", $root, "ptr", DllStructGetPtr($wi))
    If Not @error And IsArray($a) Then
        If $a[0] Then
            Local $caption = DllStructGetData($wi, "CT") - DllStructGetData($wi, "WT") - DllStructGetData($wi, "BY")
            If $caption < 0 Then $caption = 0
            Put(21, $caption)
            Put(22, DllStructGetData($wi, "BX") & " / " & DllStructGetData($wi, "BY"))
        EndIf
    EndIf
    Local $dpi = DllCall("user32.dll", "uint", "GetDpiForWindow", "hwnd", $root)
    If Not @error And IsArray($dpi) Then Put(26, $dpi[0])
    If $sampleHex <> "" Then Put(20, $sampleHex)
    MakeReport()
    $pending = False
EndFunc

; ----------------------------------------------------------------------------
; 把指定 HWND 設為目標（從清單或樹狀檢視選取），鎖定偵測並閃示藍框。
; ----------------------------------------------------------------------------
Func SelectTarget($h)
    If Not Alive($h) Then
        _UI_SetText($main, $note, "目標已失效")
        Return
    EndIf
    Local $w = Ancestor($h, 2)
    If $w = 0 Then Return
    $target = $h
    $root = $w
    $frozen = True
    UpdateState()
    HideFrame()
    FastData($lastMouse[0], $lastMouse[1])
    Details()
    $blueEnabled = True
    _UI_SetText($main, $bFrame, "藍框：開")
    $frameUntil = TimerDiff($clock) + 1500
    ShowFrame($target)
    _UI_SetText($main, $note, "")
EndFunc

; ----------------------------------------------------------------------------
; 組出「複製全部」使用的完整文字報告。
; ----------------------------------------------------------------------------
Func MakeReport()
    $report = "視窗標題：" & $titleValue & @CRLF
    For $j = 0 To 26
        $report &= $names[$j] & "：" & $values[$j] & @CRLF
    Next
    $report &= "控制項文字：" & $textValue & @CRLF & "執行檔路徑：" & $pathValue & @CRLF & _
        "座標模式：" & $mode & @CRLF & "視窗選取字串：[HANDLE:" & String($root) & "]"
    If $sampleHex <> "" Then $report &= @CRLF & "八位色碼（00補位，非Alpha量測）：" & $sampleHex8 & @CRLF & "座標 RGB：" & $sampleRGB
    If $parsedARGB <> "" Then $report &= @CRLF & "ARGB輸入解析：" & $parsedARGB & @CRLF & $alphaDescription
EndFunc

; ----------------------------------------------------------------------------
; 設定控制項文字與提示；內容沒變時略過，避免偵測中不斷重繪。
; ----------------------------------------------------------------------------
Func SetText($id, $s)
    $s = String($s)
    If $textCache.Exists(String($id)) Then
        If $textCache.Item(String($id)) = $s Then Return
    EndIf
    $textCache.Item(String($id)) = $s
    _UI_SetText($main, $id, $s)
    If $id = $titleEdit Or $id = $textEdit Or $id = $pathEdit Then _UI_EditSetSelection($main, $id, 0, 0)
    _UI_TooltipSetText($main, $id, $s)
EndFunc

; ----------------------------------------------------------------------------
; 寫入第 $j 個資訊欄位的值（同時保存到 $values 供複製與報告使用）。
; ----------------------------------------------------------------------------
Func Put($j, $s)
    $values[$j] = String($s)
    SetText($fields[$j], $values[$j])
EndFunc

#EndRegion

#Region ;===== Win32 輔助函式 =====

; ----------------------------------------------------------------------------
; 視窗代碼是否仍有效（IsWindow）。
; ----------------------------------------------------------------------------
Func Alive($h)
    Local $a = DllCall("user32.dll", "bool", "IsWindow", "hwnd", $h)
    If @error Or Not IsArray($a) Then Return False
    Return $a[0] <> 0
EndFunc

; ----------------------------------------------------------------------------
; GetAncestor。
; $flag：1＝GA_PARENT 父視窗；2＝GA_ROOT 頂層視窗
; ----------------------------------------------------------------------------
Func Ancestor($h, $flag)
    Local $a = DllCall("user32.dll", "hwnd", "GetAncestor", "hwnd", $h, "uint", $flag)
    If @error Or Not IsArray($a) Then Return 0
    Return $a[0]
EndFunc

; ----------------------------------------------------------------------------
; 取得視窗矩形。
; $client：True＝用戶端區域（GetClientRect）
; 回傳：[左, 上, 寬, 高]；失敗時全為 0
; ----------------------------------------------------------------------------
Func Rect($h, $client = False)
    Local $b = DllStructCreate("long L;long T;long R;long B"), $fn = "GetWindowRect", $v[4] = [0, 0, 0, 0]
    If $client Then $fn = "GetClientRect"
    Local $a = DllCall("user32.dll", "bool", $fn, "hwnd", $h, "ptr", DllStructGetPtr($b))
    If @error Or Not IsArray($a) Then Return $v
    If Not $a[0] Then Return $v
    $v[0] = DllStructGetData($b, 1)
    $v[1] = DllStructGetData($b, 2)
    $v[2] = DllStructGetData($b, 3) - $v[0]
    $v[3] = DllStructGetData($b, 4) - $v[1]
    Return $v
EndFunc

; ----------------------------------------------------------------------------
; 螢幕座標轉為 $h 的用戶端座標。
; 回傳：[x, y]
; ----------------------------------------------------------------------------
Func ClientPoint($h, $x, $y)
    Local $b = DllStructCreate("long X;long Y")
    DllStructSetData($b, 1, $x)
    DllStructSetData($b, 2, $y)
    DllCall("user32.dll", "bool", "ScreenToClient", "hwnd", $h, "ptr", DllStructGetPtr($b))
    Local $v[2] = [DllStructGetData($b, 1), DllStructGetData($b, 2)]
    Return $v
EndFunc

; ----------------------------------------------------------------------------
; 取得視窗類別名稱。
; ----------------------------------------------------------------------------
Func ClassOf($h)
    Local $b = DllStructCreate("wchar[256]")
    DllCall("user32.dll", "int", "GetClassNameW", "hwnd", $h, "ptr", DllStructGetPtr($b), "int", 256)
    Return DllStructGetData($b, 1)
EndFunc

; ----------------------------------------------------------------------------
; 以 WM_GETTEXT 讀取視窗文字（逾時 60 ms，遇到無回應的程式不會卡住）。
; ----------------------------------------------------------------------------
Func TextOf($h)
    Local $b = DllStructCreate("wchar[4096]")
    ; WM_GETTEXT(13)，SMTO_ABORTIFHUNG(2)，逾時 60 ms
    Local $a = DllCall("user32.dll", "lresult", "SendMessageTimeoutW", "hwnd", $h, "uint", 13, "wparam", 4096, _
        "ptr", DllStructGetPtr($b), "uint", 2, "uint", 60, "ulong_ptr*", 0)
    If @error Or Not IsArray($a) Then Return "[無法讀取]"
    If $a[0] = 0 Then Return "[逾時或存取遭拒]"
    Return DllStructGetData($b, 1)
EndFunc

; ----------------------------------------------------------------------------
; 讀取視窗長整數值並以十六進位回傳。
; $idx：-16＝GWL_STYLE；-20＝GWL_EXSTYLE
; ----------------------------------------------------------------------------
Func StyleOf($h, $idx)
    ; 64 位元需改用 GetWindowLongPtrW（本程式限 32 位元，保留相容）
    Local $fn = "GetWindowLongW", $ret = "long"
    If @AutoItX64 Then
        $fn = "GetWindowLongPtrW"
        $ret = "long_ptr"
    EndIf
    Local $a = DllCall("user32.dll", $ret, $fn, "hwnd", $h, "int", $idx)
    If @error Or Not IsArray($a) Then Return ""
    Return "0x" & Hex($a[0], 8)
EndFunc

; ----------------------------------------------------------------------------
; 取得程序的完整執行檔路徑（QueryFullProcessImageNameW）。
; ----------------------------------------------------------------------------
Func PathOf($pid)
    ; PROCESS_QUERY_LIMITED_INFORMATION(0x1000)
    Local $a = DllCall("kernel32.dll", "handle", "OpenProcess", "dword", 0x1000, "bool", False, "dword", $pid)
    If @error Or Not IsArray($a) Then Return "[無法讀取]"
    If $a[0] = 0 Then Return "[存取遭拒]"
    Local $hp = $a[0], $b = DllStructCreate("wchar[32768]")
    Local $q = DllCall("kernel32.dll", "bool", "QueryFullProcessImageNameW", "handle", $hp, "dword", 0, _
        "ptr", DllStructGetPtr($b), "dword*", 32768)
    Local $err = @error, $s = "[無法讀取]"
    If Not $err And IsArray($q) Then
        If $q[0] Then $s = DllStructGetData($b, 1)
    EndIf
    DllCall("kernel32.dll", "bool", "CloseHandle", "handle", $hp)
    Return $s
EndFunc

#EndRegion

#Region ;===== 子控制項列舉與分頁 =====

; ----------------------------------------------------------------------------
; EnumChildWindows 回呼：記錄每個子控制項的 HWND、父視窗與類別。
; 回傳：False＝已達 $MAX_CHILDREN 上限，停止列舉
; ----------------------------------------------------------------------------
Func EnumChild($h, $param)
    If $childCount >= $MAX_CHILDREN Then Return False
    $childCount += 1
    If $childCount >= UBound($children) Then ReDim $children[UBound($children) + 256][4]
    $children[$childCount][0] = $h
    $children[$childCount][1] = Ancestor($h, 1)
    $children[$childCount][2] = ClassOf($h)
    $children[$childCount][3] = ""
    Return True
EndFunc

; ----------------------------------------------------------------------------
; 列舉目前頂層視窗的所有子控制項，計算 ClassNN（類別＋同類別序號）並建立索引。
; ----------------------------------------------------------------------------
Func Enumerate()
    If Not Alive($root) Or $building Then Return
    $building = True
    _UI_ComboClose($main, $comboChild)
    $childCount = 0
    DllCall("user32.dll", "bool", "EnumChildWindows", "hwnd", $root, "ptr", $enumPtr, "lparam", 0)
    Local $counts = ObjCreate("Scripting.Dictionary"), $page = 0
    $childIndex.RemoveAll()
    ; ClassNN ＝ 類別名稱 ＋ 同類別出現序號（與 AutoIt Window Info 相同）
    For $j = 1 To $childCount
        Local $class = $children[$j][2], $n = 1
        If $counts.Exists($class) Then $n = $counts.Item($class) + 1
        $counts.Item($class) = $n
        $children[$j][3] = $class & $n
        $childIndex.Item(String($children[$j][0])) = $j
        If $children[$j][0] = $target Then $page = Int(($j - 1) / $CHILD_PAGE_SIZE)
    Next
    $listRoot = $root
    $childComboLastTarget = $target
    $childPageRequest = -1
    BuildChildPage($page)
    Put(23, $childCount)
    $building = False
    SyncCombo()
    If $treeVisible Then BuildTree()
EndFunc

; ----------------------------------------------------------------------------
; 讓子控制項下拉選單跟著目前目標切換到正確頁面與選取項目。
; ----------------------------------------------------------------------------
Func SyncCombo()
    If $listRoot <> $root Or $building Then Return
    If _UI_ComboGetOpen($main, $comboChild) Then Return
    Local $globalIndex = -1, $key = String($target)
    If $target = $root Then
        $globalIndex = 0
    ElseIf $childIndex.Exists($key) Then
        $globalIndex = $childIndex.Item($key)
    EndIf
    If $childComboLastTarget <> $target Then
        $childComboLastTarget = $target
        Local $page = 0
        If $globalIndex > 0 Then $page = Int(($globalIndex - 1) / $CHILD_PAGE_SIZE)
        If $page <> $childPage Then BuildChildPage($page)
    EndIf
    Local $idx = -1
    For $j = 0 To $childPageMapCount - 1
        If $childPageMap[$j] = $globalIndex Then
            $idx = $j
            ExitLoop
        EndIf
    Next
    If _UI_ComboGetSelected($main, $comboChild) <> $idx Then _UI_ComboSetSelected($main, $comboChild, $idx)
    Local $tip = "第 " & ($childPage + 1) & " / " & (ChildMaxPage() + 1) & " 頁，每頁最多 " & $CHILD_PAGE_SIZE & " 個子控制項。"
    If $globalIndex > 0 Then $tip &= @CRLF & $children[$globalIndex][3] & " · " & String($target)
    _UI_TooltipSetText($main, $comboChild, $tip)
EndFunc

; ----------------------------------------------------------------------------
; 回傳子控制項清單最後一頁的頁碼（從 0 起算）。
; ----------------------------------------------------------------------------
Func ChildMaxPage()
    If $childCount <= 0 Then Return 0
    Return Int(($childCount - 1) / $CHILD_PAGE_SIZE)
EndFunc

; ----------------------------------------------------------------------------
; 重建子控制項下拉選單為指定頁（第 0 項固定為頂層視窗），並更新分頁按鈕。
; AUI 下拉選單無法整批替換項目，因此銷毀後依原位置重建。
; ----------------------------------------------------------------------------
Func BuildChildPage($page)
    If $page < 0 Then $page = 0
    If $page > ChildMaxPage() Then $page = ChildMaxPage()
    Local $wasBuilding = $building
    $building = True
    _UI_ComboClose($main, $comboChild)
    $childPage = $page
    $childPageMapCount = 1
    $childPageMap[0] = 0
    Local $options = "0 · 頂層視窗", $selected = -1
    If $target = $root Then $selected = 0
    Local $first = $page * $CHILD_PAGE_SIZE + 1, $last = $first + $CHILD_PAGE_SIZE - 1
    If $last > $childCount Then $last = $childCount
    For $j = $first To $last
        Local $caption = StringReplace(StringReplace(StringReplace($children[$j][3], @CR, " "), @LF, " "), "|", "/")
        If StringLen($caption) > 42 Then $caption = StringLeft($caption, 39) & "..."
        $options &= "|" & $j & " · " & $caption
        $childPageMap[$childPageMapCount] = $j
        If $children[$j][0] = $target Then $selected = $childPageMapCount
        $childPageMapCount += 1
    Next
    Local $b = _UI_GetBounds($main, $comboChild)
    If Not IsArray($b) Then
        Local $fallback[4] = [112, 146, 435, 36]
        $b = $fallback
    EndIf
    _UI_BeginUpdate($main)
    _UI_Destroy($main, $comboChild)
    $comboChild = _UI_Combo($main, 0, $options, $selected, $b[0], $b[1], $b[2], $b[3])
    _UI_SetFont($main, $comboChild, $UI_FONT, $COMBO_FONT_SIZE)
    _UI_OnValue($main, $comboChild, "ComboValue")
    _UI_SetText($main, $childPageInput, String($page + 1))
    Local $tip = "第 " & ($page + 1) & " / " & (ChildMaxPage() + 1) & " 頁；共 " & $childCount & " 個子控制項。"
    _UI_TooltipSetText($main, $comboChild, $tip)
    _UI_TooltipSetText($main, $childPageInput, $tip)
    _UI_TooltipSetText($main, $childPrev, "上一頁；" & $tip)
    _UI_TooltipSetText($main, $childNext, "下一頁；" & $tip)
    _UI_TooltipSetText($main, $childGo, "輸入頁碼後跳轉；" & $tip)
    _UI_SetEnabled($main, $childPrev, $page > 0)
    _UI_SetEnabled($main, $childNext, $page < ChildMaxPage())
    _UI_EndUpdate($main)
    $building = $wasBuilding
EndFunc

; ----------------------------------------------------------------------------
; 「◀」「▶」「跳頁」按鈕：驗證頁碼後交由主迴圈換頁。
; ----------------------------------------------------------------------------
Func ChildPageClick($id)
    If $building Or $listRoot <> $root Then Return
    Local $page = $childPage
    If $id = $childPrev Then
        $page -= 1
    ElseIf $id = $childNext Then
        $page += 1
    ElseIf $id = $childGo Then
        Local $input = StringStripWS(_UI_GetText($main, $childPageInput), 3)
        If Not StringRegExp($input, "^[0-9]{1,5}$") Then
            _UI_Notify($main, "頁碼格式錯誤", "請輸入有效的整數頁碼。", 0, 2000)
            Return
        EndIf
        $page = Number($input) - 1
        If $page < 0 Or $page > ChildMaxPage() Then
            _UI_Notify($main, "頁碼超出範圍", "可用頁碼：1 至 " & (ChildMaxPage() + 1), 0, 2000)
            Return
        EndIf
    EndIf
    If $page < 0 Or $page > ChildMaxPage() Then Return
    $childPageRequest = $page
EndFunc

#EndRegion

#Region ;===== 父子階層視窗 =====

; ----------------------------------------------------------------------------
; 開啟／關閉「父子階層」視窗；開啟時建立樹狀檢視並設為主視窗的附屬視窗。
; ----------------------------------------------------------------------------
Func ToggleHierarchy()
    If $treeVisible Then
        CloseHierarchy()
        Return
    EndIf
    If Not Alive($root) Then
        _UI_Notify($main, "請先選取目標", "", $AUI_NOTIFY_WARNING, 2000)
        Return
    EndIf
    ; 同一根視窗沿用快取，不因打開階層而重建Combo。
    If $listRoot <> $root Then Enumerate()
    BuildTree()
    If $rootNode < 1 Then
        _UI_Notify($main, "階層建立失敗", _UI_GetLastErrorText(), $AUI_NOTIFY_DANGER, 2000)
        Return
    EndIf
    _UI_WindowHide($treeWin)
    DllCall("user32.dll", "long", "SetWindowLongW", "hwnd", $treeWin, "int", -8, "hwnd", $main)
    If _UI_WindowShow($treeWin) = 0 Then Return
    $treeVisible = True
    _UI_SetText($main, $bTree, "關閉階層")
    UpdateTreeViewport()
    RaiseOwned($treeWin)
EndFunc

; ----------------------------------------------------------------------------
; 隱藏「父子階層」視窗。
; ----------------------------------------------------------------------------
Func CloseHierarchy()
    If _UI_IsAlive($treeWin) Then _UI_WindowHide($treeWin)
    $treeVisible = False
    _UI_SetText($main, $bTree, "父子階層")
EndFunc

; ----------------------------------------------------------------------------
; 依 $children 的父子關係建立樹狀檢視。
; 父節點尚未建立的項目會在下一輪處理；找不到父節點的直接掛在根節點下。
; ----------------------------------------------------------------------------
Func BuildTree()
    $building = True
    _UI_TreeBeginUpdate($treeWin, $tree)
    _UI_TreeClear($treeWin, $tree)
    $rootNode = _UI_TreeAdd($treeWin, $tree, -1, ClassOf($root) & " · " & String($root))
    If $rootNode < 1 Then
        _UI_TreeEndUpdate($treeWin, $tree)
        $building = False
        Return
    EndIf
    ReDim $nodes[$childCount + 1]
    For $j = 0 To $childCount
        $nodes[$j] = -1
    Next
    $nodes[0] = $rootNode
    Local $index = ObjCreate("Scripting.Dictionary"), $doneNodes = 0, $progress = True
    For $j = 1 To $childCount
        $index.Item(String($children[$j][0])) = $j
    Next
    ; 反覆處理直到沒有進展：父節點已建立的子項才加入
    While $doneNodes < $childCount And $progress
        $progress = False
        For $j = 1 To $childCount
            If $nodes[$j] <> -1 Then ContinueLoop
            Local $parentNode = -1, $key = String($children[$j][1])
            If $children[$j][1] = $root Then
                $parentNode = $rootNode
            ElseIf $index.Exists($key) Then
                $parentNode = $nodes[$index.Item($key)]
            EndIf
            If $parentNode = -1 Then ContinueLoop
            $nodes[$j] = _UI_TreeAdd($treeWin, $tree, $parentNode, $children[$j][3] & " · " & String($children[$j][0]))
            $doneNodes += 1
            $progress = True
        Next
    WEnd
    For $j = 1 To $childCount
        If $nodes[$j] = -1 Then $nodes[$j] = _UI_TreeAdd($treeWin, $tree, $rootNode, $children[$j][3])
    Next
    _UI_TreeExpand($treeWin, $tree, $rootNode, True)
    _UI_TreeEndUpdate($treeWin, $tree)
    $building = False
    $treeLastVisible = -1
EndFunc

; ----------------------------------------------------------------------------
; 依目前展開的節點數調整樹狀檢視高度，讓捲動範圍正確。
; ----------------------------------------------------------------------------
Func UpdateTreeViewport()
    If Not $treeVisible Or $building Then Return
    Local $count = _UI_TreeGetVisibleCount($treeWin, $tree)
    If $count < 0 Or $count = $treeLastVisible Then Return
    $treeLastVisible = $count
    Local $height = $count * ($UI_FONT_SIZE + 18) + 12
    If $height < 454 Then $height = 454
    _UI_SetBounds($treeWin, $tree, 0, 0, 712, $height)
EndFunc

; ----------------------------------------------------------------------------
; 把視窗設為主視窗的附屬視窗並依置頂設定調整 Z 順序。
; ----------------------------------------------------------------------------
Func RaiseOwned($hw)
    ; GWLP_HWNDPARENT(-8)：設定擁有者視窗
    DllCall("user32.dll", "long", "SetWindowLongW", "hwnd", $hw, "int", -8, "hwnd", $main)
    WinSetOnTop($hw, "", Int($top))
    Local $after = 0
    If $top Then $after = -1
    DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $hw, "hwnd", $after, _
        "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x0053)
EndFunc

#EndRegion

#Region ;===== 藍色外框 =====

; ----------------------------------------------------------------------------
; 建立 4 個分層、不可點擊的置頂細長視窗，組成目標四周的藍色外框。
; ----------------------------------------------------------------------------
Func CreateFrames()
    Local $a = DllCall("kernel32.dll", "handle", "GetModuleHandleW", "ptr", 0)
    If @error Or Not IsArray($a) Then Return
    $instance = $a[0]
    ; 筆刷色為 BGR：0x00D77800 ＝ RGB(0, 120, 215)
    $a = DllCall("gdi32.dll", "handle", "CreateSolidBrush", "dword", 0x00D77800)
    If @error Or Not IsArray($a) Then Return
    $frameBrush = $a[0]
    $frameCB = DllCallbackRegister("FrameProc", "lresult", "hwnd;uint;wparam;lparam")
    If $frameCB = 0 Then Return
    Local $name = DllStructCreate("wchar[96]")
    DllStructSetData($name, 1, $frameClass)
    Local $wc = DllStructCreate("uint Size;uint Style;ptr Proc;int ClsExtra;int WndExtra;handle Instance;handle Icon;handle Cursor;handle Brush;ptr Menu;ptr Name;handle SmallIcon")
    DllStructSetData($wc, "Size", DllStructGetSize($wc))
    DllStructSetData($wc, "Proc", DllCallbackGetPtr($frameCB))
    DllStructSetData($wc, "Instance", $instance)
    DllStructSetData($wc, "Brush", $frameBrush)
    DllStructSetData($wc, "Name", DllStructGetPtr($name))
    $a = DllCall("user32.dll", "ushort", "RegisterClassExW", "ptr", DllStructGetPtr($wc))
    If @error Or Not IsArray($a) Then Return
    If $a[0] = 0 Then Return
    ; 擴充樣式：NOACTIVATE | LAYERED | TOOLWINDOW | TRANSPARENT | TOPMOST
    ; 樣式　　：WS_POPUP | WS_DISABLED
    For $j = 0 To 3
        $a = DllCall("user32.dll", "hwnd", "CreateWindowExW", "dword", 0x080800A8, "wstr", $frameClass, "wstr", "", _
            "dword", 0x88000000, "int", -10000, "int", -10000, "int", 1, "int", 1, "hwnd", 0, "handle", 0, "handle", $instance, "ptr", 0)
        If Not @error And IsArray($a) Then
            $frameHW[$j] = $a[0]
            DllCall("user32.dll", "bool", "SetLayeredWindowAttributes", "hwnd", $frameHW[$j], "dword", 0, "byte", 255, "dword", 2)
        EndIf
    Next
EndFunc

; ----------------------------------------------------------------------------
; 外框視窗的視窗程序：全部交給 DefWindowProcW。
; ----------------------------------------------------------------------------
Func FrameProc($hw, $msg, $wp, $lp)
    Local $a = DllCall("user32.dll", "lresult", "DefWindowProcW", "hwnd", $hw, "uint", $msg, "wparam", $wp, "lparam", $lp)
    If @error Or Not IsArray($a) Then Return 0
    Return $a[0]
EndFunc

; ----------------------------------------------------------------------------
; 在目標視窗四周顯示藍色外框；目標隱藏、最小化或位置沒變時不處理。
; ----------------------------------------------------------------------------
Func ShowFrame($hw)
    ; WinGetState 16＝最小化
    If Not $blueEnabled Or Not Alive($hw) Or BitAND(WinGetState($root), 16) Then
        HideFrame()
        Return
    EndIf
    Local $a = DllCall("user32.dll", "bool", "IsWindowVisible", "hwnd", $hw)
    If @error Or Not IsArray($a) Then Return
    Local $r = Rect($hw)
    If Not $a[0] Or $r[2] < 1 Or $r[3] < 1 Then
        HideFrame()
        Return
    EndIf
    Local $key = String($hw) & ":" & $r[0] & ":" & $r[1] & ":" & $r[2] & ":" & $r[3]
    If $frameShown And $key = $frameKey Then Return
    ; 上、下、左、右四條外框的 [x, y, 寬, 高]
    Local $t = $THICK, $p[4][4] = [[$r[0] - $t, $r[1] - $t, $r[2] + $t * 2, $t], _
        [$r[0] - $t, $r[1] + $r[3], $r[2] + $t * 2, $t], [$r[0] - $t, $r[1], $t, $r[3]], [$r[0] + $r[2], $r[1], $t, $r[3]]]
    For $j = 0 To 3
        If $frameHW[$j] = 0 Then ContinueLoop
        DllCall("user32.dll", "bool", "SetWindowPos", "hwnd", $frameHW[$j], "hwnd", -1, _
            "int", $p[$j][0], "int", $p[$j][1], "int", $p[$j][2], "int", $p[$j][3], "uint", 0x0050) ; SWP_NOACTIVATE | SWP_SHOWWINDOW
    Next
    $frameShown = True
    $frameKey = $key
EndFunc

; ----------------------------------------------------------------------------
; 隱藏藍色外框。
; ----------------------------------------------------------------------------
Func HideFrame()
    If Not $frameShown Then Return
    For $j = 0 To 3
        DllCall("user32.dll", "bool", "ShowWindow", "hwnd", $frameHW[$j], "int", 0)
    Next
    $frameShown = False
    $frameKey = ""
EndFunc

; ----------------------------------------------------------------------------
; 銷毀外框視窗並釋放視窗類別、回呼與筆刷。
; ----------------------------------------------------------------------------
Func DestroyFrames()
    For $j = 0 To 3
        If $frameHW[$j] <> 0 Then DllCall("user32.dll", "bool", "DestroyWindow", "hwnd", $frameHW[$j])
    Next
    DllCall("user32.dll", "bool", "UnregisterClassW", "wstr", $frameClass, "handle", $instance)
    If $frameCB <> 0 Then DllCallbackFree($frameCB)
    If $frameBrush <> 0 Then DllCall("gdi32.dll", "bool", "DeleteObject", "handle", $frameBrush)
EndFunc

#EndRegion

#Region ;===== 色彩取樣與 ARGB 解析 =====

; ----------------------------------------------------------------------------
; 讀取滑鼠位置的像素色彩，更新色碼、RGB 與色塊。
; ----------------------------------------------------------------------------
Func UpdateCurrentColor($x, $y)
    Local $color = PixelGetColor($x, $y), $errorCode = @error
    If $errorCode Then
        $sampleColor = -1
        $sampleHex = ""
        $sampleHex8 = ""
        $sampleRGB = ""
        SetText($sampleHexText, "[無法讀取]")
        SetText($sampleHex8Text, "")
        SetText($sampleRGBText, "")
        Put(20, "[無法讀取]")
        DrawSampleSwatch()
        Return
    EndIf
    $color = BitAND($color, 0x00FFFFFF)
    Local $changed = ($sampleColor <> $color)
    $sampleColor = $color
    $sampleHex = "0x" & Hex($color, 6)
    $sampleHex8 = "0x" & Hex($color, 8)
    Local $red = BitAND(BitShift($color, 16), 255), $green = BitAND(BitShift($color, 8), 255), $blue = BitAND($color, 255)
    $sampleRGB = "RGB(" & $red & ", " & $green & ", " & $blue & ")"
    SetText($sampleHexText, $sampleHex)
    SetText($sampleHex8Text, $sampleHex8)
    SetText($sampleRGBText, $sampleRGB)
    Put(20, $sampleHex)
    If $changed Then DrawSampleSwatch()
EndFunc

; ----------------------------------------------------------------------------
; 繪製目前像素色彩的色塊。
; ----------------------------------------------------------------------------
Func DrawSampleSwatch()
    If Not $uiReady Then Return
    Local $border = _UI_ThemeGetColor($main, "accent")
    If @error Or $border = 0 Then $border = 0xFF808080
    Local $fill = 0
    If $sampleColor >= 0 Then $fill = BitOR(0xFF000000, $sampleColor)
    _UI_CanvasBeginUpdate($main, $sampleSwatch)
    _UI_CanvasClear($main, $sampleSwatch, $fill)
    _UI_CanvasDrawRect($main, $sampleSwatch, 0.5, 0.5, 41, 27, $border, 1)
    _UI_CanvasEndUpdate($main, $sampleSwatch)
EndFunc

; ----------------------------------------------------------------------------
; 複製六位色碼（0xRRGGBB）。
; ----------------------------------------------------------------------------
Func CopySampleHex($id)
    If $sampleColor >= 0 Then CopyNotify($sampleHex)
EndFunc

; ----------------------------------------------------------------------------
; 複製八位色碼（0x00RRGGBB，00 為補位）。
; ----------------------------------------------------------------------------
Func CopySampleHex8($id)
    If $sampleColor >= 0 Then CopyNotify($sampleHex8)
EndFunc

; ----------------------------------------------------------------------------
; 複製 RGB(r, g, b) 格式。
; ----------------------------------------------------------------------------
Func CopySampleRGB($id)
    If $sampleColor >= 0 Then CopyNotify($sampleRGB)
EndFunc

; ----------------------------------------------------------------------------
; 解析輸入的 0xAARRGGBB 色碼，顯示 Alpha 值與不透明度百分比。
; ----------------------------------------------------------------------------
Func ParseARGB($id)
    Local $text = StringStripWS(_UI_GetText($main, $alphaInput), 3)
    If Not StringRegExp($text, "(?i)^0x[0-9a-f]{8}$") Then
        $parsedARGB = ""
        $alphaDescription = ""
        SetText($alphaText, "請輸入0xAARRGGBB")
        MakeReport()
        _UI_Notify($main, "ARGB格式錯誤", "請輸入0xAARRGGBB，例如0x80FFFFFF。", 0, 2500)
        Return
    EndIf
    $parsedARGB = "0x" & StringUpper(StringTrimLeft($text, 2))
    Local $alpha = Dec(StringMid($parsedARGB, 3, 2))
    $alphaDescription = "A=" & $alpha & " / 0x" & Hex($alpha, 2) & _
        "　不透明" & StringFormat("%.2f", $alpha * 100 / 255) & "%　透明" & StringFormat("%.2f", (255 - $alpha) * 100 / 255) & "%"
    _UI_SetText($main, $alphaInput, $parsedARGB)
    SetText($alphaText, $alphaDescription)
    _UI_TooltipSetText($main, $alphaText, "此數值來自ARGB輸入色碼，不是讀取螢幕得到的Alpha。" & @CRLF & $alphaDescription)
    MakeReport()
EndFunc

; ----------------------------------------------------------------------------
; 「帶入」按鈕：把目前像素的八位色碼帶入 ARGB 解析欄位。
; ----------------------------------------------------------------------------
Func LoadSampleARGB($id)
    If $sampleColor < 0 Then Return
    _UI_SetText($main, $alphaInput, $sampleHex8)
    ParseARGB(0)
    _UI_Notify($main, "已帶入色碼", "前導00是格式補位，並非螢幕像素的真實透明度。", 0, 2500)
EndFunc

; ----------------------------------------------------------------------------
; 點擊「ARGB 解析」標籤：複製解析後的色碼。
; ----------------------------------------------------------------------------
Func CopyParsedARGB($id)
    ParseARGB(0)
    If $parsedARGB <> "" Then CopyNotify($parsedARGB)
EndFunc

; ----------------------------------------------------------------------------
; 點擊解析結果：複製 Alpha 說明文字。
; ----------------------------------------------------------------------------
Func CopyAlphaDescription($id)
    If $alphaDescription <> "" Then CopyNotify($alphaDescription)
EndFunc

#EndRegion

#Region ;===== 複製到剪貼簿 =====

; ----------------------------------------------------------------------------
; 複製到剪貼簿並顯示「已複製！」通知。
; ----------------------------------------------------------------------------
Func CopyNotify($v)
    If ClipPut(String($v)) Then _UI_Notify($main, "已複製！", "", $AUI_NOTIFY_SUCCESS, 2000)
EndFunc

; ----------------------------------------------------------------------------
; 點擊欄位標籤：複製對應控制項的內容。
; ----------------------------------------------------------------------------
Func CopyValue($id)
    For $j = 1 To $mapCount
        If $map[$j][0] = $id Then
            CopyNotify(_UI_GetText($main, $map[$j][1]))
            Return
        EndIf
    Next
EndFunc

; ----------------------------------------------------------------------------
; 點擊數值文字：複製該欄位的值。
; ----------------------------------------------------------------------------
Func CopyField($id)
    For $j = 0 To 26
        If $fields[$j] = $id Then
            CopyNotify($values[$j])
            Return
        EndIf
    Next
EndFunc

#EndRegion
