#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKHotKey.ahk
#Include JKSession.ahk
#Include JKSettings.ahk

/************************************************************************
 * @description 가상키 담당 관리 클래스
 * @author JKAKK
 * @date 2026/06/08
 * @version 0.0.6
 ***********************************************************************/
; 임시 커서 대체용 gui
class FakeCursor
{
    /**
     * #### 가짜커서 gui
     * @type {Gui} 
     * @default null
     */
    static FakeCursorGUI := unset

    static _isVisible := false
    static IsVisible
    {
        get => this._isVisible
        set
        {
            this._isVisible := Value
            ; 진짜 커서 활/비
            JKUtility.SetVisibleCursor(!value)
            if(value)
            {
                ; 64비트 좌표 데이터를 담을 포인트 버퍼 생성 (X, Y 각각 4바이트씩 총 8바이트)
                rect := Buffer(8)
                
                ; 윈도우 API를 호출하여 CoordMode와 상관없는 '스크린 절대 좌표'를 즉시 획득
                DllCall("User32.dll\GetCursorPos", "Ptr", rect)
                
                ; 버퍼에서 X좌표(앞 4바이트)와 Y좌표(뒤 4바이트) 추출
                mx := NumGet(rect, 0, "Int")
                my := NumGet(rect, 4, "Int")
                
                ; 원래 자리에 가짜 커서 GUI를 활성화 없이 띄움
                this.FakeCursorGUI.Show("X" . mx . " Y" . my . " NoActivate")

                ; 검은색(000000) 부분을 완전히 투명하게 만듦 (Show 다음에 호출해야 적용됩니다)
                WinSetTransColor("000000", this.FakeCursorGUI.Hwnd)
            }
            ; 꺼질 때: GUI를 숨김 (메모리 파괴 없이 숨기기만 함)
            else
                this.FakeCursorGUI.Hide()
        }
    }

    ; @@ 좀 더 우아하게 할 순 없을까?
    ; 클래스가 최초로 메모리에 로드될 때 GUI를 1번만 빌드 (정적 이니셜라이저)
    static __New()
    {
        ; 클릭 관통, 타이틀바 제거, 최상단 설정
        this.FakeCursorGUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")

        ; GUI의 배경색을 순수 검은색(000000)으로 설정
        this.FakeCursorGUI.BackColor := "000000"

        ; GUI 내부의 자동 여백(Margin)을 가로/세로 모두 0으로 설정
        this.FakeCursorGUI.MarginX := 0
        this.FakeCursorGUI.MarginY := 0
        
        this.FakeCursorGUI.AddPic("x0 y0 w32 h32 Icon1", A_WinDir "\Cursors\aero_arrow.cur")

        this.IsVisible := false
    }
}

class HotKeyManager
{
    ; MARK: 변수 영역
    /**
     * #### 전체 가상키 오브젝트 풀
     * @type {Map} 
     * @default null
     * @example hotKeyObjPoolMap[keyName] := oneHotKey
     */
    static hotKeyObjPoolMap := Map()

    /**
     * #### 현재 활성화된 가상키 맵
     * @type {Map} 
     * @default null
     */
    static curActiveHotKeyMap := Map()

    /**
     * #### 현재 목표 게임명
     * @type {String} 
     * @default ""
     */
    static curTargetTitle := ""

    ; 마우스 원래 위치
    /** @type {Vector2d} */
    static mouseOriginAxis := Vector2d()

    ; 핫키 작동 down 상태
    static isPressed := false

    ; MARK: 함수 영역

    /**
     * #### 목표 게임 변경
     * *
     * @description 변경시 현재 활성화된 가상키 제거
     * @param {String} newTargetTitle - 변경된 게임명
     * @returns {void}
     */
    static OnTargetChanged(newTargetTitle)
    {
        this.curTargetTitle := newTargetTitle
    }

    /**
     * #### 가상키 데이터 업데이트
     * *
     * @description 데이터 참조로 받고 신규 가상키 생성
     * @param {HotKeyInfo} hkInfo - 새 가상키 데이터
     * @returns {void}
     */
    static SetupHotKey(hkInfo)
    {
        this.CreateAllHotKey(hkInfo)
    }

    /**
     * #### 가상키 생성
     * *
     * @see JKHotKey|@see HotKeyInfo
     * @param {HotKeyInfo} hkInfo - 가상키 데이터
     * @returns {void}
     */
    static CreateAllHotKey(hkInfo)
    {
        ; 현재 세션
        local newSession := JKSession()
        for , keyData in hkInfo.hotKeyMap
        {
            ; 유효 검사
            if(!newSession.Valid())
            {
                ; 현재 생성 중단
                JKUtility.Log("핫키 매니저 단에서 중단 session : " . newSession.insSessionNum . ", 현재 최신 세션 : " . JKSession.CurSessionNum)
                
                this.RemoveHotKey()
                break
            }

            ; 최적화용 일시 정지
            Sleep(-1)

            ; 핫키 가져오기
            this.GetOrCreateHotKey(keyData, "down")
            this.GetOrCreateHotKey(keyData, "up")
        }
    }  

    /**
     * #### 핫키 데이터 있으면 재사용, 없으면 생성
     * *
     * @see KeyData
     * @param {KeyData} keyData - 핫키 데이터
     * @param {String} inputType - 실제 키 입력 타입 | down, up
     * @returns {bool} - 제작 성공
     */
    static GetOrCreateHotKey(keyData, inputType := "down")
    {
        ; 타입 체크
        if(keyData.type != "KEY")
            return false

        newHKName := "$" . keyData.name
        ; 인풋 타입에 따라 결정
        switch  inputType {
            case "down":
            case "up":
                newHKName .= " up"

            default:
                JKUtility.Log("잘못된 가상키 입력 타입 요청: " . keyData.ToString())
                return false
        }

        ; 기존 풀 존재 확인
        /** @type {JKHotKey} */
        newHotKey := this.hotKeyObjPoolMap.Get(newHKName, false)
        ; 해당 핫키가 이미 생성된 경우 내용 업데이트 및 활성화
        if(newHotKey)
        {
            this.hotKeyObjPoolMap[newHKName].Update(keyData)
            this.hotKeyObjPoolMap[newHKName].Bind()
        }
        ; 없으면 새로 생성
        else
        {
            newHotKey := JKHotKey(newHKName, this.OnKeyEvent.Bind(this, inputType), keyData, "On", )
            ; 풀에 추가
            this.hotKeyObjPoolMap[newHKName] := newHotKey
        }

        ; 현재 활성화 풀에 추가
        this.curActiveHotKeyMap[newHKName] := newHotKey
    }

    /**
     * #### 가상키 초기화
     * *
     * @description 가상키 비활성화, 맵 초기화
     * @returns {void}
     */
    static RemoveHotKey()
    {
        oldMap := this.curActiveHotKeyMap
        this.curActiveHotKeyMap := Map()

        ; 핫키 비활성화
        for , oneHKObj in oldMap
        {
            oneHKObj.Unbind()
        }                                
    }

    /**
     * #### 해당 키 좌표 가져오기
     * *
     * @param {Vector2d} pos2D - 해당 가상키 좌표
     * @param {String} key - 키 이름
     * @returns {Bool} - 가져오기 성공 유무
     */
    static GetKeyPos(&pos2D, key)
    {
        /** @type {JKHotKey} */
        hkObj := this.hotKeyObjPoolMap.Get(key, "")
        if(hkObj == "")
        {
            JKUtility.Log("비존재 키 요청: " . key)
            return false
        }

        targetHwnd := WinExist(this.curTargetTitle)
        /** @type {Vector2d} */
        winPos := Vector2d.WinGetClientSize(targetHwnd)

        pos2D := winPos.Multiply(hkObj.pos)
        
        return true
    }

    /**
     * #### 클릭 이벤트 : 입력 가능시
     * *
     * @see HotKeyManager.GetOrCreateHotKey - 바인딩 위치
     * @param {String} keyName - 키 이름
     * @param {String} inputType - 입력 타입
     * @returns {void}
     */
    static OnKeyEvent(inputType, keyName)
    {
        ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
        if(!this.GetKeyPos(&pos2D, keyName))
            return
        
        ; 현재 활성창 체크
        if(!WinActive(this.curTargetTitle))
            return

        /** @type {JKHotKey} */
        hkObj := this.hotKeyObjPoolMap.Get(keyName, "")
        if(hkObj = "")
            return
        
        downOrUp := ''
        switch inputType 
        {
            case "down":
            {
                if(this.isPressed)
                    return
                this.isPressed := true

                downOrUp := 'D'
                ; 마우스 원래 위치 기록
                MouseGetPos(&mx,&my)
                this.mouseOriginAxis := Vector2d(mx,my)
                ; 진짜 커서는 숨기고 가짜 커서 활성화(깜빡임 방지)
                FakeCursor.IsVisible := true
            }
            case "up":
            {
                if(!this.isPressed)
                    return
                this.isPressed := false

                downOrUp := 'U'
            }
            default:
                JKUtility.Log("잘못된 inputType : " . inputType)
                return
        }

        ; 해당 좌표 클릭
        MouseClick('L',pos2D.x,pos2D.y, 1,2,downOrUp)

        ; 키를 떼면 마우스 원래 위치로 이동
        if(downOrUp = 'U')
        {
            ; 너무 빨리 원복하면 키가 씹히는 경우 발생. 지연 약간
            SetTimer(() => 
            MouseMove(this.mouseOriginAxis.x, this.mouseOriginAxis.y, 0)
            FakeCursor.IsVisible := false, -20)
        }
    }
}