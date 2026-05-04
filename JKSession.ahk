#Requires AutoHotkey v2.0
#Include Utility.ahk

; 가상키등의 유효성 판단용 세션
class JKSession
{
    /**
     * #### 최신 세션 번호 | 앱 매니저가 관리
     * @type {Number} 
     * @default 0
     */
    static curSessionNum := 0

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
        this.insSessionNum := JKSession.curSessionNum
    }

    Valid()
    {
        return this.insSessionNum == JKSession.curSessionNum
    }
}