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

/** #### 범용 사용 클래스 */
class JKUtility {
    ; MARK: 전역 변수 단
    
    ; 시트 폴더
    static sheetFolder := A_ScriptDir . "\Sheet\"
    ; 가상키 시트 폴더
    static keyDataFolder := this.sheetFolder . "\KeyData\"
    
    ; 시트 확장자
    static sheetEXT := ".csv"
    
    ; MARK: 전역 함수 단
    
    ; @@ 지금 무조건 확장자 추가하는데 정규식으로 확인해서 확장자 없을때만 추가하는건 어떨까?
    ; 폴더 위치, 파일 이름 받아서 시트 데이터 불러오기
    static LoadPrioritySheetData(csvFolderPath, csvFileName)
    {
        /** 탐색순서
         * {folderPath}/{fileName}.{ext} (분리없는 파일)
        {folderPath}/{fileName}.local.{ext} (개별 설정)
        {folderPath}/{fileName}.default.{ext} (공통 기본값)
         */
        priorityAry := [
            ""
            ,".local"
            ,".default"
        ]
    
        ; 조합될 경로
        csvPath := ""
        ; 배열로 해서 포 돌리기
        for curPR in priorityAry
        {
            ; 경로 조합
            curCSVPath := csvFolderPath . csvFileName . curPR . this.sheetEXT
    
            ; 존재확인 
            if(FileExist(curCSVPath))
            {
                ; 있으면 해당 경로 확정 포 종료
                csvPath := curCSVPath
                break
            }
        }
    
        ; 반환할 시트 데이터
        sheetData := []
    
        ; 경로 유효 확인
        if(csvPath != "")
        {
            ; 해당 경로로 시트 데이터 받기
            sheetData := this.LoadSheetData(csvPath)
        }
        ; 결과 리턴
    
        return sheetData
    }
    
    ; 시트 데이터 구조체로 변환하기
    static LoadSheetData(csvFilePath)
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
    
    ; 관리자 권한 체크 및 재실행
    static RunAdmin()
    {
        if !A_IsAdmin
        {
            Run('*RunAs "' A_AhkPath '" /Restart "' A_ScriptFullPath '"')
            ExitApp()
        }
    }

    ; map 데이터 => 클래스 로 변경
    static MapToClass(mapData, classType) 
    {
        local newClassIns := classType() ; 클래스 인스턴스 생성

        for key, value in mapData {
            if (newClassIns.HasProp(key)) 
                newClassIns.%key% := value ; Map의 값을 클래스 속성으로 설정
        }

        return newClassIns
    }
}
