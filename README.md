# Au3Info+

**視窗資訊工具**：AutoIt Window Info（Au3Info）的 AUI 重製版。拖曳準星到任何視窗，即可取得類別、ClassNN、HWND、Style、座標、像素色彩等資訊，點一下就能複製。

![AutoIt](https://img.shields.io/badge/AutoIt-3.3.16%2B%20(x86)-blue) ![Platform](https://img.shields.io/badge/platform-Windows-lightgrey) ![License](https://img.shields.io/badge/license-Unlicense-green)

---

## 功能

| 功能 | 說明 |
|---|---|
| **拖曳準星選取** | 把左上角準星拖到目標上放開即選取，Esc 取消；選取後目標四周會閃示藍框 |
| **即時偵測** | 「開始偵測」或 <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F</kbd>，資訊跟著滑鼠即時更新 |
| **27 項資訊** | 視窗／控制項類別、ClassNN、HWND、Style／ExStyle、ID、程序、位置、大小、DPI… |
| **一鍵複製** | 點欄位名稱或數值即複製；「複製全部」輸出完整文字報告 |
| **子控制項清單** | 列舉頂層視窗的所有子控制項（最多 20000 個），分頁瀏覽、直接切換目標 |
| **父子階層** | 以樹狀檢視顯示控制項的父子結構，點選節點即選取 |
| **座標模式** | 滑鼠座標可切換為相對於螢幕／視窗／用戶端區域 |
| **像素色彩** | 顯示滑鼠位置的 0xRRGGBB、0x00RRGGBB 與 RGB()，附色塊 |
| **ARGB 解析** | 輸入 0xAARRGGBB 色碼，計算 Alpha 與不透明度百分比 |
| **外觀** | 跟隨系統／淺色／深色主題，字級 14～20，可展開或收合資訊面板 |
| **置頂** | 預設置頂，<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd> 切換 |

## 系統需求

- Windows 10／11
- [AutoIt](https://www.autoitscript.com/site/autoit/downloads/) 3.3.16.1 以上，**必須使用 32 位元**（以 64 位元執行會顯示錯誤並結束）

## 快速開始

### 直接使用

到 [Releases](https://github.com/Hiura-Souji/Au3Info/releases) 下載編譯好的 `Au3Info.exe` 執行即可。程式會請求管理員權限，才能讀取以管理員身分執行的視窗與程序路徑。

### 從原始碼執行

```
git clone https://github.com/Hiura-Souji/Au3Info.git
cd Au3Info
"C:\Program Files (x86)\AutoIt3\AutoIt3.exe" Au3Info.au3
```

或在 SciTE 開啟 `Au3Info.au3` 後按 <kbd>F5</kbd>（請確認 SciTE 使用 32 位元 AutoIt）。

### 編譯

在 SciTE 按 <kbd>F7</kbd>。檔頭的 `#AutoIt3Wrapper_*` 指令已設定 32 位元輸出、圖示與版本資訊。

### 選用檔案

放在程式同一個資料夾即可，沒有也能正常執行：

| 檔案 | 用途 | 不存在時 |
|---|---|---|
| `info.ico` | 視窗與執行檔圖示 | 使用預設圖示 |
| `finder.cur` | 拖曳準星時的游標 | 使用系統十字游標 |

## 使用說明

### 選取目標

1. 按住左上角的 **準星**，拖到要查看的視窗或控制項上。
2. 放開滑鼠即選取，目標四周會閃示藍框 1.5 秒；按 <kbd>Esc</kbd> 取消。
3. 選取後會自動鎖定（停止偵測），資訊不會再跟著滑鼠變動。

也可以按「開始偵測」，讓資訊即時跟著滑鼠更新，再按一次停止。

### 資訊欄位

預設為**收合**模式，只顯示「控制項類別」「ClassNN」「滑鼠目前座標」三欄；按「▼ 展開資訊」顯示全部欄位與執行檔路徑。

| 分類 | 欄位 |
|---|---|
| 識別 | 視窗類別、控制項類別、ClassNN、視窗 HWND、控制項 HWND、父視窗 HWND、父視窗類別、控制項 ID、程序 ID |
| 樣式 | 視窗 Style、控制項 Style、視窗 ExStyle、控制項 ExStyle、控制項狀態（Visible／Enabled） |
| 座標與尺寸 | 視窗位置、控制項螢幕座標、控制項用戶端座標、視窗大小、控制項大小、用戶端大小、滑鼠目前座標、滑鼠螢幕座標 |
| 其他 | 像素色彩、標題列估算高度、邊框寬／高、子控制項數量、目標 DPI |

另有「視窗標題」「控制項文字」「執行檔路徑」三個文字欄。

> ClassNN 的計算方式與 AutoIt Window Info 相同：類別名稱＋該類別在視窗中出現的序號，例如 `Button2`。可直接用在 `ControlClick()` 等函式。

### 複製

- **點欄位名稱或數值**：複製該欄位
- **複製全部**：複製完整報告，最後附上 `[HANDLE:0x...]` 視窗選取字串，可直接用於 `WinGetTitle()` 等函式
- **色彩**：點色碼、八位色碼或 RGB 文字分別複製

### 子控制項與父子階層

- 子控制項下拉選單每頁 8 個（第 0 項固定為頂層視窗），用 ◀ ▶ 或輸入頁碼跳頁
- 「重新列舉」：目標視窗的控制項有變動時重新掃描
- 「父子階層」：開啟樹狀檢視，點選任一節點即切換目標

### ARGB 解析

在「ARGB 解析」欄輸入 `0xAARRGGBB`（例如 `0x80FFFFFF`）後按「解析」，會顯示 Alpha 值與不透明／透明百分比。「帶入」會填入目前像素的 `0x00RRGGBB`。

> 螢幕像素本身沒有 Alpha 資訊，帶入時的 `00` 只是格式補位，並非量測到的透明度。

## 專案結構

```
Au3Info/
├─ Au3Info.au3   主程式
├─ AUI.au3       AUI 介面程式庫（第三方）
├─ info.ico      圖示
├─ finder.cur    拖曳游標（選用）
├─ README.md
└─ LICENSE
```

### 程式架構

`Au3Info.au3` 以 `#Region` 依功能分區，每個函式前都有中文說明：

| 區段 | 內容 |
|---|---|
| 常數與全域變數 | 外觀、上限、27 個欄位名稱、各控制項與執行狀態 |
| 程式進入點 | 檢查 32 位元、初始化 AUI、建立視窗、進入主迴圈、結束清理 |
| 建立視窗與控制項 | `BuildMainWindow()`、`BuildTreeWindow()`、`InitWin32()` |
| 主迴圈 | `MainLoop()` 手動驅動 AUI 訊息並處理拖曳、偵測與定時更新 |
| 介面事件 | 按鈕、下拉選單、主題、字級、熱鍵 |
| 版面與繪圖 | `Layout()` 依字級與收合狀態排版；準星、格線、圖示繪製 |
| 拖曳準星與游標 | 主視窗子類別化（`CursorProc`）、滑鼠捕捉與游標 |
| 視窗偵測與資訊 | `Probe()` → `FastData()`（即時）→ `Details()`（完整） |
| Win32 輔助函式 | 類別、文字、Style、矩形、程序路徑等 API 包裝 |
| 子控制項列舉與分頁 | `EnumChildWindows`、ClassNN 計算、分頁下拉選單 |
| 父子階層視窗 | 依父子關係建立樹狀檢視 |
| 藍色外框 | 4 個分層、不可點擊的置頂視窗組成外框 |
| 色彩取樣與 ARGB 解析 | 像素色彩、色塊、ARGB 計算 |

**主迴圈時序**

```
每圈（約 8 ms）
 ├─ _UI_PumpOnce()            處理 AUI 訊息
 ├─ 拖曳中？ Esc 取消／放開選取
 ├─ 每 40 ms   Probe()        偵測滑鼠下的視窗、更新座標與色彩、顯示藍框
 ├─ 延後動作                   換頁、重新列舉、開啟階層、選取目標
 ├─ 每 350 ms  Details()      更新標題、文字、Style、路徑等完整資訊
 └─ 每 120 ms                 調整樹狀檢視高度
```

耗時的動作（列舉、建樹、換頁）不在 AUI 事件回呼中直接執行，而是設定旗標交給主迴圈，避免回呼重入造成介面卡住。

## 第三方元件

| 檔案 | 說明 |
|---|---|
| `AUI.au3` | AUI（AutoIt 使用者介面程式庫）0.9.5 測試版，授權依原作者規定 |

## 授權

本程式（`Au3Info.au3`）以 [Unlicense](LICENSE) 釋出於公眾領域，可自由使用、修改與散布。第三方元件依各自的授權條款。

---

**格雷資訊** · [grayfree.tw](https://www.grayfree.tw/) · GitHub [@Hiura-Souji](https://github.com/Hiura-Souji)
