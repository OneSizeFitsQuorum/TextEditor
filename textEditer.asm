.386
.model flat, stdcall
option casemap:none
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;Include 文件定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
include         windows.inc
include         gdi32.inc
includelib      gdi32.lib
include         user32.inc
includelib      user32.lib
include         kernel32.inc
includelib      kernel32.lib
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;Equ 等值定义
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDM_MAIN         equ           1000h

IDM_NEW          equ           1101h
IDM_OPEN         equ           1102h
IDM_SAVE          equ           1103h
IDM_SAVEAS      equ           1104h
IDM_QUIT          equ           1105h

IDM_UNDO        equ           1201h
IDM_CUT            equ           1202h
IDM_COPY         equ            1203h
IDM_PASTE         equ           1204h
IDM_DELETE        equ           1205h
IDM_FIND           equ           1206h
IDM_FINDNEXT   equ           1207h
IDM_REPLACE     equ            1208h
IDM_TURN          equ            1209h
IDM_ALL             equ            1210h
IDM_DATE          equ            1211h

IDM_FONT         equ             1301h

IDM_HELP          equ             1401h
IDM_ABOUT       equ             1402h
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;数据段
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  
.data?
	hInstance dd ?
	hWinMain dd ?
	hMenu dd ?
	hSubMenu dd ?
.const
	szClassName db 'MyTextEditer',0
	szCaptionMain db 'TextEditer++',0
	szText db "Let's do something!",0
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;代码段
.code
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_Quit  PROC
				invoke DestroyWindow, hWinMain
				invoke PostQuitMessage,NULL
				ret
_Quit  ENDP
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
;窗口过程
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_ProcWinMain PROC USES ebx edi esi,hWnd,uMsg,wParam,lParam
	local @stPs:PAINTSTRUCT
	local @stRect:RECT
	local @hDc
	mov eax,uMsg
;**********************************************************************************
	.if			eax == WM_CREATE
				invoke GetSubMenu,hMenu,1
				mov hSubMenu,eax

;**********************************************************************************
	.elseif	eax == WM_PAINT
				invoke BeginPaint, hWnd, addr @stPs
				mov @hDc, eax
				invoke GetClientRect, hWnd, addr @stRect
				invoke DrawText,@hDc, addr szText,-1,\
				addr @stRect,\
				DT_SINGLELINE Or DT_CENTER Or DT_VCENTER
				invoke EndPaint, hWnd, addr @stPs

;**********************************************************************************
	.elseif	eax == WM_CLOSE
				call _Quit
;**********************************************************************************
	.else
				invoke DefWindowProc, hWnd, uMsg, wParam,lParam
				ret
	.endif
;**********************************************************************************
	xor eax,eax
	ret
_ProcWinMain ENDP
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
_WinMain	PROC
	local @stWndClass:WNDCLASSEX
	local @stMsg:MSG
	invoke GetModuleHandle,NULL
	mov hInstance,eax
	invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass
;**********************************************************************************
;注册窗口类
;**********************************************************************************
	invoke LoadCursor,0, IDC_ARROW
	mov @stWndClass.hCursor, eax
	invoke LoadIcon,0,IDI_APPLICATION
	mov @stWndClass.hIcon, eax
	push hInstance
	pop @stWndClass.hInstance
	mov @stWndClass.cbSize, sizeof WNDCLASSEX
	mov @stWndClass.style, CS_HREDRAW or CS_VREDRAW
	mov @stWndClass.lpfnWndProc, offset _ProcWinMain
	mov @stWndClass.hbrBackground, COLOR_WINDOW+1
	mov @stWndClass.lpszClassName, offset szClassName
	invoke RegisterClassEx, addr @stWndClass
;**********************************************************************************
;建立并显示窗口
;**********************************************************************************
	invoke CreateWindowEx,WS_EX_CLIENTEDGE,\
				offset szClassName,offset szCaptionMain,\
				WS_OVERLAPPEDWINDOW or WS_VSCROLL ,\
				100,100,600,400,\
				NULL,NULL,hInstance,NULL
	mov hWinMain,eax
	invoke ShowWindow,hWinMain,SW_SHOWNORMAL
	invoke UpdateWindow,hWinMain
;**********************************************************************************
;消息循环
;**********************************************************************************
	.while TRUE
				invoke GetMessage, addr @stMsg, NULL,0,0
				.break .if eax==0
				invoke TranslateMessage, addr @stMsg
				invoke DispatchMessage, addr @stMsg
	.endw
	ret
_WinMain ENDP
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
main PROC
	call _WinMain
	invoke ExitProcess, NULL
main ENDP
;>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
END main


