.MODEL SMALL
.STACK 1000H
.Data
	CR EQU 0DH
	LF EQU 0AH
	number DB "00000$"
	i DW 1 DUP (0000H)
	j DW 1 DUP (0000H)
	k DW 1 DUP (0000H)
	ll DW 1 DUP (0000H)
	m DW 1 DUP (0000H)
	n DW 1 DUP (0000H)
	o DW 1 DUP (0000H)
	p DW 1 DUP (0000H)
.CODE
main PROC
	MOV AX, @DATA
	MOV DS,AX
	PUSH BP
	MOV BP,SP
L0:	MOV CX, 1
	MOV i,CX
	MOV AX,i
	CALL print_output
	CALL new_line
L1:	MOV CX, 5
	MOV CX, 8
	MOV j,CX
	MOV AX,j
	CALL print_output
	CALL new_line
L2:	MOV CX,i
	MOV CX, 2
	PUSH CX
	MOV CX,j
	POP AX
	IMUL CX
	MOV CX,AX
	MOV k,CX
	MOV AX,k
	CALL print_output
	CALL new_line
L3:	MOV CX,k
	PUSH CX
	MOV CX, 9
	POP AX
	CWD
	IDIV CX
	MOV CX,DX
	MOV m,CX
	MOV AX,m
	CALL print_output
	CALL new_line
L4:	MOV CX,m
	MOV AX,CX
	MOV CX,ll
	CMP AX,CX
	JLE L5
	MOV CX,0
	JMP L6
L5:
	MOV CX,1
L6:	MOV n,CX
	MOV AX,n
	CALL print_output
	CALL new_line
L7:	MOV CX,i
	MOV AX,CX
	MOV CX,j
	CMP AX,CX
	JNE L8
	MOV CX,0
	JMP L9
L8:
	MOV CX,1
L9:	MOV o,CX
	MOV AX,o
	CALL print_output
	CALL new_line
L10:	MOV CX,n
	CMP CX,0
	JNZ L11
	MOV CX,o
L11:
	MOV p,CX
	MOV AX,p
	CALL print_output
	CALL new_line
L12:	MOV CX,n
	CMP CX,0
	JCXZ L13
	MOV CX,o
L13:
	MOV p,CX
	MOV AX,p
	CALL print_output
	CALL new_line
L14:
	MOV CX, p
	MOV AX, CX
	INC AX
	MOV p,AX
	MOV AX,p
	CALL print_output
	CALL new_line
L15:	MOV CX,p
	MOV k,CX
	MOV AX,k
	CALL print_output
	CALL new_line
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
