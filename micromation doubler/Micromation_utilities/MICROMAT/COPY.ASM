
;NEW DISK COPY UTILITY FOR CP/M 2

;THIS IS AN ATTEMPT TO WRITE A DISK COPY UTILITY AS HARDWARE-INDEPENDENT
;AS POSSIBLE--I.E., TO WORK WITH ANY KIND OF DISK (ANY DENSITY)
;AND ANY KIND OF CONTROLLER

;FOR THAT REASON, ALL DISK FUNCTIONS ARE DONE THROUGH BIOS CALLS, RATHER
;THAN DIRECTLY WITH THE HARDWARE.

;THERE ARE STILL TWO PLACES THAT ARE HARDWARE DEPENDENT.
;FIRST, THE NUMBER OF TRACKS (SYSTEM TRACKS AND DATA TRACKS) TO COPY
;IS SPECIFIED IN AN EQUATE.  THIS CAN BE CALCULATED FROM THE DISK
;PARAMETER BLOCK IN ORDER TO MAKE THIS INDEPENDENT;  THAT APPROACH
;IS PLANNED FOR A FUTURE RELEASE
;SECONDLY, THE SKEW FACTOR TO USE IN READING OR WRITING SECTORS IS
;DETERMINED FROM THE DENSITY/SIDE BYTE PLACED IN SCRATCH RAM BY
;THE MICROMATION BIOS.  HOWEVER, THE ABSENCE OF THIS BYTE WILL
;NOT CRASH THIS UTILITY, IT MAY SIMPLY CAUSE IT TO COPY WITH A NON-
;OPTIMAL SKEW.  THIS COULD BE MADE MORE GENERAL BY PROMPTING THE USER
;FOR THE PROPER SKEW FACTOR TO USE, BUT A NON-SOPHISTICATED USER
;WOULDN'T KNOW WHAT TO ENTER

;		LAST UPDATED FEB 7, 1980

;	COPYRIGHT (C) 1980
;	MICROMATION, INC.
;	SAN FRANCISCO, CA


BASE	EQU	0		;BASE OF CP/M

BOOT	EQU	BASE
BDOS	EQU	BASE+5		;BDOS JUMP LOCATION
CPMBUFF	EQU	BASE+80H	;BUFFER FOR COMMAND LINE TAIL

DENSIDE	EQU	BASE+49H

BIOSLOC	EQU	BOOT+1		;ADDRESS OF WARM BOOT ROUTINE IN BIOS
SELDSKF	EQU	27		;LOW ADDRESS OF SELDSK FUNCTION
SETTRKF	EQU	30		;LOW ADDRESS OF SETTRK FUNCTION
SETSECF	EQU	33		;LOW ADDRESS OF SETSEC FUNCTION
SETDMAF	EQU	36		;LOW ADDRESS OF SETDMA FUNCTION
READF	EQU	39		;LOW ADDRESS OF READ SECTOR FUNCTION
WRITEF	EQU	42		;LOW ADDRESS OF WRITE SECTOR FUNCTION

NDISKS	EQU	4		;NUMBER OF DISKS THAT YOUR BIOS SUPPORTS
SYSTSPT	EQU	26		;NUMBER OF SECTORS PER SYSTEM TRACK

SYSTART	EQU	0		;FIRST SYSTEM TRACK NUMBER
DATSTART EQU	2		;FIRST DATA TRACK NUMBER
DATEND	EQU	76		;LAST DATA TRACK NUMBER

CR	EQU	0DH		;CARRIAGE RETURN
LF	EQU	0AH		;LINE FEED
TAB	EQU	9		;CONTROL I


		ORG	100H

	LXI	SP,100H		;INITIALIZE THE STACK POINTER
	LXI	D,LOGON
	CALL	PRINT		;PRINT THE SIGNON MESSAGE
REPEAT	CALL	GETPARM		;FIND OUT HOW MUCH OF THE DISK TO COPY
	CALL	GETSOURCE	;GET THE SOURCE DRIVE
	CALL	GETOBJECT	;GET THE OBJECT DRIVE
	LXI	D,GOMSG
	CALL	PRINT		;PROMPT USER TO LOAD DISKETTES
WAIT	CALL	CONIN
	CPI	CR		;WAIT FOR <RETURN>
	JNZ	WAIT
	CALL	GETDEN		;CHECK FOR COMPATIBLE DISK PARAMETER BLOCKS
				;ALSO SET UP POINTERS TO SKEW TABLES
	JZ	DENOK		;IF DISKS COMPATIBLE, CONTINUE
	LXI	D,DENMSG	;ELSE, PRINT INCOMPATIBILITY MESSAGE
	CALL	PRINT
	JMP	BOOT		;AND REBOOT

DENOK	LXI	D,CRLF
	CALL	PRINT		;NEW LINE TO SCREEN
	CALL	GETBUFF2	;COMPUTE THE START ADDRESS OF BUFFER 2

COPYLOOP			;ALL SET UP. NOW START THE COPY
	CALL	COPYTRACK	;COPY A TRACK
	LXI	H,TRACK
	INR	M		;INCREMENT TRACK NUMBER
	LDA	LASTTRACK	;GET NUMBER OF LAST TRACK TO COPY
	CMP	M		;LAST TRACK?
	JNC	COPYLOOP	;IF NO, DO NEXT TRACK

	LXI	D,COMPLMSG	;TELL USER WE'RE DONE
	CALL	PRINT
DONE	LXI	D,RPTMSG	;DOES HE WANT TO DO ANOTHER?
	CALL	PRINT
	CALL	CONIN		;GET HIS ANSWER
	CPI	'Y'
	JZ	REPEAT		;IF YES, GO DO IT
	CPI	'N'
	JZ	BOOT		;IF NO, REBOOT
	CPI	CR
	JNZ	DONE		;IF NO VALID ANSWER, ASK AGAIN
	JMP	BOOT

	;MESSAGES TO THE CONSOLE
LOGON	DB	CR,LF,'NEW DISK COPY UTILITY FOR CP/M 2$'

PRMPMSG	DB	CR,LF,LF,'DO YOU WANT TO COPY:'
	DB	CR,LF,TAB,'SYSTEM TRACKS ONLY? (TYPE S)'
	DB	CR,LF,TAB,'DATA TRACKS ONLY? (TYPE D)'
	DB	CR,LF,TAB,'THE ENTIRE DISK? (TYPE A) $'

SOURCEMSG
	DB	CR,LF,LF,'SOURCE DRIVE? (A, B, C, OR D) $'

OBJMSG	DB	CR,LF,'OBJECT DRIVE? (A, B, C, OR D) $'

GOMSG	DB	CR,LF,LF,'PUT SOURCE DISK ON '
ASCISRC	DB	'A'
	DB	CR,LF,'PUT OBJECT DISK ON '
ASCIOBJ	DB	'B'
	DB	CR,LF,'THEN TYPE <RETURN>$'

CRLF	DB	CR,LF,'$'

TRACKM	DB	CR,'TRACK $'

DENMSG	DB	CR,LF,LF,'DISKS ARE INCOMPATIBLE$'

COMPLMSG DB	CR,LF,LF,'**** COPY COMPLETE ****$'

RPTMSG	DB	CR,LF,LF,'DO YOU WANT TO COPY AGAIN? (Y/N) $'

READMSG	DB	CR,LF,'READ ERROR ON DRIVE $'

WRTMSG	DB	CR,LF,'WRITE ERROR ON DRIVE $'

TRKMSG	DB	'  TRACK $'

SECMSG	DB	'  SECTOR $'

COMPMSG1 DB	CR,LF,'COMPARE ERROR--TRACK $'

COMPMSG2 DB	' SOURCE DATA,ADDR = $'

COMPMSG3 DB	' OBJECT DATA,ADDR = $'

PERMMSG	DB	CR,LF,'**** PERMANENT ERROR ****$'


	;VARIABLES
SOURCE		DS	1	;SOURCE DRIVE
OBJECT		DS	1	;OBJECT	 DRIVE
SKEWPTR		DS	2	;POINTER TO SKEW TABLE
TRACK		DS	1	;CURRENT TRACK
LASTTRACK	DS	1	;LAST TRACK TO COPY
DISK		DS	1	;CURRENT DISK NUMBER (FOR ERROR ROUTINES)
SPT		DS	1	;SECTORS PER TRACK
TOTSECTS	DS	1	;TOTAL SECTORS LEFT TO COPY ON THIS TRACK
DMA		DS	2	;TEMPORARY STORAGE FOR DMA ADDRESS
BUFFLEN		DS	1	;LENGTH OF THE READ/WRITE BUFFER IN PAGES
				;(THIS NUMBER ALSO REPRESENTS THE NUMBER
				;OF SECTORS THAT EACH OF THE TWO BUFFERS
				;CAN HOLD)
BUFF2		DS	2	;POINTER TO SECOND READ/WRITE BUFFER
SECTOR		DS	1	;CURRENT SECTOR NUMBER (FOR ERROR ROUTINES)
TRYS		DS	1	;NUMBER OF RETRIES IN CASE OF COMPARE ERROR
READWRITE	DS	1	;READ/WRITE FLAG
ERRFLAG		DS	1	;00 MEANS NO ERRORS ON LAST TRACK


	;SUBROUTINES

PRINT	MVI	C,9
	JMP	BDOS

CONIN	MVI	C,1
	JMP	BDOS

PRTHEX		;PRINT NUMBER IN ACCUMULATOR IN HEX
	PUSH	PSW		;SAVE IT
	RRC			;GET HIGH NIBBLE
	RRC
	RRC
	RRC
	CALL	HEXOUT		;PRINT HIGH NIBBLE
	POP	PSW		;RESTORE NUMBER
HEXOUT				;PRINT NIBBLE IN 4 LSB'S OF ACCUMULATOR
	ANI	0FH		;MASK FOR NIBBLE
	CPI	10		;IS IT DECIMAL?
	JC	DEC
	ADI	'A'-'9'-1	;IF NO, ADD OFFSET FOR LETTERS A-F
DEC	ADI	'0'		;MAKE IT ASCII
	MOV	E,A		;MOVE IT TO E REG

CONOUT	MVI	C,2		;CONOUT FUNCTION
	JMP	BDOS


SELDSK	LHLD	BIOSLOC		;GET LOCATION OF BIOS
	MVI	L,SELDSKF	;MOVE SELDSK FUNCTION NUMBER INTO L
	PCHL			;JUMP

SETTRK	LHLD	BIOSLOC
	MVI	L,SETTRKF
	PCHL

SETSEC	LHLD	BIOSLOC
	MVI	L,SETSECF
	PCHL

SETDMA	LHLD	BIOSLOC
	MVI	L,SETDMAF
	PCHL

READ	LHLD	BIOSLOC
	MVI	L,READF
	PCHL

WRITE	LHLD	BIOSLOC
	MVI	L,WRITEF
	PCHL


GETPARM		;FIND OUT WHETHER TO COPY SYSTEM, DATA, OR ALL
	LXI	H,CPMBUFF	;POINT TO COMMAND LINE TAIL
	MOV	A,M		;GET # BYTES ON COMMAND LINE TAIL
	ORA	A		;ANY INPUT ON COMMAND LINE/
	JZ	PROMPT		;IF NO, PROMPT USER

	MOV	C,A		;SAVE # BYTES ON COMMAND LINE
GETLOOP	INX	H		;GET NEXT BYTE
	MOV	A,M
	CALL	CHKPARM		;IS IT A VALID PARAMETER?
	RZ			;IF YES, RETURN
	DCR	C		;IF NO, DECR # BYTES
	JNZ	GETLOOP		;AND CONTINUE LOOKING

PROMPT	LXI	D,PRMPMSG
	CALL	PRINT		;ASK USER TO INPUT PARAMETER
	CALL	CONIN		;WAIT FOR CONSOLE INPUT
	CALL	CHKPARM		;CHECK FOR VALID PARAMETER
	JNZ	PROMPT		;IF NO GOOD, TRY AGAIN
	RET


CHKPARM		;CHECK FOR VALID PARAMETER.
		;INITIALIZE "TRACK" AND "LASTTRACK"
	CPI	'A'
	MVI	B,SYSTART	;IF CHAR WAS "A", START AT BEGINNING OF DISK
	MVI	C,DATEND	;AND COPY TO END OF DATA AREA
	JZ	CHKOK
	CPI	'S'
	MVI	B,SYSTART	;IF CHAR WAS "S", START AT BEGINNING OF DISK
	MVI	C,DATSTART-1	;AND COPY TO END OF SYSTEM AREA
	JZ	CHKOK
	CPI	'D'
	MVI	B,DATSTART	;IF CHAR WAS "D", START AT BEGINNING OF DATA
	MVI	C,DATEND	;AND COPY TO END OF DATA AREA
	RNZ			;IF NONE OF ABOVE, RETURN WITH Z NOT SET
CHKOK	MOV	A,B
	STA	TRACK		;STORE FIRST TRACK NUMBER
	MOV	A,C
	STA	LASTTRACK	;STORE LAST TRACK NUMBER
	XRA	A		;SET Z FLAG
	RET


GETSOURCE	;FIND SOURCE DRIVE NUMBER
	LXI	D,SOURCEMSG
	CALL	PRINT		;PROMPT USER FOR IT
	CALL	GETDRIVE	;GET DRIVE NUMBER IN ASCII
	STA	ASCISRC		;STORE IT
	SUI	'A'		;CONVERT TO 0-3
	STA	SOURCE		;STORE IT
	RET


GETOBJECT	;FIND OBJECT DRIVE NUMBER
	LXI	D,OBJMSG
	CALL	PRINT		;PROMPT USER FOR IT
	CALL	GETDRIVE	;GET DRIVE NUMBER IN ASCII
	STA	ASCIOBJ		;STORE IT
	SUI	'A'		;CONVERT TO 0-3
	STA	OBJECT		;STORE IT
	RET


GETDRIVE	;GET A VALID DRIVE NUMBER FROM THE USER
	CALL	CONIN		;WAIT FOR CONSOLE INPUT
	CPI	'A'
	JC	GETDRIVE	;CHECK FOR VALID RANGE
	CPI	'A'+NDISKS
	JNC	GETDRIVE
	RET


GETDEN		;CHECK DISKS FOR COMPATIBILTY OF DPB'S
	LDA	SOURCE		;GET SOURCE DRIVE
	CALL	GETDPB		;GET DISK PARAMETER BLOCK
	LDAX	D		;GET NUMBER OF SECTORS PER TRACK
	STA	SPT		;STORE IT
	PUSH	D		;SAVE POINTER TO DPB
	SHLD	SKEWPTR		;SAVE POINTER TO SKEW TABLE
	LDA	OBJECT
	CALL	GETDPB		;GET DISK PARAMETER BLOCK
	POP	H		;RESTORE POINTER TO SOURCE DPB INTO HL
	MVI	C,15		;COMPARE DPB'S (15 BYTES LONG)
DENLOOP	LDAX	D		;GET DPB BYTE FOR OBJ
	CMP	M		;COMPARE IT TO DPB BYTE FOR SOURCE
	RNZ			;RETURN ERROR IF NOT =
	INX	D		;POINT TO NEXT BYTE
	INX	H
	DCR	C		;LOOP FOR 15 BYTES
	JNZ	DENLOOP
	XRA	A		;SET Z FLAG (SUCCESS)
	RET


GETDPB		;GET DISK PARAMETER BLOCK FOR DISK (A)
		;SET UP POINTER TO SKEW TABLE
	MOV	C,A		;PUT DISK NUMBER IN C REG
	LXI	D,0		;DISK OFF-LINE (BIOS WILL CHECK DEN)
	CALL	SELDSK		;SELECT IT
	LXI	D,10		;HL POINT TO DP HEADER
	DAD	D		;INDEX TO DPB POINTER
	MOV	E,M		;GET DPB HEADER
	INX	H		;2 BYTES
	MOV	D,M
		;THE REST OF THIS SUBROUTINE SETS UP A POINTER TO A
		;SKEW TABLE BASED ON THE FIRST BYTE (SPT) OF THE DPB
		;IT IS HARDWARE DEPENDENT AND CAN BE CHANGED OR 
		;ELIMINATED IF A BETTER WAY TO DO IT IS FOUND
	LDAX	D		;GET # SECTORS PER TRACK (SPT)
	CPI	52
	LXI	H,SKEW1		;IF < 52, DISK IS SINGLE DENSITY
	RC
	LXI	H,SKEW2		;IF > 52, DISK IS DOUBLE DENSITY
	RNZ
	LDA	DENSIDE		;IF = 52, DISK COULD BE SNGL DEN DBL SID
				;OR DBL DEN SNGL SIDED
	CPI	30		;DENSIDE=15 FOR DDSS, 30 FOR SDDS
	RC
	LXI	H,SKEW1
	RET


GETBUFF2	;CALCULATE THE NUMBER OF PAGES OF FREE MEMORY THAT CAN
		;BE USED AS A BUFFER. STORE IT IN BUFFLEN
		;DIVIDE THE FREE MEMORY IN HALF, STORE POINTER TO
		;SECOND HALF IN BUFF2
	LHLD	BDOS+1		;FIND BOTTOM OF BDOS
	MVI	L,0		;WILL USE UP TO THE PAGE BELOW BDOS
	LXI	D,-BUFF		;SUBTRACT ADDRESS FOR START OF BUFFER
	DAD	D
	MOV	A,H		;H NOW HAS # PAGES IN BUFFER
	STA	BUFFLEN		;STORE IT
	ORA	A		;CLEAR CARRY
	RAR			;DIVIDE BUFFER LENGTH BY 2
	MOV	H,A
	MOV	A,L
	RAR
	MOV	L,A
	LXI	D,BUFF		;HL NOW CONTAINS (BUFFER LENGTH)/2
	DAD	D		;ADD ADDRESS FOR START OF BUFF
	SHLD	BUFF2		;ANSWER IS ADDRESS FOR START OF 2ND HALF
	RET


COPYTRACK	;COPY A TRACK OF DATA FROM SOURCE DRIVE
		;TO OBJECT DRIVE, AND CHECK FOR ERRORS
		;THROUGHOUT THIS ROUTINE, B = NEXT SECTOR TO COPY,
		;	C = NUMBER OF SECTORS TO COPY

	;PRINT TRACK NUMBER
	LXI	H,ERRFLAG
	MOV	A,M		;GET ERROR FLAG
	MVI	M,0		;CLEAR IT
	ORA	A		;ANY ERRORS LAST TRACK?
	JZ	NOERRS
	LXI	D,CRLF		;IF YES, START NEW LINE TO SCREEN
	CALL	PRINT		;SO WE DON'T OVERWRITE ERROR MESSAGE
NOERRS	LXI	D,TRACKM
	CALL	PRINT		;PRINT "TRACK"
	LDA	TRACK
	CALL	PRTDEC		;PRINT TRACK NUMBER

	;START THE COPY
	MVI	B,0		;START WITH LOGICAL SECTOR 0
	LDA	TRACK		;GET TRACK NUMBER
	CPI	DATSTART	;IS THIS A SYSTEM TRACK?
	MVI	A,SYSTSPT	;IF YES, COPY APPROPRIATE # OF SECTORS
	JC	TRACK01
	LDA	SPT		;ELSE, LOAD # SECTORS PER TRACK
TRACK01	STA	TOTSECTS	;STORE # SECTORS TO COPY

COPYAGAIN	;THIS IS THE ENTRY POINT TO COPY ANOTHER SEGMENT OF A
		;TRACK, IN CASE THE ENTIRE TRACK WON'T FIT INTO THE BUFFER
	MVI	A,10
	STA	TRYS		;RETRY 10 TIMES IN CASE OF COMPARE ERROR
	LXI	H,TOTSECTS
	MOV	C,M		;NUMBER OF SECTORS LEFT TO COPY IN C REG
	MVI	M,0
	LDA	BUFFLEN
	CMP	C		;WILL THE REMAINING SECTORS FIT IN THE BUFFER?
	JNC	GOCOPY		;IF YES, TOTSECTS=0 AND # SECTS=TOTSECTS
				;THE TRACK WON'T ALL FIT
	MOV	D,A		;TEMP STORE BUFFLEN
	MOV	A,C		;GET TOTSECTS
	SUB	D		;TOTSECTS - BUFFLEN
	MOV	M,A		;TOTSECTS = TOTSECTS - BUFFLEN
	MOV	C,D		;# SECTORS = BUFFLEN

GOCOPY	PUSH	B		;SAVE SECTOR NUMBER AND # SECTORS
	LDA	SOURCE		;GET SOURCE DRIVE
	STA	DISK		;STORE IT
	MOV	C,A
	LXI	D,1		;DISK ON-LINE
	CALL	SELDSK		;SELECT SOURCE DRIVE
	LDA	TRACK
	MOV	C,A
	CALL	SETTRK		;GO TO DESIRED TRACK
	POP	B		;RECALL SECTOR # AND # SECTORS
	PUSH	B		;SAVE IT
	LXI	H,BUFF		;READ INTO FIRST BUFF
	CALL	READSEG		;READ THE (PARTIAL) TRACK
	LDA	OBJECT		;GET OBJECT DRIVE
	STA	DISK		;STORE IT
	MOV	C,A
	LXI	D,1		;DISK ON-LINE
	CALL	SELDSK		;SELECT OBJECT DRIVE
	LDA	TRACK
	MOV	C,A
	CALL	SETTRK		;GO TO DESIRED TRACK
	POP	B		;RECALL SECTOR # AND # SECTORS
	PUSH	B		;SAVE THEM
	LXI	H,BUFF		;WRITE FROM FIRST BUFF
	CALL	WRITESEG	;WRITE THE (PARTIAL) TRACK
	POP	B		;RECALL SECTOR # AND # SECTORS
	PUSH	B
	LHLD	BUFF2		;READ INTO SECOND BUFFER
	CALL	READSEG		;READ THE (PARTIAL) TRACK
	POP	B		;RECALL # SECTS AND SECTOR #
	PUSH	B
	LHLD	BUFF2		;POINTER TO SECOND BUFFER
	LXI	D,BUFF		;POINTER TO FIRST BUFFER
	CALL	COMPSEG		;COMPARE THE TWO BUFFERS
	POP	B		;RECALL SECTOR # AND # SECTORS
	ORA	A		;COMPARE OK?
	JZ	COMPOK		;IF YES, CONTINUE

	LXI	H,TRYS
	DCR	M		;ELSE, DECREMENT # OF TRIES
	JNZ	GOCOPY		;TRY AGAIN
	LXI	D,PERMMSG
	JMP	PRINT		;PRINT PERMANENT ERROR MESSAGE

COMPOK	MOV	A,B
	ADD	C		;SECTOR = SECTOR + # SECTORS
	MOV	B,A
	LDA	TOTSECTS
	ORA	A		;DONE WITH TRACK?
	JNZ	COPYAGAIN
	RET


READSEG		;READ A (POSSIBLY PARTIAL) TRACK INTO BUFFER AT (HL)
		;START READING AT SECTOR (B) AND READ A TOTAL OF (C) SECTS
	XRA	A		;READ FLAG
	JMP	RWSEG

WRITESEG	;DITTO FOR WRITE
	MVI	A,0FFH		;WRITE FLAG

RWSEG	STA	READWRITE	;STORE FLAG
RWSEC	SHLD	DMA
	PUSH	B		;SAVE SECTOR # AND # SECTORS
	MOV	B,H
	MOV	C,L
	CALL	SETDMA		;SET DMA ADDRESS
	LHLD	SKEWPTR		;GET POINTER TO SKEW TABLE
	LDA	TRACK
	CPI	DATSTART	;ARE WE ON A SYSTEM TRACK?
	JNC	RWDATA
	LXI	H,SKEW1		;IF YES, USE SKEW1 TABLE
RWDATA	POP	B		;RECALL SECTOR #
	MOV	E,B		;USE SECTOR # TO INDEX INTO SKEW TABLE
	MVI	D,0
	DAD	D		;INDEX INTO SKEW TABLE
	PUSH	B
	MOV	A,M		;GET TRANSLATED SECTOR
	STA	SECTOR		;SAVE IT FOR ERROR ROUTINES
	MOV	C,A		;PUT SECTOR # IN BC FOR SETSEC
	MVI	B,0
	CALL	SETSEC		;SELECT SECTOR
	LDA	READWRITE	;GET READ/WRITE FLAG
	ORA	A
	JNZ	WRTSEC
	CALL	READ		;READ THE SECTOR
	JMP	RW1		;SKIP WRITE

WRTSEC	CALL	WRITE		;WRITE THE SECTOR
RW1	ORA	A		;ANY ERRORS?
	CNZ	RWERROR		;IF YES, CALL ERROR ROUTINE
	LHLD	DMA
	LXI	D,80H
	DAD	D		;INCREMENT DMA ADDRESS
	POP	B		;RESTORE SECTOR # AND # SECTORS
	INR	B		;INCREMENT SECTOR #
	DCR	C		;ANY MORE SECTORS?
	JNZ	RWSEC
	RET


RWERROR		;READ/WRITE ERROR ROUTINE
		;BIOS RETURNED A HARD ERROR. PRINT IT
	LDA	READWRITE
	LXI	D,READMSG
	ORA	A		;SECTOR READ?
	JZ	READERR
	LXI	D,WRTMSG	;IF NO, PRINT WRITE MESSAGE
READERR	CALL	PRINT
	LDA	DISK		;GET DISK NUMBER
	ADI	'A'		;MAKE IT ASCII
	MOV	E,A
	CALL	CONOUT		;PRINT IT
	LXI	D,TRKMSG
	CALL	PRINT		;PRINT "TRACK"
	LDA	TRACK
	CALL	PRTDEC		;PRINT TRACK NUMBER
	LXI	D,SECMSG
	CALL	PRINT		;PRINT "SECTOR"
	LDA	SECTOR
	CALL	PRTDEC		;PRINT SECTOR NUMBER
	RET


COMPSEG		;COMPARE THE DATA IN THE TWO BUFFERS
		;B = SECTOR NUMBER, C = # SECTORS
		;DE = SOURCE BUFFER
		;HL = OBJECT BUFFER
	MVI	B,80H		;LENGTH OF SECTOR
COMP1	LDAX	D		;GET SOURCE BYTE
	CMP	M		;COMPARE IT WITH OBJECT BYTE
	JNZ	COMPERR		;IF NOT =, PRINT ERROR
	INX	D
	INX	H
	DCR	B
	JNZ	COMP1		;END OF 1 SECTOR

	DCR	C		;DECREMENT # SECTORS
	JNZ	COMPSEG
	XRA	A		;SUCCESSFUL COMPARE
	RET

COMPERR		;ROUTINE TO PRINT OUT COMPARE ERROR
	PUSH	H		;SAVE OBJECT BUFFER POINTER
	PUSH	H
	PUSH	H
	PUSH	D		;SAVE SOURCE BUFFER POINTER
	PUSH	D
	PUSH	PSW		;SAVE SOURCE BYTE
	LXI	D,COMPMSG1
	CALL	PRINT		;PRINT 1ST PART ERROR MESSAGE
	LDA	TRACK
	CALL	PRTDEC		;PRINT TRACK
	LXI	D,COMPMSG2
	CALL	PRINT		;PRINT NEXT PART ERROR MESSAGE
	POP	PSW		;RECALL SOURCE BYTE
	CALL	PRTHEX
	MVI	E,','
	CALL	CONOUT
	POP	D		;RECALL SOURCE BUFFER
	MOV	A,D
	CALL	PRTHEX		;PRINT IT
	POP	D
	MOV	A,E
	CALL	PRTHEX
	LXI	D,COMPMSG3
	CALL	PRINT		;PRINT NEXT PART ERROR MESSAGE
	POP	H		;RECALL OBJECT BYTE
	MOV	A,M
	CALL	PRTHEX		;PRINT IT
	MVI	E,','
	CALL	CONOUT
	POP	H		;RECALL OBJECT BUFFER
	MOV	A,H
	CALL	PRTHEX		;PRINT IT
	POP	H
	MOV	A,L
	CALL	PRTHEX
	MVI	A,1		;UNSUCCESSFUL COMPARE
	RET


PRTDEC		;CONVERT HEX NUMBER IN ACCUM TO DECIMAL AND PRINT IT
	LXI	B,0		;INITIALIZE DECIMAL NUMBER
DEC1	SUI	10H		;HIGH NIBBLE = 0?
	JC	DEC2		;IF YES, CARRY IS SET. GO TO LOW NIBBLE ROUTINE
	MOV	D,A		;SAVE HEX NUMBER
	MOV	A,C		;GET 2 LEAST SIGNIF. BCD DIGITS
	ADI	16H		;ADD 16
	DAA			;DECIMAL ADJUST
	MOV	C,A		;STORE THEM
	MOV	A,B		;GET OVERFLOW DIGIT
	ACI	0		;ADD CARRY (OVERFLOW)
	MOV	B,A		;STORE OVERFLOW DIGIT
	MOV	A,D		;RESTORE HEX NUMBER
	JMP	DEC1

DEC2	ADI	10H		;RESTORE HEX NUMBER TO RANGE OF 0-0FH
	ORA	A
	DAA			;MAKE IT DECIMAL
	ADD	C		;ADD BCD DIGITS TO LOW NIBBLE
	DAA			;DECIMAL ADJUST
	MOV	C,A		;STORE BACK IN C
	MOV	A,B		;GET OVERFLOW DIGIT
	ACI	0		;ADD IN CARRY (OVERFLOW)
	JZ	BELOW100	;DON'T PRINT LEADING 0 FROM OVERFLOW
	PUSH	B		;SAVE BCD DIGITS
	ADI	'0'		;MAKE OVERFLOW DIGIT INTO ASCII
	MOV	E,A
	CALL	CONOUT		;PRINT IT
	POP	B		;RESTORE BCD DIGITS
BELOW100 MOV	A,C		;MOVE BCD DIGITS INTO ACCUMULATOR
	JMP	PRTHEX		;PRINT THEM


SKEW1		;SINGLE DENSITY SKEW TABLE
		;SECTOR NUMBERS ARE WRITTEN SEQUENTIALLY ON THE DISK,
		;SO JUST DO AN ACTUAL SKEW OF 2
					;SIDE 0
	DB	1,3,5,7,9,11,13
	DB	15,17,19,21,23,25
	DB	2,4,6,8,10,12,14
	DB	16,18,20,22,24,26
					;SIDE 1
	DB	27,29,31,33,35,37,39
	DB	41,43,45,47,49,51
	DB	28,30,34,36,38,40,42
	DB	42,44,46,48,50,52


SKEW2		;DOUBLE DENSITY SKEW TABLE
		;SECTOR NUMBERS ARE SKEWED ON THE DISK WITH SKEWF=12
		;TAKING THAT INTO ACCOUNT, THIS TABLE IS CALCULATED
		;TO GIVE A TRUE SKEW OF 2
					;SIDE 0
	DB	1,27,10,36,6,32
	DB	2,28,11,37,7,33
	DB	3,29,12,38,8,34
	DB	4,30,13,39,9,35
	DB	5,31,14,40
	DB	23,49,19,45,15,41
	DB	24,50,20,46,16,42
	DB	25,51,21,47,17,43
	DB	26,52,22,48,18,44
					;SIDE 1
	DB	53,79,62,88,58,84
	DB	54,80,63,89,59,85
	DB	55,81,64,90,60,86
	DB	56,82,65,91,61,87
	DB	57,83,66,92
	DB	75,101,71,97,67,93
	DB	76,102,72,98,68,94
	DB	77,103,73,99,69,95
	DB	78,104,74,100,70,96


BUFF	EQU	$
