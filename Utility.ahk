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

; MARK: 전역 변수 단

; 시트 폴더
sheetFolder := A_ScriptDir . "\Sheet\"
; 가상키 시트 폴더
keyDataFolder := sheetFolder . "\KeyData\"

; 시트 확장자
sheetEXT := ".csv"

; MARK: 전역 함수 단

; @@5 KeySheetName 정할때, local 탐색 후 없으면 default 넣는 기능 추가. 
; @@7 그리고 시트 탐색시 자동으로 .csv 붙이게 하고 게임 이름 시트에선 .csv 제거하기
; 폴더 위치, 파일 이름 받아서 시트 데이터 불러오기
LoadPrioritySheetData(csvFolderPath, csvFileName)
{
    /** 탐색순서
     * {folderPath}/{fileName}.{ext} (분리없는 파일)
    {folderPath}/{fileName}.local.{ext} (개별 설정)
    {folderPath}/{fileName}.default.{ext} (공통 기본값)
     */
}

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