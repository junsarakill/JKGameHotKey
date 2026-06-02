#Requires AutoHotkey v2.0
#Include Lib\jk-utility\JKUtilityBase.ahk

/************************************************************************
 * @description 유용한 전역 기능들
 * @author JKAKK
 * @date 2026/05/19
 * @version 0.0.2
 ***********************************************************************/

/** #### 범용 사용 클래스 */
class JKUtility extends JKUtilityBase 
{
    ; MARK: 전역 변수 단

    /** @type {String} */
    static _keyDataFolder := this.SHEET_FOLDER . "\KeyData\"
    /**
     * #### 가상키 시트 폴더 경로
     * @type {String} 
     */
    static KEY_DATA_FOLDER => this._keyDataFolder
    
    ; MARK: 전역 함수 단

    static LoadPrioritySheetData(csvFolderPath, csvFileName, keyHeader := "")
    {
        return super.LoadPrioritySheetData(csvFolderPath, csvFileName, keyHeader)
    }

    static RunAdmin()
    {
        super.RunAdmin()
    }

    static MapToClass(mapData, classType)
    {
        return super.MapToClass(mapData, classType)
    }

    static Log(msg)
    {
        super.Log(msg)
    }
}
