#Requires AutoHotkey v2.0

/** x,y 2차원 자료구조 */
class Vector2d {
    /** @type {Number} */
    x := 0

    /** @type {Number} */
    y := 0

    ; 생성자
    /**
     * #### 생성자
     * *
     * @param {Number} x - x 좌표
     * @param {Number} y - y 좌표
     * @returns {void}
     */
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

/** 가상키 데이터 */
class KeyData
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
        this.name := sheetDataMap["name"]
        this.pos := Vector2d(sheetDataMap["x"], sheetDataMap["y"])
        this.type := sheetDataMap["type"]
        this.description := sheetDataMap["description"]
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
}

/** #### 범용 사용 클래스 */
class JKUtility {
    ; MARK: 전역 변수 단
    
    /** @type {String} */
    static _sheetFolder := A_ScriptDir . "\Sheet\" 
    /**
     * #### 시트 폴더 경로
     * @type {String} 
     */
    static SHEET_FOLDER => this._sheetFolder

    /** @type {String} */
    static _keyDataFolder := this.SHEET_FOLDER . "\KeyData\"
    /**
     * #### 가상키 시트 폴더 경로
     * @type {String} 
     */
    static KEY_DATA_FOLDER => this._keyDataFolder
    
    /** @type {String} */
    static _sheetEXT := ".csv"
    /**
     * #### 시트 확장자
     * @type {String} 
     * @example asd := this.KEY_DATA_FOLDER . gameName . this.SHEET_EXT
     */
    static SHEET_EXT => this._sheetEXT
    
    ; MARK: 전역 함수 단
    
    /**
     * #### 우선 순위 있는 시트 데이터 불러오기
     * *
     * @param {String} csvFolderPath - 시트 폴더 경로
     * @param {String} csvFileName - 시트 파일 이름 (확장자 없이)
     * @returns {Array} - 시트 데이터를 배열 { 맵[헤더] : 값 } 형태로 반환
     * @example 
     * sheetData := this.LoadPrioritySheetData(path, name)
     * for row in sheetData
     * {
     *     someValue := row["header"]
     * }
     */
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
            curCSVPath := csvFolderPath . csvFileName . curPR . this.SHEET_EXT
    
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
    
    /**
     * #### 시트 데이터 구조체로 변환하기
     * *
     * @param {String} csvFilePath - 시트 전체 경로
     * @returns {Array} - 배열 { 맵[헤더] : 값 } 시트 데이터
     */
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

    /**
     * #### map 데이터 => 클래스 로 변환
     * *
     * @param {Map} mapData - 변환할 map 데이터
     * @param {Class} classType - 반환할 클래스 타입
     * @returns {Class} - 변환된 클래스 데이터
     */
    static MapToClass(mapData, classType) 
    {
        local newClassIns := classType() ; 클래스 인스턴스 생성

        for key, value in mapData {
            local strKey := String(key)

            if (newClassIns.HasProp(strKey)) 
                newClassIns.%strKey% := value ; Map의 값을 클래스 속성으로 설정
        }

        return newClassIns
    }
}
