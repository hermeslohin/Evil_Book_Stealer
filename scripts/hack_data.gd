# Level 4 layout: inside the Book Stealer's supercomputer. Each character is one 32x32 tile.
#   #  circuit block          =  data bridge (one-way)     P  player start
#   B  stolen e-book          H  heart    N  ink bottle    M  growth mushroom   X  star
#   W  computer worm          D  security drone            L  laser emitter (fires down)
#   K  ink well               C  checkpoint
#   1 2  hack terminals: terminal 1 opens firewall a, terminal 2 opens firewall b
#   a b  firewall barriers    G  core-chamber gate         T  core terminal (drops its shield)
#   S  the supercomputer core
const MAP := [
	"#                                                                     #                                                                                                               #                                                           #                    #",
	"#                                                                     #                                                                                                               #                                                           #                    #",
	"#                                                                     #                                                                                                               #                                                           #                    #",
	"#                                                                     #                                                                                                               #                                                           #                    #",
	"#                                                                     #                                                                                                    D          #                                                           #                    #",
	"#                                                                     #                                                                                                       B 2     #                                                           #          S         #",
	"#                                                                     #                                                                                                      =====    #                                                           #                    #",
	"#                                                                     #                                                                                                               #                                                           #                    #",
	"#                                           D            D            #                                                                                   D              B            #            D                                D             #                    #",
	"#                                                                     a         ###############################                 ###############                        ====           b                                    #######        D       G                    #",
	"#               B  B                             B                    a             L     L     L     L                            L   L   L                 BB                       b               X                     L   L                 G  ===           === #",
	"#              ======  B        BB             =====                  a                                            B    B                                   ====     ===              b    M    B    === B        B                               G          T         #",
	"#                              ====                                   a                                               ====                                                            b   ===                    ===                              G        =====       #",
	"#           B                                                         a                                                                                                               b                                                           G                    #",
	"#  P    B B                 B              W     N           W    1   a  B B C         B     B     B     N  W               C        B   B              W         N      W        H   b  C                    W               B       B     K  C  G   T          K  T  #",
	"######################   ############   ##########################################################################    ###########################    ##########################################   ######   ###########   ###############################################",
	"######################   ############   ##########################################################################    ###########################    ##########################################   ######   ###########   ###############################################",
]
