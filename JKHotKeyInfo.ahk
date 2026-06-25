#Requires AutoHotkey v2.0
#Include Lib\jsongo_AHKv2-main/src/jsongo.v2.ahk


/************************************************************************
 * @description 가상키 정보 클래스
 * @author JKAKK
 * @date 2026/06/25
 * @version 0.0.1
 ***********************************************************************/

class JKHotKeyInfo
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
        try 
        {
            this.name := sheetDataMap["name"]
            this.pos := Vector2d(sheetDataMap["x"], sheetDataMap["y"])
            this.type := sheetDataMap["type"]
            this.description := sheetDataMap["description"]
        }
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

    ; 저장용 배열화
    ToArray()
    {
        resultAry := [
            this.name
            ,this.pos.x
            ,this.pos.y
            ,
        ]
        
    }

    ; 정보 csv 파일로 저장
    Save(fileName)
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
}