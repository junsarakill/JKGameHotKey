#Requires AutoHotkey v2.0


; 입력 가능 여부
canInput := false

; 창 이름
gameName := "ドルウェブ"
; 프로그램 이름
processName := "Dolphin.exe"

; 키 맵
keyMap := {
    Tab : [1204, 66]
    ,Esc : [55,55]                  
    ,1 : [128, 593]
    ,2 : [210, 593]
    ,3 : [940, 574]
    ,4 : [1071, 574]
    ,5 : [1205, 574]
    ,q : [177, 677]
    ,w : [358, 677]
    ,e : [551, 677]
    ,r : [739, 677]
    ,t : [932, 677]
    ,y : [1123, 677]
    ,a : [1053, 479]
    ,p : [858, 336]
    ,o : [553, 336]
    ,z : [744, 488]     
    ,x : [536, 490]
    ,space : [644, 644] 
    ,s : [793, 621]
    ,Left : [30, 358]
    ,Right : [1256, 363]
    ,F1 : [837, 155]
    ,F2 : [837, 291]
    ,F3 : [837, 425]
    ,F4 : [837, 552]

}

; kl := ""    
; 키 동적 핫 키 생성 | press, release
for key, value in keyMap.OwnProps() {
    Hotkey("$" key, ClickPos)         
    Hotkey("$" key " up", ReleaseBtn)                         
    ; kl .="$" key "`n"         
}

; MsgBox("생성된 핫키들 : `n" kl)


; 돌핀 포커스 확인
SetTimer CheckFocus, 30000 ; 1 초 마다 체크

CheckFocus() 
{
    global canInput
    ; 찾을 프로그램 이름
    canInput := WinActive(gameName) ? true : false
    ToolTip "canInput : " (canInput ? "true" : "false")

    if(!ProcessExist(processName))
    {
        ToolTip processName "이 종료됨. 핫 키 종료"
        Sleep 1000
        ExitApp
    }
}

; 입력 영역

; 종료
] & Esc::ExitApp

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

#HotIf 
    


