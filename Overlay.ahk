#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKSession.ahk
#Include JKSettings.ahk
#Include JKHotKeyInfo.ahk

/************************************************************************
 * @description 오버레이 관련 스크립트
 * @author JKAKK
 * @date 2026/05/16
 * @version 0.0.4
 ***********************************************************************/


/**
 * MARK: 오버레이 객체
 */
class JKOverlay
{
    /**
     * #### 클라위치 + 클라 내 위치 보정된 값
     * @type {Vector2d} 
     * @default 0,0
     */
    pos := Vector2d()

    /**
     * #### 오버레이 폭
     * @type {Number} 
     * ;@@ width 부분 const 니깐 생성자에서 받을 필요 없음
     * ;@@ \ 같은 전각 문자도 처리 가능하게 하면 좋을듯 | 아예 gui width 는 Autosize 로 하고 txtctrl의 크기만 조정한다 던가
     * @default 0
     */
    WIDTH => 4 + StrLen(this.name) * 8

    /**
     * #### gui 객체
     * @type {Gui} 
     * @default null
     */
    aGUI := unset

    /**
     * #### 오버레이 이름
     * @description 시트에 적혀있는 name 부분 == keyName
     * @type {String} 
     * @default ?
     */
    name := "?"

    /** @type {bool} */
    _isVisible := false
    /**
     * #### 오버레이 활성 유무
     * @see OverlayManager.CreateOverlay
     * @see OverlayManager.ClearOverlay
     * @type {bool} 
     * @default false
     */
    IsVisible {
        get => this._isVisible
        set
        {
            ; 유효성 검사
            if(!this.isActive)
                return JKUtility.Log("비활성 상태 오버레이 접근" . this.name)

            this._isVisible := value
            if(value)
            {
                ; 최신 세션 체크해서 예전꺼면 자괴
                if(!this.session.Valid())
                {
                    JKUtility.Log(Format("[JKSession] ⚠ Session Invalid Detected! text : {1} (Object: {2} / Global: {3})`n"
                        , this.name, this.session.insSessionNum, JKSession.CurSessionNum))
                    
                    return this.Destroy()
                }
                
                ; gui 활성화
                this.aGUI.Show(this.GUI_SHOW_OPTION)
            }
            else
                this.aGUI.Hide()
        }
    }

    /**
     * #### 활성 유무
     * @type {자료형} 
     * @default true
     */
    isActive := true

    /**
     * #### gui show 옵션
     * @type {String} 
     */
    GUI_SHOW_OPTION => "NoActivate w" . this.WIDTH . " h15 x" . this.pos.x . " y" . this.pos.y

    /**
     * #### 세션
     * @type {JKSession} 
     * @see JKSession
     * @default 0
     */
    session := 0

    /**
     * @param {Vector2d} pos - 클라+위치 보정된 위치 좌표
     * @param {Number} opacity - 투명도 0~255
     * @param {Number} width - 오버레이 가로 길이
     * @param {String} guiOption - gui 옵션
     * @param {String} guiBGColor - 배경색
     * @param {Array<String>} guiText - gui텍스트 컨텍스트 | newGuiText := ["Text", "x3 y2 " , keyData.name]
     */
    __New(pos, opacity := 255, width := 12
        , guiOption := "", guiBGColor := "FFFFFF", guiText := ["Text", "x3 y2 " , "?"]) 
    {
        this.aGUI := Gui()
        
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", this.aGUI.Hwnd, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)

        ; 나머지 변수는 업데이트 처리
        this.Update(pos, opacity, width, guiOption,guiBGColor, guiText)

        ; 생성 종료
        this.Awake()
    }

    /**
     * #### 오버레이 업데이트
     * @param {Vector2d} pos - 클라+위치 보정된 위치 좌표
     * @param {Number} opacity - 투명도 0~255
     * @param {Number} width - 오버레이 가로 길이
     * @param {String} guiOption - gui 옵션
     * @param {String} guiBGColor - 배경색
     * @param {Array<String>} guiText - gui텍스트 컨텍스트 | newGuiText := ["Text", "x3 y2 " , keyData.name]
     * @returns {void}
     */
    Update(pos, opacity := 255, width := 12, guiOption := "",guiBGColor := "FFFFFF", guiText := [])
    {
        JKSession.UpdateOrCreateSession(this)

        this.isActive := true
        this.name := guiText[3]
        this.aGUI.Opt(guiOption)
        this.aGUI.BackColor := guiBGColor
        this.pos := pos
        ; this.WIDTH := width

        ; 컨트롤 존재 여부 확인 후 처리
        if (!this.HasProp("txtCtrl")) 
            ; 처음 실행될 때: 컨트롤 생성 및 저장
            this.txtCtrl := this.aGUI.Add(guiText*) 
        else 
            ; 이미 생성된 이후: 값만 업데이트
            this.txtCtrl.Value := this.name
        
        ; 투명도
        WinSetTransparent(opacity, this.aGUI.Hwnd)

        ; JKUtility.Log("gui hwnd: " . this.aGUI.Hwnd . " keyname : " . this.name . " ctrlV : " . this.txtCtrl.Value)
    }

    ; 객체 생성 후 초기화 | 하위 상속에 필요
    Awake()
    {

    }

    ; 이름 변경
    Rename(newName)
    {
        this.name := newName
        this.txtCtrl.Value := newName
        this.txtctrl.Move(,, this.WIDTH)
        
        ; 폭 적용
        if(this.IsVisible)
            this.aGUI.Show(this.GUI_SHOW_OPTION)
    }

    /**
     * #### 오버레이 활성화 여부 설정
     * *
     * @param {Bool} value - 활성화 여부
     * @returns {void}
     */
    SetVisible(value := true)
    {
        this.IsVisible := value
    }

    /**
     * #### 오버레이 비활성화
     * @returns {void}
     */
    Disactive()
    {
        this.IsVisible := false  
        try this.txtCtrl.Value := ""
        this.isActive := false
    }

    /**
     * #### 오버레이 제거
     * @description 오브젝트 풀 추가해서 재사용해야하니 실질 미사용
     * @returns {void}
     */
    Destroy() 
    {
        this.Disactive()
        try this.aGUI.Destroy()
        this.aGUI := unset
    }

    ; 소멸자
    __Delete() 
    {
        try this.Destroy()
    }
}

; 오버레이 생성용 정보
class OverlayCreateInfo
{
    /**
     * #### 목표 핸들
     * @type {Number} 
     */
    hwnd := unset

    /**
     * #### 가상키 데이터
     * @type {Map<String, JKHotKeyInfo} 
     */    
    hkData := unset

    /**
     * #### 설정값
     * @type {JKSettings} 
     */
    settings := unset

    __New(hwnd, hkData, settings) 
    {
        this.hwnd := hwnd
        this.hkData := hkData
        this.settings := settings
    }
}

; MARK: 편집용 오버레이
class JKEditOverlay extends JKOverlay
{
    ; "Hotkey" | 키 입력 받는 컨트롤
    /**
     * #### 설명을 입력하세요.
     * @type {Gui.Hotkey} 
     */
    hkControl := ""

    ; 클릭하면 자기 삭제하는 버튼 컨트롤
    btnDelete := ""
    
    ; 초기화
    Awake()
    {
        super.Awake()
        
        ; 하위 컨트롤 생성
        ; Hotkey 컨트롤 생성
        this.hkControl := this.aGUI.Add("Hotkey", "w100", "a")
        this.hkControl.OnEvent("Change", this.OnChange.Bind(this))
        
        ; FIXME width 정해져서 보이는게 잘리는데 해결필요
        ; 삭제 버튼 생성
        this.btnDelete := this.aGUI.Add("Button", "x+5 w30", "X")

        this.IsVisible := true

        ; Hotkey 컨트롤에 강제로 포커스 부여
        this.hkControl.Focus()
    }    

    ; 키 입력 이벤트
    OnChange(ctrl, *)
    {
        this.Rename(ctrl.Value)
    }
    ; 유효성 검사 요청
    ; 텍스트 컨트롤 값 변경

    ; 자가 삭제 이벤트
    ; 매니저에 삭제 요청
    ; 자기 비활성화
    
    ; 비동기 검사 결과 받아서 유효 상태 변경

    ; 포커스 잃으면 임시 저장 요청 이벤트
    ; 비유효 상태면 저장 불가 처리

}

; MARK: 매니저 클래스
class OverlayManager
{
    /**
     * #### 전체 오버레이 오브젝트 풀
     * @type {Map} 
     * @example overlayObjPoolMap[name] := oneOverlay
     * @description name == keyName, oneOverlay == JKOverlay()
     */
    static overlayObjPoolMap := Map()

    /**
     * #### 현재 활성화된 오버레이 맵
     * @type {Map} 
     */
    static curActiveOverlayMap := Map()
    
    /**
     * #### 오버레이 상태 변경
     * @param {bool} isActive - 활성 유무
     * @param {OverlayCreateInfo} overlayContext - 오버레이 새 데이터
     * @returns {void} - 반환값 설명
     */
    static OnOverlayStateChanged(isActive, overlayContext)
    {
        if(isActive)
            this.GetOrCreateOverlay(overlayContext, true)
        else
            this.ClearOverlay()
    }

    /**
     * #### 가상키 오버레이 생성
     * @param {OverlayCreateInfo} ocInfo - 오버레이 새 데이터
     * @param {bool} isActive - 생성 후 즉시 활성 유무
     * @returns {void}
     */
    static GetOrCreateOverlay(ocInfo, isActive := true)
    {
        if(!ocInfo.hwnd || ocInfo.hwnd = 0)
        {
            JKUtility.Log("hwnd 없음: " . ocInfo.hwnd)
            return
        }

        ; for 생성 중 확인할 세션
        local newSession := JKSession()

        ; 새 오버레이 생성
        for keyName, keyData in ocInfo.hkData
        {
            ; 세션 유효 검사
            if(!newSession.Valid())
            {
                JKUtility.Log("오버레이 매니저 단에서 중단 session : " . newSession.insSessionNum . ", 현재 최신 세션 : " . JKSession.CurSessionNum)
                
                this.ClearOverlay()
                break
            }

            ; 최적화용 일시 정지
            Sleep(-1)

            ; MARK: 오버레이 객체 용 인자 설정
            winPos := Vector2d.WinGetClientSize(ocInfo.hwnd)
            
            newOverlayPos := winPos.Multiply(keyData.pos)
            newOverlayWidth := 4 + StrLen(keyData.name) * 8
            newOpacity := ocInfo.settings.overlayOpacity

            newGuiOption := "-Caption AlwaysOnTop +ToolWindow -Border +Parent" . ocInfo.hwnd
            newGuiBGColor := ocInfo.settings.overlayBGColor
            ; 사용시 * 뒤에 붙이기
            newGuiText := ["Text", "x3 y2 " , keyData.name]
            ; ========

            ; 기존 풀에 존재 확인
            /** @type {JKOverlay} */
            newOverlay := this.overlayObjPoolMap.Get(keyName, false)
            ; 있으면 업데이트 하고 재사용
            if(newOverlay)
                newOverlay.Update(newOverlayPos, newOpacity, newOverlayWidth, newGuiOption, newGuiBGColor, newGuiText)
            else
                newOverlay := JKOverlay(newOverlayPos, newOpacity, newOverlayWidth, newGuiOption, newGuiBGColor, newGuiText)

            ; 설정에 따라 오버레이 활성화
            newOverlay.SetVisible(isActive)

            if(!newOverlay.isActive)
            {
                JKUtility.Log("생성 중단된 오버레이 자괴 됨 : " . newOverlay.name . newOverlay.session.insSessionNum)
                
                continue
            }    

            ; 오브젝트 풀, 활성 오버레이 맵에 추가
            this.overlayObjPoolMap[newOverlay.name] := newOverlay
            this.curActiveOverlayMap[newOverlay.name] := newOverlay
        }
    }

    /**
     * #### 오버레이 비활성화
     * @returns {void}
     */
    static ClearOverlay()
    {
        oldMap := this.curActiveOverlayMap
        this.curActiveOverlayMap := Map()

        for , overlayObj in oldMap
        {
            overlayObj.Disactive()
        }
    }
}