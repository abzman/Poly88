Changes to make Nascom BASIC run on Polly

Relocated UART port definitions to match UART hardware settings on IA-1010 Card

1) changed uart status/config port from $80 to $00
2) changed uart data port from $81 to $00
    status bit layout changed to match:
        bit5 to bit0 for irq pending for read buffer full bit
        bit7 to bit1 for for transmitter busy bit
        
Changes are all local to intmini.asm.
They are all "in place" don't affect the binary size at all

