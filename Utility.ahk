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

    static SetVisibleCursor(value)
    {
        super.SetVisibleCursor(value)
    }

    /**
     * #### 마스터키를 가진 맵 데이터를 CSV 파일로 저장하기
     * @param {String} csvFileFullPath - 저장할 CSV 전체 경로
     * @param {Map<String, Map<String, String>>} dataMap - 마스터맵
     * @param {Array} headers - (선택 사항) 저장할 헤더 순서 지정 | 비지정 시 데이터에서 추출
     */
    static SaveSheetData(csvFolderPath, csvFileName, dataMap, headers := "")
    {
        ; 데이터가 비어있으면 함수 종료
        if (dataMap.Count = 0)
            return

        ; 파일 경로
        csvPath := this.GetPriorityFilePath(csvFolderPath, csvFileName)

        ; 헤더 정보가 전달되지 않은 경우 맵의 첫 번째 내부 데이터에서 추출
        if (headers = "")
        {
            headers := []
            ; 첫 번째 요소의 내부 Map을 가져와 헤더 추출
            for , field in dataMap
            {
                for header, in field
                {
                    headers.Push(header)
                }
                break
            }
        }

        csvContent := ""
        ; 1. 헤더 행 작성
        for index, header in headers
        {
            ; 각 헤더 필드를 CSV 형식에 맞게 이스케이프 처리 후 연결
            csvContent .= this.FormatCSVField(header) . (index = headers.Length ? "" : ",")
        }
        csvContent .= "`r`n"

        ; 2. 데이터 행 작성
        for , field in dataMap
        {
            rowContent := ""
            for index, header in headers
            {
                ; 필드가 존재하면 가져오고 없으면 빈 값 처리
                value := (field.Has(header) ? field[header] : "")
                ; CSV 형식에 맞게 이스케이프 처리 후 연결
                rowContent .= this.FormatCSVField(value) . (index = headers.Length ? "" : ",")
            }
            csvContent .= rowContent . "`r`n"
        }

        ; 3. 파일 쓰기 (UTF-8)
        ; 파일이 이미 존재할 경우 덮어쓰기 위해 기존 내용을 삭제하거나 새로 생성
        if (FileExist(csvPath))
        {
            FileDelete(csvPath)
        }
        FileAppend(csvContent, csvPath, "UTF-8")
    }

    /**
     * #### 문자열을 CSV 필드 표준 형식에 맞게 이스케이프 처리
     * @param {String} fieldText - 원본 텍스트
     * @returns {String} - 이스케이프 처리된 텍스트
     */
    static FormatCSVField(fieldText)
    {
        ; 값 내부에 큰따옴표, 쉼표, 줄바꿈이 포함되어 있는지 확인
        if (InStr(fieldText, '"') || InStr(fieldText, ",") || InStr(fieldText, "`n") || InStr(fieldText, "`r"))
        {
            ; 내부의 큰따옴표(")를 두 개("")로 치환하고 전체를 큰따옴표로 감싸기
            return '"' . StrReplace(fieldText, '"', '""') . '"'
        }
        return fieldText
    }

    static EnumToString(enum, num)
    {
        for propName, propValue in enum.OwnProps()
        {
            if (propValue == num)
                return propName
        }
        
        ; 매칭되는 숫자가 없을 경우 기본값 반환
        return "UNKNOWN"
    }
}
