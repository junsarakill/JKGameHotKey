#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include Overlay.ahk
/************************************************************************
 * @description 가상키 데이터 편집 중재자
 * @author JKAKK
 * @date 2026/07/01
 * @version 0.0.1
 ***********************************************************************/

; MARK: 편집 GUI
; 편집 이벤트 입력을 받는 인터페이스 클래스
class JKEditGUI
{
    /**
     * #### 편집 메인 gui
     * @type {Gui} 
     */
    static aGUI := unset
    
    /**
     * #### 클릭 이벤트용 투명 txt 컨트롤
     * @type {Gui.Text} 
     */
    static blankCtrl := unset

    ; 편집 모드 투명도
    static editBGOpacity := 100

    ; 오버레이 BG 색상 추가
    static editBGColor := "dfdfdf"

    /**
     * #### 편집 gui 이벤트 딜리게이트 배열
     * 이벤트별 필요 매개 변수
     * * `('add')`
     * @see JKEditManager.EditGUIEventHandler
     * @type {Array<Function>}
     */
    static OnEditGUIEventDel := []

    ; 생성자
    static __New()
    {
        ; 편집 메인 gui 생성
        this.aGUI := Gui("-Caption +ToolWindow +AlwaysOnTop")
        this.aGUI.BackColor := this.editBGColor
        WinSetTransparent(this.editBGOpacity, this.aGUI)
        ; TODO 대상 창 타이틀 바에 편집 진입용 gui 생성 및 비활성

        this.blankCtrl := this.aGUI.AddText("x0 y0 w0 h0", "")

        ; 크기 동기화 바인드
        this.aGUI.OnEvent("Size", this.OnSizeSync.Bind(this))
        ; 클릭 이벤트 바인드
        this.blankCtrl.OnEvent("Click", this.OnClick.Bind(this))
    }

    /**
     * #### 대상 창에 gui 붙이기
     * @param {Number} targetHwnd - 대상 창 핸들
     * @returns {void}
     */
    static AttachTargetHwnd(targetHwnd)
    {
        ; GUI의 소유권 변경해서 포커스 변경 방지
        this.aGUI.Opt("+Parent" . targetHwnd)

        Sleep(-1)
        
        ; WS_EX_NOACTIVATE: 클릭해도 활성화되지 않음)
        this.aGUI.Opt("+E0x08000000")

        ; 대상 창의 크기 구하기
        WinGetClientPos(, , &targetW, &targetH, targetHwnd)

        guiShowOption := Format("x0 y0 w{} h{}"
                            , targetW, targetH)

        ; JKUtility.Log("show option : " guiShowOption)
        
        ; 기존 GUI를 새 위치와 크기로 재배치하여 보여주기
        this.aGUI.Show(guiShowOption)

        ; @@ 레이어 관련 기능 추가할때 수정할 곳
        ; 편집 배경을 부모 창의 '가장 자식 레이어 최하단(HWND_BOTTOM)'으로 보냅니다.
        ; @@ jkhotkey 보단 아래에 있도록 레이어 수정 필요
        ; HWND_BOTTOM = 1
        ; SWP_NOSIZE(0x0001) | SWP_NOMOVE(0x0002) = 크기와 위치 유지
        ; DllCall("SetWindowPos", "Ptr", this.Hwnd, "Ptr", 1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002)

        DllCall("SetWindowPos", "Ptr", this.aGUI.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0010)
    }

    /**
     * #### 편집 gui 초기화
     * @see JKEditManager.ExitEditMode
     * @description 편집 모드가 다시 활성화 될때, 문제 되지 않도록 처리
     * @returns {void}
     */
    static ResetGUI()
    {
        this.aGUI.Hide()
        this.aGUI.Opt("-Parent")
        this.aGUI.Move(0,0,0,0)
    }   

    /**
     * #### 편집 gui 크기 변경시 컨트롤 크기 동기화
     * @description 클릭 이벤트 받을 컨트롤은 같은 크기 유지해야함.
     * @param {Number} newW - 새 폭
     * @param {Number} newH - 새 높이
     * @returns {void}
     */
    static OnSizeSync(_guiObj, _minMax, newW, newH)
    {
        this.blankCtrl.Move(0, 0, newW, newH)
    }

    /**
     * #### 클릭 이벤트 처리
     * @description 
     * @returns {void} - 
     */
    static OnClick(_guiObj, _clickInfo)
    {
        ; 클릭된 좌표 구하기
        MouseGetPos(&ctrlX, &ctrlY, , , 2)

        JKUtility.Log("컨트롤 내부 기준 좌표:`n" . Vector2d(ctrlX,ctrlY).ToString())
        
        ; JKUtility.Log(Format("컨트롤 내부 기준 좌표:`nX: {}, Y: {}", ctrlX, ctrlY))

        ; 가상키 추가 요청
        JKUtility.CallMulticastDel(this.OnEditGUIEventDel, 'add', Vector2d(ctrlX, ctrlY))
    }

    
}

; 편집용 dto 컨텍스트
class EditInfo
{
    ; 게임명
    gameName := ""
    
    ; 가상키 데이터 맵
    hkDataMap := Map()

    __New(gameName := "", hkDataMap := Map()) 
    {
        this.gameName := gameName
        this.hkDataMap := hkDataMap    
    }
}

; MARK: 편집 매니저
; 편집 gui 와 다른 매니저들을 이어주는 중재자 클래스
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

            this.CurEditState := value

            ; JKUtility.Log("현재 편집 모드 상태 : " value)

            value ? this.ActiveEditMode() 
                  : this.ExitEditMode()
        }   
    }

    ; 편집 상태 ENUM
    static EDIT_STATE := {
        DISACTIVE : 0
        , ACTIVE : 1
        , TYPE : 2
    }

    static _curEditState := THIS.EDIT_STATE.DISACTIVE
    ; 현재 편집 상태
    static CurEditState {
        get => this._curEditState
        set 
        {
            this._curEditState := value 

            JKUtility.Log("현재 편집 상태 : " JKUtility.EnumToString(this.EDIT_STATE, value))
        }
    }

    ; 대상 창 핸들
    static curTargetHwnd := 0

    static _curEditInfo := EditInfo()
    /**
     * #### 가상키 데이터 컨텍스트
     * @type {EditInfo} 
     */
    static CurEditInfo {
        get => this._curEditInfo
        set
        {
            this._curEditInfo := value
        }
    }

    ; 임시 가상키 데이터 맵
    static tempHKDataMap := Map()

    /**
     * #### 편집 매니저 이벤트 딜리게이트 배열
     * 이벤트별 필요 매개 변수
     * * `('begin')`
     * * `('save', EditInfo)`
     * @see AppManager.EditManagerEventHandler
     * @type {Array<Function>}
     */
    static OnEditEventDel := []

    static __New()
    {
        ; 편집 gui 이벤트 처리 바인딩
        SetTimer(() => JKEditGUI.OnEditGUIEventDel.Push(
            JKEditManager.EditGUIEventHandler.Bind(JKEditManager)
        ), -1)
    }


    ; 편집 모드 토글
    static ToggleEditMode()
    {
        this.IsEditState := !this.IsEditState
    }
    
    /**
     * #### 편집 모드 활성화
     * @returns {void}
     */
    static ActiveEditMode()
    {
        ; 현재 창 hwnd 기반으로 반투명 클릭 가능 gui 만들기
        this.curTargetHwnd := WinExist("A")
        ; JKUtility.Log("gui 활성 시작, hwnd: " this.curTargetHwnd)

        if(!this.curTargetHwnd)
            return JKUtility.Log("hwnd 없음")

        ; 편집 모드 활성화 딜리게이트 실행
        JKUtility.CallMulticastDel(this.OnEditEventDel, "begin")

        ; 대상 창에 gui 붙이기
        JKEditGUI.AttachTargetHwnd(this.curTargetHwnd)

        this.tempHKDataMap := Map()
    }

    ; 편집 모드 종료
    static ExitEditMode()
    {
        ; 편집 gui 초기화
        JKEditGUI.ResetGUI()

        ; 저장 요청
        JKUtility.CallMulticastDel(this.OnEditEventDel, "save", this.CurEditInfo)

        ; 포커스 되돌리기
        if(this.curTargetHwnd)
            WinActivate(this.curTargetHwnd)
    }

    /**
     * #### 편집 GUI 이벤트 처리
     * @see JKEditManager.OnEditEventDel
     * @param {'add'} eventType - 이벤트의 종류
     * @param {...*} _params - 이벤트와 함께 전달되는 가변 파라미터들
     * @overload EditGUIEventHandler('add')
     * @returns {void}
     */
    static EditGUIEventHandler(eventType, _params*)
    {
        switch(eventType)
        {
            case "add":
                /** @type {Vector2d} */
                clickPos := _params[1]
                ; 가상키 추가 시작
                this.AddNewHK(clickPos)
            default:
                JKUtility.Log("비대상 이벤트")
        }

    }

    static AddNewHK(clickPos)
    {
        ; 1. 신규 가상키 입력 상태로 변경
        ; this.CurEditState := this.EDIT_STATE.TYPE
        newGuiOption := "-Caption AlwaysOnTop +ToolWindow -Border +Parent" . this.curTargetHwnd

        ; JKUtility.Log(clickPos.ToString())
        ; 2. 클릭 위치에 입력 받을 오버레이 gui 생성
        static newOverlay := JKEditOverlay(clickPos, 200, , newGuiOption, "ac0909")

        ; 포커스 잃음 이벤트에 임시 목록 저장 하도록 바인드
        ; 키 입력 이벤트에 충돌 검사 함수 바인드

        ; 6. 편집 일반 상태로 변경 | 굳이 필요 없나? 어차피 가상키 이벤트에서 다 처리되는데
    }

    ; 충돌 검사 함수
    static CheckValidHotkey(overlayObj)
    {
        ; 신규,수정 키 입력 이벤트때 해당 입력이 기존 목록과 충돌하는지 유효성 확인
        ; 확인 결과 해당 gui 객체에게 주입
        ; this.CurEditInfo.hkDataMap + this.tempHKDataMap

        overlayObj.ValidStateChange(false)
    }

    ; 저장 이벤트
    ; 메인 gui 저장 버튼에 이 함수 바인드
    ; 임시 오버레이 목록과 기존 목록 병합
    ; 수정된 목록 앱 매니저에게 반환
    ; 편집 모드 종료

    ; 취소 이벤트
    ; 임시 목록 비우기
    ; 편집 모드 종료
}