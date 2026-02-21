import { motion } from "motion/react";
import { Clock, ArrowLeft, Search } from "lucide-react";
import { useNavigate } from "react-router";

interface PlayedGame {
  title: string;
  console: string;
  lastPlayed: string;
  hoursPlayed: string;
  image: string;
  gameId: string;
}

const playedGames: PlayedGame[] = [
  {
    title: "Pokemon Emerald",
    console: "GBA",
    lastPlayed: "Today",
    hoursPlayed: "45h 30m",
    image: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=300&h=200&fit=crop",
    gameId: "pokemon-emerald",
  },
  {
    title: "Final Fantasy VII",
    console: "PS1",
    lastPlayed: "Yesterday",
    hoursPlayed: "32h 15m",
    image: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=300&h=200&fit=crop",
    gameId: "final-fantasy-vii",
  },
  {
    title: "Super Mario 64 DS",
    console: "NDS",
    lastPlayed: "2 days ago",
    hoursPlayed: "28h 45m",
    image: "https://images.unsplash.com/photo-1566576721346-d4a3b4eaeb55?w=300&h=200&fit=crop",
    gameId: "super-mario-64-ds",
  },
  {
    title: "Crash Bandicoot",
    console: "PS1",
    lastPlayed: "3 days ago",
    hoursPlayed: "21h 10m",
    image: "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=200&fit=crop",
    gameId: "crash-bandicoot",
  },
  {
    title: "The Legend of Zelda: Minish Cap",
    console: "GBA",
    lastPlayed: "4 days ago",
    hoursPlayed: "18h 20m",
    image: "https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=300&h=200&fit=crop",
    gameId: "zelda-minish-cap",
  },
  {
    title: "Metroid Fusion",
    console: "GBA",
    lastPlayed: "5 days ago",
    hoursPlayed: "15h 40m",
    image: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=300&h=200&fit=crop",
    gameId: "metroid-fusion",
  },
  {
    title: "Kingdom Hearts",
    console: "PS1",
    lastPlayed: "1 week ago",
    hoursPlayed: "42h 55m",
    image: "https://images.unsplash.com/photo-1552820728-8b83bb6b773f?w=300&h=200&fit=crop",
    gameId: "kingdom-hearts",
  },
  {
    title: "Pokemon Crystal",
    console: "GBC",
    lastPlayed: "1 week ago",
    hoursPlayed: "38h 25m",
    image: "https://images.unsplash.com/photo-1578303512597-81e6cc155b3e?w=300&h=200&fit=crop",
    gameId: "pokemon-crystal",
  },
  {
    title: "Mario Kart DS",
    console: "NDS",
    lastPlayed: "2 weeks ago",
    hoursPlayed: "52h 10m",
    image: "https://images.unsplash.com/photo-1593376893114-1aed528d80cf?w=300&h=200&fit=crop",
    gameId: "mario-kart-ds",
  },
  {
    title: "Tekken 3",
    console: "PS1",
    lastPlayed: "2 weeks ago",
    hoursPlayed: "25h 35m",
    image: "https://images.unsplash.com/photo-1538481199705-c710c4e965fc?w=300&h=200&fit=crop",
    gameId: "tekken-3",
  },
];

export default function PlayedGames() {
  const navigate = useNavigate();

  return (
    <div className="min-h-full bg-background pb-20">
      {/* Animated background effect */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <motion.div
          animate={{
            opacity: [0.03, 0.08, 0.03],
            scale: [1, 1.2, 1],
          }}
          transition={{
            duration: 10,
            repeat: Infinity,
            repeatType: "reverse",
          }}
          className="absolute -top-1/2 -right-1/2 w-full h-full bg-gradient-to-br from-primary to-accent rounded-full blur-3xl"
        />
        <motion.div
          animate={{
            opacity: [0.03, 0.08, 0.03],
            scale: [1.2, 1, 1.2],
          }}
          transition={{
            duration: 8,
            repeat: Infinity,
            repeatType: "reverse",
          }}
          className="absolute -bottom-1/2 -left-1/2 w-full h-full bg-gradient-to-tr from-accent to-primary rounded-full blur-3xl"
        />
      </div>

      {/* Header */}
      <div className="sticky top-0 z-50 backdrop-blur-xl bg-background/80 border-b border-border/50">
        <div className="px-4 py-3 pt-8">
          <div className="flex items-center gap-3 mb-4">
            <motion.button
              whileHover={{ scale: 1.05, x: -2 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => navigate("/")}
              className="w-8 h-8 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <ArrowLeft className="w-4 h-4 text-foreground" />
            </motion.button>
            <div className="flex-1">
              <h1 className="text-lg font-bold text-foreground">
                Recently Played
              </h1>
              <p className="text-xs text-muted-foreground">
                {playedGames.length} games
              </p>
            </div>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-8 h-8 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <Search className="w-4 h-4 text-foreground" />
            </motion.button>
          </div>
        </div>
      </div>

      {/* Games Grid */}
      <main className="relative px-4 py-4">
        <div className="grid grid-cols-2 gap-3">
          {playedGames.map((game, index) => (
            <motion.div
              key={game.gameId}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.05 }}
              whileHover={{ scale: 1.03, y: -4 }}
              onClick={() => navigate(`/game/${game.gameId}`)}
              className="group relative cursor-pointer rounded-xl overflow-hidden bg-card border border-border/50"
            >
              {/* Game image */}
              <div className="relative h-28 overflow-hidden">
                <img
                  src={game.image}
                  alt={game.title}
                  className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                />
                <div className="absolute inset-0 bg-gradient-to-t from-background via-background/60 to-transparent" />
                
                {/* Console badge */}
                <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full bg-primary/90 backdrop-blur-sm">
                  <span className="text-[9px] font-semibold text-primary-foreground">
                    {game.console}
                  </span>
                </div>

                {/* Hours played badge */}
                <div className="absolute top-2 left-2 px-2 py-0.5 rounded-full bg-background/80 backdrop-blur-sm border border-border/30">
                  <span className="text-[9px] font-medium text-foreground">
                    {game.hoursPlayed}
                  </span>
                </div>
              </div>

              {/* Game info */}
              <div className="p-3">
                <h3 className="text-sm font-semibold text-foreground mb-1 line-clamp-2 leading-tight">
                  {game.title}
                </h3>
                <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
                  <Clock className="w-2.5 h-2.5" />
                  <span>{game.lastPlayed}</span>
                </div>
              </div>

              {/* Hover effect overlay */}
              <div className="absolute inset-0 bg-gradient-to-t from-primary/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
            </motion.div>
          ))}
        </div>

        {/* Empty state hint (if you want to show when no games) */}
        {playedGames.length === 0 && (
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="flex flex-col items-center justify-center py-16 px-4"
          >
            <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mb-4">
              <Clock className="w-8 h-8 text-muted-foreground" />
            </div>
            <h3 className="text-base font-semibold text-foreground mb-1">
              No Games Yet
            </h3>
            <p className="text-sm text-muted-foreground text-center">
              Start playing some games to see them here
            </p>
          </motion.div>
        )}
      </main>
    </div>
  );
}