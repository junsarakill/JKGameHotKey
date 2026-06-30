#Requires AutoHotkey v2.0
/************************************************************************
 * @description 가상키 데이터 편집 중재자
 * @author JKAKK
 * @date 2026/07/01
 * @version 0.0.1
 ***********************************************************************/


class JKEditManager
{
    /** @type {bool} */
    static _isEditState := false
    /**
     * #### 편집 모드 활성 유무
     * @type {bool} 
     */
    static IsEditState {
        get => this._isEditState
        set
        {
            this._isEditState := value

            value ? this.ActiveEditMode() 
                  : this.ExitEditMode()
        }   
    }


    ; 편집 모드 토글
    static ToggleEditMode()
    {
        this.IsEditState := !this.IsEditState
    }
    
    ; 편집 모드 활성화
    static ActiveEditMode()
    {
        
    }

    ; 편집 모드 종료
    static ExitEditMode()
    {

    }

    
}