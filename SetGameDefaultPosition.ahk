#Requires AutoHotkey v2.0
#Include Utility.ahk

; 클래스 영역

; 게임명 : 기본 위치 데이터
class PosData
{
    name := "" ; string
    pos := "" ; vector2d
    monitor := 0

    __New(name := "", x := 0, y := 0, monitor := 0)
    {
        this.name := name
        this.pos := Vector2d(x, y)
        this.monitor := monitor
    }
}

; 전역 변수 영역

; 기본 위치 시트 경로
defaultPosSheetName := "JK_GameDefaultPosition.csv"
defaultPosSheetPath := sheetFolder . defaultPosSheetName

;기본 위치 데이터 | PosData 배열
defaultPosData := LoadDefaultPosSheetData(defaultPosSheetPath)

; 기본 위치 시트 데이터 PosData 구조체 배열로 변환
LoadDefaultPosSheetData(defaultPosSheetPath)
{
    ; 맵 변환한 시트 데이터 배열
    dataAry := LoadSheetData(defaultPosSheetPath)
    
    ; PosData 배열 형태로 반환할 값
    posDataAry := []
    for oneData in dataAry
    {
        onePosData := PosData(oneData["name"], oneData["x"], oneData["y"], oneData["monitor"])

        posDataAry.Push(onePosData)
    }

    return posDataAry
}


; 위치 데이터 받아서 시트에 있는 기본 위치로 창 옮기기
SetDefaultPosition(posData)
{
    ; 전체 프로세스에 해당 게임 존재 체크
    if(WinExist(posData.name))
    {
        ; 위치 이동
        WinMove(posData.pos.x, posData.pos.y, , , posData.name)
    }
}

; 시트내 모든 게임에 위치 변경
RunSetGameDefaultPosition()
{
    global defaultPosData
    for posData in defaultPosData
    {
        SetDefaultPosition(posData)
    }
}


; XXX 디버그용
; F7::
; {
;     global defaultPosData
;     for posData in defaultPosData
;     {
;         SetDefaultPosition(posData)
;     }
; }

; XXX 종료 키
; ] & Esc::CloseScript

; CloseScript()
; {
;     ExitApp
; }