.386
.model flat, stdcall
option casemap:none
;-----------------------------------------------------------------------
;Include 文件定义
;-----------------------------------------------------------------------
include			windows.inc
include			gdi32.inc
includelib		gdi32.lib
include			user32.inc
includelib		user32.lib
include			kernel32.inc
includelib		kernel32.lib
include			comctl32.inc
includelib		comctl32.lib
include			comdlg32.inc
includelib		comdlg32.lib
;-----------------------------------------------------------------------
;Equ 等值定义
;-----------------------------------------------------------------------
;Menu
IDM_MAIN		equ    	1000h

IDM_NEW			equ    	1101h
IDM_OPEN		equ    	1102h
IDM_SAVE		equ    	1103h
IDM_SAVEAS		equ    	1104h
IDM_PAGESET		equ		1105h
IDM_QUIT		equ		1106h

IDM_UNDO		equ		1201h
IDM_REDO		equ		1202h
IDM_CUT			equ		1203h
IDM_COPY		equ		1204h
IDM_PASTE		equ		1205h
IDM_DELETE		equ		1206h
IDM_FIND		equ		1207h
IDM_REPLACE		equ		1208h
IDM_ALL			equ		1209h
IDM_DATE		equ		1210h

IDM_FONT		equ		1301h

IDM_HELP		equ		1401h
IDM_ABOUT		equ		1402h

;Accelerators 	
IDA_MAIN		equ		2000h
;Statusbar
IDCC_STATUSBAR	equ		3000h
;-----------------------------------------------------------------------
;数据段
;-----------------------------------------------------------------------
.data
	hInstance		dd		?
	hWinMain		dd		?
	hStatusBar		dd		?
	hWinEdit		dd		?
	hFile			dd 		?
	hFind			dd 		?
	hReplace		dd 		?
	hMainMenu		dd		?
	hSubMenu		dd		?
	;OPENFILENAME
	szFile			db 		MAX_PATH	dup(?)
	szFileTitle		db 		MAX_PATH	dup(?)
	;CHOOSEFONT
	stLogFont		LOGFONT<?>
	;CHOOSECOLOR
	szFontColors	dd		16			dup(?)
	;FINDREPLACE
	iWM_FINDREPLACE	dd		?
	stFr			FINDREPLACE<?>
	szFindWhat		db		100			dup(?)
	szReplaceWith	db		100			dup(?)
	;StatusBar
	szFormat_1		db		'最近保存文件大小:%d字节 %d行', 0
	;全局存储窗口大小
	stRect_MainWin 	RECT<?>
	;行号相关
	charFmt  		db  	'%4u', 0
	lpEditProc		dd		?
	;全局存储字体
	stCharFormat	CHARFORMAT<?>
	;时间
	stSystemTime SYSTEMTIME <>
	stTimeString db 30 dup(?)

.const
	szClassName		db		'MyTextEditor',0
	szCaptionMain	db		'TextEditor++',0
	szText			db		"Let's do something!",0
	szSaveSucceed	db		'保存成功', 0
	szNotice		db		'提示', 0
	;OPENFILENAME
	szFilter		db		'文本文件(*.txt)', 0, '*.txt', 0
					db		'所有文件(*.*)', 0, '*.*', 0, 0
	szDefaultExt		db		'txt', 0
	szFileHasModified	db 	'文件已被修改,是否保存?', 0
	;FINDREPLACE
	szFindReplace	db    	'commdlg_FindReplace', 0
	szNotFound		db		'文本中没有找到匹配项!', 0
	;EDITSTREAM
	szCannotOpenTheFile	db		'无法打开该文件.', 0

	szDllRiched20	db		'riched20.dll',0
	szClassEdit		db		'RichEdit20A',0
	szFont			db		'宋体',0
	szTxt			db		'无格式文本',0

	dwStatusWidth	dd		300,500,-1

	szHelpTitle		db		'帮助',0
	szHelp			db		'详情请查看作业文档',0

	szAboutTitle	db		'关于TextEditor++',0
	szAbout			db		'基于Win32汇编的文本编辑器',0dh,0ah,0dh,\
							'开发者：谭新宇 卢北辰 刘文华',0dh,0ah,0

;-----------------------------------------------------------------------
;代码段
;-----------------------------------------------------------------------
.code
;-----------------------------------------------------------------------
;显示行号（包括行号栏）
;-----------------------------------------------------------------------
_ShowLineNum  	PROC  	
				local	@stClientRect:RECT		;RichEdit的客户区大小
				local @hDcEdit				;RichEdit的Dc（设备环境）
				local @Char_Height			;字符的高度
				local @Line_Count				;文本的总行数	
				local @ClientHeight			;RichEdit的客户区高度
				local	@CharFmt:CHARFORMAT		;RichEdit中的一个结构，用于获取字符的一系列信息，这里只用它来获取字符高度	
				local	@hdcBmp					;与RichEdit兼容的位图dc
				local	@hdcCpb					;与RichEdit兼容的Dc
				local	@stBuf[10]:byte			;显示行号的缓冲区
				local @Margin						;行间距
				pushad
				
				;将位图载入RichEdit环境中		
				invoke  GetDC, hWinEdit										;获取RichEdit的Dc	
				mov		@hDcEdit, eax
				invoke  CreateCompatibleDC, @hDcEdit						;创建与RichEdit兼容的位图Dc
				mov		@hdcCpb, eax
				invoke  GetClientRect, hWinEdit, addr @stClientRect			;创建与RichEdit兼容的位图
				mov		ebx, @stClientRect.bottom
				sub		ebx, @stClientRect.top
				mov		@ClientHeight, ebx
				invoke  CreateCompatibleBitmap, @hDcEdit, 45, @ClientHeight;
				mov		@hdcBmp, eax
				invoke  SelectObject, @hdcCpb, @hdcBmp						
				;填充颜色
				invoke  CreateSolidBrush, 0face87h							
				invoke  FillRect, @hdcCpb, addr @stClientRect, eax			
				invoke  SetBkMode, @hdcCpb, TRANSPARENT		
				;获取总行数
				invoke  SendMessage, hWinEdit, EM_GETLINECOUNT, 0, 0
				mov 	@Line_Count, eax	
				;获取文本格式
				invoke  RtlZeroMemory, addr @CharFmt, sizeof @CharFmt
				mov		@CharFmt.cbSize, sizeof @CharFmt	
				invoke  SendMessage, hWinEdit, EM_GETCHARFORMAT, SCF_DEFAULT, addr @CharFmt;获取字符高度，以英寸为单位，需转化为磅，只要除以20就行
				;获取行高
				mov		eax, @CharFmt.yHeight									
				cdq
				mov		ebx, 20
				div		ebx
				mov		@Char_Height, eax
				;获取行间距
				mov		ebx, 3
				div		ebx
				mov		@Margin, eax

				invoke	RtlZeroMemory, addr @stBuf, sizeof @stBuf				
				;设置显示行号的前景色
				invoke  SetTextColor, @hdcCpb, 0000000h
				mov		ebx, @Char_Height
				mov		@Char_Height,1 
				;获取文本框中第一个可见的行的行号，没有这个行号显示不会跟着文本的滚动而滚动。
				invoke  SendMessage, hWinEdit, EM_GETFIRSTVISIBLELINE, 0, 0
				mov		edi, eax
				inc		edi			
				;在位图dc中循环输出行号
				.while	edi <= @Line_Count
						invoke  wsprintf, addr @stBuf, addr charFmt, edi			;返回存储的字符数
						invoke  TextOut, @hdcCpb, 1, @Char_Height, addr @stBuf, eax 
						mov		edx, @Char_Height
						add		edx, ebx
						add		edx, 	@Margin	;这里加上行间距，并不精确。
						mov		@Char_Height, edx
						inc  	edi
						.break  .if  edx > @ClientHeight 
				.endw		
				;将已"画好"的位图真正"贴"到RichEdit中
				invoke	BitBlt, @hDcEdit, 0, 0, 45, @ClientHeight, @hdcCpb, 0, 0, SRCCOPY 
				invoke	DeleteDC, @hdcCpb
				invoke	ReleaseDC, hWinEdit, @hDcEdit
				invoke	DeleteObject, @hdcBmp
			
				popad							
				
				ret

_ShowLineNum 	ENDP
;-----------------------------------------------------------------------
;文本编辑框处理
;-----------------------------------------------------------------------
_SubProcEdit  	PROC	hWnd, uMsg, wParam, lParam
				local	@stPs: PAINTSTRUCT
				local	@stPt: POINT
				local	@stRange:CHARRANGE
				
				mov		eax, uMsg
				.if		eax == WM_PAINT
						invoke	CallWindowProc, lpEditProc, hWnd, uMsg, wParam, lParam
						invoke  BeginPaint, hWinEdit, addr @stPs
						invoke  _ShowLineNum
						invoke  EndPaint, hWinEdit, addr @stPs
						ret
				.elseif	eax == WM_RBUTTONDOWN
						;处理右键点击
						invoke 	GetCursorPos, addr @stPt
						invoke 	TrackPopupMenu, hSubMenu, TPM_LEFTALIGN, @stPt.x, @stPt.y, 0, hWinEdit, NULL
				.elseif eax == WM_COMMAND
						;处理文本框内右键菜单选项
						mov		eax, wParam
						.if ax == IDM_UNDO
								invoke  SendMessage, hWinEdit, EM_UNDO, 0, 0

						.elseif ax == IDM_REDO
								invoke  SendMessage, hWinEdit, EM_REDO, 0, 0

						.elseif ax == IDM_CUT
								invoke  SendMessage, hWinEdit, WM_CUT, 0, 0

						.elseif ax == IDM_COPY
								invoke  SendMessage, hWinEdit, WM_COPY, 0, 0

						.elseif ax == IDM_PASTE
								invoke  SendMessage, hWinEdit, WM_PASTE, 0, 0

						.elseif ax == IDM_DELETE
								invoke  SendMessage, hWinEdit, WM_CLEAR, 0, 0

						.elseif ax == IDM_ALL
								mov	@stRange.cpMin, 0
								mov	@stRange.cpMax, -1
								invoke  SendMessage, hWinEdit, EM_EXSETSEL, 0, addr @stRange

						.elseif ax == IDM_FIND
								and		stFr.Flags, not FR_DIALOGTERM
								invoke	FindText, addr stFr
								mov		hFind, eax

						.elseif ax == IDM_REPLACE
								and		stFr.Flags, not FR_DIALOGTERM
								invoke	ReplaceText, addr stFr
								mov		hReplace, eax
						.endif
				.endif
				invoke  CallWindowProc, lpEditProc, hWnd, uMsg, wParam, lParam
				ret

_SubProcEdit 	ENDP
;-----------------------------------------------------------------------
_PageSet PROC
	local	@stPs:PAGESETUPDLG
	invoke	RtlZeroMemory,addr @stPs,sizeof @stPs
	mov		@stPs.lStructSize,sizeof @stPs
	push	hWinMain
	pop		@stPs.hwndOwner
	invoke	PageSetupDlg,addr @stPs
	ret

_PageSet ENDP
;-----------------------------------------------------------------------
_CheckModify	PROC
	;判断文档是否被修改过
	invoke 	SendMessage, hWinEdit, EM_GETMODIFY, 0, 0
	.if 	eax
		invoke	MessageBox, hWinMain, addr szFileHasModified, addr szNotice, MB_YESNOCANCEL
		.if		eax == IDYES
			.if 	!hFile
				call 	_SaveAs
			.else
				call 	_Save
			.endif
		.elseif	eax == IDCANCEL
			mov		eax, FALSE
			ret
		.endif
	.endif
	mov 	eax, TRUE
	ret
				
_CheckModify	ENDP
;-----------------------------------------------------------------------
_ProcStream		PROC	uses ebx edi esi dwCookie, lpBuffer, dwBytes, lpBytes
			
				.if 	dwCookie
						invoke	ReadFile, hFile, lpBuffer, dwBytes, lpBytes, NULL
				.else
						invoke  WriteFile, hFile, lpBuffer, dwBytes, lpBytes, NULL
				.endif
				
				xor		eax, eax
				
				ret
				
_ProcStream		ENDP
;-----------------------------------------------------------------------
_New			PROC

				invoke	CloseHandle, hFile
				invoke 	DestroyWindow, hWinEdit
				invoke 	GetClientRect, hWinMain, addr stRect_MainWin
				mov		eax, stRect_MainWin.bottom
				sub		eax, 0018h
				invoke 	CreateWindowEx, WS_EX_CLIENTEDGE, offset szClassEdit, NULL,\
								WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_AUTOVSCROLL or ES_MULTILINE or ES_NOHIDESEL or ES_WANTRETURN or ES_LEFT,\
								0, 0, stRect_MainWin.right, eax,\
								hWinMain, NULL, hInstance, NULL
				mov		hWinEdit, eax
				invoke 	SendMessage, hWinEdit, EM_SETTEXTMODE, TM_PLAINTEXT, 0
				invoke 	SendMessage, hWinEdit, EM_EXLIMITTEXT, NULL, -1
				invoke  SendMessage, hWinEdit, EM_SETMARGINS, EC_RIGHTMARGIN or EC_LEFTMARGIN, 00050005h + 45
				invoke 	RtlZeroMemory, addr stCharFormat, sizeof stCharFormat
				mov		stCharFormat.cbSize, sizeof CHARFORMAT
				mov		stCharFormat.dwMask, CFM_BOLD or CFM_COLOR or CFM_FACE or CFM_ITALIC or CFM_SIZE or CFM_UNDERLINE or CFM_STRIKEOUT
				mov		stCharFormat.yHeight, 12 * 20
				invoke 	lstrcpy, addr stCharFormat.szFaceName, addr szFont
				invoke 	SendMessage, hWinEdit, EM_SETCHARFORMAT, SCF_ALL, addr stCharFormat
				invoke  SetWindowLong, hWinEdit, GWL_WNDPROC, addr _SubProcEdit
				mov		lpEditProc, eax
				
				;设置标题栏
				invoke 	SetWindowText, hWinMain, addr szCaptionMain
				invoke  SendMessage, hStatusBar, SB_SETTEXT, 0, NULL
				invoke 	SendMessage, hStatusBar, SB_SETTEXT, 1, NULL
				
				ret
				
_New			ENDP
;-----------------------------------------------------------------------
_Open			PROC	
				local @stOfn: OPENFILENAME
				local @stEs: EDITSTREAM
				local @szBuffer[256]: byte
				local @FileSize
				local	@LineNumber
				
				invoke 	RtlZeroMemory, addr @stOfn, sizeof @stOfn
				push		hWinMain
				pop		@stOfn.hwndOwner
				mov		@stOfn.lStructSize, sizeof OPENFILENAME
				mov		@stOfn.lpstrFilter, offset szFilter
				mov		@stOfn.lpstrFile, offset szFile
				mov		@stOfn.nMaxFile, MAX_PATH
				mov		@stOfn.lpstrFileTitle, offset szFileTitle
				mov		@stOfn.nMaxFileTitle, MAX_PATH
				mov		@stOfn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
				mov		@stOfn.lpstrDefExt, offset szDefaultExt 
				
				invoke 	GetOpenFileName, addr @stOfn
				.if eax
					;成功打开文件
					invoke	CreateFile, addr szFile, GENERIC_READ or GENERIC_WRITE,\
							FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
					.if		eax == INVALID_HANDLE_VALUE
							invoke	MessageBox, hWinMain, addr szCannotOpenTheFile, NULL, MB_OK or MB_ICONSTOP
							ret
					.endif
					push 	eax 
					.if 	hFile
							invoke 	CloseHandle, hFile
					.endif
					pop 	eax
					mov		hFile, eax
					mov		@stEs.dwCookie, TRUE
					mov		@stEs.dwError, NULL
					mov		@stEs.pfnCallback, offset _ProcStream
					invoke 	SendMessage, hWinEdit, EM_STREAMIN, SF_TEXT, addr @stEs
					invoke  SendMessage, hWinEdit, EM_SETMODIFY, FALSE, NULL

					;设置部分状态栏信息
					invoke 	GetFileSize, hFile, NULL
					mov		@FileSize, eax
					invoke  SendMessage, hWinEdit, EM_GETLINECOUNT, 0, 0
					mov		@LineNumber, eax
					invoke 	wsprintf, addr @szBuffer, addr szFormat_1, @FileSize, @LineNumber
					invoke  SendMessage, hStatusBar, SB_SETTEXT, 0, addr @szBuffer
					invoke 	SendMessage, hStatusBar, SB_SETTEXT, 1, addr szFile

					;更改标题栏
					invoke 	SetWindowText, hWinMain, @stOfn.lpstrFileTitle

				.endif	
				ret
				
_Open			ENDP	
;-----------------------------------------------------------------------
_Save			PROC
				local	@stEs: EDITSTREAM
				local @szBuffer[256]: byte
				local @FileSize
				local	@LineNumber
				
				invoke 	SetFilePointer, hFile, 0, 0, FILE_BEGIN
				invoke 	SetEndOfFile, hFile
				mov 	@stEs.dwCookie, FALSE
				mov 	@stEs.pfnCallback, offset _ProcStream
				invoke 	SendMessage, hWinEdit, EM_STREAMOUT, SF_TEXT, addr @stEs
				invoke 	SendMessage, hWinEdit, EM_SETMODIFY, FALSE, 0

				;设置部分状态栏信息
				invoke 	GetFileSize, hFile, NULL
				mov		@FileSize, eax
				invoke  SendMessage, hWinEdit, EM_GETLINECOUNT, 0, 0
				mov		@LineNumber, eax
				invoke 	wsprintf, addr @szBuffer, addr szFormat_1, @FileSize, @LineNumber
				invoke  SendMessage, hStatusBar, SB_SETTEXT, 0, addr @szBuffer
				invoke 	SendMessage, hStatusBar, SB_SETTEXT, 1, addr szFile

				invoke 	MessageBox, hWinMain, offset szSaveSucceed, offset szNotice, MB_OK
				ret
				
_Save			ENDP	
;-----------------------------------------------------------------------	
_SaveAs			PROC
				local 	@stOfn: OPENFILENAME

				
				invoke 	RtlZeroMemory, addr @stOfn, sizeof @stOfn
				push	hWinMain
				pop		@stOfn.hwndOwner
				mov		@stOfn.lStructSize, sizeof OPENFILENAME
				mov		@stOfn.lpstrFilter, offset szFilter
				mov		@stOfn.lpstrFile, offset szFile
				mov		@stOfn.nMaxFile, MAX_PATH
				mov		@stOfn.lpstrFileTitle, offset szFileTitle
				mov		@stOfn.nMaxFileTitle, MAX_PATH
				mov		@stOfn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
				mov		@stOfn.lpstrDefExt, offset szDefaultExt 
				
				invoke 	GetSaveFileName, addr @stOfn
				.if		eax
					invoke	CreateFile, addr szFile, GENERIC_READ or GENERIC_WRITE,\
							FILE_SHARE_READ or FILE_SHARE_WRITE, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
					.if		eax == INVALID_HANDLE_VALUE
							invoke	MessageBox, hWinMain, addr szCannotOpenTheFile, NULL, MB_OK or MB_ICONSTOP
							mov		eax, FALSE
							ret
					.endif
					push 	eax 
					.if 	hFile
							invoke 	CloseHandle, hFile
					.endif
					pop 	eax
					mov		hFile, eax
					call 	_Save

					;成功提示
					invoke 	MessageBox, hWinMain, offset szSaveSucceed, offset szNotice, MB_OK
				.endif

				mov 	eax, TRUE
				
				ret
				
_SaveAs			ENDP
;-----------------------------------------------------------------------
_Quit			PROC
				invoke _CheckModify
				.if eax
					invoke 	DestroyWindow, hWinMain
					invoke 	PostQuitMessage, NULL
				.endif
				ret
				
_Quit			ENDP
;-----------------------------------------------------------------------
_FindReplace	PROC
				local	@stFtEx: FINDTEXTEX
				
				invoke 	SendMessage, hWinEdit, EM_EXGETSEL, 0, addr @stFtEx.chrg
				.if		stFr.Flags & FR_DOWN
						push	@stFtEx.chrg.cpMax
						pop 	@stFtEx.chrg.cpMin
				.endif
				mov 	@stFtEx.chrg.cpMax, -1
				
				mov 	@stFtEx.lpstrText, offset szFindWhat
				mov     ecx, stFr.Flags
				and 	ecx, FR_MATCHCASE or FR_DOWN or FR_WHOLEWORD
				
				invoke	SendMessage, hWinEdit, EM_FINDTEXTEX, ecx, addr @stFtEx
				.if 	eax == -1
						invoke	MessageBox, NULL, addr szNotFound, addr szNotice, MB_OK
						ret
				.endif
				invoke	SendMessage, hWinEdit, EM_EXSETSEL, 0, addr @stFtEx.chrgText
				invoke	SendMessage, hWinEdit, EM_SCROLLCARET, NULL, NULL
				.if		stFr.Flags & FR_REPLACE
						invoke	SendMessage, hWinEdit, EM_REPLACESEL, TRUE, addr szReplaceWith
				.endif
				.if		stFr.Flags & FR_REPLACEALL 
						invoke 	SendMessage, hWinEdit, WM_SETTEXT, 0, addr szReplaceWith
				.endif
				ret
				
_FindReplace	ENDP
;-----------------------------------------------------------------------
_SetFont PROC _lpszFont,_dwFontSize,_dwColor
		local	@stCf:CHARFORMAT

		invoke	RtlZeroMemory,addr @stCf,sizeof @stCf
		mov	@stCf.cbSize,sizeof @stCf
		mov	@stCf.dwMask,CFM_SIZE or CFM_FACE or CFM_BOLD or CFM_COLOR
		push _dwColor
		pop @stCf.crTextColor
		push	_dwFontSize
		pop	@stCf.yHeight
		mov	@stCf.dwEffects,0
		invoke	lstrcpy,addr @stCf.szFaceName,_lpszFont
		invoke	SendMessage,hWinEdit,EM_SETTEXTMODE,1,0
		invoke	SendMessage,hWinEdit,EM_SETCHARFORMAT,SCF_ALL,addr @stCf

		ret
_SetFont ENDP
;-----------------------------------------------------------------------
_ChooseFont			PROC
				local 	@stCf: CHOOSEFONT
				
				pushad
				invoke 	RtlZeroMemory, addr @stCf, sizeof @stCf
				mov		@stCf.lStructSize, sizeof @stCf
				push		hWinMain
				pop		@stCf.hwndOwner
				mov		@stCf.lpLogFont, offset stLogFont
				push		szFontColors
				pop		@stCf.rgbColors
				mov		@stCf.Flags, CF_SCREENFONTS or CF_INITTOLOGFONTSTRUCT or CF_EFFECTS
				
				invoke	ChooseFont, addr @stCf
				.if			eax
							mov eax,@stCf.iPointSize
							shl eax,1
							invoke _SetFont,addr stLogFont.lfFaceName,eax,@stCf.rgbColors
				.endif
				popad
				
				ret		
_ChooseFont			ENDP	
;-----------------------------------------------------------------------
_Date 			PROC
				invoke GetLocalTime ,ADDR stSystemTime

				mov ebx, offset stTimeString

				mov ax, stSystemTime.wYear
				mov dx, 0
				mov cx, 1000
				div cx
				add al, 48
				mov [ebx], al
				inc ebx
				mov ax, dx
				mov dx, 0
				mov cx, 100
				div cx
				add al, 48
				mov [ebx], al
				inc ebx
				mov ax, dx
				mov dx, 0
				mov cx, 10
				div cx
				add al, 48
				mov [ebx], al
				inc ebx
				mov ax, dx
				add al, 48
				mov [ebx], al
				inc ebx

				mov al, 47
				mov [ebx], al
				inc ebx

				mov ax, stSystemTime.wMonth
				mov dx, 0
				mov cx, 10
				div cx
				add al, 48
				mov [ebx], al
				inc ebx
				mov ax, dx
				add al, 48
				mov [ebx], al
				inc ebx

				mov al, 47
				mov [ebx], al
				inc ebx

				mov ax, stSystemTime.wDay
				mov dx, 0
				mov cx, 10
				div cx
				add al, 48
				mov [ebx], al
				inc ebx
				mov ax, dx
				add al, 48
				mov [ebx], al
				inc ebx
				invoke SendMessage, hWinEdit,EM_REPLACESEL,0,addr stTimeString

				ret
_Date			ENDP
;-----------------------------------------------------------------------
;窗口过程
;-----------------------------------------------------------------------
_ProcWinMain PROC USES ebx edi esi,hWnd,uMsg,wParam,lParam 
	;wParam参数高16位是通知码，低16位是命令ID  lParam是发送WM_COMMAND消息的子窗口句柄
	;菜单消息的通知码是0，加速键消息的通知码是1
	;对于菜单和加速键引发的WM_COMMAND消息，lParam的值为0
	local @stPos: POINT
	local @stRange:CHARRANGE
	mov	eax,uMsg
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.if	eax == WM_CREATE
				;初始化和注册查找和替换
				invoke 	RtlZeroMemory, addr stFr, sizeof stFr
				mov		stFr.lStructSize, sizeof FINDREPLACE
				push	hWnd
				pop		stFr.hwndOwner
				mov		stFr.Flags, FR_DOWN
				;暂未加入提示信息常亮
				mov		stFr.lpstrFindWhat, offset szFindWhat
				mov		stFr.wFindWhatLen, sizeof szFindWhat
				mov		stFr.lpstrReplaceWith, offset szReplaceWith
				mov		stFr.wReplaceWithLen, sizeof szReplaceWith
				invoke 	RegisterWindowMessage, addr szFindReplace
				mov		iWM_FINDREPLACE, eax
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
				;创建文本窗口	
				invoke	CreateWindowEx,WS_EX_OVERLAPPEDWINDOW,OFFSET szClassEdit,NULL,\
					WS_CHILD or WS_VISIBLE or WS_VSCROLL or ES_AUTOVSCROLL or ES_MULTILINE or ES_NOHIDESEL or ES_WANTRETURN or ES_LEFT,\
					0, 0, 0, 0, hWnd, NULL, hInstance, NULL
				mov		hWinEdit, eax
				invoke	SendMessage, hWinEdit, EM_SETTEXTMODE, TM_PLAINTEXT, 0
				invoke	SendMessage, hWinEdit, EM_SETEVENTMASK, 0, ENM_MOUSEEVENTS
				invoke	SendMessage, hWinEdit, EM_EXLIMITTEXT, NULL, -1
				invoke	SendMessage, hWinEdit, EM_SETMARGINS, EC_RIGHTMARGIN or EC_LEFTMARGIN, 00050000h + 45
				invoke	RtlZeroMemory, addr stCharFormat, sizeof stCharFormat  
				mov		stCharFormat.cbSize, sizeof CHARFORMAT
				mov		stCharFormat.dwMask, CFM_BOLD or CFM_COLOR or CFM_FACE or CFM_ITALIC or CFM_SIZE or CFM_UNDERLINE or CFM_STRIKEOUT
				mov		stCharFormat.yHeight, 12 * 20
				invoke	SendMessage, hWinEdit, EM_SETCHARFORMAT, SCF_ALL, addr stCharFormat
				invoke	lstrcpy, addr stCharFormat.szFaceName, addr szFont
				invoke  SetWindowLong, hWinEdit, GWL_WNDPROC, addr _SubProcEdit
				mov		lpEditProc, eax

				invoke GetSubMenu,hMainMenu,1
				mov hSubMenu,eax
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.elseif	eax == WM_COMMAND
				;处理顶部菜单选项
				mov eax,wParam
				.if ax == IDM_NEW
					invoke	_CheckModify
					.if	eax
						invoke _New
					.endif

				.elseif ax == IDM_OPEN
					invoke _CheckModify
					.if	eax
						invoke _Open
					.endif

				.elseif ax == IDM_SAVE
					.if !hFile
						call _SaveAs
					.else
						call _Save
					.endif

				.elseif ax == IDM_SAVEAS
					call	_SaveAs

				.elseif ax == IDM_PAGESET
					call _PageSet

				.elseif ax == IDM_QUIT
					invoke _Quit

				.elseif ax == IDM_UNDO 
					invoke SendMessage, hWinEdit, EM_UNDO, 0, 0

				.elseif ax == IDM_REDO
					invoke SendMessage, hWinEdit, EM_REDO, 0, 0

				.elseif ax == IDM_CUT
					invoke SendMessage, hWinEdit, WM_CUT, 0, 0

				.elseif ax == IDM_COPY
					invoke SendMessage, hWinEdit, WM_COPY, 0, 0

				.elseif ax == IDM_PASTE
					invoke SendMessage, hWinEdit, WM_PASTE, 0, 0

				.elseif ax == IDM_DELETE
					invoke SendMessage, hWinEdit, WM_CLEAR, 0, 0

				.elseif ax == IDM_FIND
					and stFr.Flags, not FR_DIALOGTERM
					invoke FindText, addr stFr
					mov hFind, eax

				.elseif ax == IDM_REPLACE 
					and stFr.Flags, not FR_DIALOGTERM
					invoke ReplaceText, addr stFr
					mov hReplace, eax

				.elseif ax == IDM_ALL 
					mov @stRange.cpMin, 0
					mov @stRange.cpMax, -1
					invoke SendMessage, hWinEdit, EM_EXSETSEL, 0, addr @stRange

				.elseif ax == IDM_DATE
					call _Date

				.elseif ax == IDM_FONT
					call _ChooseFont
					call _ShowLineNum

				.elseif ax == IDM_HELP
					invoke  MessageBox, hWinMain,addr szHelp, addr szHelpTitle, MB_OK

				.elseif ax == IDM_ABOUT
					invoke  MessageBox, hWinMain,addr szAbout, addr szAboutTitle, MB_OK
				.endif		
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.elseif	eax == WM_RBUTTONDOWN
				invoke  GetCursorPos, addr @stPos
				invoke  TrackPopupMenu, hSubMenu, TPM_LEFTALIGN, @stPos.x, @stPos.y, NULL, hWinEdit, NULL
;-----------------------------------------------------------
	;!!!这段会在用户调出查找/替换页面并选择取消时调用......不知道其他操作怎么判断用户是否选择取消?
	.elseif eax == iWM_FINDREPLACE
				.if stFr.Flags & FR_DIALOGTERM
				;用户按下取消，对话框关闭
				.else
					call _FindReplace
				.endif
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    .elseif eax == WM_SIZE
				invoke 	MoveWindow, hStatusBar, 0, 0, 0, 0, TRUE
				invoke 	GetClientRect, hWnd, addr stRect_MainWin
				mov		ebx, stRect_MainWin.bottom
				sub		ebx, 0018h
				invoke 	MoveWindow, hWinEdit, 0, 0, stRect_MainWin.right, ebx, TRUE
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.elseif	eax ==	WM_ACTIVATE
			mov	eax,wParam
			.if	(ax ==	WA_CLICKACTIVE ) || (ax == WA_ACTIVE)
				invoke	SetFocus,hWinEdit
			.endif
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.elseif	eax == WM_CLOSE
				call _Quit
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.else
				invoke DefWindowProc, hWnd, uMsg, wParam,lParam
				ret
	.endif
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	xor eax,eax
	ret
_ProcWinMain ENDP
;-----------------------------------------------------------------------
_WinMain	PROC
	local @stWndClass: WNDCLASSEX
	local @stMsg: MSG
	local @hAccelerator: DWORD
	local @hRichEdit: DWORD
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;注册文本编辑框
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	LoadLibrary,addr szDllRiched20
	mov		@hRichEdit,eax
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;得到窗口句柄并载入菜单和加速键
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	GetModuleHandle,NULL
	mov		hInstance,eax
	invoke	LoadMenu,hInstance,IDM_MAIN
	mov		hMainMenu,eax
	invoke	LoadAccelerators,hInstance,IDA_MAIN
	mov		@hAccelerator,eax
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;注册窗口类
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	RtlZeroMemory,addr @stWndClass,sizeof @stWndClass
	invoke	LoadCursor,0, IDC_ARROW
	mov		@stWndClass.hCursor, eax
	invoke	LoadIcon,0,IDI_APPLICATION
	mov		@stWndClass.hIcon, eax
	push	hInstance
	pop		@stWndClass.hInstance
	mov		@stWndClass.cbSize, sizeof WNDCLASSEX
	mov		@stWndClass.style, CS_HREDRAW or CS_VREDRAW
	mov		@stWndClass.lpfnWndProc, offset _ProcWinMain
	mov		@stWndClass.hbrBackground, COLOR_WINDOW+1
	mov		@stWndClass.lpszClassName, offset szClassName
	invoke	RegisterClassEx, addr @stWndClass
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;建立并显示窗口
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	CreateWindowEx,WS_EX_CLIENTEDGE,\
				offset szClassName,offset szCaptionMain,\
				WS_OVERLAPPEDWINDOW ,\
				100,100,600,400,\
				NULL,hMainMenu,hInstance,NULL
	mov		hWinMain,eax
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;创建状态栏
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	CreateStatusWindow,WS_CHILD or WS_VISIBLE or SBARS_SIZEGRIP,NULL,hWinMain,IDCC_STATUSBAR
	mov		hStatusBar,eax
	invoke	SendMessage, hStatusBar, SB_SETPARTS, 2, offset dwStatusWidth
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;显示并更新窗口
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	invoke	ShowWindow,hWinMain,SW_SHOWNORMAL
	invoke	UpdateWindow,hWinMain
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;消息循环
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	.while TRUE
				invoke	GetMessage, addr @stMsg, NULL,0,0
				.break .if eax == 0
				invoke	TranslateAccelerator,hWinMain,@hAccelerator,addr @stMsg
				.if eax == 0
					invoke	TranslateMessage, addr @stMsg
					invoke	DispatchMessage, addr @stMsg
				.endif
	.endw
	invoke	FreeLibrary, @hRichEdit
	ret
_WinMain ENDP
;-----------------------------------------------------------------------
main PROC
	call	_WinMain
	invoke	ExitProcess, NULL
main ENDP
;-----------------------------------------------------------------------
END main