# Level 7 layout: the year 3000, a city ruled by the Cyborg Book Stealer. Each character is one 32x32 tile.
#   #  steel                  =  neon grate (one-way)      P  player start
#   B  banned book            H  heart    N  ink bottle    M  growth mushroom   X  star
#   Z  robot guard (shoots)   D  hover drone               L  laser emitter (fires down)
#   J  jump pad               m  hover platform (drifts side to side)   ^  electric floor
#   K  ink well               C  checkpoint                Y  propaganda hologram (scenery)
#   G  arena gate             S  the Cyborg Book Stealer
const MAP := [
	"#                                                                                                                                                                                                                     #                                  #",
	"#                                                                                                                                                                                                                     #                                  #",
	"#                                                             Y                                                                                          Y                                                            #                                  #",
	"#                                                                 D                                                                               D                                                 Y                 #                                  #",
	"#     Y                                                                                                  Y                                                                                                            #                                  #",
	"#                                                                                                                                                                                                                     #                                  #",
	"#                                   D                        B B B  Z   H B                                             D                      B B   Z                                          D                     #                                  #",
	"#                                                          #################        D                                                        ###########                                                      BH      #                                  #",
	"#                                                          #################                                                B                ###########    B                                                ####     #                                  #",
	"#                                     ##############       #################          B                             B                        ###########   ###  ###############                              ####     G                                  #",
	"#                                     ##############       #################                                                                 ###########        ###############                              ####     G                                  #",
	"#             B B              BB       L   L   L          #################                          M                     m                ###########          L  L  L  L     BB          X         B     ####     G     ====                ====     #",
	"#            =====                                         #################          m             =====           m                        ###########                                   =====             ####     G                                  #",
	"#                                                          #################                                                                 ###########                                                     ####     G                                  #",
	"#  P   B B B        Z    ^^ N             B   B   B  CK  J #################                   C  Z  ^^^  B N                      CK  Z   J ###########           B  B  B  N         C  Z  ^^     Z       J #### CK  G                       S          #",
	"##############################    ##############################################             ###################                 ###############################################    ##################   #################################################",
	"##############################    ##############################################             ###################                 ###############################################    ##################   #################################################",
]
