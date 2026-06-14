#Include Lib\jsongo_AHKv2-main/src/jsongo.v2.ahk
/************************************************************************
 * @description 설정 데이터
 * @author JKAKK
 * @date 2026/05/11
 * @version 0.0.1
 ***********************************************************************/
/** 설정 클래스
 * @description 설정 저장에 필요없는 변수는 _ 붙이기
 */
class JKSettings
{
    /** @type {Bool} */
    enableOverlay := true

    /** 
     * #### 가상키 오버레이 투명도
     * @type {number} 
     * @range `0` ~ `255`
     * @default `100`  
     */
    overlayOpacity := 100
    ; 오버레이 BG 색상 추가
    overlayBGColor := "dfdfdf"

    /** @type {String} */
    version := "0.0.1"

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
            if(FileExist(JKSettings._PATH))
                FileDelete(JKSettings._PATH)

            FileAppend(jsonStr, JKSettings._PATH, "UTF-8")

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
            return JKSettings()

        try {
            jsonData := FileRead(this._PATH, "UTF-8")
            ; json => map 변환
            mapData := jsongo._Parse(jsonData)
            
            ; map => 클래스 변환
            return JKUtility.MapToClass(mapData, JKSettings)
        } 
        catch Error as e 
        {
            MsgBox("정상 로드 실패, 초기값 반환: " . e.Message)

            return JKSettings()
        }    

    }

    /**
     * #### 필요 변수만 저장용 맵으로 변환
     * *
     * @returns {Map<String, String>} - 설정 저장용
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