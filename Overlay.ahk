#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKSession.ahk

/************************************************************************
 * @description 오버레이 관련 스크립트
 * @author JKAKK
 * @date 2026/05/11
 * @version 0.0.3
 ***********************************************************************/


/**
 * MARK: 오버레이 객체
 */
class JKOverlay
{
    /**
     * #### 오버레이 위치
     * @description 클라위치 + 클라 내 위치 보정된 결과 값
     * @type {Vector2d} 
     */
    pos := Vector2d()

    ; 오버레이 폭
    width := 0

    /** @type {Gui} */
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
    IsVisible
    {
        get => this._isVisible
        set
        {
            this._isVisible := value

            ; 유효성 검사
            if(!this.isValid)
            {
                JKUtility.Log("제거상태 오버레이 접근" . this.name)
                return
            }

            if(value)
            {
                ; 최신 세션 체크해서 예전꺼면 자괴
                if(!this.session.Valid())
                {
                    JKUtility.Log(Format("[JKSession] ⚠ Invalid Detected! text : {1} (Object: {2} / Global: {3})`n"
                        , this.name, this.session.insSessionNum, JKSession.curSessionNum))
                    
                    return this.Destroy()
                }
                
                ; gui 활성화
                this.aGUI.Show(this.GuiShowOption)
            }
            else
                this.aGUI.Hide()
            }
    }

    /**
     * #### gui show 옵션
     * @type {String} 
     * @default null
     */
    GuiShowOption => "NoActivate w" . this.width . " h15 x" . this.pos.x . " y" . this.pos.y

    /** @type {String} */
    /**
     * #### 백업용 gui show 옵션
     * @type {String} 
     * @default null
     */
    prevGuiShowOption := ""

    /**
     * #### 세션
     * @type {JKSession} 
     * @see JKSession
     * @default null
     */
    session := 0

    ; 존재 유효 유무
    isValid := true

    /**
     * @param {Vector2d} pos - 클라+위치 보정된 위치 좌표
     * @param {Number} opacity - 투명도 0~255
     * @param {Number} width - 오버레이 가로 길이
     * @param {String} guiOption - gui 옵션
     * @param {String} guiBGColor - 배경색
     * @param {Array} guiText - ["Text", 위치, keyName]
     * @returns {OverlayInfo}
     */
    __New(pos := Vector2d(), opacity := 255, width := 12
        , guiOption := "", guiBGColor := "FFFFFF", guiText := ["","",""]) 
    {
        this.aGUI := Gui(guiOption)
        
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", this.aGUI.Hwnd, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)

        ; 나머지 변수는 업데이트
        this.Update(pos, opacity, width, guiBGColor, guiText)
    }

    ; 업데이트
    Update(pos := Vector2d(), opacity := 255, width := 12, guiBGColor := "FFFFFF", guiText := ["","",""])
    {
        JKSession.UpdateOrCreateSession(this)

        this.isValid := true
        this.name := guiText[2]

        ; gui 생성
        this.aGUI.BackColor := guiBGColor
        ; 컨트롤 존재 여부 확인 후 처리
        if (!this.HasProp("txtCtrl")) 
        {
            ; 처음 실행될 때: 컨트롤 생성 및 저장
            this.txtCtrl := this.aGUI.Add(guiText*) 
        } 
        else 
        {
            ; 이미 생성된 이후: 값만 업데이트
            this.txtCtrl.Value := guiText[2]
        }
        
        ; 투명도
        WinSetTransparent(opacity, this.aGUI.Hwnd)

        this.pos := pos
        this.width := width
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

    ; @@오버레이 비활성화

    /**
     * #### 오버레이 제거
     * *
     * @returns {void}
     */
    Destroy() {
        this.IsVisible := false
        try this.aGUI.Destroy()
        this.aGUI := unset
        this.isValid := false
    }

    ; 소멸자
    __Delete() {
        try this.Destroy()
    }
}

; MARK: 매니저 클래스
class OverlayManager
{
    /**
     * #### 전체 오버레이 오브젝트 풀
     * @type {Map} 
     * @default null
     * @example overlayObjPoolMap[name] := oneOverlay
     * @description name == keyName, oneOverlay == JKOverlay()
     */
    static overlayObjPoolMap := Map()

    ; 현재 활성화된 오버레이 맵
    static overlayActiveMap := Map()

    ; 오버레이 상태 변경
    static OnOverlayStateChanged(isActive, overlayContext)
    {
        if(isActive)
        {
            this.GetOrCreateOverlay(overlayContext.hwnd
                            , overlayContext.hkInfo
                            , overlayContext.settings, true)
        }
        else
            this.ClearOverlay()
    }

    /**
     * #### 가상키 오버레이 생성
     * *
     * @param {Number} processHandle - 적용할 프로세스 값
     * @param {HotKeyInfo} curHKInfo - 가상키 데이터
     * @param {JKSettings} settings - 설정 데이터
     * @param {bool} isActive - 생성 후 즉시 활성 유무
     * @returns {void}
     */
    static GetOrCreateOverlay(targetHwnd, curHKInfo, settings, isActive := true)
    {
        if(!targetHwnd || targetHwnd = 0)
            return
        ; 창 위치 가져오기
        WinGetClientPos(&outX, &outY, , , "ahk_id " targetHwnd)

        /** @type {Vector2d} */
        curClientPos := Vector2d(outX, outY)

        ; 최신 세션 가져오기
        local newSession := JKSession()

        ; 새 오버레이 생성
        for keyName, keyData in curHKInfo.hotKeyMap
        {
            ; 세션 유효 검사
            if(!newSession.Valid())
            {
                JKUtility.Log("오버레이 매니저 단에서 중단 session : " . newSession.insSessionNum . ", 현재 최신 세션 : " . JKSession.curSessionNum)
                
                this.ClearOverlay()
                break
            }

            ; 최적화용 일시 정지
            Sleep(-1)

            ; ===오버레이 객체 용 인자 설정
            ; 클라 위치에 맞추어 보정
            cx := curClientPos.x + keyData.pos.x
            cy := curClientPos.y + keyData.pos.y

            newOverlayPos := Vector2d(cx, cy)
            newOverlayWidth := 4 + StrLen(keyData.name) * 8
            newOpacity := settings.overlayOpacity

            newGuiOption := "-Caption AlwaysOnTop +ToolWindow -Border"
            newGuiBGColor := settings.overlayBGColor
            ; 사용시 * 뒤에 붙이기
            newGuiText := ["Text", "x3 y2 " , keyData.name]
            ; ========

            ; 기존 풀에 존재 확인
            /** @type {JKOverlay} */
            newOverlay := this.overlayObjPoolMap.Get(keyName, false)
            ; 있으면 업데이트 하고 재사용
            if(newOverlay)
            {
                newOverlay.Update()
            }
            else
            {
                newOverlay := JKOverlay(newOverlayPos, newOpacity, newOverlayWidth, newGuiOption, newGuiBGColor, newGuiText)
            }

            ; 설정에 따라 오버레이 활성화
            newOverlay.SetVisible(isActive)

            if(!newOverlay.isValid)
            {
                JKUtility.Log("생성 중단된 오버레이 자괴 됨 : " . newOverlay.name . newOverlay.session.insSessionNum)
                
                continue
            }    

            ; 오브젝트 풀, 활성 오버레이 맵에 추가
            this.overlayObjPoolMap[newOverlay.name] := newOverlay
            this.overlayActiveMap[newOverlay.name] := newOverlay
        }
    }

    /**
     * #### 오버레이 초기화
     * *
     * @see OverlayInfo
     * @returns {void}
     */
    static ClearOverlay()
    {
        oldMap := this.overlayActiveMap
        this.overlayActiveMap := Map()

        for , overlayObj in oldMap
        {
            overlayObj.Destroy()
        }
    }
}