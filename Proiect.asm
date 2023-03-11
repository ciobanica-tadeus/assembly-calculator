.386
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern printf: proc
extern scanf: proc
extern atof : proc
extern strlen : proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
msg db "Introduceti o expresie :",13,10,0	;----mesajul de inceput
expresia db 100 dup(0)						;----expresia citita de la tastatura de catre utilizator
MakeNumber db 30 dup(0)						;----vectorul in care vom forma numarul
value dq 0.0 								;----variabila in care copiem valoarea calculata
operator1 db 0
operator2 db 0
precedenceOperator2 dd 0 
;tipurile de date string,integer,float
string_format db "%s",0
integer_format db "%d",0
float_format db "%.1lf",13,10,0 
.code
;------------------------------------------------
;;macro pentru a folosi functiile cu un singur parametru 
apel1 macro comanda,arg1
	push arg1
	call comanda 
	add esp,4
endm
;------------------------------------------------
;;macro pentru a folosi functiile cu doi parametri
apel2 macro comanda,arg1,arg2
	push arg2
	push arg1
	call comanda 
	add esp,8
endm
;---------------------------------------------------
;;macro pentru a folosi functiile cu trei parametri
apel3 macro comanda,arg1,arg2,arg3
	push arg3
	push arg2
	push arg1
	call comanda 
	add esp,12
endm
;---------------------------------------------------------
;;macroul care verifica daca un caracter este >='0' si <='9'
IsDigit macro char
local final,isdigit
	push ecx
	push edx 
	cmp char, '0'
	jl final
	cmp char,'9' 
	jg final 
	mov eax,1
	jmp isdigit
final:
	mov eax,0
isdigit:
	pop edx 
	pop ecx
endm
;------------------------------------------------------
;;macroul care verifica daca un caracter este '.'-punct
IsPoint macro char
local final1,ispoint
	push ecx
	push edx 
	cmp char, '.'
	jne final1
	mov eax,1
	jmp ispoint
final1:
	mov eax,0
ispoint:
	pop edx 
	pop ecx
endm
;-----------------------------------------------------------------------------
;;macroul care verifica daca un caracter este unul dintre operatiile acceptate de calculator
;; '*', '/' ,'+','-'
IsOperator macro char
local final2,false,fin
	push ecx
	push edx
	cmp char,'-'
	je final2
	cmp char,'+'
	je final2
	cmp char,'*'
	je final2
	cmp char,'/'
	je final2
	jmp false
final2:
	mov eax,1
	jmp fin
false:
	mov eax,0
fin:
	pop edx
	pop ecx
endm
;------------------------------------------------------------------------------
;--macroul care efectueaza o operatie intre 2 valori de pe stiva 
;--rezultatul fiind salvat intodeuna intr-o variabila pentru a putea fi folosita ulterior 
ApplyOperation macro char
local multiply,divide,sum,substraction,endofoperation,log,sin
	push ecx
	push edx
	cmp char,'*'
	je multiply
	cmp char,'/'
	je divide
	cmp char,'+'
	je sum
	cmp char , '-'
	je substraction
	cmp char,'l'
	je log
	cmp char,'s'
	je sin
multiply:
	fmul
	jmp endofoperation
divide:
	fdiv
	jmp endofoperation
sum:
	fadd
	jmp endofoperation
substraction:
	fsub
	jmp endofoperation
log:							;--fyl2x = ST(1)*log(ST(0)) ==> incarcam valoarea 1 apoi facem schimb ST(0) cu ST(1)
	fld1
	fxch ST(1)
	fyl2x
	jmp endofoperation
sin:
	fsin
	jmp endofoperation
endofoperation:
	lea eax, value
	fstp QWord ptr [eax]
	fld QWord ptr [value]
	pop edx
	pop ecx
endm
;-----------------------------------------------------
;macroul care verifica ordinea efectuarii operatiilor
;ordinea in ordinea prioritara este : 1.sin
									; 2.log
									; 3.* si /
									; 4.+ si -
Precedence macro char
local return0, return1,return2,return3,return4,endofprecedence 
	push ecx
	push edx
	cmp char,'#'
	je return0
	cmp char,'('
	je return0
	cmp char,'+'
	je return1
	cmp char,'-'
	je return1 
	cmp char,'*'
	je return2
	cmp char,'/'
	je return2
	cmp char,'l'
	je return3
	cmp char,'s'
	je return4
return0:
	mov eax,0
	jmp endofprecedence
return1:
	mov eax,1
	jmp endofprecedence
return2:
	mov eax,2
	jmp endofprecedence
return3:
	mov eax,3
	jmp endofprecedence
return4:
	mov eax,4
	jmp endofprecedence
endofprecedence:	
	pop edx
	pop ecx
endm
;------------------------------------
;functia care verifica daca caracterul din sirul expresia este litera 's' sau 't'
Isletter proc
	push ebp
	mov ebp, esp
	push ecx
	push edx
	mov ecx,[ebp+8]
	cmp ecx,'s'
	je sinus
	cmp ecx,'l'
	je logaritm
	mov eax,0
	jmp end_
sinus:
	mov eax,2
	jmp end_
logaritm:
	mov eax,1
	jmp end_
end_:
	pop edx
	pop ecx
	mov esp, ebp
	pop ebp
	ret 4
Isletter endp
;----------------------------------------------------
;functia care verifica daca caracterul este p si in caz afirmativ pune pe stiva operanzilor valoarea pi
Ispi proc
	push ebp
	mov ebp, esp
	push ecx
	push edx
	mov ecx,[ebp+8]
	cmp ecx,'p'
	je pi
	jmp endpi
pi:
	fldpi
	mov eax,1
endpi:
	add esi,2
	pop edx
	pop ecx
	mov esp, ebp
	pop ebp
	ret 4
Ispi endp

;----------------------------------------------------
;functia care incarca valoarea precedenta pe stiva daca primul caracter este un operator
pushLastValue proc
	push ebp
	mov ebp, esp 
	fld QWord ptr [value]
	mov esp, ebp
	pop ebp
	ret 0
PushLastValue endp
;----------------------------------------------------------------
;functia care va evalua expresia si va returna rezultatul
EvaluateExpresion proc

	push ebp
	mov ebp, esp
	mov esi,0
	mov ecx,0
	mov eax,0
	mov eax,'#'
	push eax 	;-------punem pe stiva caracterul '#' pentru a sti la sfarsit ca am efectuat toate operatiile  

	IsOperator expresia[0]
	cmp eax,1
	je push_lastValue
loop_:
	cmp expresia[esi],'='
	je endofstring
	cmp expresia[esi],'('
	je isopeningbrace ;; daca este paranteza deschisa facem push
	IsDigit expresia[esi]
	cmp eax,1
	je donumber
	jmp endwhile_makenumber
	
					;-----WHILE IS DIGIT OR POINT-----	
					;copiem cate un byte in sirul MakeNumber
			donumber:
					IsDigit expresia[esi]
					cmp eax,1
					je copy_NR
					IsPoint expresia[esi]
					cmp eax,1
					jne endofnumber
			copy_NR:
					mov al,expresia[esi]
					mov MakeNumber[ecx],al
					inc ecx
					inc esi
					jmp donumber
					;;punem pe stiva numarul si golim vectorul in care se formeaza numarul
			endofnumber:
				push ecx
				push offset MakeNumber
				call atof
				add esp,4
				pop ecx
				clear:
				mov MakeNumber[ecx],0
				loop clear
				mov ecx,0
				mov MakeNumber,0
				jmp loop_
					;-----NUMBER IS MADE, NEXT STEP-----
					
endwhile_makenumber:
	cmp expresia[esi],')'
	je whilebrace
	IsOperator expresia[esi]
	cmp eax,1
	je pushOperator
;---verificam daca e litera s sau l si pentru aceasta vom apela procedura Isletter ==> 1. daca avem in eax 1 inseamna ca avem litera s deci vom efectua sinus 
;																					   2. daca avem in eax 2 inseamna ca avem litera l deci vom efectua log
	mov eax,0
	mov al,expresia[esi]
	push eax
	call Isletter
	cmp eax,1
	je DOSIN
	cmp eax,2
	je DOLOG
;------daca am ajuns pana aici inseamna ca nu avem nici una dintre optiunile de mai sus: '=' , '(','cifra', '.','operator', 's', 'l'
;------atunci verificam daca este litera p in caz afirmativ vom pune pe stiva valoarea pi si mergem cu 2 pozitii inainte in sirul expresia 
;------ altfel trecem mai departe 
	mov eax,0
	mov al,expresia[esi]
	push eax
	call Ispi
	jmp loop_ 
;-----Ultima conditie a fost verificata trecem la inceputul functiei

							;-----Punem pe stiva operatorilor caracterul 's' sau 'l' pentru a sti ce functie folosim cand scoatem pe stiva---
							DOSIN:
								mov eax,0
								mov al,expresia[esi]
								push eax
								jmp enddofunction
							DOLOG:
								mov eax,0
								mov al,expresia[esi]
								push eax
								jmp enddofunction
							enddofunction:
								add esi,3 ;--- incrementam 3 pentru a trece de 'sin' respectiv 'log'
								jmp loop_
								;----END DOFUNCTION --------
	;-- scoatem de pe stiva ultimul operator si verificam precedenta operatorului scos de pe stiva cu cel din sir 
	;-- in cazul in care cel scos de pe stiva are precedenta mai mica decat cel din sir atunci punem pe stiva in ordinea urmatoare : 1.push operator2
																						                                           ; 2.push expresia[esi]-(operatorul din sir)
	;-- altfel efectuam operatia scoasa de pe stiva => scoatem urmatorul operator => verificam din nou precedenta  
		pushOperator:
				mov eax,0
				pop eax
				mov operator2,al
				;---operator2 = ultimul operator de pe stiva
				;---operator1 = operatorul din expresie
		loopprecedence:
				Precedence operator2
				mov precedenceOperator2,eax
				mov eax ,0
				mov al, expresia[esi]
				mov operator1,al
				Precedence operator1
				cmp eax,precedenceOperator2
				jg pushoperators
				ApplyOperation operator2
				mov eax,0
				pop eax
				mov operator2,al
				jmp loopprecedence
	
		pushoperators:
				mov eax,0
				mov al, operator2
				push eax
				mov al,expresia[esi]
				push eax
				inc esi
		finofwhile:
				jmp loop_
	
;---pune pe stiva paranteza deschisa '('
isopeningbrace:
	mov eax,0
	mov al, expresia[esi]
	push eax
	inc esi 
	jmp loop_
;---am ajuns la paranteza inchisa in sir deci trebuie sa efectuam operatiile din paranteza pana cand gasim operatorul '(' pus mai devreme pe stiva
whilebrace:
	mov eax,0
	pop eax
	mov operator2,al
	Precedence operator2
	cmp eax,0 
	je end_whilebrace
	ApplyOperation operator2
	jmp whilebrace
end_whilebrace:
	inc esi
	jmp loop_
;---in cazul in care primul caracter din sir a fost un operator -> vom pune pe stiva valoare calculata inainte	
push_lastvalue:
	call pushLastValue 
	jmp loop_
;---------------------------------------------------------
endofstring:
	;------- am parcurs toata expresia si continuarea e sa tot scoatem de pe stiva operatori si sa efectuam operatia
	;------- pana cand scoatem de pe stiva caracterul '#' care inseamna ca nu mai avem operatii de efectuat	
		finwhile:
			mov eax,0
			pop eax
			mov operator2,al
			Precedence operator2
			mov precedenceOperator2,eax
			cmp precedenceOperator2,0 
			je afisare_rezultat
			ApplyOperation operator2
			jmp finwhile
;---afisam rezultatul salvat in variabila value de tip dq - 64 biti	
afisare_rezultat:
	push dword ptr [value + 4]
	push dword ptr [value]
	push offset float_format
	call printf 
	add esp,12
	
	mov esp, ebp
	pop ebp
	ret 0
	
EvaluateExpresion endp
;---------------------------------------------------------------------------------------------------
;functia care citeste expresia si o verifica daca contine egal la sfarsit altfel se termina programul 
citire_expresie proc 
	push ebp
	mov ebp, esp
	sub esp, 4
	;de aici incepe bucla while de citire continua care se va opri doar atunci cand ultimul caracter va fi t[exit]
while_:
	apel2 printf, offset string_format, offset msg 	;------afisam mesajul pentru utilizator printf(%s,msg)
	apel2 scanf,offset string_format,offset expresia  ;------- citim expresia = scanf(%s,expresia)
	apel1 strlen, offset expresia   ;----- calculam lungimea sirului citit, pentru ca dorim sa stim care e ultimul caracter din sir
	dec eax		;-----decrementam eax pentru a fi la ultima pozitie din string --> strlen(expresia) - 1 
	mov [ebp-4],eax
	lea esi,expresia
	add esi,[ebp-4]
	mov ebx,0
	mov bl,byte ptr [esi] 	;---mutam ultimul caracter in ebx pentru a verifica daca este caracterul '=', in caz afirmativ vom calcula expresia altfel se termina programul
	cmp bl,'='
	jne final
	call EvaluateExpresion 
	jmp while_
final:	
	mov esp, ebp
	pop ebp
	ret 0
citire_expresie endp

start:
;----------------------- main ------------
	call citire_expresie 
	;terminarea programului
	push 0
	call exit
end start