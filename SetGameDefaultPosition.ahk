#Requires AutoHotkey v2.0
#Include Utility.ahk

; 클래스 영역

; 게임명 : 기본 위치 데이터
class PosInfo
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

; 기본 위치 데이터
; @@ TODO 시트 로드해서 데이터 가져오기


; @@ 게임 프로세스 받아서 시트에 있는 기본 위치로 창 옮기기
SetDefaultPosition(processName)
{
    ; @@ 시트에서 해당 게임 위치 데이터 가져오기
    
    ; @@ 위치 이동
    SetPosition(processName, processPosInfo)
}

; 해당 위치로 프로세스 위치 이동
SetPosition(processName, posInfo)
{
    ; ToolTip Format("{1} , {2}", processName, posInfo.x)
    
    ; 창 위치 이동
    WinMove(posInfo.x, posInfo.y, , ,processName)

    ; WinGetPos(&x,&y,&w,&h,processName)
    ; ToolTip("X: " . x . "`nY: " . y . "`nWidth: " . w . "`nHeight: " . h)
}


; @@ 디버그용
F1::
{
    curTitle := WinGetTitle("ドルウェブ") ; "A"는 현재 활성화된 창을 의미합니다.

    targetPos := PosInfo()
    targetPos.x := 0
    targetPos.y := 0

    SetPosition(curTitle, targetPos)
}

; 종료 키
] & Esc::CloseScript

CloseScript()
{
    ExitApp
}