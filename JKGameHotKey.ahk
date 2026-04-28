#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib\jsongo_AHKv2-main/src/jsongo.v2.ahk
#Include Utility.ahk
#Include SetGameDefaultPosition.ahk
#Include HotKeyManager.ahk

; MARK: 클래스 선언

/** 가상키 데이터 */
class KeyData
{
    /** @type {String} */
    name := ""

    /** @type {Vector2d} */
    pos := Vector2d()

    /** @type {String} */
    type := ""

    /** @type {String} */
    description := ""

    /**
     * #### 생성자
     * *
     * @param {Map} sheetDataMap - 가상키 데이터 시트 맵 | 헤더 name, x, y, type, description
     * @returns {void}
     */
    __New(sheetDataMap := [])
    {
        this.name := sheetDataMap["name"]
        this.pos := Vector2d(sheetDataMap["x"], sheetDataMap["y"])
        this.type := sheetDataMap["type"]
        this.description := sheetDataMap["description"]
    }

    /**
     * #### 클래스 데이터 출력
     * *
     * @returns {String}
     */
    ToString()
    {
        return Format("name : {1}, pos : {2}, type : {3}, desc : {4}"
        , this.name, this.pos.ToString(), this.type, this.description)
    }
}


/** 가상키 데이터, 오버레이 객체를 전부 가지고 있는 청사진 클래스 */
class HotKeyInfo
{
    /**
     * #### 가상키 데이터 맵
     * @type {Map} 
     * @default null
     * @see keyData
     * @example for key, keyData in this.hotKeyMap
     */
    hotKeyMap := Map()

    /**
     * #### 가상키 오버레이 맵
     * @type {Map} 
     * @default null
     * @see OverlayInfo
     * @example for guiHwnd , overlayInfo in this.overlayMap
     */
    overlayMap := Map()
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

    /** @type {String} */
    text := "?"

    /** @type {Bool} */
    isVisible := false

    /** @type {String} */
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

    /**
     * #### 오버레이 활성화 여부 설정
     * *
     * @param {Bool} value - 활성화 여부
     * @param {String} option - gui 옵션
     * @returns {void}
     */
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

    /**
     * #### 오버레이 제거
     * *
     * @returns {void}
     */
    Destroy() {
        this.aGUI.Destroy()
    }

    ; 소멸자
    __Delete() {
        this.Destroy()
    }
}

/** 설정 클래스
 * @description 설정 저장에 필요없는 변수는 _ 붙이기
 */
class SettingData
{
    /** @type {Bool} */
    enableOverlay := true

    /** @type {String} */
    version := "1.0.0"

    /**
     * #### 설정 파일 경로
     * @type {String} 
     * @readonly
     */
    static _PATH => A_ScriptDir . "\Setting.json"

    /**
     * #### 설정 저장
     * *
     * @returns {bool} - 저장 성공 유무
     */
    Save()
    {
        try
        {
            jsonStr := jsongo.Stringify(this.ToMap(), , 4)

            ; 기존 파일 제거
            if(FileExist(SettingData._PATH))
                FileDelete(SettingData._PATH)

            FileAppend(jsonStr, SettingData._PATH, "UTF-8")

            return true
        }
        catch Error as e 
        {
            MsgBox(
                "오류 발생 위치: " . e.Line . "번째 줄`n" .
                "발생 함수: " . e.What . "`n" .
                "메시지: " . e.Message
            )

            return false
        }
    }

    /**
     * #### 설정 불러오기
     * *
     * @returns {SettingData} - 설정 객체
     */
    static Load()
    {
        ; 설정 파일 존재 확인
        if(!FileExist(this._PATH))
            ; 없다면 초기값 반환
            return SettingData()

        try {
            jsonData := FileRead(this._PATH, "UTF-8")
            ; json => map 변환
            mapData := jsongo._Parse(jsonData)
            
            ; map => 클래스 변환
            return JKUtility.MapToClass(mapData, SettingData)
        } 
        catch Error as e 
        {
            MsgBox("정상 로드 실패, 초기값 반환: " . e.Message)

            return SettingData()
        }    

    }

    /**
     * #### 필요 변수만 저장용 맵으로 변환
     * *
     * @returns {Map} - 설정 저장용
     */
    ToMap()
    {
        /** @type {Map} */
        resultMap := Map()

        for name, value in this.OwnProps()
        {
            ; 불필요 변수 스킵
            if(SubStr(name, 1, 1) = "_")
                continue

            resultMap[name] := value
        }

        return resultMap
    }
}

/** MARK: 스크립트 진행 구조
 * 0. 스크립트 시작 | {@link AppManager.BeginPlay}
 * 1. 게임명 : 파일명 시트 정보 가져오기 | {@link JKUtility.LoadPrioritySheetData} => {@link AppManager.sheetNameTable}
 * 2. 포커스 체크 딜리게이트 등록 | {@link AppManager.BindFocusChange} -> {@link AppManager.ShellHook}
 * -> 포커스 체크 | {@link AppManager.CheckFocus}
 * -> 현재 매핑 게임명과 같은지 검사
 * -> 다르면 키매핑 제거 | {@link HotKeyManager.RemoveHotKey}
 * -> 다르면 시트에 해당 게임명 있는지 검사 | {@link AppManager.FindGameName}
 *
 * 있으면 키매핑 데이터 불러오기 | {@link AppManager.LoadKeyData}
 * -> 해당 게임 키매핑 생성 | {@link HotKeyManager.CreateHotKey}  
 * 
 * 없으면 전체 프로세스에 목표 게임 존재 체크
 * -> 없으면 스크립트 종료 {@link AppManager.CloseScript}
 * 
 * 3. 가상키 누르기 | {@link  HotKeyManager.OnKeyDown}
 * -> 해당 키 좌표 가져오기 | {@link  HotKeyManager.GetKeyPos}
 * -> 해당 좌표 클릭 | {@link HotKeyManager.OnKeyDown}
 * -> 가상키 떼기 | {@link HotKeyManager.OnKeyUp}
 * 
 */

/**
 * #### 스크립트 총괄 클래스
 */
class AppManager 
{
    ; MARK: 변수 영역

    /** @type {SettingData} */
    static _settings := SettingData.Load()
    /**
     * #### 설정 데이터
     * @type {SettingData} 
     * @readonly
    */
    static SETTINGS => this._settings

    /**
     * #### 기본 가상키 파일명
     * @type {String} 
     * @readonly
     */
    static DEFAULT_KEY_SHEET_NAME => "JK_DefaultKeyData"

    /**
     * #### 게임명 : 파일명 시트 파일명
     * @type {String} 
     * @readonly
     */
    static KEY_SHEET_NAME => "JK_AHK_SheetNameKey"

    /**
     * #### 게임명 : 파일명 정보 구조체 | 배열 { 맵[헤더] : 값 }
     * @type {Array} 
     * @default Ary[Map[Header]:value]
     */
    static sheetNameTable := JKUtility.LoadPrioritySheetData(JKUtility.SHEET_FOLDER, this.KEY_SHEET_NAME)

    /** @type {String} */
    static _curTargetTitle := ""
    /**
     * #### 현재 목표 게임명
     * @type {String} 
     * @default null
     * @description 목표 변경시 가상키 재할당
     */
    static CurTargetTitle {
        get => this._curTargetTitle
        set {
            this._curTargetTitle := value

            ; 가상키 매니저에 업데이트
            HotKeyManager.OnTargetChanged(value)

            ; 현재 오버레이 제거
            this.ClearOverlay()

            ; 시트에 있는 게임인지 체크해서 활성 유무 변경
            this.IsActive := this.FindSheetName(value)
            /** {@link AppManager.OnActiveChanged} */ 
        }
    }
    

    /**
     * #### 전체 가상키 데이터
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
            ; 상태 변경
            this.OnActiveChanged()
        }
    }

    /** @private */
    static _isScriptActive := true
    /**
     * #### 스크립트 활성 여부
     * @type {bool} 
     * @default true
     */
    static IsScriptActive {
        get => this._isScriptActive
        set {
            this._isScriptActive := value
            ; 현재 가상키를 제거 처리
            HotKeyManager.RemoveHotKey()

            this.ClearOverlay()
            ; true로 변경될때는 isactive의 활성 유무 다시 체크
            if(value == true)
                this.IsActive := this.FindSheetName(this.curTargetTitle)
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
        if(this.CurTargetTitle = curTitle)
            return

        this.CurTargetTitle := curTitle
    }

    /**
     * #### 활성 상태 변경시 발동
     * *
     * @see AppManager.IsActive
     * @description 목표에 맞는 가상키 생성 또는 스크립트 종료 체크
     * @returns {void}
     */
    static OnActiveChanged()
    {
        if(this.IsScriptActive && this.IsActive)
        {
            ; ToolTip("시트에 있음 키매핑 생성: " curTitle)

            processHandle := WinActive(this.CurTargetTitle)
            ; 키 매핑 시트 데이터 가져오기
            this.curHKInfo.hotKeyMap := this.LoadKeyData(this.CurTargetTitle)
            ; 가상키 매니저에 데이터 업데이트
            HotKeyManager.SetupHotKey(this.curHKInfo)

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
                ToolTip("목표 게임 없음. 핫 키 종료")
                Sleep(1000) 
                this.CloseScript()
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

        gameKeyData := JKUtility.LoadPrioritySheetData(JKUtility.KEY_DATA_FOLDER, sheetName)

        defaultKeyData := JKUtility.LoadPrioritySheetData(JKUtility.KEY_DATA_FOLDER, this.DEFAULT_KEY_SHEET_NAME)

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

    ; MARK: 오버레이 관리 영역

    /**
     * #### 가상키 오버레이 생성
     * *
     * @param {Number} processHandle - 적용할 프로세스 값
     * @param {HotKeyInfo} curHKInfo - 가상키 데이터
     * @returns {void}
     */
    static CreateOverlay(targetHwnd, curHKInfo)
    {
        if(!targetHwnd || targetHwnd = 0)
            return
        ; 창 위치 가져오기
        WinGetClientPos(&outX, &outY, , , "ahk_id " targetHwnd)

        /** @type {Vector2d} */
        curClientPos := Vector2d(outX, outY)

        ; 새 오버레이 생성
        for , keyData in curHKInfo.hotKeyMap
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

    /**
     * #### 오버레이 토글
     * *
     * @returns {void}
     */
    static ToggleOverlay()
    {
        this.SETTINGS.enableOverlay := !this.SETTINGS.enableOverlay
        ; ToolTip(this.SETTINGS.enableOverlay " asdadawd")

        processHandle := WinActive(this.CurTargetTitle)

        if(this.SETTINGS.enableOverlay)
            this.CreateOverlay(processHandle, this.curHKInfo)
        else
            this.ClearOverlay()
    }

    ; 오버레이 초기화
    /**
     * #### 오버레이 초기화
     * *
     * @see OverlayInfo
     * @returns {void}
     */
    static ClearOverlay()
    {
        for , overlayObj in this.curHKInfo.overlayMap
        {
            overlayObj.Destroy()
        }

        this.curHKInfo.overlayMap := Map()
    }

    /**
     * #### 스크립트 활성화 토글
     * *
     * @returns {void}
     */
    static ToggleScript()
    {
        this.IsScriptActive := !this.IsScriptActive
    }

    /**
     * #### 스크립트 종료
     * *
     * @returns {void}
     */
    static CloseScript()
    {
        ; 설정 저장
        this.SETTINGS.Save()

        ExitApp()
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
[ & Esc::AppManager.WaitStartProgram()                   

; 종료 키
] & Esc::AppManager.CloseScript()

; 스크립트 활성/비활성화 토글
] & ` up::AppManager.ToggleScript()



; MARK: 활성화 입력 영역
#HotIf AppManager.IsActive

; 오버레이 토글 키
` up::AppManager.ToggleOverlay()

; 현재 게임 기본 위치로
F7::SetGameDefaultPosition.RunSetGameDefaultPosition()


#HotIf 

