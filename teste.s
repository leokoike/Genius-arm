@ Constantes para o endereço dos dispositivos:
	.equ	leds,	0x90001
	.equ	slider,	0x90010
	.equ	display_cmd, 0x90020
	.equ	display_data, 0x90024
	.equ	timer,	0x90030
	.equ	red, 	0x90040
	.equ	green,	0x90041
	.equ	yellow,	0x90042
	.equ	blue,	0x90043
@ Constantes utilizadas
	.equ	on,	1
	.equ	off,	0
	.equ	user,	0x10
	.equ	fiq,	0x40
	.equ	irq,	0x80
	.equ	tempo,	1000
@ endereços das pilhar
	.equ stack,     0x80000
	.equ stack_fiq, 0x72000
	.equ stack_irq, 0x70000
@ modos de interrupção no registrador de status
	.equ modo_irq,	0x12
	.equ modo_fiq,	0x11
	.equ modo_user,	0x10
@ constantes para "commands"
	.set LCD_CLEARDISPLAY,0x01
	.set LCD_RETURNHOME,0x02
	.set LCD_DISPLAYCONTROL,0x08
	.set LCD_FUNCTIONSET,0x20
	.set LCD_SETDDRAMADDR,0x80
	.set LCD_BUSYFLAG,0x80

@ constantes para "display on/off control"
	.set LCD_DISPLAYON,0x04
	.set LCD_BLINKOFF,0x00

@ constantes para "function set"
	.set LCD_8BITMODE,0x10
	.set LCD_2LINE,0x08
	.set LCD_5x8DOTS,0x00

@ vetor de interrupção
	.org 	6*4
	b	tratador_timer
	b	tratador_slider

_start:
	mov	sp,#0x10000
	mov	r0,#modo_irq	
	msr	cpsr,r0
	mov	sp,#stack_irq
	mov	r0,#modo_fiq
	msr	cpsr,r0
	mov	sp,#stack_fiq
	mov	r0,#modo_user
	bic     r0,r0,#(irq+fiq)
	msr	cpsr,r0
	mov	sp,#stack

	mov	r2,#0
	mov	r3,#0
	mov	r4,#0
	mov	r5,#0
	mov	r6,#0
	mov	r7,#0
	b	read_slider
@----------------------------------------------------------------------------------------
@ r2 - contem a velocidade
read_slider:
	ldr	r4,=flag_slider		@ verifica se a flag do slider ativou
	ldr	r1,[r4]			@ se sim, desativo a flag e armazeno na flag
	cmp	r1,#on			@ e faço a leitura da velocidade e guardo em r2
	moveq	r1,#off			@ e deixo a variavel de fase como 1
	streq	r1,[r4]			@ e desvio para o begin		
	ldreq	r4,=slider
	ldreq	r1,[r4]
	moveq	r2,r1
	ldreq	r4,=fase
	moveq	r1,#1
	streq	r1,[r4]
	ldreq	r4,=contador
	moveq	r1,#0
	streq	r1,[r4]
	
	beq	begin

	bne	read_slider		@ se nao, volto para esperar ler o slider
@------------------------------------------------------------------------------------
@ r3 - numero de loops
@ r6 - loop atual
@ r5 - auxiliar para loop2
begin:
	ldr	r4,=contador
	ldr	r0,[r4]
	cmp	r0,#3
	moveq	r0,#0
	streq	r0,[r4]
	ldreq	r4,=fase
	moveq	r1,#1
	streq	r1,[r4]
	ldreq	r1,=msg_over
	bleq	lcd_sp
	beq	read_slider
		
	ldr	r4,=fase		@ verifica se o jogo acabou
	ldr	r1,[r4]			@ se sim, ele retorna para a leitura do slider
	cmp	r1,#6			@ e mostra uma mensagem de vitoria
	moveq	r1,#1			@ e tambem espero uma nove leitura de velocidade
	streq	r1,[r4]
	ldreq	r1,=msg_win
	bleq	lcd_sp
	beq	read_slider

	bl	lcd_refresh
	
	ldr	r4,=fase		@ verifica se o jogo comecou/resetou
	ldr	r1,[r4]			@ se sim, r3=4 e r6=0 
	cmp	r1,#1			@ calculo o intervalo do timer e armazena nele
	moveq	r3,#4			@ desvia para o loop
	moveq	r6,#0
	rsb	r4,r2,#6
	mov	r1,#100
	mul	r4,r1
	ldr	r1,=timer
	str	r4,[r1]
	beq	loop			

	ldr	r4,=contador
	ldr	r1,[r4]
	cmp	r1,#1
	bpl	loop
	
	mov	r5,r3			@ se nao, r5 recebe r3-1
	sub	r5,#1			@ e desvia para o loop2
	b	loop2
@------------------------------------------------------------------------------------
@ r2 - velocidade
@ r3 - quantidade de loops
@ r6 - numero do loop atual
loop:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r0,[r4]
	cmp	r0,#on
	bne	loop			@ se nao volto para o loop
	moveq	r0,#off			@ se sim altero a flag
	streq	r0,[r4]

	cmp	r3,r6			@ verifico se o loop terminou
	ldreq	r4,=timer		@ carrego um novo intervalo para o timer
	moveq	r5,#tempo
	moveq	r1,#3
	muleq	r5,r1
	streq	r5,[r4]
	ldreq	r4,=leds		@ se sim, deixo os leds todos apagados
	moveq	r5,#0
	streq	r5,[r4]	
	moveq	r6,#0			@ zero o loop
	moveq	fp,sp			@ guardo a posicao do stack pointer
	beq	led_setoff		@ desvio para a leitura dos botoes

	ldr	r4,=flag_slider
	ldr	r1,[r4]
	cmp	r1,#on
	beq	read_slider


	push	{r2,r3}
	bl	genrand_int32		@ r0 contem o numero aleatorio
	pop	{r2,r3}
	mov	r5,#3			@
	and	r0,r5		
	ldr	r4,=color
	ldrb	r5,[r4,r0]		@ carrego qual led deve acender
	ldr	r4,=leds
	str	r5,[r4]			@ armazeno no endereco das leds
	push	{r5}
	add	r6,#1
	b	loop
@-----------------------------------------------------------------------------------
led_setoff:
	mov	r0,#0

	ldr	r1,=red			@ verifico se a luz vermelha acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=green		@ verifico se a luz verde acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=yellow		@ verifico se a luz amarela acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=blue		@ verifico se a luz azul acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	cmp	r0,#0
	bne	led_setoff

	beq	loop1
@-----------------------------------------------------------------
@ r6 - numero do loop
@ r7 - endereço do stack pointer
loop1:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r0,[r4]			
	cmp	r0,#on
	moveq	r0,#off
	streq	r0,[r4]
	ldreq	r4,=leds
	moveq	r1,#0
	streq	r1,[r4]
	beq	verifica
	
	cmp	r3,r6			@ verifica se terminou o loop
	ldreq	r4,=fase		@ incremento a variavel da fase
	ldreq	r1,[r4]
	addeq	r1,#1
	streq	r1,[r4]
	ldreq	r4,=timer
	moveq	r1,#tempo
	streq	r1,[r4]
	ldreq	r4,=contador
	moveq	r1,#0
	streq	r1,[r4]	
	addeq	r3,#1
	moveq	r6,#0
	beq	wait
	
	ldr	r1,=red			@ verifico se a luz vermelha acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r1,#0x8
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=green		@ verifico se a luz verde acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r1,#0x4
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=yellow		@ verifico se a luz amarela acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r1,#0x2
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=blue		@ verifico se a luz azul acendeu
	ldr	r4,[r1]
	cmp	r4,#on
	moveq	r1,#0x1
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara
	
	b	loop1
@---------------------------------------------------------------------------------
verifica:
	cmp	r6,#0
	ldreq	r1,=msg_over
	bleq	lcd_sp
	beq	read_slider
	
	ldr	r4,=contador
	ldr	r1,[r4]
	add	r1,#1
	str	r1,[r4]
	
	cmp	r1,#3
	beq	begin

	ldr	r4,=leds
	mov	r1,#0
	str	r1,[r4]
	mov	r6,#0
	ldr	r4,=timer
	mov	r1,#tempo
	str	r1,[r4]
	ldr	r1,=msg_erro
	bl	lcd_sp

	b	wait
@-----------------------------------------------------------------------------------
compara:
	add	r7,r6,#1
	sub	r4,r3,r7
	mov	r0,#4
	mul	r0,r4
	add	fp,r0
	ldrb	r4,[fp]
	cmp	r4,r1
	addeq	r6,#1
	ldreq	r4,=timer		@ carrego um novo intervalo para o timer
	moveq	r5,#tempo
	streq	r5,[r4]
	mov	fp,sp
	beq	loop1

	ldr	r4,=contador
	ldr	r1,[r4]
	add	r1,#1
	str	r1,[r4]

	ldr	r4,=timer
	mov	r1,#tempo
	str	r1,[r4]
	ldr	r4,=leds
	mov	r1,#0
	str	r1,[r4]
	mov	r6,#0
	ldr	r1,=msg_erro
	bl	lcd_sp

	b	wait
@-----------------------------------------------------------------------------------
wait:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r1,[r4]			
	cmp	r1,#on
	moveq	r1,#off
	streq	r1,[r4]
	ldreq	r4,=leds
	moveq	r1,#0
	streq	r1,[r4]
	
	rsbeq	r4,r2,#6
	moveq	r1,#100
	muleq	r4,r1
	ldreq	r1,=timer
	streq	r4,[r1]
	beq	begin
	
	bne	wait
@----------------------------------------------------------------------------------
wait1:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r1,[r4]			
	cmp	r1,#on
	moveq	r1,#off
	bxeq	lr
	
	bne	wait1
@--------------------------------------------------------------------------
loop2:
	cmp	r5,r6			@ verifico se o loop terminou
	beq	loop

	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r0,[r4]
	cmp	r0,#on
	bne	loop2			@ se nao volto para o loop
	moveq	r0,#off			@ se sim altero a flag
	streq	r0,[r4]
	
	ldr	r1,=flag_slider
	ldr	r4,[r1]
	cmp	r4,#on
	beq	read_slider
	
	add	r7,r6,#1
	sub	r4,r5,r7
	mov	r0,#4
	mul	r0,r4
	add	fp,r0
	ldrb	r1,[fp]
	ldr	r4,=leds
	str	r1,[r4]
	add	r6,#1
	mov	fp,sp	
	b	loop2
@-----------------------------------------------------------------------------------
lcd_refresh:
	push	{lr}
	mov	r0,#LCD_FUNCTIONSET+LCD_8BITMODE+LCD_2LINE+LCD_5x8DOTS
	bl      wr_cmd
	mov	r0,#LCD_CLEARDISPLAY
	bl      wr_cmd
	mov	r0,#LCD_RETURNHOME
	bl      wr_cmd
	mov	r0,#LCD_DISPLAYCONTROL+LCD_DISPLAYON+LCD_BLINKOFF
	bl      wr_cmd
	ldr	r1, =msg
	bl	write_msg
	mov	r0,#(LCD_SETDDRAMADDR+64)
	bl      wr_cmd
	ldr		r1, =msg1
	bl      write_msg1
	pop	{lr}
	bx	lr
@---------------------------------------------------------------------------
lcd_sp:
	push	{lr}
	
	mov	r0,#LCD_FUNCTIONSET+LCD_8BITMODE+LCD_2LINE+LCD_5x8DOTS
	bl	wr_cmd
	mov	r0,#LCD_CLEARDISPLAY
	bl	wr_cmd
	mov	r0,#LCD_RETURNHOME
	bl	wr_cmd
	mov	r0,#LCD_DISPLAYCONTROL+LCD_DISPLAYON+LCD_BLINKOFF
	bl	wr_cmd

	bl	write_msg2
	pop	{lr}	
	bx	lr
@-------------------------------------------------------------------------
wr_cmd:
	ldr	r4,=display_cmd @ r6 tem porta display
	ldrb	r5,[r4]
	tst	r5,#LCD_BUSYFLAG
	beq	wr_cmd           @ espera BF ser 1
	strb	r0,[r4]
	mov	pc,lr
wr_dat:
	ldr	r10,=display_cmd
	ldrb	r5,[r10]
	tst	r5,#LCD_BUSYFLAG
	beq	wr_dat
	ldr	r10,=display_data
	strb	r0,[r10]
	mov	pc,lr
write_msg:
	push	{lr}
	mov	r4,r2
	sub	r4,#1
	mov	r5,#9
	mul	r4,r5
	b	write_msg_loop
write_msg1:
	push	{lr}
	ldr	r5,=fase
	ldr	r4,[r5]
	sub	r4,#1
	mov	r5,#8
	mul	r4,r5
	b	write_msg_loop
write_msg2:
	push	{lr}
	mov	r4,#0
	b	write_msg_loop

write_msg_loop:
	ldrb	r0,[r1,r4]
	cmp	r0,#0
	popeq	{pc}
	bl	wr_dat
	add	r1,#1
	b	write_msg_loop

end:
	mov     r7, #1     @ exit é syscall #1
	swi     #0x55      @ invoca syscall 
fase:
	.word	1
color:
	.byte	0x1,0x2,0x4,0x8
contador:
	.word	0

flag_timer:
	.word	0
flag_slider:
	.word	0
flag_button:
	.word	0
msg:
	.asciz	"Speed 1\x0","Speed 2\x0","Speed 3\x0","Speed 4\x0","Speed 5\x0"
msg1:
	.asciz	"Fase 1\x0","Fase 2\x0", "Fase 3\x0", "Fase 4\x0", "Fase 5\x0"
msg_erro:
	.asciz	"Tente novamente\x0"
msg_over:
	.asciz	"Fim de jogo\x0"
msg_win:
	.asciz	"Parabens!\x0"

	.align	4
tratador_slider:
	ldr	r8,=flag_slider			@ ativa a flag_slider
	mov	r9,#1
	str	r9,[r8]
	movs	pc,lr
tratador_timer:
	ldr	r8,=flag_timer			@ ativa a flag_timer
	mov	r9,#1
	str	r9,[r8]
	movs	pc,lr
