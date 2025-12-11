#Requires AutoHotkey v2.0

; ======================================================================================================================
;  Classe LVEditInline - édition inline (version simplifiée, sans tracking de changements)
; ======================================================================================================================
class LVEditInline {
    __New(LV) {
        if (Type(LV) != "Gui.ListView")
            throw Error("Class LVICE requires a Gui.ListView!")
        This.DoubleClickFunc := ObjBindMethod(This, "DoubleClick")
        This.BeginLabelEditFunc := ObjBindMethod(This, "BeginLabelEdit")
        This.EndLabelEditFunc := ObjBindMethod(This, "EndLabelEdit")
        This.CommandFunc := ObjBindMethod(This, "Command")
        LV.OnNotify(-3, This.DoubleClickFunc)
        This.LV := LV
        This.HWND := LV.Hwnd
    }

    DoubleClick(LV, L) {
        Item := NumGet(L + (A_PtrSize * 3), 0, "Int")
        Subitem := NumGet(L + (A_PtrSize * 3), 4, "Int")

        RC := Buffer(16, 0)
        NumPut("Int", 0, "Int", SubItem, RC)
        DllCall("SendMessage", "Ptr", LV.Hwnd, "UInt", 0x1038, "Ptr", Item, "Ptr", RC) ; LVM_GETSUBITEMRECT

        This.CX := NumGet(RC, 0, "Int")
        This.CY := NumGet(RC, 4, "Int")
        This.CH := NumGet(RC, 12, "Int") - This.CY

        if (Subitem = 0) {
            ; Largeur exacte de la première colonne
            This.CW := DllCall("SendMessage", "Ptr", LV.Hwnd, "UInt", 0x101D, "Ptr", 0, "Ptr", 0, "Int")
        } else {
            This.CW := NumGet(RC, 8, "Int") - This.CX
        }

        This.Item := Item
        This.Subitem := Subitem
        This.LV.OnNotify(-175, This.BeginLabelEditFunc)
        DllCall("PostMessage", "Ptr", LV.Hwnd, "UInt", 0x1076, "Ptr", Item, "Ptr", 0) ; LVM_EDITLABEL
    }

    BeginLabelEdit(LV, L) {
        This.HEDT := DllCall("SendMessage", "Ptr", LV.Hwnd, "UInt", 0x1018, "Ptr", 0, "Ptr", 0, "UPtr")
        This.ItemText := LV.GetText(This.Item + 1, This.Subitem + 1)
        DllCall("SendMessage", "Ptr", This.HEDT, "UInt", 0x00D3, "Ptr", 0x01, "Ptr", 4) ; EM_SETMARGINS
        DllCall("SendMessage", "Ptr", This.HEDT, "UInt", 0x000C, "Ptr", 0, "Ptr", StrPtr(This.ItemText)) ; WM_SETTEXT
        DllCall("SetWindowPos", "Ptr", This.HEDT, "Ptr", 0, "Int", This.CX, "Int", This.CY,
            "Int", This.CW, "Int", This.CH, "UInt", 0x04)
        OnMessage(0x0111, This.CommandFunc, -1)
        This.LV.OnNotify(-175, This.BeginLabelEditFunc, 0)
        This.LV.OnNotify(-176, This.EndLabelEditFunc)
        return False
    }

    EndLabelEdit(LV, L) {
        static OffText := 16 + (A_PtrSize * 4)
        This.LV.OnNotify(-176, This.EndLabelEditFunc, 0)
        OnMessage(0x0111, This.CommandFunc, 0)
        if (TxtPtr := NumGet(L, OffText, "UPtr")) {
            ItemText := StrGet(TxtPtr)
            LV.Modify(This.Item + 1, "Col" . (This.Subitem + 1), ItemText)
        }
        LV.ModifyCol(This.Subitem + 1, "AutoHdr")
        return False
    }

    Command(W, L, M, H) {
        if (L = This.HEDT) {
            N := (W >> 16) & 0xFFFF
            if (N = 0x0400) || (N = 0x0300) || (N = 0x0100) {
                DllCall("SetWindowPos", "Ptr", L, "Ptr", 0, "Int", This.CX, "Int", This.CY,
                    "Int", This.CW, "Int", This.CH, "UInt", 0x04)
            }
        }
    }
}
