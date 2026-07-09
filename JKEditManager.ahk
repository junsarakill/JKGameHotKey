#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include Overlay.ahk
/************************************************************************
 * @description 가상키 데이터 편집 중재자
 * @author JKAKK
 * @date 2026/07/01
 * @version 0.0.1
 ***********************************************************************/

; @@ editGui 분리 | 클릭용 txtCtrl, OnSize 이벤트 처리등


class JKEditManager
{
    /** @type {bool} */
    static _isEditState := false
    /**
     * #### 편집 모드 활성 유무
     * @type {bool} 
     */
    static IsEditState {
        get => this._isEditState
        set
        {
            this._isEditState := value

            JKUtility.Log("현재 편집 모드 상태 : " value)

            value ? this.ActiveEditMode() 
                  : this.ExitEditMode()
        }   
    }

    /**
     * #### 편집 메인 gui
     * @type {Gui} 
     */
    static editMainGUI := unset

    ; 편집 모드 투명도
    static editModeBGOpacity := 100

    ; 오버레이 BG 색상 추가
    static editModeBGColor := "dfdfdf"

    ; 대상 창 핸들
    static curTargetHwnd := 0

    ; 대상 게임명
    static curTargetName := ""

    ; 대상 가상키 데이터 맵
    static curTargetHKMap := Map()

    /**
     * #### 편집 이벤트 딜리게이트
     * @callback EditEventCallback
     * @param {string} eventType - 이벤트의 종류 (예: 'Begin', 'Save')
     * @param {...*} params - 이벤트와 함께 전달되는 가변 파라미터들
     * @type {Array<EditEventCallback>}
     * @default []
     */
    static OnEditEventDel := []

    static __New()
    {
        ; @@ 창 타이틀 바에 생길 gui 미리 생성 및 비활성화
        this.editMainGUI := Gui("-Caption +ToolWindow +AlwaysOnTop")
        this.editMainGUI.BackColor := this.editModeBGColor
        WinSetTransparent(this.editModeBGOpacity, this.editMainGUI)

        ; this.editMainGUI.OnEvent("Click", this.OnClickEvent.Bind(this))
    }


    ; 편집 모드 토글
    static ToggleEditMode()
    {
        this.IsEditState := !this.IsEditState
    }
    
    ; 편집 모드 활성화
    static ActiveEditMode()
    {
        ; 매니저에게 핫키 정보랑 현재 창 이름 받기
        ; 현재 창 hwnd 기반으로 반투명 클릭 가능 gui 만들기
        this.curTargetHwnd := WinExist("A")
        ; JKUtility.Log("gui 활성 시작, hwnd: " this.curTargetHwnd)

        if(!this.curTargetHwnd)
            return JKUtility.Log("hwnd 없음")

        ; 편집 모드 활성화 딜리게이트 실행
        JKUtility.CallMulticastDel(this.OnEditEventDel, "begin")
        
        ; GUI의 소유권 변경해서 포커스 변경 방지
        this.editMainGUI.Opt("+Parent" . this.curTargetHwnd)

        Sleep(-1)
        
        ; WS_EX_NOACTIVATE: 클릭해도 활성화되지 않음)
        this.editMainGUI.Opt("+E0x08000000")

        ; 대상 창의 좌표와 크기 구하기
        WinGetClientPos(, , &targetW, &targetH, this.curTargetHwnd)

        guiShowOption := Format("x0 y0 w{} h{}",targetW, targetH)

        ; JKUtility.Log("show option : " guiShowOption)
        
        ; 기존 GUI를 새 위치와 크기로 재배치하여 보여주기
        this.editMainGUI.Show(guiShowOption)

        ; 편집 배경을 부모 창의 '가장 자식 레이어 최하단(HWND_BOTTOM)'으로 보냅니다.
        ; @@ jkhotkey 보단 아래에 있도록 레이어 수정 필요
        ; HWND_BOTTOM = 1
        ; SWP_NOSIZE(0x0001) | SWP_NOMOVE(0x0002) = 크기와 위치 유지
        ; DllCall("SetWindowPos", "Ptr", this.editMainGUI.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002)

        DllCall("SetWindowPos", "Ptr", this.editMainGUI.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0010)
    }

    ; 편집 모드 종료
    static ExitEditMode()
    {
        ; 편집 gui 초기화
        this.editMainGUI.Hide()
        this.editMainGUI.Opt("-Parent")
        this.editMainGUI.Move(0,0,0,0)

        ; @@ 편집 종료 딜리게이트 실행 | 편집한 가상키 데이터 맵 반환

        ; 포커스 되돌리기
        if(this.curTargetHwnd)
            WinActivate(this.curTargetHwnd)
    }

    ; 오버레이 추가 이벤트
    static OnClickEvent(*)
    {
        ; 클릭 좌표 가져오기
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mouseX, &mouseY)

        JKUtility.Log(Format("x: {} y : {}", mouseX, mouseY))
    }
    

    
}