# AsmPong
Simple ping pong clone game written in assembly
It works in 16-bit real mode.

## How to run in emulator

```console
qemu-system-i386 game.bin
```

## Alternative: Run in real hardware
# 1) Plug the USB

# 2) Make it bootable

```console
sudo dd if=real.bin of=/dev/<usb-drive>
```

# 3) Boot from USB

## Controls

- 'a' = move left
- 'd' = move right
- 'p' = pause (removed in real mode)
- 'spacebar' = restart after death screen
