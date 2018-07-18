;recréation du firware du cat's meow sur PIC12F675
;Auteur: Jacques Deschênes
;Date: 2013-10-06
;Description:
;    suite à la demande de réparation d'un jouet pour chat appellé "Cat's meow",
;    je constate que c'est le MCU qui est défecteux. Le marquage du MCU a été
;    effacé mais je constate que l'alimentation est sur les même broches qu'un
;    PIC12F6xx. J'entreprends donc de remplacer le MCU par un PIC12F675. Pour ce
;    faire je dois écrire ma propre version du firmware.

    include <P12F675.INC>
    __config  _WDTE_OFF & _MCLRE_OFF & _PWRTE_ON & _BODEN_ON & _FOSC_INTRCIO

    radix dec

#define    OPTION_CFG  H'01'
#define    LEFT_DRV GP0
#define    RIGHT_DRV GP1
#define    PRNG_TAPS H'B4'  ;
#define    F_DIR 0   ; direction de la rotation
#define    DEAD_TIME 20 ; délais temps mort
#define    MIN_DLY 500 ; délais mininum durée rotation

;  ************ macros *******************


_left_start macro
    bsf GPIO, LEFT_DRV
    endm

_right_start macro
    bsf GPIO, RIGHT_DRV
    endm

_case macro n, addr
    xorlw n
    skpnz
    goto addr
    xorlw n
    endm

_cpyr16 macro rsrc, rdest
    movfw rsrc
    movwf rdest
    movfw rsrc+1
    movwf rdest+1
    endm

_addl16 macro r16, lit16
    movlw lit16&H'FF'
    addwf r16,F
    skpnc
    incf r16+1
    movlw (lit16>>8)&H'FF'
    addwf r16+1,F
    endm


; *********  variables *************
    cblock  H'20'
flags : 1  ;  indicateurs booléens
prng   : 2  ;  générateur de nombres pseudo aléatoires 16 bits
dly_cnt : 2 ; compteur pour delay_ms
    endc

    code
    org 0
rst_vector
    pagesel init
    goto init

    org 4
isr_vector
    retfie

;;;;;;;;;  random  ;;;;;;;;;;;;;;;;
;; générateur de pseudo hazard
;; REF: http://en.wikipedia.org/wiki/Linear_feedback_shift_register
random
    btfss prng,0
    goto rand01
    movlw PRNG_TAPS
    xorwf prng+1
    bcf prng, 0
rand01
    rrf  prng+1, W
    rrf  prng, F
    rrf  prng+1
    return


delay_ms
    banksel TMR0
    movlw 5
    movwf TMR0
    movfw TMR0
    skpz
    goto $-2
    decfsz dly_cnt
    goto delay_ms+1
    movf dly_cnt+1,F
    skpnz
    return
    decfsz dly_cnt+1,F
    goto delay_ms+1
    return

stop_motor
    banksel GPIO
    clrf GPIO
    movlw DEAD_TIME
    movwf dly_cnt
    clrf dly_cnt+1
    call delay_ms
    return

motor_left
    call stop_motor
    banksel GPIO
    _left_start
    return

motor_right
    call stop_motor
    banksel GPIO
    _right_start
    return


init
    banksel OSCCAL
    movwf OSCCAL
; détection BOD et POR
    banksel PCON
    btfss PCON, NOT_POR
    goto power_on
    btfsc PCON, NOT_BOR
    goto power_on
; si le moteur est bloqué le voltage tombe et produit un BOR
; on inverse alors le sens de la rotation
    movlw (1<<F_DIR)
    xorwf flags, F
    goto $+2
power_on
    clrf flags
    movlw 3
    movwf PCON
    clrf ANSEL    ; désactivation des entrées A/N
    movlw OPTION_CFG
    banksel OPTION_REG
    movwf OPTION_REG
    banksel GPIO
    clrf GPIO
    movlw ~((1<<LEFT_DRV)|(1<<RIGHT_DRV))
    banksel TRISIO
    movwf TRISIO  ; GP0 et GP1 en sortie, les autres en entrée
    movlw 1
    movwf prng

main
    btfsc flags, F_DIR
    goto rot_left
    call motor_right
    goto $+2
rot_left
    call motor_left
    movlw (1<<F_DIR) ; Inverse l'indicateur de direction
    xorwf flags, F   ; pour la boucle suivante.
    call random      ; durée la rotation au hazard.
    _cpyr16 prng, dly_cnt
    _addl16 dly_cnt, MIN_DLY
    movlw 3
    andwf dly_cnt+1,F   ; durée maximale de la rotation ~1sec.
    call delay_ms
    goto main


    end




