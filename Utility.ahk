#Requires AutoHotkey v2.0

; x,y 2차원
class Vector2d {
    x := 0
    y := 0

    ; 생성자
    __New(x := 0, y := 0) {
        this.x := x
        this.y := y
    }

    IsEqual(&other)
    {
        return this.x == other.x 
            && this.y == other.y
    }

    ToString()
    {
        return Format("x : {1}, y : {2}", this.x, this.y)
    }
}

sheetFolder := A_ScriptDir . "\KeyData\"

; 시트 데이터 구조체로 변환하기
LoadSheetData(csvFilePath)
{
    ; csv 데이터
    csvData := FileRead(csvFilePath, "UTF-8")
    
    ; 행 분리
    rows := StrSplit(csvData, "`r`n")

    ; 헤더 가져오기
    headers := StrSplit(rows[1], ",")

    ; 시트 구분해서 구조체(map을 가진 배열)에 저장
    data := []
    
    for i, row in rows {
        if(i = 1)
            continue

        rowData := StrSplit(row, ",")
        ; 행 데이터 구조체화
        field := Map()
        
        for index, header in headers
        {
            field[header] := rowData[index]
        }

        data.Push(field)
    }

    return data
}