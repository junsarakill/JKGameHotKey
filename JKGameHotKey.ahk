#Requires AutoHotkey v2.0

; 클래스 선언

; csv 구조체
class CSVRow
{
    __New(headerAry, rowData)
    {
        for key, value in headerAry
        {
            this[value] := rowData[key]
        }
    }
}

; 가상키 데이터
class KeyData
{
    name := ""
    pos := Vector2d()
    type := ""
    description := ""

    __New(name, x, y, type, desc)
    {
        this.name := name
        this.pos := Vector2d(x,y)
        this.type := type
        this.description := desc
    }
}

class HotKeyInfo
{
    hotKeyMap := Map()

    overlayMap := Map()

    ; 핫키 초기화
    ClearHotKey()
    {

    }

    ; 핫키 맵 추가
    AddHotKeyMap(&keyData)
    {
        this.hotKeyMap.Set(keyData["name"], keyData)
    }
}

class Vector2d {
    x := 0
    y := 0

    ; 생성자
    __New(x := 0, y := 0) {
        this.x := x
        this.y := y
    }

    IsEqual(&other)
    {
        return this.x == other.x 
            && this.y == other.y
    }
}

; 좌표, gui 
class OverlayInfo
{
    pos := Vector2d()
    aGUI := Gui()
    text := "?"
    isVisible := false

    ; 생성자
    __New(x := 0, y := 0, text := "?") {
        this.pos := Vector2d(x,y)
        this.text := text
    }

    SetActive(value := true, option := "")
    {
        if(value)
            this.aGUI.Show(option)
        else
            this.aGUI.Hide()

        isVisible := value
    }
}

; 가상키 영역
/* 스크립트 진행 구조
1. 게임명 : 파일명 시트 정보 가져오기 | LoadSheetData => sheetNameMap
2. 포커스 체크 딜리게이트 등록 | BindFocusChange -> ShellHook
-> 포커스 체크 | CheckFocus
-> 현재 매핑 게임명과 같은지 검사
-> 다르면 키매핑 제거 | RemoveHotKey
-> 다르면 시트에 해당 게임명 있는지 검사 | FindGameName
-> 있으면 해당 게임 키매핑 생성 | CreateHotKey


-> 없으면 전체 프로세스에 목표 게임 존재 체크
-> 없으면 스크립트 종료
*/


; 게임명 : 파일명 시트 경로
sheetFolder := A_ScriptDir . "\KeyData\"
keySheetName := "JK_AHK_SheetNameKey.csv"

; 게임명 : 파일명 정보 구조체 | 배열 { 맵[헤더] : 값 }
sheetNameTable := LoadSheetData(sheetFolder . keySheetName)

; 현재 목표 게임명
curTargetTitle := ""

; 가상키 데이터 배열
hkInfo := HotKeyInfo()

; 프로그램 실행 단
BeginPlay()

BeginPlay()
{
    ; 포커스 체크 딜리게이트 등록
    BindFocusChange()
}

BindFocusChange()
{
    ; 스크립트 핸들을 등록합니다.
    DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd) 

    ; SHELLHOOK 메시지를 수신합니다.
    OnMessage(DllCall("RegisterWindowMessage", "str", "SHELLHOOK"), ShellHook) 
}

; 포커스 변경됨
ShellHook(wParam, lParam, *) 
{
    ; HSHELL_RUDEAPPACTIVATED || HSHELL_WINDOWACTIVATED
    if (wParam = 0x8004 || wParam = 4) 
    { 
        ; lParam이 0이면 현재 활성 창의 핸들을 가져옵니다.
        hwnd := lParam || WinExist("A") 

        curTitle := WinGetTitle(hwnd)
        ToolTip curTitle
        ; 프로그램 체크
        CheckFocus(&curTitle)
    }
}

; 타겟 프로그램 포커스 확인
CheckFocus(&curTitle) 
{
    global curTargetTitle
    global hkInfo

    ; 현재 목표 게임인지 체크
    if(curTargetTitle = curTitle)
        return

    ; @@ 변경되었으니 키 매핑 제거
    RemoveHotKey()
    ; 시트에 있는 게임인지 체크
    if(FindGameName(&curTitle))
    {
        ToolTip("시트에 있음 키매핑 생성: " curTitle)
        
        curTargetTitle := curTitle

        ; 키 매핑 시트 데이터 가져오기
        keyData := LoadKeyData(&curTitle)


        ; 가상키 생성
        CreateHotKey(&curTitle, &keyData, &hkInfo)

        processHandle := WinActive(curTitle)
        ; 오버레이 생성
        CreateOverlay(&processHandle, &keyData, &hkInfo)
    }
    else
    {
        ; 전체 프로세스에 시트 게임이 하나도 없는지 체크

        ; 없으면 스크립트 종료
    }

    ; global canInput
    ; global infoMap
    ; global processHandle
    ; ; 찾을 프로그램 이름
    ; processHandle := WinActive(gameName)
    ; canInput := processHandle ? true : false
    ; ; ToolTip "" (canInput ? "it" : "if")

    ; ; 입력 가능     
    ; if(canInput)
    ; {
    ;     ; 오버레이 활성화
    ;     ActiveOverlay(&processHandle)
    ; }
    ; else
    ; {
    ;     for oneInfo in infoMap
    ;     {
    ;         oneInfo.SetActive(false)
    ;     }
    ; }


    ; ; 프로그램 없으면 종료
    ; if(waitStart and !ProcessExist(processName))
    ; {
    ;     ToolTip processName "이 종료됨. 핫 키 종료"
    ;     Sleep 1000
    ;     ExitApp
    ; }
}


; 시트 데이터 구조체로 변환하기
LoadSheetData(csvFilePath)
{
    ; csv 데이터
    csvData := FileRead(csvFilePath)
    
    ; 행 분리
    rows := StrSplit(csvData, "`r`n")

    ; 헤더 가져오기
    headers := StrSplit(rows[1], ",")

    ; 시트 구분해서 구조체에 저장
    data := []
    
    for i, row in rows {
        if(i = 1)
            continue

        rowData := StrSplit(row, ",")
        ; 행 데이터 구조체화
        field := Map()
        
        ; FIXME 인코딩 문제
        ; MsgBox(headers.Length " " rowData.Length " " rowData[1])
        ; if(Trim(rowData[1]) = "K 기록소")
        ; {
        ;     MsgBox("Asd")
        ; }
        for index, header in headers
        {
            field[header] := rowData[index]
        }

        data.Push(field)
    }

    return data
}

; 해당 게임명에 대한 가상키 데이터 불러오기
LoadKeyData(&gameName)
{
    global sheetNameTable
    resultKeyDataTable := []
    sheetName := ""
    ; 해당 게임명 시트에 존재 확인
    for row in sheetNameTable
    {
        ; 존재하면 시트명 가져오기
        if(row["gameName"] = gameName)
        {
            sheetName := row["sheetName"]
            break
        }
    }

    if(sheetName = "")
        return resultKeyDataTable

    ; 파일 경로 설정
    sheetPath := sheetFolder . sheetName
    ; 해당 시트 데이터 불러오기
    sheetData := LoadSheetData(sheetPath)

    return sheetData
}

FindGameName(&gameName)
{
    global sheetNameTable
    
    ; 시트 이름 테이블에서 찾아보기
    for i, row in sheetNameTable
    {
        if(row["gameName"] = gameName)
            return true
    }

    return false
}

; keyData => 
CreateHotKey(&curTitle, &keyData, &curHKInfo)
{
    for keyInfo in keyData
    {
        ; 타입 체크
        if(keyInfo["type"] = "KEY")
        {
            ; 핫 키 생성
            Hotkey("$" keyInfo["name"], ClickPos)
            Hotkey("$" keyInfo["name"] " up", ReleaseBtn)
            ; 키 맵에 추가
            curHKInfo.AddHotKeyMap(&keyInfo)
        }
    }
}

CreateOverlay(&processHandle, &keyData, &curHKInfo)
{
    ; 창 위치 가져오기
    pos := WinGetClientPos(&outX, &outY, &outWidth, &outHeight, "ahk_id " processHandle)

    curClientPos := Vector2d(outX, outY)

    ; 정보 배열 초기화
    curHKInfo.ClearHotKey()

    ; 새 오버레이 생성
    for keyInfo in keyData
    {
        ToolTip("d: " keyInfo["name"])
        newOverlay := OverlayInfo()
        ; GUI 생성 | 포커스 비활성화
        newOverlay.aGUI := Gui("LastFound -Caption AlwaysOnTop", "ToolWindow -Border *E0x20")
        newOverlay.aGUI.Color := "dfdfdf"
        newOverlay.aGUI.Add("Text", "x3 y2 " , keyInfo["name"])

        ; 클라 위치에 맞추어 보정
        cx := curClientPos.x + keyInfo["x"]
        cy := curClientPos.y + keyInfo["y"]

        weight := 4 + StrLen(keyInfo["name"]) * 8
        
        ; 오버레이 위치 업데이트
        newOverlay.SetActive(true, "NoActivate w" weight " h15 x" cx " y" cy)
    
        oh := newOverlay.aGUI.Hwnd
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", oh, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)
    }
}


RemoveHotKey()
{

}





; 시작 실행 딜레이
waitStart := false

; 입력 가능 여부
canInput := false

; 창 이름
gameName := "EXILIUM"
; 프로그램 이름
processName := "GF2_Exilium.exe"
; 프로세스 핸들
processHandle := 0

; 키 맵
keyMap := {
    Tab : [100, 35]
    ,z : [862,569]
    ,x : [567, 569]
    ,t : [1303,115]
    ,r : [1234,704]
    ,Capslock : [1212,43]
}

; 오버레이 정보 배열               
infoMap := [
    ; 특수 리스트
    OverlayInfo(0,185,"O 공지")
    ,OverlayInfo(0,200,"D 한정")
    ,OverlayInfo(0,215,"J 출석")
    ,OverlayInfo(0,230,"K 기록소")
    ,OverlayInfo(0,245,"B 창고")
    ,OverlayInfo(0,260,"M 메일")
    ; 메인화면
    ,OverlayInfo(96,628,"Q")
    ,OverlayInfo(1304,473,"E")
    ,OverlayInfo(95,693, "I")
    ,OverlayInfo(1010,720,"F")
    ,OverlayInfo(1306,400,"G")
    ,OverlayInfo(1300,333,"L")
    ,OverlayInfo(1304,264,"C")
    ,OverlayInfo(930,719,"V")
    ,OverlayInfo(1081,720, "U")
    ; 전투 화면
    ,OverlayInfo(1213,46,"O")
    ,OverlayInfo(1338,47,"T")
    ,OverlayInfo(48,623,"C")
    ,OverlayInfo(1154,43,"R")
]

; 키 맵에 있는 거 오버레이 배열에 추가
for key, value in keyMap.OwnProps()
{
    if(key == "Capslock")
    {
        infoMap.Push(OverlayInfo(value[1], value[2], "cl"))    
        continue
    }
    
    infoMap.Push(OverlayInfo(value[1], value[2], key))
}


; 키 동적 핫 키 생성 | press, release
for key, value in keyMap.OwnProps() {
    Hotkey("$" key, ClickPos)         
    Hotkey("$" key " up", ReleaseBtn)                         
}

SetTimer WaitStartProgram, 5000

; 최초 프로그램 시작 대기
WaitStartProgram()
{
    global waitStart
    waitStart := true
}



; 입력 영역

; 종료
] & Esc::ExitApp

[ & Esc::WaitStartProgram                   

; 해당 키 좌표 가져오기
GetKeyPos(&valueAry, key)
{
    ; $ 잘라내기
    key := StrReplace(key, "$")
    key := StrReplace(key, " up")    
    
    if(!canInput or !hkInfo.hotKeyMap.HasOwnProp(key))
    {   
        if(!GetKeyState(key, "P"))
            return false

        ToolTip(key)
        if(GetKeyState("Alt", "P"))
            return false
        SendInput("{" key "}")
        Sleep(100)
        return false
    }

    ; 해당 키 좌표 가져오기
    valueAry := hkInfo.hotKeyMap.GetOwnPropDesc(key).Value

    if(valueAry.Length < 2)
        return false

    return true
}

; 클릭 : 입력 가능 시만
ClickPos(hotKey)
{
    ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
    if(!GetKeyPos(&valueAry, hotKey))
        return

    ; 해당 좌표 클릭
    MouseClick('L',valueAry[1],valueAry[2], 1,2,'D')
    return
}

ReleaseBtn(hotKey)
{   
    ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
    if(!GetKeyPos(&valueAry, hotKey))
        return

    ; 클릭 해제
    MouseClick('L',valueAry[1],valueAry[2], 1,2,'U')
    return                          
}

enableOverlay := true

` up:: {
    ; flip
    global enableOverlay
    global infoMap
    enableOverlay := !enableOverlay

    for oneInfo in infoMap
    {
        oneInfo.SetActive(enableOverlay)
    }

    WinActivate(processHandle)
}

; 오버레이 기능 영역

; 이전 위치
prevClientPos := Vector2d(-1, -1)
isInit := true

; 오버레이 활성화 및 갱신
ActiveOverlay(&processHandle)
{
    global prevClientPos
    global isInit
    global infoMap
    global enableOverlay

    pos := WinGetClientPos(&outX, &outY, &outWidth, &outHeight, "ahk_id " processHandle)

    curClientPos := Vector2d(outX, outY)

    ; 직전과 같은 위치면 업데이트 안함 and 보이는 상태
    if(prevClientPos.IsEqual(&curClientPos)
        and infoMap[1].isVisible
        or !enableOverlay)
        return
    
    ; 활성화 or 업데이트
    prevClientPos := curClientPos

    if(isInit)
    {
        isInit := false
        
        ; 정보 배열 초기화
        for oneInfo in infoMap
        {
            oneInfo.aGUI := Gui("LastFound -Caption AlwaysOnTop", "ToolWindow -Border *E0x20")
            oneInfo.aGUI.Color := "dfdfdf"
            oneInfo.aGUI.Add("Text", "x3 y2 " , oneInfo.text)
        }
    }

    for oneInfo in infoMap
    {
        ; 클라 위치에 맞추어 보정
        cx := curClientPos.x + oneInfo.pos.x
        cy := curClientPos.y + oneInfo.pos.y

        weight := 4 + StrLen(oneInfo.text) * 8
        
        ; 오버레이 위치 업데이트
        oneInfo.SetActive(true, "NoActivate w" weight " h15 x" cx " y" cy)
    
        oh := oneInfo.aGUI.Hwnd
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", oh, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)
    }
}
