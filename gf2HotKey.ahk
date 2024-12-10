#Requires AutoHotkey v2.0

; 클래스 선언

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
    ,z : [862,540]
    ,x : [567, 540]
    ,t : [1303,115]
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
    infoMap.Push(OverlayInfo(value[1], value[2], key))
}


; 키 동적 핫 키 생성 | press, release
for key, value in keyMap.OwnProps() {
    Hotkey("$" key, ClickPos)         
    Hotkey("$" key " up", ReleaseBtn)                         
}

; 최초 프로그램 시작 대기
SetTimer WaitStartProgram, 5000

WaitStartProgram()
{
    global waitStart
    waitStart := true
}

; 타겟 프로그램 포커스 확인
SetTimer CheckFocus, 30000 

CheckFocus() 
{
    global canInput
    global infoMap
    global processHandle
    ; 찾을 프로그램 이름
    processHandle := WinActive(gameName)
    canInput := processHandle ? true : false
    ; ToolTip "" (canInput ? "it" : "if")

    ; 입력 가능     
    if(canInput)
    {
        ; 오버레이 활성화
        ActiveOverlay(&processHandle)
    }
    else
    {
        for oneInfo in infoMap
        {
            oneInfo.SetActive(false)
        }
    }


    ; 프로그램 없으면 종료
    if(waitStart and !ProcessExist(processName))
    {
        ToolTip processName "이 종료됨. 핫 키 종료"
        Sleep 1000
        ExitApp
    }
}

; 입력 영역

; 종료
] & Esc::ExitApp

[ & Esc::WaitStartProgram                   

#HotIf canInput   
; 해당 키 좌표 가져오기
GetKeyPos(&valueAry, key)
{
    CheckFocus()

    ; $ 잘라내기
    key := StrReplace(key, "$")
    key := StrReplace(key, " up")    
    
    if(!canInput or !keyMap.HasOwnProp(key))
    {   
        if(!GetKeyState(key, "P"))
        {
            return false
        }                                               

        ToolTip(key)
        if(GetKeyState("Alt", "P"))
            return false
        SendInput("{" key "}")
        Sleep(100)
        return false
    }

    ; 해당 키 좌표 가져오기
    valueAry := keyMap.GetOwnPropDesc(key).Value

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

#HotIf 
    

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
