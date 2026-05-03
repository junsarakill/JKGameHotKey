#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKHotKey.ahk

/************************************************************************
 * @description 가상키 담당 관리 클래스
 * @author JKAKK
 * @date 2026/04/30
 * @version 0.0.3
 ***********************************************************************/
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
        ; this.RemoveHotKey()
    }

    /**
     * #### 가상키 데이터 업데이트
     * *
     * @description 데이터 참조로 받고 신규 가상키 생성
     * @param {HotKeyInfo} hkInfo - 새 가상키 데이터
     * @param {BoundFunc} validCheckDel - 세션 유효 체크하는 딜리게이트
     * @returns {void}
     */
    static SetupHotKey(hkInfo, validCheckDel)
    {
        this.CreateAllHotKey(hkInfo, validCheckDel)
    }

    /**
     * #### 가상키 생성
     * *
     * @see JKHotKey|@see HotKeyInfo
     * @param {HotKeyInfo} hkInfo - 가상키 데이터
     * @param {BoundFunc} validCheckDel - 세션 유효 체크하는 딜리게이트
     * @returns {void}
     */
    static CreateAllHotKey(hkInfo, validCheckDel)
    {
        for , keyData in hkInfo.hotKeyMap
        {
            ; 최적화용 일시 정지
            Sleep(-1)

            ; 최신 세션인지 검증
            if(!validCheckDel.Call())
            {
                ; 예전꺼면 중단
                return
            }

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
        bindMethodName := ""
        ; 인풋 타입에 따라 결정
        switch  inputType {
            case "down":
                bindMethodName := "OnKeyDown"
            case "up":
                newHKName .= " up"
                bindMethodName := "OnKeyUp"

            default:
                ToolTip("잘못된 가상키 입력 타입 요청: " . keyData.ToString())
                return false
        }

        ; 해당 핫키가 이미 생성된 경우 내용 업데이트 및 활성화
        if(this.hotKeyObjPoolMap.Has(newHKName))
        {
            this.hotKeyObjPoolMap[newHKName].Update(keyData)
            this.hotKeyObjPoolMap[newHKName].Bind()
        }
        ; 없으면 새로 생성
        else
        {
            newHotKey := JKHotKey(newHKName, ObjBindMethod(this, bindMethodName), "On", keyData.pos, , keyData.description)
            ; 풀에 추가
            this.hotKeyObjPoolMap[newHKName] := newHotKey
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
        ; 핫키 비활성화
        for , oneHKObj in this.hotKeyObjPoolMap
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
        ; ToolTip(key)

        if(!this.hotKeyObjPoolMap.Has(key))
        {
            ToolTip("비존재 키 요청: " . key)
            return false
        }

        /** @type {JKHotKey} */
        pos2D := this.hotKeyObjPoolMap[key].pos

        return true
    }

    /**
     * ;@@ 나중에 통합 해보기 objmethodbind 가 인자 여러개 가능해보임 분기처리
     * #### 클릭 이벤트 : 입력 가능시
     * *
     * @see HotKeyManager.CreateHotKey - 바인딩 위치
     * @param {String} keyName - 키 이름
     * @returns {void}
     */
    static OnKeyDown(keyName)
    {
        ; ToolTip(keyName)
        ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
        if(!this.GetKeyPos(&pos2D, keyName))
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
     * @param {String} keyName - 키 이름
     * @returns {void}
     */
    static OnKeyUp(keyName)
    {   
        ; 좌표 가져오기 및 입력 체크| 입력 불가시 return
        if(!this.GetKeyPos(&pos2D, keyName))
            return
        
        ; 현재 활성창 체크
        if(!WinActive(this.curTargetTitle))
            return

        ; 해당 좌표 클릭 해제
        MouseClick('L',pos2D.x,pos2D.y, 1,2,'U')
        return                       
    }
}