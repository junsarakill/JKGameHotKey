#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\jsongo_AHKv2-main/src/jsongo.v2.ahk
#Include Utility.ahk

; 클래스 선언

; 가상키 데이터
class KeyData
{
    name := ""
    pos := Vector2d()
    type := ""
    description := ""

    __New(sheetDataMap)
    {
        this.name := sheetDataMap["name"]
        this.pos := Vector2d(sheetDataMap["x"], sheetDataMap["y"])
        this.type := sheetDataMap["type"]
        this.description := sheetDataMap["description"]
    }

    ToString()
    {
        return Format("name : {1}, pos : {2}, type : {3}, desc : {4}"
        , this.name, this.pos.ToString(), this.type, this.description)
    }
}

class HotKeyInfo
{
    ; 키 데이터 맵 | key, keyInfo
    hotKeyMap := Map()
    ; 오버레이 맵 | gui Hwnd, overlayInfo
    overlayMap := Map()

    ; 핫키 초기화
    ClearHotKey()
    {
        ; 핫키 제거
        for key, keyData in this.hotKeyMap
        {
            ; 타입 체크
            if(keyData.type = "KEY")
            {                               
                Hotkey("$" keyData.name, "Off") ; 핫키 비활성화
                Hotkey("$" keyData.name " up", "Off") ; 핫키 비활성화
                Hotkey("$" keyData.name, "") ; 핫키를 빈 문자열로 설정하여 제거
                Hotkey("$" keyData.name " up", "") ; 핫키를 빈 문자열로 설정하여 제거       
            }
        }                                   

        ; 오버레이 제거
        for hwnd, info in this.overlayMap
        {
            info.Destroy()
        }

        this.hotKeyMap := Map()
        this.overlayMap := Map()    
    }

    ; 오버레이 초기화
    ClearOverlay()
    {
        for key, value in this.overlayMap
        {
            value.Destroy()
        }

        this.overlayMap := Map()
    }
}

; 좌표, gui 
class OverlayInfo
{
    pos := Vector2d()
    aGUI := Gui()
    text := "?"
    isVisible := false

    prevOption := ""

    ; 생성자
    __New(x := 0, y := 0, text := "?") {
        this.pos := Vector2d(x,y)
        this.text := text
    }

    SetActive(value := true, option := "")
    {
        if(value)
        {
            ; 옵션 없으면 이전 옵션 재적용
            if(option = "")
                option := this.prevOption

            if(this.prevOption != option)
                this.prevOption := option
            
            this.aGUI.Show(option)
        }
        else
            this.aGUI.Hide()

        isVisible := value

        
    }

    ; 오버레이 제거
    Destroy() {
        this.aGUI.Destroy() ; GUI 닫기
    }

    ; 소멸자
    __Delete() {
        this.Destroy() ; 오버레이 제거 메서드 호출
    }
}

; 설정 구조체
class SettingData
{
    enableOverlay := true

    ToMap()
    {
        map := {
            enableOverlay : this.enableOverlay
        }
        
        return map
    }
}

; 전역 함수 단

; map 데이터 => 클래스 로 변경
MapToClass(&mapData, classType) 
{
    local newClassIns := classType() ; 클래스 인스턴스 생성

    for key, value in mapData {
        if (newClassIns.HasOwnProp(key)) {
            newClassIns.%key% := value ; Map의 값을 클래스 속성으로 설정
        }
    }

    return newClassIns
}

/* 스크립트 진행 구조
1. 게임명 : 파일명 시트 정보 가져오기 | LoadSheetData => sheetNameMap
2. 포커스 체크 딜리게이트 등록 | BindFocusChange -> ShellHook
-> 포커스 체크 | CheckFocus
-> 현재 매핑 게임명과 같은지 검사
-> 다르면 키매핑 제거 | RemoveHotKey
-> 다르면 시트에 해당 게임명 있는지 검사 | FindGameName

있으면 키매핑 데이터 불러오기 | LoadKeyData
-> 해당 게임 키매핑 생성 | CreateHotKey

없으면 전체 프로세스에 목표 게임 존재 체크
-> 없으면 스크립트 종료

3. 가상키 누르기 | ClickPos
-> 해당 키 좌표 가져오기 | GetKeyPos
-> 해당 좌표 클릭 | MouseClick
-> 가상키 떼기 | ReleaseBtn
-> 이하 같음

*/

; 전역 변수 영역

; 설정 json 파일 
settingPath := A_ScriptDir . "\Setting.ini"
; 설정 데이터
settings := LoadSetting(&settingPath)

; 기본 가상키 데이터
defaultKeySheetName := "JK_DefaultKeyData.csv"
defaultKeySheetPath := sheetFolder . defaultKeySheetName

; 게임명 : 파일명 시트 경로
keySheetName := "JK_AHK_SheetNameKey.csv"
keySheetPath := sheetFolder . keySheetName

; 게임명 : 파일명 정보 구조체 | 배열 { 맵[헤더] : 값 }
sheetNameTable := LoadSheetData(keySheetPath)

; 현재 목표 게임명
curTargetTitle := ""

; 가상키 데이터 맵
hkInfo := HotKeyInfo()

; 시작 대기 여부
checkStart := false

; 오버레이 투명도 | 0~255
overlayOpacity := 100

; 핫키 활성 여부
isActive := false

; 세팅 불러오기
LoadSetting(&path)
{
    jsonData := FileRead(path, "UTF-8")
    ; json map 변환 => 구조체로 변환
    mapData := jsongo._Parse(jsonData)
    return MapToClass(&mapData, SettingData)
}

; 세팅 저장하기
SaveSetting(&settingData, &path) {
    jsonString := jsongo.Stringify(settingData) ; JSON 문자열로 변환

    ; 파일을 쓰기 모드로 열기
    file := FileOpen(path, "w") ; "w" 모드는 덮어쓰기 모드
    if !file 
    {
        MsgBox("파일을 열 수 없습니다: " path)
        return
    }

    file.Write(jsonString) ; JSON 문자열 쓰기
    file.Close() ; 파일 닫기
}

; ========프로그램 실행 영역
BeginPlay()

BeginPlay()
{
    ; 최초 프로그램 시작 대기
    SetTimer WaitStartProgram, 5000

    ; 포커스 체크 딜리게이트 등록
    BindFocusChange()
}

; 최초 프로그램 시작 대기
WaitStartProgram()
{
    global checkStart
    checkStart := true
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

        if(!hwnd) 
            return

        curTitle := WinGetTitle(hwnd)
        ; ToolTip curTitle
        ; 프로그램 체크
        CheckFocus(&curTitle)
    }
}

; 타겟 프로그램 포커스 확인
CheckFocus(&curTitle) 
{
    global sheetNameTable
    global curTargetTitle
    global hkInfo
    global isActive

    ; 현재 목표 게임인지 체크
    if(curTargetTitle = curTitle)
        return

    curTargetTitle := curTitle

    ; 변경되었으니 키 매핑 제거
    RemoveHotKey()
    ; 시트에 있는 게임인지 체크
    isActive := FindGameName(&curTitle)
    if(isActive)
    {
        ; ToolTip("시트에 있음 키매핑 생성: " curTitle)

        processHandle := WinActive(curTitle)
        ; 키 매핑 시트 데이터 가져오기
        hkInfo.hotKeyMap := LoadKeyData(&curTitle)

        ; 가상키 생성
        CreateHotKey(&curTitle, &hkInfo)
        
        ; 오버레이 생성
        CreateOverlay(&processHandle, &hkInfo)
    }
    else if(checkStart)
    {
        ; ToolTip("dow" curTitle)
        
        ; 전체 프로세스에 시트 게임이 하나도 없는지 체크
        isEnd := true
        for row in sheetNameTable
        {
            if(WinExist(row["gameName"]))
            {
                isEnd := false
                break
            }
        }
        
        ; 없으면 스크립트 종료
        if(isEnd)
        {
            ToolTip "목표 게임 없음. 핫 키 종료"
            Sleep 1000
            CloseScript
        }
    }
}

; 해당 게임명에 대한 가상키 데이터 불러오기 + 기본 키 데이터
LoadKeyData(&gameName)
{
    global sheetNameTable
    
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
    ; 비 존재시 함수 종료
    if(sheetName = "")
        return Map()

    ; 파일 경로 설정
    gameSheetPath := sheetFolder . sheetName
    ; 해당 시트 데이터 불러오기
    gameKeyData := LoadSheetData(gameSheetPath)

    ; 기본 키 데이터 불러오기
    defaultKeyData := LoadSheetData(defaultKeySheetPath)

    ; 결합
    fullKeyData := []
    fullKeyData.Push(gameKeyData*)
    fullKeyData.Push(defaultKeyData*)

    ; 반환 값 선언
    keyDataMap := Map()
    ; 가상키 데이터 클래스로 변환
    for oneData in fullKeyData
    {
        keyDataMap[oneData["name"]] := KeyData(oneData)
    }

    ; 가상키 데이터 맵 반환
    return keyDataMap
}

FindGameName(&gameName)
{
    global sheetNameTable
    
    ; 시트 이름 테이블에서 찾아보기
    for row in sheetNameTable
    {
        if(row["gameName"] = gameName)
            return true
    }

    return false
}

CreateHotKey(&curTitle, &curHKInfo)
{
    for key, keyData in curHKInfo.hotKeyMap
    {
        ; 타입 체크
        if(keyData.type = "KEY")
        {
            ; 핫 키 생성
            Hotkey("$" keyData.name, ClickPos)
            Hotkey("$" keyData.name " up", ReleaseBtn)
            Hotkey("$" keyData.name, "On") ; 핫키 활성화
            Hotkey("$" keyData.name " up", "On") ; 핫키 활성화
        }
    }
}

CreateOverlay(&processHandle, &curHKInfo)
{
    if(!processHandle || processHandle = 0)
        return
    ; 창 위치 가져오기
    pos := WinGetClientPos(&outX, &outY, &outWidth, &outHeight, "ahk_id " processHandle)

    curClientPos := Vector2d(outX, outY)

    ; 새 오버레이 생성
    for key, keyData in curHKInfo.hotKeyMap
    {
        newOverlay := OverlayInfo()
        ; GUI 생성 | 포커스 비활성화
        newOverlay.aGUI := Gui("LastFound -Caption AlwaysOnTop +ToolWindow -Border")

        newOverlay.aGUI.Color := "dfdfdf"
        newOverlay.aGUI.Add("Text", "x3 y2 " , keyData.name)
        ; 투명도 0~255
        WinSetTransparent(overlayOpacity, newOverlay.aGUI.hwnd)

        ; 클라 위치에 맞추어 보정
        cx := curClientPos.x + keyData.pos.x
        cy := curClientPos.y + keyData.pos.y

        weight := 4 + StrLen(keyData.name) * 8
    
        oh := newOverlay.aGUI.Hwnd
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", oh, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)

        ; 오버레이 위치 업데이트
        option := "NoActivate w" weight " h15 x" cx " y" cy
        ; 설정에 따라 오버레이 활성화
        newOverlay.SetActive(settings.enableOverlay, option)
        
        ; 오버레이 맵에 추가
        curHKInfo.overlayMap[newOverlay.aGUI.Hwnd] := newOverlay
    }
}

RemoveHotKey()
{
    global hkInfo

    hkInfo.ClearHotKey()
}

; ===========입력 영역

; XXX 디버그용 즉시 체크 시작
[ & Esc::WaitStartProgram                   

; 종료 키
] & Esc::CloseScript

; 해당 키 좌표 가져오기
GetKeyPos(&pos2D, key)
{
    ; $ 잘라내기
    key := StrReplace(key, "$")
    key := StrReplace(key, " up")

    global hkInfo

    ; 핫 키 인지 확인
    if(!hkInfo.hotKeyMap.Has(key))
        return false

    if(hkInfo.hotKeyMap[key].type != "KEY")
        return false

    ; 해당 키 좌표 가져오기
    pos2D := hkInfo.hotKeyMap[key].pos

    return true
}

; 클릭 : 입력 가능 시만
ClickPos(hotKey)
{
    ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
    if(!GetKeyPos(&pos2D, hotKey))
        return

    ; 해당 좌표 클릭
    MouseClick('L',pos2D.x,pos2D.y, 1,2,'D')
    return
}

ReleaseBtn(hotKey)
{   
    ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
    if(!GetKeyPos(&pos2D, hotKey))
        return

    ; 해당 좌표 클릭 해제제
    MouseClick('L',pos2D.x,pos2D.y, 1,2,'U')
    return                       
}

#HotIf isActive

; 오버레이 토글
` up:: {
    global settings
    global hkInfo
    ; flip
    
    settings.enableOverlay := !settings.enableOverlay

    processHandle := WinActive(curTargetTitle)

    if(settings.enableOverlay)
    {
        CreateOverlay(&processHandle, &hkInfo)
    }
    else
    {
        hkInfo.ClearOverlay()
    }
}

; @@ 현재 게임 기본 위치로


#HotIf 

; 스크립트 종료
CloseScript()
{
    global settingPath
    
    ; 설정 저장
    settingMap := settings.ToMap()
    SaveSetting(&settingMap, &settingPath)

    ExitApp
}