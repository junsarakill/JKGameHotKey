#Requires AutoHotkey v2.0
#Include Utility.ahk
#Include JKSession.ahk

/************************************************************************
 * @description 오버레이 관련 스크립트
 * @author JKAKK
 * @date 2026/05/08
 * @version 0.0.1
 ***********************************************************************/

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

    /**
     * #### 가상키 오버레이 생성
     * ;FIXME
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

            if(!newOverlay.isValid)
            {
                JKUtility.Log("예전 오버레이 자괴 됨 : " . newOverlay.text . newOverlay.session.insSessionNum)
            }    
            

            ; 오버레이 맵에 추가
            curHKInfo.overlayMap[newOverlay.aGUI.Hwnd] := newOverlay
        }
    }
}