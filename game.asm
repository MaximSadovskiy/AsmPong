[bits 16]
org 0x7C00

%define COLOR_BLACK 0
%define COLOR_BLUE 1
%define COLOR_GREEN 2
%define COLOR_CYAN 3
%define COLOR_RED 4
%define COLOR_MAGENTA 5
%define COLOR_BROWN 6
%define COLOR_LIGHTGRAY 7
%define COLOR_DARKGRAY 8
%define COLOR_LIGHTBLUE 9
%define COLOR_LIGHTGREEN 10
%define COLOR_LIGHTCYAN 11
%define COLOR_LIGHTRED 12
%define COLOR_LIGHTMAGENTA 13
%define COLOR_YELLOW 14
%define COLOR_WHITE 15

%define BACKGROUND_COLOR COLOR_BLACK
%define BORDER_COLOR COLOR_DARKGRAY

%define WIDTH 320
%define HEIGHT 200
%define COLUMNS 40
%define ROWS 25

%define BALL_COLOR          COLOR_LIGHTRED
%define BALL_HEIGHT         11
%define BALL_WIDTH          13
%define BALL_START_POS_x    (WIDTH  / 2 - BALL_WIDTH - 5)
%define BALL_START_POS_y    (5)
%define BALL_DELTA_X        1
%define BALL_DELTA_Y        2

%define PLAYER_COLOR        COLOR_LIGHTGREEN
%define PLAYER_HEIGHT       6
%define PLAYER_WIDTH        55
%define PLAYER_START_POS_X  (WIDTH  / 2 - PLAYER_WIDTH / 2 - 5)
%define PLAYER_START_POS_Y  (HEIGHT / 2 + 62)
%define PLAYER_VELOCITY_X   16

%define VGA_OFFSET          0xA000
%define VGA_MODE            0x13
%define VIDEO_INTERRUPT     0x10
%define CLOCK_INTERRUPT     0x15
%define KEYBOARD_INTERRUPT  0x16

%macro drawPlayer 0
    mov dx, PLAYER_START_POS_X
    mov ax, PLAYER_START_POS_Y
    add dx, word[GameData + GameState.PlayerDeX]
    mov bx, PLAYER_WIDTH 
    mov cl, PLAYER_HEIGHT
    mov ch, PLAYER_COLOR
    call drawQuad
%endmacro

struc GameState
    .PlayerDeX:   resw 1
    .BallX:       resw 1
    .BallY:       resw 1
    .BallDeX:     resw 1
    .BallDeY:     resw 1
    .Intersection resb 1
endstruc

global _main
_main:
    mov ax, VGA_MODE
    int VIDEO_INTERRUPT
    ;jmp initilizeGame
    jmp frameLoop

frameLoop:
    call delay
    
    call clearScreen
    drawPlayer
    call drawBall
    ;call drawBorders

    jmp readKey
delay:
    mov ax, ((0x86 << 8) + 0x00 << 0)
    xor cx, cx
    mov dx, 13500
    int CLOCK_INTERRUPT
    ret

readCharBlocking:
    xor ax, ax
    int KEYBOARD_INTERRUPT
    ret
readCharNonBlocking:
    mov ax, ((0x01 << 8) + 0x00)
    int KEYBOARD_INTERRUPT
    ret
readKey:
    call readCharNonBlocking
    jz frameLoop
    call readCharBlocking
    jmp .handleKey
.handleKey:
    cmp al, 'p'
    je pauseScreen
    cmp al, 'a'
    je moveLeft
    cmp al, 'd'
    je moveRight
    ;cmp al, 'y'
    ;je halt
    jmp readKey

drawBall:
    mov byte[GameData + GameState.Intersection], 1
    mov cx, word[GameData + GameState.BallX]
    mov bx, cx ; save old
    add cx, word[GameData + GameState.BallDeX]

    cmp cx, (WIDTH - BALL_WIDTH - 2)
    jg .reverseXRight
    cmp cx, 0
    jl .reverseX
    mov[GameData + GameState.BallX], cx
    ; Intersection
    mov dx, (PLAYER_START_POS_X + PLAYER_WIDTH)
    add dx, word[GameData + GameState.PlayerDeX]
    cmp cx, dx
    jg .interX
    ; TESTTTTT
    ;sub dx, PLAYER_WIDTH
    ;add cx, BALL_WIDTH
    ;sub dx, (PLAYER_WIDTH - BALL_WIDTH)
    ;sub cx, (PLAYER_WIDTH - BALL_WIDTH)
    add cx, (PLAYER_WIDTH + BALL_WIDTH)
    cmp cx, dx
    jb .interX
    jmp .calcX
.calcX:
    mov bx, word[GameData + GameState.BallY]
    mov cx, bx ; save old
    mov dx, word[GameData + GameState.BallDeY]
    add bx, dx
    ; dx =  floor
    mov dx, HEIGHT - BALL_HEIGHT
    ;sub dx, BALL_HEIGHT
    mov word[GameData + GameState.BallY], bx
    cmp bx, 0
    jl .reverseY
    cmp bx, dx
    jg deathScreen
    ;inter
    cmp bx, (PLAYER_START_POS_Y + PLAYER_HEIGHT)
    ja .interY
    cmp bx, PLAYER_START_POS_Y - BALL_HEIGHT
    jb .interY
    jmp .calcY
.calcY:
    cmp byte[GameData + GameState.Intersection], 1
    je .makeInter
    mov dx, word[GameData + GameState.BallX]
    mov ax, word[GameData + GameState.BallY]
    mov bx, BALL_WIDTH
    mov cx, ((BALL_COLOR << 8) + BALL_HEIGHT << 0)
    call drawQuad
    ret
.interX:
    mov byte[GameData + GameState.Intersection], 0
    jmp .calcX
.interY:
    mov byte[GameData + GameState.Intersection], 0
    jmp .calcY
.makeInter:
    mov byte[GameData + GameState.Intersection], 0
    mov ax, word[GameData + GameState.BallDeY]
    imul ax, -1
    mov word[GameData + GameState.BallDeY], ax
    jmp .calcY
.reverseXRight:
    mov bx, (WIDTH - BALL_WIDTH - 3) ; +3 = bug with right wall
    jmp .reverseX
.reverseX:
    mov ax, word[GameData + GameState.BallDeX]
    imul ax, -1
    mov word[GameData + GameState.BallDeX], ax
    mov word[GameData + GameState.BallX], bx ; restore old
    jmp .calcX
.reverseY:
    mov ax, word[GameData + GameState.BallDeY]
    imul ax, -1
    mov word[GameData + GameState.BallDeY], ax
    mov word[GameData + GameState.BallY], cx ; restore old
    jmp .calcY

clearScreen:
    mov ax, VGA_OFFSET
    mov es, ax
    xor si, si
    jmp .clLoop
.clLoop:
    mov byte[es:si], BACKGROUND_COLOR
    inc si
    cmp si, (WIDTH * HEIGHT)
    jb .clLoop
    ret

deathScreen:
    ;call delay
    call clearScreen
    ; Draw gameover screen
    mov ax, ((0x13 << 8) + 0x00 << 0)
    mov bp, gameOverText
    mov cx, gameOverText_size
    mov dx, (((ROWS / 2 - 2) << 8) + ((COLUMNS / 2 - gameOverText_size / 2) << 0))
    xor bx, bx
    mov es, bx
    mov bl, COLOR_LIGHTGRAY
    int VIDEO_INTERRUPT

    call readCharBlocking
    cmp al, ' '
    je newGame
    jmp deathScreen
newGame:
    mov word[GameData + GameState.BallY], BALL_START_POS_y
    ; No space for that :)
    ;mov word[GameData + GameState.BallX], BALL_START_POS_x
    ;mov word[GameData + GameState.BallDeX],   BALL_DELTA_X
    ;mov word[GameData + GameState.BallDeY],   BALL_DELTA_Y
    ;mov word[GameData + GameState.PlayerDeX], 0x0
    jmp frameLoop
pauseScreen:
    mov ax, ((0x13 << 8) + 0x00 << 0)
    mov bp, gamePausedText
    mov cx, gamePausedText_size
    mov dx, (((ROWS / 2 - 2) << 8) + ((COLUMNS / 2 - gamePausedText_size / 2) << 0))
    xor bx, bx
    mov es, bx
    mov bl, COLOR_YELLOW
    int VIDEO_INTERRUPT

    call readCharBlocking
    cmp al, 'p'
    je frameLoop
    jmp pauseScreen

moveLeft:
    ; Precalc min width
    mov bx, (-PLAYER_START_POS_X)
    mov ax, word[GameData + GameState.PlayerDeX]
    sub ax, PLAYER_VELOCITY_X
    mov cx, ax
    add cx, PLAYER_START_POS_X
    ; if delta < 0 set to min width
    cmp cx, 0
    jl moveCondition
    jmp moveEnd
moveRight:
    ; ax next delta
    mov ax, word[GameData + GameState.PlayerDeX]
    add ax, PLAYER_VELOCITY_X
    ; Precalc max width
    mov bx, (WIDTH - (PLAYER_START_POS_X + PLAYER_WIDTH) - 2) 
    mov cx, ax
    add cx, (PLAYER_START_POS_X + PLAYER_WIDTH)
    ; if delta < 320 set to max width
    cmp cx, WIDTH
    jg moveCondition
    jmp moveEnd
moveCondition:
    mov ax, bx
    jmp moveEnd
moveEnd:
    mov word[GameData + GameState.PlayerDeX], ax
    jmp readKey

;   dx    ax     cl     bx      ch
; (posX, posY, height, length, color)
drawQuad:
    mov di, bx ; save length
    mov ss, dx ; save posX
    ;si = posX + posY * WIDTH
    mov bx, WIDTH
    mul bx ; posY * WIDTh
    mov dx, ss
    add ax, dx ; + posX

    mov si, ax

    xor ax, ax
    mov ss, ax
    mov ax, VGA_OFFSET
    mov es, ax

    mov dx, cx  ; move height and color to dx
    xor bx, bx  ; bx <- iterX
    xor cx, cx  ; cx <- iterY
    jmp dqLoop
dqLoop:
    mov byte[es:si], dh ; dh = color
    inc bx
    mov ax, di
    cmp bx, ax ; if iterX >= length
    ja dqCheckLine
    inc si
    jmp dqLoop
dqCheckLine:
    cmp cl, dl ; if iterY >= height
    ja return
    xor bx, bx ; iterX = 0
    inc cx     ; iterY += 1
    mov ax, di
    sub si, ax
    add si, WIDTH
    jmp dqLoop
return:
    ret
;halt:
;    hlt

GameData:
istruc GameState
    at GameState.PlayerDeX,    dw 0
    at GameState.BallX,        dw BALL_START_POS_x
    at GameState.BallY,        dw BALL_START_POS_y
    at GameState.BallDeX,      dw BALL_DELTA_X
    at GameState.BallDeY,      dw BALL_DELTA_Y
    at GameState.Intersection, db 0
iend

gameOverText:       db 'Game over'
gameOverText_size   equ ($ - gameOverText)
gamePausedText:     db 'Paused'
gamePausedText_size equ ($ - gamePausedText)

times 510 - ($-$$) db 0
dw 0xAA55
