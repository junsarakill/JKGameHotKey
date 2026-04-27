#Requires AutoHotkey v2.0
#Include Utility.ahk

/************************************************************************
 * @description 가상키 담당 관리 클래스
 * @author JKAKK
 * @date 2026/04/25
 * @version 0.0.1
 ***********************************************************************/
class HotKeyManager
{
    ; MARK: 변수 영역

    /**
     * #### 현재 전체 가상키 데이터
     * @type {HotKeyInfo} 
     * @default null
     */
    static curHKInfo := HotKeyInfo()

    ; @@ 전체 가상키 객체 풀 [$키이름전문] : 핫키객체
    static hotKeyObjPoolMap := Map()

    /**
     * #### 현재 목표 게임명
     * @type {String} 
     * @default null
     */
    static curTargetTitle := ""
    

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

        ; 변경되었으니 키 매핑 제거
        this.RemoveHotKey()
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
        this.curHKInfo := hkInfo

        this.CreateHotKey(this.curHKInfo)
    }

    /**
     * #### 가상키 생성
     * *
     * @param {HotKeyInfo} hkInfo - 가상키 데이터
     * @returns {void}
     */
    static CreateHotKey(hkInfo)
    {
        for , keyData in hkInfo.hotKeyMap
        {
            ; 타입 체크
            if(keyData.type = "KEY")
            {
                ; 핫 키 생성
                Hotkey("$" keyData.name, ObjBindMethod(this, "OnKeyDown"), "On")
                Hotkey("$" keyData.name " up", ObjBindMethod(this, "OnKeyUp"), "On")
            }
        }
    }  

    ; @@ 가상키 오브젝트 풀에서 받아오기
    static GetHotKey(fullKeyName, methodName)
    {
        ; 오브젝트 풀에 있으면 재사용
        if(this.hotKeyObjPoolMap.Has(fullKeyName))
        {
            /** @type {} */
            hkObj := this.hotKeyObjPoolMap[fullKeyName]
            
        }
        

    } 

    /**
     * #### 가상키 초기화
     * *
     * @description 가상키 비활성화, 맵 초기화
     * @returns {void}
     */
    static RemoveHotKey()
    {
        ; 핫키 제거
        for , keyData in this.curHKInfo.hotKeyMap
        {
            ; 타입 체크
            if(keyData.type = "KEY")
            {                               
                Hotkey("$" keyData.name, "Off") ; 핫키 비활성화
                Hotkey("$" keyData.name " up", "Off") ; 핫키 비활성화
            }
        }                                   
        
        this.curHKInfo.hotKeyMap := Map()
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

    /**
     * #### 클릭 이벤트 : 입력 가능시
     * *
     * @see HotKeyManager.CreateHotKey - 바인딩 위치
     * @param {String} hotKey - 키 이름
     * @returns {void}
     */
    static OnKeyDown(hotKey)
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

    /**
     * #### 릴리스 이벤트 : 입력 가능시
     * *
     * @see HotKeyManager.CreateHotKey - 바인딩 위치
     * @param {String} hotKey - 키 이름
     * @returns {void}
     */
    static OnKeyUp(hotKey)
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

    /** ;@@ 가상키 객체 오브젝트 풀링화
     * 현재 hotkey() 객체를 보유하고 있지 않음. 간접적으로 설정중.
     * 1. 일단 핫키 객체를 보유할 맵을 추가 [$키이름전문] : 핫키객체
     * {@link HotKeyInfo}
     * 
     * 2. 생성시 해당 핫키가 존재 검사 및 없으면 생성/ 있으면 활성화 로직 추가 | OnEvent 로 바인딩 함수 변경
     * {@link HotKeyManager.CreateHotKey}
     * 
     * 3. 비활성화 시 제거 대신 풀에 있는 핫키 비활성화.| 오버레이도 추후 같은 로직으로 생성/비활성화
     * {@link HotKeyInfo.ClearHotKey}
     * 
     * 미리 만들진 말고 lazy intial 로 생성한 만큼 저장해두기
     */


}