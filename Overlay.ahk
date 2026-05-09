#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKSession.ahk

/************************************************************************
 * @description 오버레이 관련 스크립트
 * @author JKAKK
 * @date 2026/05/09
 * @version 0.0.2
 ***********************************************************************/


/**
 * 오버레이 정보를 관리하는 클래스
 */
class JKOverlay
{
    /** @type {Vector2d} */
    pos := Vector2d()

    /** @type {Gui} */
    aGUI := unset

    /** @type {String} */
    name := "?"

    /** @type {Bool} */
    isVisible := false

    /** @type {String} */
    prevGuiShowOption := ""

    ; 세션
    session := unset
    
    ; 존재 유효 유무
    isValid := true

    /**
     * @param {number} x 초기 X 좌표
     * @param {number} y 초기 Y 좌표
     * @param {string} name 표시할 텍스트
     * @returns {OverlayInfo}
     */
    __New(pos := Vector2d(), opacity := 255, width := 12
        , guiOption := "", guiBGColor := "FFFFFF", guiText := ["","",""]) 
    {
        this.session := JKSession()
        this.isValid := true
        this.name := guiText[2]

        ; gui 생성
        this.aGUI := Gui(guiOption)
        this.aGUI.BackColor := guiBGColor
        this.aGUI.Add(guiText*)
        ; 투명도
        WinSetTransparent(opacity, this.aGUI.Hwnd)
        ; 포커스 되지 않게 설정
        DllCall("SetWindowLong", "Ptr", this.aGUI.Hwnd, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)

        this.pos := pos
        this.width := width

        this.guiShowOption := "NoActivate w" . this.width . " h15 x" . this.pos.x . " y" . this.pos.y
    }

    /**
     * #### 오버레이 활성화 여부 설정
     * *
     * @param {Bool} value - 활성화 여부
     * @returns {void}
     */
    SetActive(value := true)
    {
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

            ; 옵션 없으면 이전 옵션 재적용
            if(this.guiShowOption = "")
                this.guiShowOption := this.prevGuiShowOption

            if(this.prevGuiShowOption != this.guiShowOption)
                this.prevGuiShowOption := this.guiShowOption
            
            this.aGUI.Show(this.guiShowOption)
        }
        else
            this.aGUI.Hide()

        this.isVisible := value
    }

    /**
     * #### 오버레이 제거
     * *
     * @returns {void}
     */
    Destroy() {
        try this.aGUI.Hide()
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
class overlayManager
{
    /**
     * #### 전체 오버레이 오브젝트 풀
     * @type {Map} 
     * @default null
     * @example overlayObjPoolMap[guiHwnd] := oneOverlay
     * @description guiHwnd == Gui.Hwnd, oneOverlay == Overlay()
     */
    static overlayObjPoolMap := Map()

    static overlayOpacity := 100
    static overlayBGColor := "dfdfdf"

    /**
     * #### 가상키 오버레이 생성
     * ;FIXME 설정 데이터 받아서 적용하기
     * *
     * @param {Number} processHandle - 적용할 프로세스 값
     * @param {HotKeyInfo} curHKInfo - 가상키 데이터
     * @param {bool} isActive - 생성 후 즉시 활성 유무
     * @returns {void}
     */
    static CreateOverlay(targetHwnd, curHKInfo, isActive := false)
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
        for , keyData in curHKInfo.hotKeyMap
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

            ; 오버레이 객체 용 인자 설정
            ; 클라 위치에 맞추어 보정
            cx := curClientPos.x + keyData.pos.x
            cy := curClientPos.y + keyData.pos.y

            newOverlayPos := Vector2d(cx, cy)
            newOverlayWidth := 4 + StrLen(keyData.name) * 8
            newOpacity := this.overlayOpacity

            newGuiOption := "-Caption AlwaysOnTop +ToolWindow -Border"
            newGuiBGColor := this.overlayBGColor
            ; 사용시 * 뒤에 붙이기
            newGuiText := ["Text", "x3 y2 " , keyData.name]
            ; ========
            
            /** @type {JKOverlay} */
            newOverlay := JKOverlay(newOverlayPos, newOpacity, newOverlayWidth, newGuiOption, newGuiBGColor, newGuiText)
            
            ; 설정에 따라 오버레이 활성화
            newOverlay.SetActive(isActive)

            if(!newOverlay.isValid)
            {
                JKUtility.Log("예전 오버레이 자괴 됨 : " . newOverlay.name . newOverlay.session.insSessionNum)
            }    

            ; 오버레이 맵에 추가
            ; @@ 오브젝트 풀, 그리고 현재 활성화된 풀 에도 추가
            curHKInfo.overlayMap[newOverlay.aGUI.Hwnd] := newOverlay
        }
    }

    /**
     * #### 오버레이 초기화
     * ;FIXME appmanager 에서 curhkinfo의 overlaymap 제거함.
     * 따라서 자체 풀이랑 활성화 풀에서 비활성화 하게 변경필요.
     * *
     * @see OverlayInfo
     * @returns {void}
     */
    static ClearOverlay()
    {
        oldMap := this.curHKInfo.overlayMap
        this.curHKInfo.overlayMap := Map()

        for , overlayObj in oldMap
        {
            overlayObj.Destroy()
        }
    }
}