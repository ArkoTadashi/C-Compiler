.MODEL SMALL
.STACK 1000H
.Data
	CR EQU 0DH
	LF EQU 0AH
	number DB "00000$"
	a DW 1 DUP (0000H)
	b DW 1 DUP (0000H)
.CODE
main PROC
	MOV AX, @DATA
	MOV DS,AX
	PUSH BP
	MOV BP,SP
;S:if(B)S1 else S2 -- line 9
L0:
	JCXZ L2

	ADD SP, 0
	JMP L1
L2:
	ADD SP, 0
L1:
	ADD SP, 0
	POP BP
	MOV AH, 4CH
	INT 21H
main ENDP

new_line PROC
	PUSH AX
	PUSH DX
	MOV AH,2
	MOV dl,cr
	INT 21h
	MOV AH,2
	MOV dl,lf
	INT 21h
	POP DX
	POP AX
	RET
new_line ENDP

print_output PROC  ;print what is in ax
	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX
	PUSH SI
	LEA SI,number
	MOV BX,10
	ADD SI,4
	CMP AX,0
	JNGE negate
print:
	XOR DX,DX
	DIV BX
	MOV [SI],dl
	ADD [SI],'0'
	DEC SI
	CMP AX,0
	JNE print
	INC SI
	LEA DX,SI
	MOV AH,9
	INT 21h
	POP SI
	POP DX
	POP CX
	POP BX
	POP AX
	RET
negate:
	PUSH AX
	MOV AH,2
	MOV dl,'-'
	INT 21h
	POP AX
	NEG AX
	JMP print
print_output ENDP
END main
