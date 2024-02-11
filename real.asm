org 0x7c00
bits 16


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

%define LOWER_FLOOR (HEIGHT - BALL_HEIGHT)

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

boot:
    jmp main
    TIMES 3-($-$$) DB 0x90   ; Support 2 or 3 byte encoded JMPs before BPB.
    ; Fake BPB
    TIMES 34 DB 0xAA
main:
    xor ax, ax
    mov ds, ax
    mov ss, ax    ; Set stack just below bootloader at 0x0000:0x7c00
    mov sp, boot
    cld           ; Forward direction for string instructions
    mov ax, VGA_MODE
    int VIDEO_INTERRUPT
    jmp frameLoop
frameLoop:
    call delay
    call clearScreen
    drawPlayer
    call drawBall
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
    cmp al, 'a'
    je moveLeft
    cmp al, 'd'
    je moveRight
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
    add cx, (PLAYER_WIDTH + BALL_WIDTH)
    cmp cx, dx
    jb .interX
    jmp .calcX
.calcX:
    mov bx, word[GameData + GameState.BallY]
    mov cx, bx ; save old
    ;fix
    add bx, word[GameData + GameState.BallDeY]
    ; dx =  floor
    mov word[GameData + GameState.BallY], bx
    cmp bx, 0
    jl .reverseY
    cmp bx, LOWER_FLOOR
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
deathScreen:
    call clearScreen
    mov ax, ((0x13 << 8) + 0x00 << 0)
    mov bp, gameOverText
    mov cx, gameOverText_size
    mov dx, (((ROWS / 2 - 2) << 8) + ((COLUMNS / 2 - gameOverText_size / 2) << 0))
    xor bx, bx
    mov es, bx
    mov bl, COLOR_YELLOW
    int VIDEO_INTERRUPT

    call readCharBlocking
    cmp al, ' '
    jne deathScreen
    ; Restart Game
    mov word[GameData + GameState.BallY], BALL_START_POS_y
    jmp frameLoop
clearScreen:
    mov bx, VGA_OFFSET
    mov es, bx
    xor di, di
    mov ax, ((0x0 << 8) + (BACKGROUND_COLOR << 0))
    mov cx, WIDTH * HEIGHT /  2
    rep stosw ; Store AL at ES:[DI] and increment DI after each store
    ret
moveLeft:
    mov bx, (-PLAYER_START_POS_X)
    mov ax, word[GameData + GameState.PlayerDeX]
    sub ax, PLAYER_VELOCITY_X
    mov cx, ax
    add cx, PLAYER_START_POS_X
    cmp cx, 0
    jge moveEnd ; Jump if cx >=  0, which is the minimum width
    mov ax, bx ; Set to min width if delta <  0
moveEnd:
    mov word[GameData + GameState.PlayerDeX], ax
    jmp readKey
moveRight:
    mov ax, word[GameData + GameState.PlayerDeX]
    add ax, PLAYER_VELOCITY_X
    mov bx, (WIDTH - (PLAYER_START_POS_X + PLAYER_WIDTH) -  2)
    mov cx, ax
    add cx, (PLAYER_START_POS_X + PLAYER_WIDTH)
    cmp cx, WIDTH
    jle moveEnd ; Jump if cx <= WIDTH, which is the maximum width
    mov ax, bx ; Set to max width if delta > WIDTH
    jmp moveEnd

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
times 510 - ($-$$) db 0
dw 0xAA55
