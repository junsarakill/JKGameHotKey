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
            ,this.type
            ,this.description
        ]
        
        return resultAry
    }
    
    ToMap()
    {
        resultObj := {
            name: this.name
            ,x: this.pos.x
            ,y: this.pos.y
            ,type: this.type
            ,description: this.description
        }

        resultMap := Map()
        for key, value in resultObj.OwnProps()
        {
            resultMap[key] := value
        }

            
        return resultMap
    }
}