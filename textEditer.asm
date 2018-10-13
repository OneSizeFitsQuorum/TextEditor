.386
.model flat, stdcall
.stack 4096

includelib irvine32.lib
 
ExitProcess	PROTO STDCALL:DWORD
  
.data


.code
main PROC

	invoke ExitProcess, 0
main ENDP
END main


