;
;PROM ROUTINES FOR MICROMATION DOUBLER, VERSION C.2
;THE C.1 VERSION HAS NOPS IN SYNC ROUTINE TO ALLOW MORE FREQUENT REFRESH
;OF DYNAMIC RAMS
;IT ALSO SETS UP THE SIDE BIT EARLIER TO MEET SETUP TIME FOR Y-E DATA DRIVES
;
;THIS VERSION HAS THE FOLLOWING CHANGES FROM C.1:
;HAS FIX FOR C.1 BUG IN SETTING UP DENSITY
;DISABLES INTERRUPTS AFTER FINDING CORRECT SECTOR
;HAS SLOWER STEP AND SETTLE TIMES
;
;		FEB 11, 1980

BASE		ORG	0F800H
BUFF		EQU	BASE+400H	;SCRATCHPAD RAM
	;
	;START OF HARDWARE PORT DEFINITIONS
	;
WRCONT		EQU	BASE+600H
WRCLK		EQU	WRCONT+1
WRUART		EQU	WRCONT+2
WRMRKCRC	EQU	WRCONT+4
WRMRK		EQU	WRCONT+5
WRDATA		EQU	WRCONT+6
WRCRC		EQU	WRCONT+7
RDSTAT		EQU	WRCONT
RDUART		EQU	WRCONT+2
RDMRKCRC	EQU	WRCONT+4
RDMARK		EQU	WRCONT+5
RDDATA		EQU	WRCONT+6
SYNCPORT	EQU	WRCONT+7
	;
	;START OF RAM VARIABLE DEFINITIONS
	;
ERRORBYTE	EQU	BUFF	;NO. OF ERRORS DURING RETRIES
DENBYTE		EQU	BUFF+1	;0 FOR SINGLE DENSITY
				;4 FOR DOUBLE DENSITY
READWRITE	EQU	BUFF+2	;0  FOR READ
				;10H FOR WRITE
CONTROLBYTE	EQU	BUFF+3	;RAM IMAGE OF RDSTAT OR WRCONT
TRACK		EQU	BUFF+4
PRESDISK	EQU	BUFF+5
LOGINTAB	EQU	BUFF+6	;FOR EACH DRIVE
			;0 IF DRIVE HAS NOT BEEN LOGGED IN
			;55H IF DRIVE HAS BEEN LOGGED IN
SECTOR		EQU	BUFF+0AH
DMA		EQU	BUFF+0BH ;DMA ADDRESS
DISK		EQU	BUFF+0DH
TESTNEXT	EQU	BUFF+0EH ;55H IF WANT TO TEST DENSITY
				 ; OF NEXT TRACK
TWOSIDE		EQU	BUFF+0FH
STEPTIME	EQU	BUFF+10H
ABOVE43		EQU	BUFF+11H ;10H IF (TRACK)<44D
				 ; 50H OTHERWISE
TRACKTAB	EQU	BUFF+12H
DENMAP		EQU	BUFF+16H ;SAME CONVENTION AS DENBYTE
TRY1		EQU	BUFF+20H
RETRYCOUNT	EQU	BUFF+21H
CURRDRIVE	EQU	BUFF+22H
TESTMAX		EQU	BUFF+23H ;NO. RETRIES FOR DENSITY TEST

STEPSETTLE	EQU	15
HEADSETTLE	EQU	40
STACK		EQU	BUFF+64D

	JMP	COLDBOOT
	JMP	HOME
	JMP	SELDSK
	JMP	SETTRK
	JMP	SETSEC
	JMP	SETDMA
	JMP	READ
	JMP	WRITE
	JMP	SKEW
	JMP	SETDEN
WRITEPROTECT	CALL	DISKREADY1	;LOADS HEAD
					;WAITS TILL DISK READY
					;RETURNS (RDSTAT) IN B
		MOV	A,B
		ANI	04	;WRITEPRT BIT FROM DRIVE
		RNZ
		LDA	RDMARK	;RESETS HEAD LOAD COUNTER
		RET


READ:		;ENTRY POINT FOR READ ROUTINE
	XRA	A		;(READWRITE)= 00 FOR READ
	JMP	GO

WRITE:		;ENTRY POINT FOR WRITE ROUTINE
	MVI	A,10H		;(READWRITE)=10H FOR WRITE

GO	STA	READWRITE
	LHLD	DENBYTE		;(L)=(DENBYTE)
	LDA	CONTROLBYTE
	CMA
	ANI	0FBH		;MASK OUT BIT 2 (SD/-DD = 0)
	ORA	L
	CMA
	STA	WRCONT
	CALL	DISKREADY1
	LDA	SECTOR
	MOV	C,A		;(C)=(SECTOR)
	LDA	TRACK
	MOV	B,A		;(B)=(TRACK)
	XRA	A
	STA	ERRORBYTE	;(ERRORBYTE)= 0
	MOV	A,L
	ORA	A		;TEST FOR SINGLE DENSITY
	JZ	SD

		;DOUBLE DENSITY READ OR WRITE
READDD
BLOOP	CALL	SYNC		;SYNC ON HEADER
				;FOUND HEADER
	MVI	M,0AH		;FIND OA CLOCK FOR ID MARK
	LDAX	D		;SYNC WITH -EOW
	LDA	RDMRKCRC
	CPI	0A1H		;DATA FOR ID MARK
	JNZ	BLOOP
				;FOUND ID ADDRESS MARK
				;
	LDAX	D		;BYTE AFTER ID MARK SHOULD BE FE
	CPI	0FEH
	JNZ	BLOOP
				;FOUND FE BYTE
				;
	LDAX	D		;TRACK BYTE FROM DISK
	CMP	B		;(B)=(TRACK)
	JNZ	TERROR1		;TRACK ERROR

	LDAX	D		;SECTOR BYTE FROM DISK
	CMP	C		;(C)=(SECTOR)
	JNZ	BLOOP		;WRONG SECTOR.  TRY AGAIN

	LDAX	D
	DI			;DISABLE INTERRUPTS BEFORE CHECKING ID CRC
	LDAX	D
	LDAX	D		;READ 1 BYTE PAST ID CRC
	LDA	RDSTAT
	RAR			;CHECK ID CRC
	LDAX	D
	JC	ERROR		;ID CRC ERROR

	LDAX	D
	LDA	ABOVE43
	MOV	B,A
	LDAX	D
	MOV	M,B		;(WRCLK)=(ABOVE43)
	LDAX	D		;NOW 5 BYTES INTO GAP
	MVI	B,9
GLOOP	LDAX	D
	DCR	B
	JNZ	GLOOP

	LDAX	D		;NOW 15 BYTES INTO GAP
	LDA	READWRITE
	ORA	A		;CHECK FOR WRITE
	LDAX	D		;16 BYTES INTO GAP
	JNZ	WRITEDD
				;
				;DOUBLE DENSITY READ
				;
	LDAX	D
	LDAX	D
	MVI	M,0FFH
	LDAX	D
	LDAX	D
	LDAX	D		;21 BYTES INTO GAP
	INX	D		;(D)=SYNCPORT
	LDAX	D		;SYNC ON FF CLOCK PATTERN
	DCX	D		;(D)=RDDATA
	MVI	M,0AH		;(WRCLK)=0A
				;CLOCK PATTERN FOR DATA MARK
	LHLD	DMA
	LDAX	D		;SYNC WITH -EOW
	LDA	RDMRKCRC	;GET DATA PATTERN FOR DATA MARK
	CPI	0A1H
	JNZ	ERROR		;MISSING DATA MARK
				;
				;FOUND DATA MARK
				;START TRANSFERRING DATA
				;
RXFER	LDAX	D
	MOV	M,A
	INX	H
	MOV	B,D
	LDAX	D
	MOV	M,A
	INX	H
	MOV	C,E
	LDAX	B
	MOV	M,A
	INX	H
	MVI	E,0E1H
	LDAX	B
	MOV	M,A		;4 BYTES OF DATA
	INX	H
	LDAX	B

RLOOP	MOV	M,A
	LDAX	B
	INR	E
	INX	H
	MOV	M,A
	LDAX	B
	INX	H
	MOV	M,A
	LDAX	B
	INX	H
	MOV	M,A
	INX	H
	LDAX	B
	JNZ	RLOOP		;HAVE TRANSFERRED 128 BYTES
				;AND HAVE READ 129TH BYTE

	LDAX	B
	LDAX	B		;READ 1 BYTE PAST CRC
	LDA	RDSTAT
	RAR			;CHECK DATA CRC
	JC	ERROR		;DATA CRC ERROR
		;
		;SUCCESSFUL SECTOR READ
		;
	XRA	A		;RETURN 00 IN ACCUMULATOR
	STA	WRCLK
	RET

ERROR:		;ARRIVE HERE ON ANY OF FOLLOWING CONDITIONS
		;	30H TRACK ERRORS
		;	ID CRC ERROR
		;	MISSING DATA MARK
		;	DATA CRC ERROR

	MVI	A,0EFH		;RETURN EFH IN ACC
	ORA	A		;	(UNSUCCESSFUL READ)
	STA	WRCLK
	RET

TERROR:		;ARRIVE HERE ON TRACK ERROR IN SINGLE DENSITY
	CALL	ERRORCOUNT	;INCREMENT ERRORBYTE
	JNZ	ALOOP		;TRY AGAIN IF LESS THAN 30H

NO	MVI	A,0EFH		;30H TRACK ERRORS
	ORA	A		;RETURN EFH IN ACC
	STC			;(UNSUCESSFUL DISK OPERATION)
	STA	WRCLK
	RET

TERROR1:	;ARRIVE HERE ON TRACK ERROR IN DOUBLE DENSITY
	CALL	ERRORCOUNT	;INCREMENT ERRORBYTE
	JNZ	BLOOP		;TRY AGAIN IF LESS THAN 30H
	JMP	NO

ERRORCOUNT	LXI	H,ERRORBYTE
		INR	M		;INCREMENT ERRORBYTE
		MOV	A,M
		CPI	30H
		RET

WRITEDD:	;DOUBLE DENSITY WRITE
		;ARRIVE HERE 16 BYTES AFTER ID FIELD
	MVI	A,4EH
	STAX	D		;WRITE 4 BYTES OF 4E
	STAX	D
	STAX	D
	STAX	D
	XRA	A
	STAX	D		;WRITE 6 BYTES OF 00
	STAX	D
	LHLD	DMA
	STAX	D
	STAX	D
	LXI	B,WRMRKCRC
	STAX	D
	STAX	D
	MVI	A,0A1H
	STAX	B		;WRITE DATA MARK (A1)
	MVI	C,0E1H

		;START WRITING DATA TO DISK FROM MEMORY
WXFER	MOV	A,M
WLOOP	STAX	D
	INX	H
	INR	C
	MOV	A,M
	STAX	D
	INX	H
	MOV	A,M
	STAX	D
	INX	H
	MOV	A,M
	INX	H
	STAX	D
	MOV	A,M
	JNZ	WLOOP
		;WHEN WE ARRIVE HERE WE'VE WRITTEN
		; 31*4=124 BYTES TO DISK
	STAX	D
	INX	H
	MOV	A,M
	STAX	D
	INX	H
	MOV	A,M
	INX	H
	STAX	D
	MOV	A,M
	STAX	D		;128TH BYTE TO DISK
	MVI	A,0FFH
	STA	WRCRC		;WRITE 2 BYTES OF DATA CRC
	STA	WRCRC
	STAX	D		;WRITE 3 BYTES OF FF
	STAX	D
	STAX	D
	XRA	A		;RETURN 00 IN ACC
	STA	WRCLK		;(SUCCESSFUL WRITE)
	RET

		;SINGLE DENSITY ROUTINES
		;ENTRY POINT IS SD  (BELOW)

WRITESD:	;ARRIVE HERE 6 BYTES PAST ID FIELD
	MVI	A,0FFH
	STAX	D		;WRITE 3 BYTES FF (BYTES 7,8,9)
	STAX	D
	STAX	D
	XRA	A
	STAX	D		;WRITE 6 BYTES OO (BYTES 10-15)
	STAX	D
	LHLD	DMA
	STAX	D
	STAX	D
	STAX	D
	STAX	D		;BYTE 15 OF GAP
	MVI	A,0FBH		;WRITE DATA MARK FOR SINGLE DEN
	STA	WRMRKCRC
	MVI	C,0E1H
	JMP	WXFER		;JUMP TO COMMON WRITE ROUTINE

SYNC		;ROUTINE TO SYNC ON HEADER
	LXI	H,WRCLK
	MVI	M,0FFH
	LXI	D,SYNCPORT
CLOOP	LDAX	D		;SYNC ON FF CLOCK IN HEADER
	ORA	A		;SHOULD HAVE 00 DATA
				;FOUND SYNC PATTERN
	NOP
	NOP
	DCX	D		;(D)=WRDATA=READDATA
	RZ
	JMP	SYNC


		;SINGLE DENSITY ENTRY POINT

SD
ALOOP	CALL	SYNC
				;FOUND HEADER
MLOOP	MVI	M,0C7H		;CLOCK PATTERN FOR ID MARK
LLOOP	LDA	RDMRKCRC
	ORA	A
	JZ	LLOOP
	CPI	0FEH
	JZ	NLOOP
	MVI	M,0FFH
	LDA	SYNCPORT
	ORA	A
	JZ	MLOOP
	JMP	ALOOP
NLOOP				;FOUND DATA MARK
	LDAX	D		;TRACK BYTE FROM DISK
	CMP	B
	JNZ	TERROR		;TRACK ERROR
	LDAX	D		;SIDE BYTE FROM DISK (IGNORE)
	LDAX	D		;SECTOR BYTE FROM DISK
	CMP	C
	JNZ	ALOOP		;WRONG SECTOR.  TRY AGAIN

				;FOUND CORRECT TRACK AND SECTOR
	DI			;DISABLE INTERRUPTS BEFORE CHECKING ID CRC
	LDAX	D
	LDAX	D		;CRC BYTE
	LDAX	D		;CRC BYTE
	LDAX	D		;GAP BYTE 1
	LDA	RDSTAT		;CHECK ID CRC
	RAR
	LDAX	D		;GAP BYTE 2
	LDAX	D		;GAP BYTE 3
	JC	ERROR		;ID CRC ERROR

	LDAX	D		;GAP BYTE 4
	LDA	ABOVE43
	MOV	M,A
	LDAX	D		;GAP BYTE 5
	LDA	READWRITE
	ORA	A		;CHECK FOR WRITE
	LDAX	D		;GAP BYTE 6
	JNZ	WRITESD

		;SINGLE DENSITY READ
	LDAX	D		;READ 6 BYTES OF GAP
	LDAX	D
	LDAX	D
	LDAX	D
	LDAX	D
	LDAX	D
	MVI	M,0FFH		;(WRCLK)=FF
	LXI	B,RDDATA
	LDAX	D		;GAP BYTE 14
	INX	D		;(D)=SYNCPORT
	LDAX	D
	MVI	M,0C7H		;CLOCK PATTERN FOR DATA MARK
	MVI	E,04		;(D)=RDMRKCRC
	LDAX	B		;GAP BYTE 16
	LDAX	D		;READ DATA MARK
	ANI	0FCH
	CPI	0F8H		;DATA PATTERN FOR DATA MARK
	JNZ	ERROR		;MISSING DATA MARK
			;FOUND SINGLE DENSITY DATA MARK
	MVI	E,0E0H		;32*4=128 BYTE TRANSFER
	LDAX	B
	LHLD	DMA
	JMP	RLOOP		;JUMP TO MAIN READ ROUTINE


TEST:		;TESTS DENSITY OF DISKETTE IN LOGGED-IN DRIVE
		;RETURNS 00 IN ACC IF DOUBLE DENSITY
		;RETURNS 0F IN ACC IF SINGLE DENSITY
		;RETURNS 0A IN ACC IF TEST FAILS 
	XRA	A
	STA	TESTMAX		;(TESTMAX)=0
TEST1	XRA	A
	STA	ERRORBYTE	;(ERRORBYTE)=0
	CALL	DISKREADY	;LOAD HEAD
	LXI	B,WRCONT
	LDA	CONTROLBYTE
	ORI	80H		;SET CONTROLLER FOR SIDE 0
	ANI	0FBH		;TRY DOUBLE DENSITY
	STAX	B

LOOP6:		;DOUBLE DENSITY TEST
	LXI	H,WRCLK
	MVI	M,0FFH
	LXI	D,SYNCPORT	;SYNC ON FF CLOCK IN HEADER
LOOP7	LDAX	D		;READ DATA PATTERN
	INR	L		;ABORT AFTER 256 TRIES
	JZ	RETRY
	ORA	A		;DATA SHOULD BE 00
	JNZ	LOOP7
				;FOUND HEADER
	DCX	D		;(D)=READDATA
	MVI	L,01		;(H)=WRCLK
	MVI	M,0AH
	LDAX	D		;SYNC WITH -EOW
	LDA	RDMRKCRC	;LOOK FOR ID MARK
	CPI	0A1H
	JNZ	RETRY
				;FOUND ID MARK
	LDAX	D		;FE BYTE
	LDAX	D		;TRACK BYTE
	LDAX	D		;SECTOR BYTE
	LDAX	D		;CRC BYTE
	LDAX	D		;CRC BYTE
	LDAX	D		;GAP BYTE 1
	LDAX	B
	RAR			;CHECK ID CRC
	JC	RETRY
				;ID CRC OK
	XRA	A		;RETURN 00
	RET

RETRY	CALL	ERRORCOUNT
	JNZ	LOOP6

		;SINGLE DENSITY TEST
		;ARRIVE HERE AFTER 30H TRIES AT DOUBLE DENSITY
SDTEST	XRA	A
	STA	ERRORBYTE	;(ERRORBYTE)=0
	LDA	CONTROLBYTE
	ORI	84H		;SET UP SIDE 0, SINGLE DENSITY
	STAX	B		;TO WRCONT
SDLOOP1	MVI	E,07		;(D)=SYNCPORT
	LXI	H,WRCLK
	MVI	M,0FFH		;SYNC ON FF CLOCK PATTERN
SDLOOP2	LDAX	D		;GET CORRESPONDING DATA
	INR	L		;ABORT AFTER 256 TRIES
	JZ	RETRY1
	ORA	A		;DATA SHOULD BE 00
	JNZ	SDLOOP2
				;FOUND HEADER
	DCX	D		;(D)=READDATA
	MVI	L,01		;(H)=WRCLK
	MVI	M,0C7H		;LOOK FOR C7 CLOCK
	LDAX	D		;SYNC WITH -EOW
	LDA	RDMRKCRC
	CPI	0FEH		;DATA FOR ID MARK
	JNZ	RETRY1
				;FOUND ID MARK
	LDAX	D		;TRACK BYTE
	LDAX	D		;SIDE
	LDAX	D		;SECTOR
	LDAX	D
	LDAX	D		;CRC BYTE
	LDAX	D		;CRC BYTE
	LDAX	D
	LDAX	B		;GET RDSTAT
	RAR			;CHECK ID CRC
	JC	RETRY1
				;ID CRC OK
	ORI	0FFH		;RETURN FF
	RET

RETRY1	CALL	ERRORCOUNT
	JNZ	SDLOOP1

		;FAILED BOTH DOUBLE AND SINGLE DENSITY
		; TESTS 30H TIMES
	LXI	H,TESTMAX
	INR	M		;INCREMENT TESTMAX
	MOV	A,M
	CPI	10
	JNZ	TEST1
		;FAILED TEST 10 TIMES
	ORA	A		;RETURN 0A
	RET


SKEW:		;COMPUTES PHYSICAL SECTOR FROM LOGICAL SECTOR
		;SKEW FACTOR IS 8
		;INPUT AND OUTPUT ARE IN C REG
		;OUTPUT=(((INPUT) MOD 52)*8 - 7) MOD 52
		;IF INPUT>52, SELECTS SIDE 1
	LXI	H,0
	PUSH	H
	LDA	CONTROLBYTE
	ANI	7FH		;SIDE 1
	MOV	E,A
	MOV	A,C
	SUI	52
	MOV	B,A		;(B)=(C)-52
	MOV	A,E		;(A)=(CONTROLBYTE)^7F
	JP	SKIPY
				;INPUT WAS LESS THAN 52
	ORI	80H		;CHOOSE SIDE 0
	MOV	B,C
SKIPY	STA	TWOSIDE
	MOV	A,B		;(B)=(INPUT) MOD 52
	MOV	L,B
	POP	B
LOOP10	INR	C
	SUI	13
	JP	LOOP10
	DAD	H
	DAD	H
	DAD	H
	MOV	A,H
	ORA	A
	MOV	A,L
	CNZ	HIGH
LOOP11	CPI	52
	JC	SKIP12
	ADI	204
	JMP	LOOP11
SKIP12	ADD	C
	MOV	C,A
	RET
HIGH	ADI	48
	RET


SETDMA	MOV	H,B
	MOV	L,C
	SHLD	DMA		;STORE DMA ADDRESS
	RET


SETSEC	MOV	A,C
	STA	SECTOR		;STORE SECTOR NUMBER
	RET


SETTRK:		;STEPS DRIVE TO TRACK (C)
	MOV	A,C
	CPI	44D		;IF (C)<44
	MVI	A,10H		;  THEN (ABOVE43)=10H
	JC	SKIP3
	MVI	A,50H		;  ELSE (ABOVE43)=50H
SKIP3	STA	ABOVE43
	CALL	DISKREADY

STEPLOOP LXI	H,TRACK
	MOV	A,M		;GET (TRACK)
	CMP	C		;DONE?
	JZ	DONESTEP
	CALL	STEPHEAD	;NO, STEP HEAD
	JMP	STEPLOOP	;REPEAT

STEPHEAD JC	STEPIN		;IF (TRACK)<(C) THEN STEP IN
STEPOUT	LDA	CONTROLBYTE	;ELSE STEP OUT
	DCR	M		;(TRACK)=(TRACK)-1
	ORI	02H		;DIR=OUT
	JMP	DOSTEP

STEPIN	LDA	CONTROLBYTE
	INR	M		;(TRACK)=(TRACK)+1
	ANI	0FDH		;DIR=IN

DOSTEP	STAX	D		;STORE DIRECTION IN WRCONT
	DCR	A		;-STEP=0
	STAX	D
	INR	A		;-STEP=1
	STAX	D
	LDA	STEPTIME
	MOV	B,A		;WAIT 8 MS FOR NEXT STEP
	JMP	DELAY		;DELAY EXECUTES A RETURN

DONESTEP MVI	B,STEPSETTLE
	CALL	DELAY		;WAIT 8 MS FOR STEP SETTLE
	MOV	A,C
	CPI	2		;IF (TRACK)<2 THEN SET TESTNEXT
	JC	SETTN
	LDA	TESTNEXT
	ORA	A
	MVI	A,0
	STA	TESTNEXT
	STC
	JNZ	SETDEN		;IF TESTNEXT=55 TEST DENSITY
	RET

SETDEN:		;TESTS DENSITY
		;UPDATES DENBYTE AND DENMAP
	CALL	TEST		;TEST DENSITY
	MVI	A,4		;IF Z IS SET (DOUBLE DENSITY)
	JZ	SKIP		;  THEN (DENBYTE)=4
	MVI	A,0		;  ELSE (DENBYTE)=0
SKIP	STA	DENBYTE
	LXI	H,DENMAP
	PUSH	PSW
	LDA	PRESDISK
	MOV	C,A
	MVI	B,0
	DAD	B
	POP	PSW		;SAVE FLAGS
	MOV	M,A		;(DENMAP(PRESDISK))=(DENBYTE)
	RET

SELDSK:		;SELECTS DRIVE POINTED TO BY C REG
		;LOADS HEAD OF SELECTED DRIVE
	LXI	H,MASKTABLE
	MVI	B,0
	DAD	B		;C CONTAINS DRIVE NUMBER
	MOV	A,M		;MASKTABLE CONTAINS 0 FOR
SELDSK1	STA	WRCONT		; SELECTED DRIVE, 1'S ELSEWHERE
	STA	TWOSIDE
	STA	CONTROLBYTE
	LXI	H,TRACKTAB
	LDA	PRESDISK
	MOV	E,A
	MOV	D,B
	DAD	D
	LDA	TRACK
	MOV	M,A		;(TRACKTAB(PRESDISK))=(TRACK)
	MOV	A,C
	STA	PRESDISK	;(PRESDISK)=(C)
	STA	DISK		;(DISK)=(C)
	LXI	H,TRACKTAB
	DAD	B
	MOV	A,M
	STA	TRACK		;(TRACK)=(TRACKTAB(C))
	LXI	H,LOGINTAB
	DAD	B
	MOV	A,M
	ORA	A		;HAS DRIVE BEEN LOGGED IN?
	JNZ	INOK
	MVI	A,55H		;NO. MARK AS LOGGED IN
	MOV	M,A
	CALL	HOME		;  AND HOME THE HEAD
INOK	CALL	DISKREADY	;LOAD HEAD
	MVI	B,HEADSETTLE
	CALL	DELAY		;WAIT FOR HEAD SETTLING
	LDA	TRACK
	CPI	02
	JNC	SETDEN
SETTN	MVI	A,55H		;ON TRACKS 0 AND 1, WE WANT
	STA	TESTNEXT	; TO TEST DENSITY OF NEXT TRACK
	JMP	SETDEN		;TEST DENSITY OF THIS TRACK


HEADLOAD LDAX	D		;ASSUMES (D)=RDSTAT
	ANI	20H		;HEAD ALREADY LOADED?
	LDA	RDMARK		;RESET HEAD LOAD COUNTER
	MVI	B,HEADSETTLE
	CNZ	DELAY		;IF HEAD WASN'T LOADED
	RET

DELAY:		;DELAYS (B) MILLISECONDS
	PUSH	H		;SAVE HL
DELAY2	LDA	CONTROLBYTE
	ANI	4		;IF SINGLE DENSITY,
	MVI	L,31		;	31 BYTES * 32 USEC = 1 MS
	JNZ	DELAY1
	MVI	L,63		;IN DD, 63 BYTES * 16 USEC = 1 MS
DELAY1	LDA	RDDATA
	DCR	L
	JNZ	DELAY1
	DCR	B		;END 1 MS LOOP
	JNZ	DELAY2
	POP	H		;RESTORE HL
	RET


HOME	CALL	DISKREADY
	LXI	H,TRACK		;FOR STEPIN AND STEPOUT
ATHOME	CALL	STEPIN		;STEP TOWARD 76
	LDAX	D
	ANI	02		;  UNTIL -TRK0 IS INACTIVE
	JZ	ATHOME
GOHOME	CALL	STEPOUT		;THEN STEP TOWARD 00
	LDAX	D
	ANI	02		;  UNTIL -TRK0 IS ACTIVE
	JNZ	GOHOME
	MVI	A,10H
	STA	ABOVE43		;(ABOVE43)=10H
	STA	TESTNEXT	;(TESTNEXT)=10H
	XRA	A
	STA	TRACK		;(TRACK)=00
	JMP	SETDEN		;TEST DENSITY


DISKREADY1 LDA	RDSTAT
	MOV	B,A
	ANI	0A0H		;IF DRIVE READY AND HEAD LOADED
	RZ			;	THEN RETURN
DISKREADY PUSH	B
	LXI	D,WRCONT	;(D)=WRCONT=RDSTAT
	CALL	HEADLOAD	;LOAD HEAD
	POP	B
	LDAX	D
	RLC
	JC	DISKREADY	;LOOP UNTIL DRIVE READY
	RET


COLDBOOT LXI	SP,STACK
	XRA	A
	LXI	B,BUFF
CBUFF	STAX	B		;ZERO OUT RAM BUFFER
	INR	C
	JNZ	CBUFF

	MVI	A,10
	STA	STEPTIME	;SET STEPTIME LONGER THAN IT NEEDS TO BE
				;TO BE SAFE, SINCE COLD BOOT LOADER RESETS IT
	LXI	B,0
	CALL	SETDMA		;SETDMA DOES NOT CHANGE C REG, SO...
	CALL	SELDSK		;SELECT DRIVE A
	MVI	C,01		;LOAD BOOTSTRAP LOADER
	CALL	SETSEC		;  FROM TRACK 0 SECTOR 1
	CALL	READ
	JNZ	COLDBOOT	;ON READ FAILURE, TRY AGAIN
	RST	0		;EXECUTE BOOTSTRAP LOADER
				;(SAVES 2 BYTES OVER JMP 0000)

MASKTABLE	DB	0BFH,0DFH,0EFH,0F7H
