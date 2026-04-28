#Requires AutoHotkey v2.0
#Include Utility.ahk
/************************************************************************
 * @description ahk v2 HotKey() 를 객체로 래핑 용도
 * @author JKAKK
 * @date 2026/04/27
 * @version 0.0.1
 ***********************************************************************/


class JKHotKey
{
    ; MARK: 변수 영역

    ; /** @type {String} */
    ; _uid := ""
    ; /**
    ;  * #### 객체 식별용 uid
    ;  * @type {String} 
    ;  * @default ""
    ;  * @readonly
    ;  * @description 키이름 + pos위치 + 콜백함수id + 태그 를 조합한 전문
    ;  */
    ; UID => this._uid

    /** @type {bool} */
    _isActive := false
    /**
     * #### 가상키 활성 유무
     * @property
     * @type {bool} 
     * @default false
     */
    IsActive {
        get => this._isActive
        set {
            this._isActive := value

            ; 활성 유무에 따라 핫키 바인드
            if(value)
                Hotkey(this.keyName, this.Callback, this.option)
            else
                try Hotkey(this.keyName, "Off")
        }
    }

    /**
     * #### 가상키 이름 전문으로 넣어야함
     * @type {String} 
     * @default ""
     * @example keyName := "$F1 up"
     */
    keyName := ""

    /** @type {Func|BoundFunc} */
    _callback := ""
    /**
     * #### 콜백 함수를 담은 변수
     * @type {Func|BoundFunc} 
     * @default null
     */
    Callback {
        get => this._callback
        set {
            this._callback := value

            ; 활성화 상태라면 핫키 업데이트
            if(this.IsActive)
                Hotkey(this.keyName, this.Callback, this.option)
        }
    }

    /**
     * #### 가상키 생성시 옵션
     * @type {String} 
     * @default ""
     * @description 주로 "On" "Off" 넣거나 생략
     */
    option := ""

    /**
     * #### 가상키 입력 위치
     * @type {Vector2d} 
     * @default null
     */
    pos := Vector2d()

    /**
     * #### 가상키 태그
     * @type {String} 
     * @default ""
     * @description 구분용 태그
     */
    tag := ""

    /**
     * #### 가상키 설명
     * @type {String} 
     * @default "없음"
     */
    desc := ""

    ; MARK: 함수 영역
    ; 생성자
    __New(keyName, callback, option := "", pos := Vector2d(), tag := "", desc := "없음")
    {

        this.keyName := keyName
        this.option := option
        this.pos := pos
        this.tag := tag
        this.desc := desc

        this.IsActive := false
        this.Callback := Callback

        ; 옵션이 바로 시작이면 활성화
        if(option == "On")
            this.Bind()

            
        ; ; XXX UID 생성
        ; this._uid := this.keyName . "_" . this.pos.ToString() . "_" . String(this.Callback) . "_" . this.tag
    }

    ; 함수 바인드 및 핫키 등록
    Bind()
    {
        this.IsActive := true
    }

    ; 바인드 해제 및 비활성화
    Unbind()
    {
        this.IsActive := false
    }

    ; 활성화 토글
    Toggle()
    {
        this.IsActive := !this.IsActive
    }

    ; 자괴
    Destroy()
    {
        this.Unbind()
        this.Callback := ""
    }

    ; 변수 출력
    ToString() 
    {
        return Format(
            '{{ "keyName": "{}", "option": "{}", "tag": "{}", "desc": "{}", "isActive": {} }}',
            this.keyName, 
            this.option,
            this.tag, 
            this.desc,
            this.IsActive ? "true" : "false"
        )
    }

    ; 소멸자
    __Delete() {
        try this.Unbind()
    }

}


; XXX 출력 테스트
; asd := JKHotKey("$F1", "")

; MsgBox(asd.ToString())