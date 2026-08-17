#Requires AutoHotkey v2.0
#SingleInstance Ignore
#Include Utility.ahk
#Include SetGameDefaultPosition.ahk
#Include HotKeyManager.ahk
#Include JKSession.ahk
#Include JKSettings.ahk
#Include Overlay.ahk
#Include JKHotKeyInfo.ahk
#Include JKEditManager.ahk

/************************************************************************
 * @description 스크립트 총괄 클래스
 * @author JKAKK
 * @date 2026/06/15
 * @version 0.3.0
 ***********************************************************************/

/** MARK: 스크립트 진행 구조
 * 0. 스크립트 시작 | {@link AppManager.BeginPlay}
 * 1. 게임명 : 파일명 시트 정보 가져오기 | {@link JKUtility.LoadPrioritySheetData} => {@link AppManager.sheetNameTable}
 * 2. 포커스 체크 딜리게이트 등록 | {@link AppManager.BindFocusChange} -> {@link AppManager.ShellHook}
 * -> 포커스 체크 | {@link AppManager.CheckFocus}
 * -> 현재 매핑 게임명과 같은지 검사
 * -> 다르면 키매핑 제거 | {@link HotKeyManager.RemoveHotKey}
 * -> 다르면 시트에 해당 게임명 있는지 검사 | {@link AppManager.FindSheetName}
 *
 * 있으면 키매핑 데이터 불러오기 | {@link AppManager.LoadKeyData}
 * -> 해당 게임 키매핑 생성 | {@link HotKeyManager.CreateAllHotKey}  
 * -> 오버레이 생성 | {@link OverlayManager.GetOrCreateOverlay}
 * 
 * 없으면 전체 프로세스에 목표 게임 존재 체크
 * -> 없으면 스크립트 종료 {@link AppManager.CloseScript}
 * -> 변경된 가상키 데이터 저장 {@link AppManager.SaveHKDataToCSV}
 * 
 * 3. 가상키 누르기 | {@link  HotKeyManager.OnKeyEvent}
 * -> 해당 키 좌표 가져오기 | {@link  HotKeyManager.GetKeyPos}
 * 
 */


/**
 * #### 스크립트 총괄 클래스
 */
class AppManager 
{
    ; MARK: 변수 영역

    /** @type {JKSettings} */
    static _settings := JKSettings.Load()
    /**
     * #### 설정 데이터
     * @type {JKSettings} 
     * @see JKSettings
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
     * #### 게임명 : 파일명 정보 마스터맵 | 맵 [마스터키헤더 : {맵[헤더] : 값}]
     * @type {Map<String, Map<String, String>>} 
     * @default Map["gameName":{Map[header:value]}]
     */
    static sheetNameTable := JKUtility.LoadPrioritySheetData(JKUtility.SHEET_FOLDER, this.KEY_SHEET_NAME)

    /** @type {String} */
    static _curTargetTitle := ""
    /**
     * #### 현재 목표 게임명
     * @type {String} 
     * @description 목표 변경시 가상키 재할당
     */
    static CurTargetTitle {
        get => this._curTargetTitle
        set 
        {
            this._curTargetTitle := value

            ; 가상키 매니저에 업데이트
            HotKeyManager.OnTargetChanged(value)

            ; 시트에 있는 게임인지 체크해서 활성 유무 변경
            this.IsActive := this.FindSheetName(value)
            /** {@link AppManager.OnActiveChanged} */ 
        }
    }

    /**
     * #### 가상키 데이터 캐시 맵
     * @type {Map<String, Map<String, JKHotKeyInfo>>} 
     * @description Map[게임이름 : Map[키 이름 : 키 데이터]]
     */
    static _cachedHKMap := Map()

    /**
     * #### 스크립트 시작 대기 시간
     * @type {Number} 
     * @see AppManager.BeginPlay
     * @readonly
     * @default 5000
     */
    static SCRIPT_START_DELAY_MS => 5000

    /**
     * #### 스크립트 시작 대기 여부
     * @type {Bool} 
     * @default false
     */
    static canCloseScript := false

    /** @type {bool} */
    static _isActive := false
    /**
     * #### 핫키 활성 여부
     * @type {Bool} 
     * @default false
     */
    static IsActive 
    {
        get => this._isActive
        set 
        {
            ; 비활성=>비활성 스킵
            if(this._isActive == false && value == false)
                return

            this._isActive := value

            ; 상태 변경
            this.OnActiveChanged()
        }
    }

    /**
     * #### 오버레이 활성 여부
     * @type {bool} 
     * @default true
     */
    static IsOverlayActive
    {
        get => this.SETTINGS.enableOverlay
        set
        {
            ; 비활성=>비활성 스킵 | 활성=>활성은 유효 프로그램 간 전환때 필요함
            if(this.SETTINGS.enableOverlay == false 
            && value == false)
                return

            this.SETTINGS.enableOverlay := value
            ; 상태 변경
            this.SetOverlayState(value)
        }
    }

    /** @type {bool} */
    static _isScriptActive := true
    /**
     * #### 스크립트 활성 여부
     * @type {bool} 
     * @default true
     */
    static IsScriptActive 
    {
        get => this._isScriptActive
        set 
        {
            this._isScriptActive := value

            ; 현재 가상키를 제거 처리
            HotKeyManager.RemoveHotKey()
            OverlayManager.ClearOverlay()

            ; true로 변경될때는 isactive의 활성 유무 다시 체크
            if(value)
                this.IsActive := this.FindSheetName(this.curTargetTitle)
        }
    }

    ; MARK: 딜리게이트 단
    
    /**
     * #### 오버레이 활성 상태 변경 딜리게이트
     * @type {Array<BoundFunc>} 
     * @see OverlayManager.OnOverlayStateChanged
     * @example callback(isOverlayActive, overlayContext)
     * @description overlayContext == 오버레이 업데이트 용 데이터
     * @default []
     */
    static OnOverlayStateChangedDel := []

    
    

    ; MARK: 함수 영역

    /**
     * #### 스크립트 시작 준비
     * *
     * @returns {void}
     */
    static BeginPlay()
    {
        ; 오버레이 상태 변경 바인딩
        this.OnOverlayStateChangedDel.Push(OverlayManager.OnOverlayStateChanged.Bind(OverlayManager))

        ; 편집 매니저 이벤트 처리 바인딩
        JKEditManager.OnEditEventDel.Push(this.EditManagerEventHandler.Bind(AppManager))

        ; 최초 프로그램 시작 대기
        this.WaitStartProgram(this.SCRIPT_START_DELAY_MS)

        ; 포커스 체크 딜리게이트 등록
        this.BindFocusChange()
    }

    /**
     * #### 스크립트 시작 대기
     * *
     * @returns {void}
     */
    static WaitStartProgram(delayMs := 0)
    {
        ; 1회성 타이머를 위해 내부에서 음수로 변환 (절댓값 활용)
        local negativeDelay := -Abs(delayMs)

        SetTimer(() => this.canCloseScript := true
        , negativeDelay)
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

        ; 추후 활용시 프로퍼티화 할 딜리게이트
        local shellHookDel := this.ShellHook.Bind(this)

        ; SHELLHOOK 메시지를 수신합니다.
        OnMessage(DllCall("RegisterWindowMessage", "str", "SHELLHOOK"), shellHookDel) 
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
        ; HSHELL_RUDEAPPACTIVATED || HSHELL_WINDOWACTIVATED
        ; 0x8004(강제 활성화) 또는 4(일반 활성화)인 경우 체크
        if (wParam = 0x8004 || wParam = 4) 
            ; 바로 넘기면 과부하로 오류 발생해서 비동기 처리
            SetTimer(this.AsyncCheckFocus.Bind(this, lParam), -1)
    }

    /**
     * #### 목표 게임 확인 비동기 처리
     * *
     * @param {Number} lParam - 포커스된 창 핸들
     */
    static AsyncCheckFocus(lParam)
    {
        ; lParam이 0이면 현재 활성 창의 핸들을 가져오기
        hwnd := lParam || WinExist("A") 
        if(!hwnd) 
            return

        curTitle := WinGetTitle(hwnd)

        AppManager.CheckFocus(curTitle)
    }

    /**
     * #### 타겟 프로그램 포커스 확인
     * @description 확인 후 스크립트 활성 또는 종료 여부 판단
     * @param {String} curTitle - 현재 포커스된 창 이름
     * @returns {void}
     */
    static CheckFocus(curTitle) 
    {
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
        ; 가상키 신규 세션
        JKSession.CurSessionNum++
        
        ; 현재 가상키, 오버레이 제거
        HotKeyManager.RemoveHotKey()
        OverlayManager.ClearOverlay()

        if(this.IsScriptActive && this.IsActive)
        {
            processHandle := WinActive(this.CurTargetTitle)
            ; 키 매핑 시트 데이터 가져오기
            curHKData := this.GetKeyData(this.CurTargetTitle)

            ; 가상키 매니저에 데이터 업데이트
            HotKeyManager.SetupHotKey(curHKData)

            ; 오버레이 생성
            if(this.IsOverlayActive)
                OverlayManager.GetOrCreateOverlay(OverlayCreateInfo(processHandle, curHKData, this.SETTINGS), true)
        }
        else if(this.canCloseScript)
        {
            ; 전체 프로세스에 시트 게임이 하나도 없는지 체크
            for gameName, in this.sheetNameTable
            {
                if(WinExist(gameName))
                    return
            }
            
            ; 없으면 스크립트 종료
            this.CloseScript()
        }
    }

    ; 게임명에 해당하는 가상키 데이터 얻기
    static GetKeyData(gameName)
    {
        resultKeyData := Map()

        ; 1. 캐시맵에 존재 확인
        if(this._cachedHKMap.Has(gameName))
            resultKeyData := this._cachedHKMap[gameName]
        ; 2. 없으면 csv 파일 읽어와서 캐싱
        else
        {
            resultKeyData := this.LoadKeyData(gameName)
            this._cachedHKMap[gameName] := resultKeyData
        }

        return resultKeyData
    }

    /**
     * #### 해당 게임명에 대한 전용+기본 가상키 데이터 불러오기
     * @param {String} gameName - 게임명
     * @returns {Map<String, JKHotKeyInfo>} - 가상키 데이터 맵
     */
    static LoadKeyData(gameName)
    {
        ; 게임명 시트에 존재 확인
        sheetName := AppManager.FindSheetName(gameName)

        ; 비 존재시 함수 종료
        if(!sheetName)
            return Map()

        ; 키 데이터 가져오기
        defaultKeyDataTable := JKUtility.LoadPrioritySheetData(JKUtility.KEY_DATA_FOLDER, AppManager.DEFAULT_KEY_SHEET_NAME)

        gameKeyDataTable := JKUtility.LoadPrioritySheetData(JKUtility.KEY_DATA_FOLDER, sheetName)

        ; 결합
        fullKeyDataTable := defaultKeyDataTable.Clone()
        for keyName, keyDataObj in gameKeyDataTable
        {
            fullKeyDataTable[keyName] := keyDataObj
        }

        ; 내부 시트값 클래스화
        fullKeyDataMap := JKUtility.MasterMapToClassMap(fullKeyDataTable, JKHotKeyInfo)

        return fullKeyDataMap
    }

    /**
     * #### 게임명으로 가상키 시트 파일명 찾기
     * @param {String} gameName - 게임명
     * @returns {String} - 시트 파일명
     */
    static FindSheetName(gameName)
    {
        sheetName := this.sheetNameTable.Has(gameName) 
                ? this.sheetNameTable[gameName].Get("sheetName", "") 
                : ""

        return sheetName
    }

    ; 오버레이 상태 변경
    static SetOverlayState(value)
    {
        ; 오버레이 생성 재료
        overlayContext := false
        if(this.IsOverlayActive)
        {
            overlayContext := OverlayCreateInfo(
                WinActive(this.CurTargetTitle)
                , this.GetKeyData(this.CurTargetTitle)
                , this.SETTINGS)
        }

        ; 상태 변경 딜리게이트 실행
        JKUtility.CallMulticastDel(this.OnOverlayStateChangedDel, value, overlayContext)
    }

    /**
     * #### 오버레이 토글
     * @returns {void}
     */
    static ToggleOverlay()
    {
        this.IsOverlayActive := !this.IsOverlayActive
    }

    /**
     * #### 스크립트 활성화 토글
     * @returns {void}
     */
    static ToggleScript()
    {
        this.IsScriptActive := !this.IsScriptActive
    }

    /**
     * #### 스크립트 종료
     * @see AppManager.OnActiveChanged
     * @returns {void}
     */
    static CloseScript()
    {
        exitMsg := "목표 게임 없음. 핫 키 종료"
        JKUtility.Log(exitMsg)
        ToolTip(exitMsg)

        Sleep(1000) 

        ExitApp()
    }

    ; 스크립트 종료시 작동
    static OnScriptExit(_exitReason, _exitCode)
    {
        ; 데이터 저장
        this.SETTINGS.Save()
        this.SaveHKDataToCSV()
    }

    /**
     * #### 가상키 캐시 데이터 csv 저장
     * @returns {void}
     */
    static SaveHKDataToCSV()
    {
        for gameName, hkDataMap in this._cachedHKMap
        {
            ; 핫키 데이터맵을 순수 맵화
            hkMasterMap := Map()
            for keyName, hkInfo in hkDataMap
            {
                hkMasterMap[keyName] := hkInfo.ToMap()
            }

            ; 시트 이름
            sheetName := this.FindSheetName(gameName)

            ; csv 저장
            JKUtility.SaveSheetData(JKUtility.KEY_DATA_FOLDER, sheetName, hkMasterMap, ["name", "x","y","type","description"])
        }
    }

    /**
     * #### 편집 매니저 이벤트 처리
     * @see JKEditManager.OnEditEventDel
     * @param {'begin'|'save'} eventType - 이벤트의 종류 (예: 'Begin', 'Save')
     * @param {...*} _params - 이벤트와 함께 전달되는 가변 파라미터들
     * @overload EditManagerEventHandler('begin')
     * @overload EditManagerEventHandler('save', EditInfo)
     * @returns {void}
     */
    static EditManagerEventHandler(eventType, _params*)
    {
        switch(eventType)
        {
            case "begin":
                ; FIXME 핫키 작동 비활성화 | 클릭 만 막지 핫키가 unbind된게 아닌 문제
                HotKeyManager.isActive := false

                ; @@ 수정 모드로 활성화할 필요도 있을듯?
                this.IsOverlayActive := true

                ; 편집 모드 시작시 대상 가상키 데이터 주입
                JKEditManager.CurEditInfo := EditInfo(
                    this.CurTargetTitle
                    , this._cachedHKMap[this.CurTargetTitle].Clone())
            default:
                JKUtility.Log("비대상 이벤트")
                
                ; @@ 종료시 핫키 활성화
                HotKeyManager.isActive := true
        }

    }
}



; MARK: 프로그램 실행 영역

; 우선순위 설정
ProcessSetPriority("High")
; ListLines(false)
; KeyHistory(0)
A_MaxHotKeysPerInterval := 200

; 관리자 권한 실행
JKUtility.RunAdmin()

; shell32.dll의 44번 아이콘(별 모양)을 트레이 아이콘으로 설정
TraySetIcon("JKGameHotKeyICO.ico")

; 종료 딜리게이트 바인드
OnExit(AppManager.OnScriptExit.Bind(AppManager))

; 프로그램 시작
AppManager.BeginPlay()


; MARK: 입력 영역

; XXX 디버그용 즉시 체크 시작
[ & Esc::AppManager.WaitStartProgram()   

; 디버그용 활성 창 핸들 표시
[ & F1::
{
    static isRunning := false
    static timerFn := () => JKUtility.TooltipCurHwnd()

    ; isRunning이 true면 0(해제), false면 50(시작)
    SetTimer(timerFn, (isRunning := !isRunning) ? 50 : -0)

    if(!isRunning)
        ToolTip()
}


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

; 편집 모드 토글
] & F8::JKEditManager.ToggleEditMode()


#HotIf 

