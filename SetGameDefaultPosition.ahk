#Requires AutoHotkey v2.0
#Include Utility.ahk

; MARK: 클래스 영역

/** 게임명 : 기본 위치 데이터 */
class PosData
{
    /** @type {String} */
    name := ""

    /** @type {Vector2d} */
    pos := ""

    /** @type {Number} */
    monitor := 0

    /**
     * #### 생성자
     * *
     * @param {String} name - 프로세스 창 이름
     * @param {Number} x - x 좌표
     * @param {Number} y - y 좌표
     * @param {Number} monitor - 모니터 번호
     * @returns {void}
     */
    __New(name := "", x := 0, y := 0, monitor := 0)
    {
        this.name := name
        this.pos := Vector2d(x, y)
        this.monitor := monitor
    }

    /**
     * #### 생성자 (맵)
     * *
     * @param {Map} mapData - 생성 데이터 맵
     * @returns {PosData} - 새 객체
     */
    static NewFromMap(mapData := Map())
    {
        newIns := JKUtility.MapToClass(mapData, PosData)

        ; x,y 변환
        if(mapData.Has("x") && mapData.Has("y"))
        {
            newIns.pos := Vector2d(mapData.Get("x"), mapData.Get("y"))
        }

        return newIns
    }
}

class SetGameDefaultPosition
{
    ; MARK: 변수 영역

    /** @type {String} */
    static _defaultPosSheetName := "JK_GameDefaultPosition" . JKUtility.SHEET_EXT
    /** @type {String} */
    static DEFAULT_POS_SHEET_NAME => this._defaultPosSheetName
    
    /** @type {String} */
    static _defaultPosSheetPath := JKUtility.SHEET_FOLDER . this.DEFAULT_POS_SHEET_NAME
    /**
     * #### 기본 위치 시트 경로
     * @type {String} 
     */
    static DEFAULT_POS_SHEET_PATH => this._defaultPosSheetPath

    /** @type {Array} */
    static _defaultPosData := this.LoadDefaultPosSheetData(this.DEFAULT_POS_SHEET_PATH)
    /**
     * #### 기본 위치 데이터
     * @type {Array} - Array{PosData} 
     */
    static DEFAULT_POS_DATA => this._defaultPosData

    ; MARK: 함수 영역

    /**
     * #### 기본 위치 시트 데이터 PosData 클래스 배열로 변환
     * *
     * @param {String} defaultPosSheetPath - 시트 경로
     * @returns {Array} - Array{PosData}
     */
    static LoadDefaultPosSheetData(defaultPosSheetPath)
    {
        ; 맵 변환한 시트 데이터 배열
        dataAry := JKUtility.LoadSheetData(defaultPosSheetPath)
        
        ; PosData 배열 형태로 반환할 값
        posDataAry := []
        for oneData in dataAry
        {
            onePosData := PosData.NewFromMap(oneData)

            posDataAry.Push(onePosData)
        }

        return posDataAry
    }

    /**
     * #### 위치 데이터 받아서 기본 위치로 창 옮기기
     * *
     * @param {PosData} posData - 위치 데이터
     * @returns {void}
     */
    static SetDefaultPosition(posData)
    {
        /** geminai said / 26.02.19
         * AutoHotkey의 WinMove 함수를 사용할 때 크기가 변하는 이유는 크게 두 가지입니다. 
            WinMove는 매개변수를 생략할 경우 시스템의 기본값이나 이전 상태를 참조하려는 성향이 있고, 윈도우의 DPI(배율) 설정이 모니터마다 다를 때 계산 착오가 발생하기 때문입니다.


            따라서 현재 1번 모니터 배율 100% 옆 3번 서브 모니터 배율이 150% 라서 문제 발생
            + gf2 해상도가 1366x768 이라 550,280 이동시 3번 모니터 영역을 약간 침범함.
        */
        ; 전체 프로세스에 해당 게임 존재 체크
        if(curProcHandle := WinExist(posData.name))
        {
            ; wintitle 
            curProcName := "ahk_id " curProcHandle
            ; 현재 사이즈 가져오기
            WinGetPos(,, &curW, &curH, curProcName)

            ; 위치 이동 | 사이즈 유지
            WinMove(posData.pos.x, posData.pos.y, curW, curH, curProcName)
        }
    }

    /**
     * #### 기본 위치 있는 모든 게임 위치로
     * *
     * @returns {void}
     */
    static RunSetGameDefaultPosition()
    {
        for posData in this.DEFAULT_POS_DATA
        {
            this.SetDefaultPosition(posData)
        }
    }

}

; MARK: 스크립트 실행 영역

; DPI 간섭 방지 / 26.02.19
DllCall("SetThreadDpiAwarenessContext", "ptr", -3)

; XXX 디버그용
; F7::
; {
;     global defaultPosData
;     for posData in defaultPosData
;     {
;         SetDefaultPosition(posData)
;     }
; }

; XXX 종료 키
; ] & Esc::CloseScript

; CloseScript()
; {
;     ExitApp
; }