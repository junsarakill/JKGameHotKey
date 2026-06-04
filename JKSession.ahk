#Requires AutoHotkey v2.0
#Include Utility.ahk

/************************************************************************
 * @description 유효성 판단용 세션
 * @author JKAKK
 * @date 2026/05/16
 * @version 0.0.2
 ***********************************************************************/

; 가상키등의 유효성 판단용 세션
class JKSession
{

    /** @type {Number} */
    static _curSessionNum := 0
    /**
     * #### 최신 세션 번호 | 앱 매니저가 관리
     * @type {Number} 
     * @default 0
     */
    static CurSessionNum
    {
        get => this._curSessionNum
        set
        {
            this._curSessionNum := Value
            JKUtility.Log(Format(
            "--------------------------------------------------`n" .
            ">>> Global Session Updated to: {1}`n" .
            "--------------------------------------------------", 
            Value
            ))
        }
    }

    /**
     * #### 객체들이 가질 고유 세션 번호
     * @description 생성시 최신 세션 번호 가져오고 검증시 최신 세션 번호랑 비교
     * @type {Number} 
     * @default 0
     */
    insSessionNum := 0

    __New()
    {
        ; 최신 세션 번호 주입
        this.Update()
    }

    Update()
    {
        this.insSessionNum := JKSession.CurSessionNum
    }

    Valid()
    {
        isValid := this.insSessionNum == JKSession.CurSessionNum
        return isValid
    }

    /**
     * #### 세션 업데이트 or 동적 생성
     * *
     * @description 해당 클래스가 세션 객체 가지고 있으면 업데이트, 없으면 발급
     * @param {Object} targetObj - 세션을 가질 객체
     * @param {String} propName - 세션 속성의 이름
     * 
     * @example JKSession.UpdateOrCreateSession(this, "session")
     * @returns {void}
     */
    static UpdateOrCreateSession(targetObj, propName := "session")
    {
        if (HasProp(targetObj, propName) && targetObj.%propName% is JKSession)
            targetObj.%propName%.Update()
        else
            targetObj.%propName% := JKSession()
    }
}