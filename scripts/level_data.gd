# Level layout. Each character is one 32x32 tile.
#   #  solid bookshelf      =  one-way platform    ^  spikes
#   P  player start         B  stolen book         H  heart
#   W  bookworm enemy       C  checkpoint          G  boss gate
#   N  ink bottle (+5 ink)  K  ink well (stand in it to refill)
#   M  growth mushroom (get big, absorbs one hit)
#   X  invincibility star (briefly unstoppable)
#   I  inkling (throws ink at you)
#   S  the Evil Book Stealer (boss)
const MAP := [
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                                                                                                                                                                       B                           #                                  #",
	"#                                                                                                                                                                                                                     =====                         #                                  #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#                                                                          BB                                                                        B                                                B                       W                     #                H                 #",
	"#                                                                         ====                                                                      ====                                            =====                    ====                   #             ========             #",
	"#                                                                                                                                                                                                                                                   #                                  #",
	"#           B          B     B           B B                 B                                  B            B        B     W  B                                     B      B      B                                                 B   B          #                                  #",
	"#         =====            =====        =====               ###      ====                      ###          ####     ===  ######               ====                 ===    ===   =====          ####                               ====  ##         G    =====                =====    #",
	"#                ##                                         ###                                             ####                      #                      ##                                 ####                                     ##         G                                  #",
	"#  P   B      K  ## W       I    NW           W  ^^^        ###   I    N   ^^^^   C K   W B          CM ^^^ ####  WN       I     ^^K  #    C  N  X^^^^^   B  ##  W    I          ^^^^^   M  W   #### ^^^    C N  W   WM ^^^^^   ^^^ N    ## H C KB  G                           S      #",
	"######################    ############################    ####################################     #################     ###########  #  #################################     #########################################################################################################",
	"######################    ############################    ####################################     #################     ###########  #  #################################     #########################################################################################################",
]
