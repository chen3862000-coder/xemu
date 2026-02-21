import { motion } from "motion/react";
import { ArrowLeft, Search, Gamepad2 } from "lucide-react";
import { useNavigate } from "react-router";
import { gamesData } from "../data/games";

interface Game {
  name: string;
  coverImage: string;
  rating: number;
  playTime: string;
  lastPlayed: string;
  platform: string;
}

export default function AllGames() {
  const navigate = useNavigate();

  // Flatten all games from all platforms
  const allGames: Game[] = [];
  Object.entries(gamesData).forEach(([platform, games]) => {
    games.forEach((game) => {
      allGames.push({
        ...game,
        platform,
      });
    });
  });

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
              <h1 className="text-lg font-bold text-foreground">All Games</h1>
              <p className="text-xs text-muted-foreground">
                {allGames.length} games total
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
          {allGames.map((game, index) => (
            <motion.div
              key={`${game.platform}-${game.name}`}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.4, delay: index * 0.02 }}
              whileHover={{ scale: 1.03, y: -4 }}
              onClick={() => {
                // Navigate to game play page
                const gameIdSlug = game.name.toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, "");
                navigate(`/play/${game.platform}/${gameIdSlug}`);
              }}
              className="group relative cursor-pointer rounded-xl overflow-hidden bg-card border border-border/50"
            >
              {/* Game emoji/icon background */}
              <div className="relative h-28 overflow-hidden bg-gradient-to-br from-muted/50 to-muted flex items-center justify-center">
                <div className="text-5xl">{game.coverImage}</div>
                <div className="absolute inset-0 bg-gradient-to-t from-background via-background/60 to-transparent" />
                
                {/* Platform badge */}
                <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full bg-primary/90 backdrop-blur-sm">
                  <span className="text-[9px] font-semibold text-primary-foreground">
                    {game.platform}
                  </span>
                </div>

                {/* Play time badge */}
                <div className="absolute top-2 left-2 px-2 py-0.5 rounded-full bg-background/80 backdrop-blur-sm border border-border/30">
                  <span className="text-[9px] font-medium text-foreground">
                    {game.playTime}
                  </span>
                </div>

                {/* Rating stars */}
                <div className="absolute bottom-2 left-2 flex gap-0.5">
                  {[...Array(5)].map((_, i) => (
                    <span
                      key={i}
                      className={`text-xs ${
                        i < game.rating ? "text-yellow-400" : "text-muted"
                      }`}
                    >
                      ★
                    </span>
                  ))}
                </div>
              </div>

              {/* Game info */}
              <div className="p-3">
                <h3 className="text-sm font-semibold text-foreground mb-1 line-clamp-2 leading-tight">
                  {game.name}
                </h3>
                <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
                  <Gamepad2 className="w-2.5 h-2.5" />
                  <span>{game.lastPlayed}</span>
                </div>
              </div>

              {/* Hover effect overlay */}
              <div className="absolute inset-0 bg-gradient-to-t from-primary/10 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none" />
            </motion.div>
          ))}
        </div>
      </main>
    </div>
  );
}