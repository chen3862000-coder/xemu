import { motion } from "motion/react";
import { Clock } from "lucide-react";
import { useNavigate } from "react-router";

interface RecentGame {
  title: string;
  console: string;
  lastPlayed: string;
  progress: number;
  image: string;
  gameId: string;
}

const recentGames: RecentGame[] = [
  {
    title: "Pokemon Emerald",
    console: "GBA",
    lastPlayed: "Today",
    progress: 75,
    image: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=300&h=200&fit=crop",
    gameId: "pokemon-emerald",
  },
  {
    title: "Final Fantasy VII",
    console: "PS1",
    lastPlayed: "Yesterday",
    progress: 45,
    image: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=300&h=200&fit=crop",
    gameId: "final-fantasy-vii",
  },
];

export function RecentGames() {
  const navigate = useNavigate();

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Clock className="w-4 h-4 text-primary" />
          <h2 className="text-base font-semibold">Continue Playing</h2>
        </div>
        <button 
          onClick={() => navigate("/played-games")}
          className="text-xs text-primary hover:text-primary/80 transition-colors"
        >
          View All
        </button>
      </div>

      <div className="flex gap-3 overflow-x-auto pb-2 -mx-4 px-4 scrollbar-hide">
        {recentGames.map((game, index) => (
          <motion.div
            key={game.title}
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 0.4, delay: index * 0.1 }}
            whileHover={{ scale: 1.03, y: -4 }}
            onClick={() => navigate(`/game/${game.gameId}`)}
            className="group relative cursor-pointer rounded-xl overflow-hidden bg-card border border-border/50 min-w-[160px] flex-shrink-0"
          >
            {/* Game image */}
            <div className="relative h-24 overflow-hidden">
              <img
                src={game.image}
                alt={game.title}
                className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-background via-background/50 to-transparent" />
              
              {/* Console badge */}
              <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full bg-primary/90 backdrop-blur-sm">
                <span className="text-[10px] font-semibold text-primary-foreground">
                  {game.console}
                </span>
              </div>
            </div>

            {/* Game info */}
            <div className="p-3 space-y-2">
              <div>
                <h3 className="text-sm font-semibold text-foreground mb-0.5 truncate">
                  {game.title}
                </h3>
                <div className="flex items-center gap-1 text-[10px] text-muted-foreground">
                  <Clock className="w-2.5 h-2.5" />
                  <span>{game.lastPlayed}</span>
                </div>
              </div>
            </div>
          </motion.div>
        ))}
      </div>
    </div>
  );
}