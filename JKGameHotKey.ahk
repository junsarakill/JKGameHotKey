#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\jsongo_AHKv2-main/src/jsongo.v2.ahk
#Include Utility.ahk
#Include SetGameDefaultPosition.ahk

; MARK: 클래스 선언

/** 가상키 데이터 */
class KeyData
{
    name := ""
    pos := Vector2d()
    type := ""
    description := ""

    __New(sheetDataMap)
    {
        this.name := sheetDataMap["name"]
        this.pos := Vector2d(sheetDataMap["x"], sheetDataMap["y"])
        this.type := sheetDataMap["type"]
        this.description := sheetDataMap["description"]
    }

    ToString()
    {
        return Format("name : {1}, pos : {2}, type : {3}, desc : {4}"
        , this.name, this.pos.ToString(), this.type, this.description)
    }
}

class HotKeyInfo
{
    ; 키 데이터 맵 | key, keyInfo
    hotKeyMap := Map()
    ; 오버레이 맵 | gui Hwnd, overlayInfo
    overlayMap := Map()

    ; 핫키 초기화
    ClearHotKey()
    {
        ; 핫키 제거
        for key, keyData in this.hotKeyMap
        {
            ; 타입 체크
            if(keyData.type = "KEY")
            {                               
                Hotkey("$" keyData.name, "Off") ; 핫키 비활성화
                Hotkey("$" keyData.name " up", "Off") ; 핫키 비활성화
                ; Hotkey("$" keyData.name, "") ; 핫키를 빈 문자열로 설정하여 제거
                ; Hotkey("$" keyData.name " up", "") ; 핫키를 빈 문자열로 설정하여 제거       
            }
        }                                   

        ; 오버레이 제거
        for hwnd, info in this.overlayMap
        {
            info.Destroy()
        }

        this.hotKeyMap := Map()
        this.overlayMap := Map()    
    }

    ; 오버레이 초기화
    /**
     * 
     */
    ClearOverlay()
    {
        for key, value in this.overlayMap
        {
            value.Destroy()
        }

        this.overlayMap := Map()
    }
}

/**
 * 오버레이 정보를 관리하는 클래스
 */
class OverlayInfo
{
    /** @type {Vector2d} */
    pos := Vector2d()
    /** @type {Gui} */
    aGUI := Gui()
    text := "?"
    isVisible := false

    prevOption := ""

    /**
     * @param {number} x 초기 X 좌표
     * @param {number} y 초기 Y 좌표
     * @param {string} text 표시할 텍스트
     * @returns {OverlayInfo}
     */
    __New(x := 0, y := 0, text := "?") {
        this.pos := Vector2d(x,y)
        this.text := text
    }

    SetActive(value := true, option := "")
    {
        if(value)
        {
            ; 옵션 없으면 이전 옵션 재적용
            if(option = "")
                option := this.prevOption

            if(this.prevOption != option)
                this.prevOption := option
            
            this.aGUI.Show(option)
        }
        else
            this.aGUI.Hide()

        this.isVisible := value
    }

    ; 오버레이 제거
    Destroy() {
        this.aGUI.Destroy() ; GUI 닫기
    }

    ; 소멸자
    __Delete() {
        this.Destroy() ; 오버레이 제거 메서드 호출
    }
}

; 설정 구조체
class SettingData
{
    enableOverlay := true

    ToMap()
    {
        map := {
            enableOverlay : this.enableOverlay
        }
        
        return map
    }
}

/** MARK: 스크립트 진행 구조
* 1. 게임명 : 파일명 시트 정보 가져오기 | {@link JKUtility.LoadPrioritySheetData} => {@link AppManager.sheetNameTable}
* 2. 포커스 체크 딜리게이트 등록 | {@link AppManager.BindFocusChange} -> {@link AppManager.ShellHook}
* -> 포커스 체크 | {@link AppManager.CheckFocus}
* -> 현재 매핑 게임명과 같은지 검사
* -> 다르면 키매핑 제거 | {@link AppManager.RemoveHotKey}
* -> 다르면 시트에 해당 게임명 있는지 검사 | {@link AppManager.FindGameName}
*
* 있으면 키매핑 데이터 불러오기 | {@link AppManager.LoadKeyData}
* -> 해당 게임 키매핑 생성 | {@link AppManager.CreateHotKey}  
* 
* 없으면 전체 프로세스에 목표 게임 존재 체크
* -> 없으면 스크립트 종료
* 
* 3. 가상키 누르기 | {@link  AppManager.ClickPos}
* -> 해당 키 좌표 가져오기 | {@link  AppManager.GetKeyPos}
* -> 해당 좌표 클릭 | {@link AppManager.MouseClick}
* -> 가상키 떼기 | {@link AppManager.ReleaseBtn}
* -> 이하 같음
* 
*/

/**
 * #### 스크립트 총괄 클래스
 */
class AppManager 
{
    ; MARK: 변수 영역

    /**
     * #### 설정 json 파일
     * @type {String} 
     * @readonly
     */
    static SETTING_PATH => A_ScriptDir . "\Setting.ini"

    /**
     * #### 설정 데이터
     * @type {SettingData} 
     * @readonly
    */
    static _settings := this.LoadSetting(this.SETTING_PATH) 
    /** @type {SettingData} */
    static SETTINGS => this._settings

    /**
     * #### 기본 가상키 파일명
     * @type {String} 
     */
    static defaultKeySheetName := "JK_DefaultKeyData"
    ; defaultKeySheetPath := keyDataFolder . defaultKeySheetName

    /**
     * #### 게임명 : 파일명 시트 파일명
     * @type {String} 
     */
    static keySheetName := "JK_AHK_SheetNameKey"
    ; keySheetPath := sheetFolder . keySheetName

    /**
     * #### 게임명 : 파일명 정보 구조체 | 배열 { 맵[헤더] : 값 }
     * @type {Array} 
     * @default Ary[Map[Header]:value]
     */
    static sheetNameTable := JKUtility.LoadPrioritySheetData(JKUtility.sheetFolder, this.keySheetName)

    /**
     * #### 현재 목표 게임명
     * @type {String} 
     * @default null
     */
    static curTargetTitle := ""

    /**
     * #### 가상키 데이터
     * @type {HotKeyInfo} 
     * @default null
     */
    static curHKInfo := HotKeyInfo()

    /**
     * #### 스크립트 시작 대기 여부
     * @type {Bool} 
     * @default false
     */
    static checkStart := false

    /** 
     * #### 가상키 오버레이 투명도
     * @type {number} 
     * @range `0` ~ `255`
     * @default `100`  
     */
    static overlayOpacity := 100

    /** @private */
    static _isActive := false
    /**
     * #### 핫키 활성 여부
     * @type {Bool} 
     * @default false
     */
    static IsActive {
        get => this._isActive
        set {
            this._isActive := value
            ; @@ 상태 변경
            ; this.OnActiveChanged()
        }
    }

    ; FIXME 클래스화 끝나고 사용
    static OnActiveChanged()
    {
        if(this.IsActive)
        {
            ; ToolTip("시트에 있음 키매핑 생성: " curTitle)

            processHandle := WinActive(this.curTargetTitle)
            ; 키 매핑 시트 데이터 가져오기
            this.curHKInfo.hotKeyMap := this.LoadKeyData(this.curTargetTitle)

            ; 가상키 생성
            this.CreateHotKey(this.curHKInfo)
            
            ; 오버레이 생성
            this.CreateOverlay(processHandle, this.curHKInfo)
        }
        else if(this.checkStart)
        {
            ; ToolTip("dow" curTitle)
            
            ; 전체 프로세스에 시트 게임이 하나도 없는지 체크
            isEnd := true
            for row in this.sheetNameTable
            {
                if(WinExist(row["gameName"]))
                {
                    isEnd := false
                    break
                }
            }
            
            ; 없으면 스크립트 종료
            if(isEnd)
            {
                ToolTip "목표 게임 없음. 핫 키 종료"
                Sleep 1000
                this.CloseScript
            }
        }
    }
    

    ; MARK: 함수 영역

    /**
     * #### 스크립트 시작 준비
     * *
     * @returns {void}
     */
    static BeginPlay()
    {
        ; 최초 프로그램 시작 대기
        SetTimer(() => AppManager.WaitStartProgram(), -5000)

        ; 포커스 체크 딜리게이트 등록
        this.BindFocusChange()
    }

    /**
     * #### 스크립트 시작 대기
     * *
     * @returns {void}
     */
    
    static WaitStartProgram()
    {
        this.checkStart := true
    }

    /**
     * #### 딜리게이트 바인드
     * *
     * @returns {void}
     */
    
    static BindFocusChange()
    {
        ; 스크립트 핸들을 등록합니다.
        DllCall("RegisterShellHookWindow", "ptr", A_ScriptHwnd)

        ; SHELLHOOK 메시지를 수신합니다.
        OnMessage(DllCall("RegisterWindowMessage", "str", "SHELLHOOK"), ObjBindMethod(this, "ShellHook")) 
    }

    ; 포커스 변경됨
    /**
     * #### 윈도우 포커스 변경시 작동
     * *
     * @see AppManager.BindFocusChange - 바인딩 위치
     * @param {Number} wParam - 이벤트 식별값
     * @param {Number} lParam - 창 핸들
     * @param {*} _ - 미사용 나머지
     * @returns {void}
     */
    static ShellHook(wParam, lParam, *) 
    {
        ; ToolTip("wp:" wParam " lp:" lParam)

        ; HSHELL_RUDEAPPACTIVATED || HSHELL_WINDOWACTIVATED
        if (wParam = 0x8004 || wParam = 4) 
        { 
            ; lParam이 0이면 현재 활성 창의 핸들을 가져옵니다.
            hwnd := lParam || WinExist("A") 

            if(!hwnd) 
                return

            curTitle := WinGetTitle(hwnd)
            ; ToolTip curTitle

            AppManager.CheckFocus(curTitle)
        }
    }

    /**
     * #### 타겟 프로그램 포커스 확인
     * @description 확인 후 스크립트 활성 또는 종료 여부 판단
     * @param {String} curTitle - 현재 포커스된 창 이름
     * @returns {void}
     */
    static CheckFocus(curTitle) 
    {
        ; ToolTip("curtitle: " curTitle)
        ; 현재 목표 게임인지 체크
        if(this.curTargetTitle = curTitle)
            return

        this.curTargetTitle := curTitle

        ; 변경되었으니 키 매핑 제거
        this.RemoveHotKey()
        ; 시트에 있는 게임인지 체크해서 활성 유무 변경
        this.IsActive := this.FindSheetName(curTitle)

        ; @@ 클래스화 끝나면 제거 및 프로퍼티에 작업
        if(this.IsActive)
        {
            ; ToolTip("시트에 있음 키매핑 생성: " curTitle)

            processHandle := WinActive(curTitle)
            ; 키 매핑 시트 데이터 가져오기
            this.curHKInfo.hotKeyMap := this.LoadKeyData(curTitle)

            ; 가상키 생성
            this.CreateHotKey(this.curHKInfo)
            
            ; 오버레이 생성
            this.CreateOverlay(processHandle, this.curHKInfo)
        }
        else if(this.checkStart)
        {
            ; ToolTip("dow" curTitle)
            
            ; 전체 프로세스에 시트 게임이 하나도 없는지 체크
            isEnd := true
            for row in this.sheetNameTable
            {
                if(WinExist(row["gameName"]))
                {
                    isEnd := false
                    break
                }
            }
            
            ; 없으면 스크립트 종료
            if(isEnd)
            {
                ToolTip "목표 게임 없음. 핫 키 종료"
                Sleep 1000
                this.CloseScript
            }
        }
    }

    /**
     * #### 해당 게임명에 대한 가상키 데이터 불러오기 + 기본 키 데이터
     * *
     * @param {String} gameName - 게임명
     * @returns {Map} - 가상키 데이터 맵
     */
    static LoadKeyData(gameName)
    {
        ; 게임명 시트에 존재 확인
        sheetName := this.FindSheetName(gameName)

        ; 비 존재시 함수 종료
        if(sheetName = false)
            return Map()

        gameKeyData := JKUtility.LoadPrioritySheetData(JKUtility.keyDataFolder, sheetName)

        defaultKeyData := JKUtility.LoadPrioritySheetData(JKUtility.keyDataFolder, this.defaultKeySheetName)

        ; 결합
        fullKeyData := []
        fullKeyData.Push(gameKeyData*)
        fullKeyData.Push(defaultKeyData*)

        ; 반환 값 선언
        keyDataMap := Map()
        ; 가상키 데이터 클래스로 변환
        for oneData in fullKeyData
        {
            keyDataMap[oneData["name"]] := KeyData(oneData)
        }

        ; 가상키 데이터 맵 반환
        return keyDataMap
    }
    
    /**
     * #### 게임명으로 가상키 시트 파일명 찾기
     * @description 부가기능으로 해당 게임명이 시트에 존재하는지 확인 가능
     * *
     * @param {String} gameName - 게임명
     * @returns {String} - 시트 파일명
     */
    static FindSheetName(gameName)
    {
        sheetName := ""

        ; 시트 이름 테이블에서 찾아보기
        for row in this.sheetNameTable
        {
            if(row["gameName"] = gameName)
            {
                sheetName := row["sheetName"]
                break
            }
        }

        return sheetName
    }

    /**
     * #### 가상키 생성
     * *
     * @param {HotKeyInfo} curHKInfo - 가상키 데이터
     * @returns {void}
     */
    static CreateHotKey(curHKInfo)
    {
        for key, keyData in curHKInfo.hotKeyMap
        {
            ; 타입 체크
            if(keyData.type = "KEY")
            {
                ; 핫 키 생성
                Hotkey("$" keyData.name, ObjBindMethod(this, "ClickPos"), "On")
                Hotkey("$" keyData.name " up", ObjBindMethod(this, "ReleaseBtn"), "On")
            }
        }
    }

    ; @@ 여기부터 다시 작업
    static CreateOverlay(processHandle, curHKInfo)
    {
        if(!processHandle || processHandle = 0)
            return
        ; 창 위치 가져오기
        pos := WinGetClientPos(&outX, &outY, &outWidth, &outHeight, "ahk_id " processHandle)

        /** @type {Vector2d} */
        curClientPos := Vector2d(outX, outY)

        ; 새 오버레이 생성
        for key, keyData in curHKInfo.hotKeyMap
        {
            /** @type {OverlayInfo} */
            newOverlay := OverlayInfo()

            ; GUI 생성 | 포커스 비활성화
            newOverlay.aGUI := Gui("LastFound -Caption AlwaysOnTop +ToolWindow -Border")

            newOverlay.aGUI.Color := "dfdfdf"
            newOverlay.aGUI.Add("Text", "x3 y2 " , keyData.name)
            ; 투명도 0~255
            WinSetTransparent(this.overlayOpacity, newOverlay.aGUI.hwnd)

            ; 클라 위치에 맞추어 보정
            cx := curClientPos.x + keyData.pos.x
            cy := curClientPos.y + keyData.pos.y

            weight := 4 + StrLen(keyData.name) * 8
        
            oh := newOverlay.aGUI.Hwnd
            ; 포커스 되지 않게 설정
            DllCall("SetWindowLong", "Ptr", oh, "Int", -20, "Int", 0x80000 | 0x20 | 0x8)

            ; 오버레이 위치 업데이트
            option := "NoActivate w" weight " h15 x" cx " y" cy
            ; 설정에 따라 오버레이 활성화
            newOverlay.SetActive(this.SETTINGS.enableOverlay, option)

            
            ; 오버레이 맵에 추가
            curHKInfo.overlayMap[newOverlay.aGUI.Hwnd] := newOverlay
        }
    }

    static RemoveHotKey()
    {
        
        this.curHKInfo.ClearHotKey()
    }

    ; 해당 키 좌표 가져오기
    static GetKeyPos(&pos2D, key)
    {
        ; $ 잘라내기
        key := StrReplace(key, "$")
        key := StrReplace(key, " up")

        ; 핫 키 인지 확인
        if(!this.curHKInfo.hotKeyMap.Has(key))
            return false

        if(this.curHKInfo.hotKeyMap[key].type != "KEY")
            return false

        ; 해당 키 좌표 가져오기
        pos2D := this.curHKInfo.hotKeyMap[key].pos

        return true
    }

    ; 클릭 : 입력 가능 시만
    static ClickPos(hotKey)
    {
        ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
        if(!this.GetKeyPos(&pos2D, hotKey))
            return
        
        ; 현재 활성창 체크
        if(!WinActive(this.curTargetTitle))
            return

        ; 해당 좌표 클릭
        MouseClick('L',pos2D.x,pos2D.y, 1,2,'D')
        return
    }

    static ReleaseBtn(hotKey)
    {   
        ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
        if(!this.GetKeyPos(&pos2D, hotKey))
            return
        
        ; 현재 활성창 체크
        if(!WinActive(this.curTargetTitle))
            return

        ; 해당 좌표 클릭 해제
        MouseClick('L',pos2D.x,pos2D.y, 1,2,'U')
        return                       
    }

    static ToggleOverlay()
    {
        this.SETTINGS.enableOverlay := !this.SETTINGS.enableOverlay
        ; ToolTip(this.SETTINGS.enableOverlay " asdadawd")

        processHandle := WinActive(this.curTargetTitle)

        if(this.SETTINGS.enableOverlay)
            this.CreateOverlay(processHandle, this.curHKInfo)
        else
            this.curHKInfo.ClearOverlay()
    }

    ; 세팅 불러오기
    static LoadSetting(path)
    {
        jsonData := FileRead(path, "UTF-8")
        ; json map 변환 => 구조체로 변환
        mapData := jsongo._Parse(jsonData)

        return JKUtility.MapToClass(mapData, SettingData)
    }

    ; 세팅 저장하기
    static SaveSetting(settingData, path) 
    {
        jsonString := jsongo.Stringify(settingData) ; JSON 문자열로 변환

        ; 파일을 쓰기 모드로 열기
        file := FileOpen(path, "w") ; "w" 모드는 덮어쓰기 모드
        if !file 
        {
            MsgBox("파일을 열 수 없습니다: " path)
            return
        }

        file.Write(jsonString) ; JSON 문자열 쓰기
        file.Close() ; 파일 닫기
    }

    ; 스크립트 종료
    static CloseScript()
    {
        ; 설정 저장
        settingMap := this.SETTINGS.ToMap()
        this.SaveSetting(settingMap, this.SETTING_PATH)

        ExitApp
    }
}



; MARK: 프로그램 실행 영역

; 관리자 권한 실행
JKUtility.RunAdmin()

; shell32.dll의 44번 아이콘(별 모양)을 트레이 아이콘으로 설정
TraySetIcon("JKGameHotKeyICO.ico")

; 프로그램 시작
AppManager.BeginPlay()


; MARK: 입력 영역

; XXX 디버그용 즉시 체크 시작
[ & Esc::AppManager.WaitStartProgram                   

; 종료 키
] & Esc::AppManager.CloseScript

; @@ 스크립트 활성/비활성화 토글
; 310 line 에 있는 가상키 제거, 가상키 생성 부분을 따와서 토글 함수에 추가
; XXX isActive 변경 시 작동하도록 프로퍼티화 해서 통합하는 것도 좋을듯.
; Status {                        ; 변수와 프로퍼티를 하나의 블록처럼 관리
;         get => this._status
;         set => this._status := value
;     }
; ] & `::



; MARK: 활성화 입력 영역
#HotIf AppManager.IsActive

; 오버레이 토글
` up::AppManager.ToggleOverlay

; 현재 게임 기본 위치로
F7::SetGameDefaultPosition.RunSetGameDefaultPosition


#HotIf 

