# Level 4 layout: lost in time, way back in the age of dinosaurs. Each character is one 32x32 tile.
#   #  rock                   =  log platform (one-way)    P  player start
#   B  stone tablet           H  heart    N  ink bottle    M  growth mushroom   X  star
#   R  raptor (charges you)   F  pterodactyl (swoops down) ^  stalagmites
#   K  ink well               C  checkpoint                O  time portals (each pair, left to right, links up)
#   v  (top row) meteors rain from the volcano above these columns
#   G  arena gate             S  the Book Stealer riding his T-Rex
const MAP := [
	"#                                                                                                                                                   vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv        #                                #",
	"#                                                                                                                                                                                                                     #                                #",
	"#                                                                                                                                                                                                                     #                                #",
	"#                                                                                                                                                                                                                     #                                #",
	"#                                                      O BBBBH                                                                                                                                                        #                                #",
	"#                                                     #########                                                                                                                                                       #                                #",
	"#                                                                                     F                                                                                 F                                             #                                #",
	"#                                     F                                                                     F                                                                                 F                       #                                #",
	"#                                                                                                                                                                                                                     #                                #",
	"#                                                                            M                                                                                                                                        G                                #",
	"#                                                                           ###                                                                                                                                       G                                #",
	"#             B B      B                 B                      BB     B    ###          B   B B                                                          X    B    B            BB                B                  G    ====               ====     #",
	"#            =====                     =====                   ====   ###   ###             =====        B                                              =====      ###         ======          ##                     G                                #",
	"#                                                                     ###   ###                                                                                    ###                         ##                     G                                #",
	"#  P   B B B       R        ^^  N  R          CK   O    R  ^^         ###   ### ^^^ R             C  R        ^^ N R  B  O                  O  CK   B B      R     ###    ^^ R         C  N R  ##      ^^ R  H  B CK  G                     S          #",
	"######################   ###############   ####################    #####################   #############   #################              ####################   ###############    ##############   ###################################################",
	"######################   ###############   ####################    #####################   #############   #################              ####################   ###############    ##############   ###################################################",
]
