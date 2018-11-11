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
	mov	sp,#0x10000		@ deixo o endereço da pilha com um valor especifico
	mov	r0,#modo_irq		@ coloco o processador no modo de interrupcao irq
	msr	cpsr,r0			
	mov	sp,#stack_irq		@ set da pilha de interrupção irq
	mov	r0,#modo_fiq		@ coloco o processador no modo de interrupção fiq
	msr	cpsr,r0			
	mov	sp,#stack_fiq		@ set da pilha de interrupção fiq
	mov	r0,#modo_user		@ coloco o processador no modo usuario
	bic     r0,r0,#(irq+fiq)	@ interrupções habilitadas
	msr	cpsr,r0			
	mov	sp,#stack		@ set da pilha do usuario

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
	streq	r1,[r4]			@ e deixo a variavel contador como 0		
	ldreq	r4,=slider		@ e deixo a flag_erro como 0
	ldreq	r1,[r4]			@ e desvio para o begin
	moveq	r2,r1
	ldreq	r4,=flag_erro
	moveq	r1,#0
	streq	r1,[r4]
	ldreq	r4,=fase
	moveq	r1,#1
	streq	r1,[r4]
	ldreq	r4,=contador
	moveq	r1,#0
	streq	r1,[r4]
	ldreq	r4,=flag_timer
	moveq	r1,#0
	streq	r1,[r4]
	beq	begin

	bne	read_slider		@ se nao, volto para esperar ler o slider
@------------------------------------------------------------------------------------
@ r3 - numero de loops
@ r6 - loop atual
@ r5 - auxiliar para loop2
begin:
	ldr	r4,=contador		@ verifico se houve 3 erros
	ldr	r0,[r4]			@ se sim, deixo 0 a variavel contador
	cmp	r0,#3			@ e deixo a variavel de fase como 1
	moveq	r0,#0			@ carrego a mensagem de Fim de jogo
	streq	r0,[r4]			@ escrevo no display lcd
	ldreq	r4,=fase		@ e por fim desvio e espero a leitura da velocidade
	moveq	r1,#1
	streq	r1,[r4]
	ldreq	r1,=msg_over
	moveq	sp,#stack
	bleq	lcd_sp
	beq	read_slider
		
	ldr	r4,=fase		@ verifica se o jogo acabou
	ldr	r1,[r4]			@ se sim, ele retorna para a leitura do slider
	cmp	r1,#6			@ e mostra uma mensagem de vitoria
	moveq	r1,#1			@ e tambem espero uma nove leitura de velocidade
	streq	r1,[r4]
	ldreq	r1,=msg_win
	bleq	lcd_sp
	moveq	sp,#stack
	beq	read_slider

	bl	lcd_refresh		@ atualiza o display lcd com a velocidade e fase
	
	ldr	r4,=fase		@ verifica se o jogo comecou/resetou
	ldr	r1,[r4]			@ se sim, r3=4 e r6=0 
	cmp	r1,#1			@ calculo o intervalo do timer e armazena nele
	moveq	r3,#4			@ desvia para o loop
	moveq	r6,#0
	moveq	sp,#stack
	ldr	r4,=flag_timer
	mov	r1,#0
	str	r1,[r4]
	rsb	r4,r2,#6
	mov	r1,#100
	mul	r1,r4
	ldr	r4,=timer
	str	r1,[r4]
	beq	loop			
 
	ldr	r4,=flag_erro		@ verifico se houve alguma novo erro de sequencias
	ldr	r1,[r4]			@ se sim, desativo a flag
	cmp	r1,#1			@ desvio para o loop
	moveq	r1,#0			@ para receber uma nova sequencia
	streq	r1,[r4]	
	beq	loop
	
	mov	r5,r3			@ se nao, r5 recebe r3-1
	sub	r5,#1			@ e desvia para o loop2
	b	loop2
@------------------------------------------------------------------------------------
@ r2 - velocidade
@ r3 - quantidade de loops
@ r6 - numero do loop atual
loop:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao do timer
	ldr	r0,[r4]			@ se nao, espero receber uma interrupcao do timer
	cmp	r0,#on			@ se sim, desativo a flag_timer e continuo
	bne	loop
	moveq	r0,#off
	streq	r0,[r4]

	cmp	r3,r6			@ verifico se o loop terminou
	ldreq	r4,=timer		@ se sim, armazeno 3s para o timer
	moveq	r5,#tempo		@ e desligo todos os leds
	moveq	r1,#3			@ e zero o numero de loops
	muleq	r5,r1			@ e guardo o endereço do último valor da sequencia
	streq	r5,[r4]			@ e por fim, desvio para led_setoff
	ldreq	r4,=leds
	moveq	r5,#0
	streq	r5,[r4]	
	moveq	r6,#0
	moveq	fp,sp
	beq	led_setoff

					@ caso o loop nao tenha terminado

	ldr	r4,=flag_slider		@ verifico se houve mudanca na velocidade
	ldr	r1,[r4]			@ se sim, desvio para ver a nova velocidade
	cmp	r1,#on
	beq	read_slider


	push	{r2,r3}			@ empilho r2,r3 para gerar um numero aleatorio
	bl	genrand_int32		@ e com isso r0 possui esse numero aleatorio
	pop	{r2,r3}			@ desempilho r2 e r3
	mov	r5,#3			@ r5 recebe uma mascara de bits
	and	r0,r5			@ assim o numero aleatorio fica entre 0 e 3
	ldr	r4,=color		@ e depois pego um dos valores de cor no vetor de cores
	ldrb	r5,[r4,r0]		@ em seguida, armazeno esse valor no endereço do led
	ldr	r4,=leds		@ empilho esse valor para depois compara-lo
	str	r5,[r4]			@ incremento o loop
	push	{r5}			@ e desvio de volta 
	add	r6,#1
	b	loop
@-----------------------------------------------------------------------------------
@ esse função desliga todos os botões antes de fazer a leitura da sequência
led_setoff:
	mov	r0,#0

	ldr	r1,=red			@ verifico se o botão vermelho esta ativo
	ldr	r4,[r1]			@ se sim, incremento r0
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=green		@ verifico se o botão verde esta ativo
	ldr	r4,[r1]			@ se sim, incremento r0
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=yellow		@ verifico se o botão amarelo esta ativo
	ldr	r4,[r1]			@ se sim, incremento r0
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	ldr	r1,=blue		@ verifico se o botão azul esta ativo
	ldr	r4,[r1]			@ se sim, incremento r0
	cmp	r4,#on
	moveq	r4,#off
	streq	r4,[r1]
	addeq	r0,#1

	cmp	r0,#0			@ por fim, verifico se nenhum botão está ativo
	bne	led_setoff		@ se não, volto para o começo da função
	beq	loop1			@ se sim, vou para a leitura da sequência
@-----------------------------------------------------------------
@ r3 - quantidade de loops total
@ r6 - loop atual
loop1:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r0,[r4]			@ se sim, desativo a flag_timer
	cmp	r0,#on			@ e desligo os leds
	moveq	r0,#off			@ e desvio para verifica
	streq	r0,[r4]
	ldreq	r4,=leds
	moveq	r1,#0
	streq	r1,[r4]
	beq	verifica
	
	cmp	r3,r6			@ verifica se terminou o loop
	ldreq	r4,=fase		@ se sim, incremento a variavel da fase
	ldreq	r1,[r4]			@ e armazeno um valor no timer
	addeq	r1,#1			@ incremento o numero total de loops
	streq	r1,[r4]			@ e faço um reset no loop atual
	ldreq	r4,=timer		@ por fim vou para wait
	moveq	r1,#tempo
	streq	r1,[r4]
	addeq	r3,#1
	moveq	r6,#0
	beq	wait
	
	ldr	r1,=red			@ verifico se o botão vermelho foi pressionado
	ldr	r4,[r1]			@ se sim, ligo o led vermelho
	cmp	r4,#on			@ e desvio para compara
	moveq	r1,#0x8
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=green		@ verifico se o botão verde foi pressionado
	ldr	r4,[r1]			@ se sim, ligo o led verde
	cmp	r4,#on			@ e desvio para compara
	moveq	r1,#0x4
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=yellow		@ verifico se o botão amarelo foi pressionado
	ldr	r4,[r1]			@ se sim, ligo o led amarelo
	cmp	r4,#on			@ e desvio para compara
	moveq	r1,#0x2
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara

	ldr	r1,=blue		@ verifico se o botão azul foi pressionado
	ldr	r4,[r1]			@ se sim, ligo o led azul
	cmp	r4,#on			@ e desvio para compara
	moveq	r1,#0x1
	ldreq	r4,=leds
	streq	r1,[r4]
	beq	compara
	
	b	loop1			@ caso nenhum botão foi ativado, volto para o loop1
@---------------------------------------------------------------------------------
@ essa função verifica se termino o jogo ou se considero como um erro
verifica:
	cmp	r6,#0			@ verifico se é o primeiro ciclo do loop
	ldreq	r1,=msg_over		@ se for, carrego a mensagem Fim de jogo
	bleq	lcd_sp			@ escrevo no display lcd
	beq	read_slider		@ desvio para a leitura do slider
	
	ldr	r4,=contador		@ se não, carrego valor do contador de erros
	ldr	r1,[r4]
	add	r1,#1
	str	r1,[r4]
	
	cmp	r1,#3			@ verifico se houve 3 erros
	beq	begin			@ se sim, desvio para o begin

	ldr	r4,=flag_erro		@ se nao, ativa a flag_erro
	mov	r1,#1
	str	r1,[r4]

	ldr	r4,=leds		@ desligo os leds
	mov	r1,#0			@ faço um reset no loop atual
	str	r1,[r4]			@ armazeno um tempo para aparecer a mensagem de erro
	mov	r6,#0			@ carrego essa mensagem
	ldr	r4,=timer		@ e escrevo no display lcd
	mov	r1,#tempo
	str	r1,[r4]
	ldr	r1,=msg_erro
	bl	lcd_sp

	b	wait			@ por fim desvio para o wait
@-----------------------------------------------------------------------------------
@ essa função compara o botão com a cor da sequência
compara:
	add	r7,r6,#1		@ faço uma conta para encontrar as cores da sequência
	sub	r4,r3,r7		@ de acordo com o valor do loop atual
	mov	r0,#4			@ e desloco na pilha
	mul	r0,r4			@ e pego o valor
	add	fp,r0
	ldrb	r4,[fp]
	sub	fp,r0

	cmp	r4,r1			@ verifico se o botão está certo na sequência
	addeq	r6,#1			@ se sim, incremento o loop atual
	ldreq	r4,=timer		@ carrego um novo intervalo para o timer
	moveq	r1,#tempo		@ volto a posição da pilha
	streq	r1,[r4]			@ e desvio para o loop1
	beq	loop1

	ldr	r4,=flag_erro		@ se nao, ativa a flag_erro
	mov	r1,#1
	str	r1,[r4]
	
	ldr	r4,=contador		@ incrementa o contador
	ldr	r1,[r4]
	add	r1,#1
	str	r1,[r4]

	cmp	r1,#3
	beq	begin
	
	ldr	r4,=timer		@ carrego um tempo para a mensagem de erro aparacer
	mov	r1,#tempo		@ e desativo os leds
	str	r1,[r4]			@ e faço um reset no loop atual
	ldr	r4,=leds		@ carrego a mensgem de erro
	mov	r1,#0			@ e escrevo no display lcd
	str	r1,[r4]
	mov	r6,#0
	ldr	r1,=msg_erro
	bl	lcd_sp

	b	wait			@ por fim vou para wait
@-----------------------------------------------------------------------------------
@ essa função espera um intervalo de tempo para mensagem ficar no display
wait:
	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r1,[r4]			@ se sim, desativo a flag_timer
	cmp	r1,#on			@ desativo os leds
	moveq	r1,#off			@ calculo o intervalo de tempo para a sequecia de cores 
	streq	r1,[r4]			@ e desvio para o begin
	ldreq	r4,=leds
	moveq	r1,#0
	streq	r1,[r4]
	rsbeq	r4,r2,#6
	moveq	r1,#100
	muleq	r4,r1
	ldreq	r1,=timer
	streq	r4,[r1]
	beq	begin
	
	bne	wait			@ se não, volto para wait
@--------------------------------------------------------------------------
loop2:
	cmp	r5,r6			@ verifico se o loop terminou
	beq	loop			@ se sim vou para loop

	ldr	r4,=flag_timer		@ verifico se houve interrupcao
	ldr	r0,[r4]			@ se nao, volto para o começo do loop2
	cmp	r0,#on
	bne	loop2

	moveq	r0,#off			@ se sim, desativo a flag_timer
	streq	r0,[r4]			@ verifico se houver alteração na velocidade

	ldr	r1,=flag_slider		@ caso haja, vou para a leitura da velocidade
	ldr	r4,[r1]
	cmp	r4,#on
	beq	read_slider
	
	add	r7,r6,#1		@ carrego as cores que apareceram na fase passada
	sub	r4,r5,r7		@ para isso faco um calculo com o numero do loop atual
	mov	r0,#4			@ e desloco a posição da pilha 
	mul	r0,r4			@ e carrego o valor da sequência
	add	fp,r0			@ e ligo a cor correspondente
	ldrb	r1,[fp]			@ retorno a posição da pilha
	sub	fp,r0
	ldr	r4,=leds		@ e desloco para o começo do loop2
	str	r1,[r4]
	add	r6,#1	
	b	loop2
@-----------------------------------------------------------------------------------
@ essa função atualiza o display lcd com a velocidade e a fase do jogo
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
	ldr	r1,=msg1
	bl      write_msg1
	pop	{lr}
	bx	lr
@---------------------------------------------------------------------------
@ essa função atualiza o display lcd com mensagens especiais de apenas uma linha
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
@ função que verifica porta de comando do display pode ser utilizada. Se sim, escreve o comando na porta
wr_cmd:
	ldr	r4,=display_cmd @ r6 tem porta display
	ldrb	r5,[r4]
	tst	r5,#LCD_BUSYFLAG
	beq	wr_cmd           @ espera BF ser 1
	strb	r0,[r4]
	mov	pc,lr
@ função que verifica a porta de comando deo display pode ser utilizada. Se sim, escreve no display. 
wr_dat:
	ldr	r10,=display_cmd
	ldrb	r5,[r10]
	tst	r5,#LCD_BUSYFLAG
	beq	wr_dat
	ldr	r10,=display_data
	strb	r0,[r10]
	mov	pc,lr
@ função que chama para escever a velocidade no display
write_msg:
	push	{lr}
	mov	r4,r2
	sub	r4,#1
	mov	r5,#9
	mul	r4,r5
	b	write_msg_loop
@ função que chama para escrever a fase no display
write_msg1:
	push	{lr}
	ldr	r5,=fase
	ldr	r4,[r5]
	sub	r4,#1
	mov	r5,#8
	mul	r4,r5
	b	write_msg_loop
@ função que chama para escrever as mensagens especiais
write_msg2:
	push	{lr}
	mov	r4,#0
	b	write_msg_loop
@ loop que pega letra por letra para a escrita até ter um 0x00.
write_msg_loop:
	ldrb	r0,[r1,r4]
	cmp	r0,#0
	popeq	{pc}
	bl	wr_dat
	add	r1,#1
	b	write_msg_loop

fase:
	.word	1
color:
	.byte	0x1,0x2,0x4,0x8
contador:
	.word	0
flag_erro:
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
