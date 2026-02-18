import { motion } from "motion/react";
import { useNavigate, useParams } from "react-router";
import { ArrowLeft, Search, Filter, Gamepad2 } from "lucide-react";
import { GameCard } from "../components/game-card";
import { gamesData } from "../data/games";

const emulatorInfo: Record<string, { name: string; icon: string; gradient: string }> = {
  GB: { name: "Game Boy", icon: "🎮", gradient: "from-green-500/20 to-green-600/20" },
  GBC: { name: "Game Boy Color", icon: "🎨", gradient: "from-blue-500/20 to-purple-600/20" },
  GBA: { name: "Game Boy Advance", icon: "⚡", gradient: "from-purple-500/20 to-pink-600/20" },
  NDS: { name: "Nintendo DS", icon: "📱", gradient: "from-cyan-500/20 to-blue-600/20" },
  PS1: { name: "PlayStation 1", icon: "💿", gradient: "from-gray-500/20 to-gray-700/20" },
  "3DS": { name: "Nintendo 3DS", icon: "🔺", gradient: "from-red-500/20 to-orange-600/20" },
  PSP: { name: "PlayStation Portable", icon: "🎯", gradient: "from-indigo-500/20 to-purple-600/20" },
};

export default function GameList() {
  const navigate = useNavigate();
  const { platform } = useParams<{ platform: string }>();
  
  const platformKey = platform?.toUpperCase() || "GB";
  const games = gamesData[platformKey as keyof typeof gamesData] || [];
  const info = emulatorInfo[platformKey] || emulatorInfo.GB;

  return (
    <div className="min-h-full bg-background">
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
      <motion.header
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="sticky top-0 z-50 backdrop-blur-xl bg-background/80 border-b border-border/50"
      >
        <div className="px-4 py-3 pt-8">
          <div className="flex items-center gap-3 mb-3">
            {/* Back button */}
            <motion.button
              onClick={() => navigate("/")}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-9 h-9 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <ArrowLeft className="w-5 h-5 text-foreground" />
            </motion.button>

            <div className="flex-1">
              <h1 className="text-lg font-bold bg-gradient-to-r from-primary via-accent to-primary bg-clip-text text-transparent">
                {info.name}
              </h1>
              <p className="text-[10px] text-muted-foreground">
                {games.length} games available
              </p>
            </div>

            <div className="text-3xl">{info.icon}</div>
          </div>

          {/* Search and filter */}
          <div className="flex items-center gap-2">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
              <input
                type="text"
                placeholder="Search games..."
                className="w-full h-9 pl-9 pr-3 rounded-full bg-muted/50 border border-border/50 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all"
              />
            </div>
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-9 h-9 rounded-full bg-muted/50 hover:bg-muted flex items-center justify-center transition-colors"
            >
              <Filter className="w-4 h-4 text-foreground" />
            </motion.button>
          </div>
        </div>
      </motion.header>

      <main className="relative px-4 py-4 space-y-4">
        {/* Platform banner */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.2 }}
          className={`relative overflow-hidden rounded-2xl bg-gradient-to-br ${info.gradient} border border-border/50 p-5`}
        >
          <div className="relative">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <Gamepad2 className="w-5 h-5 text-primary" />
                <span className="text-sm font-semibold text-foreground">Quick Stats</span>
              </div>
              <span className="text-xs text-muted-foreground">{platformKey}</span>
            </div>
            <div className="grid grid-cols-3 gap-3">
              <div className="text-center">
                <p className="text-2xl font-bold text-foreground">{games.length}</p>
                <p className="text-xs text-muted-foreground">Games</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-foreground">
                  {games.reduce((acc, game) => acc + parseInt(game.playTime), 0)}h
                </p>
                <p className="text-xs text-muted-foreground">Played</p>
              </div>
              <div className="text-center">
                <p className="text-2xl font-bold text-foreground">
                  {games.filter(g => g.rating === 5).length}
                </p>
                <p className="text-xs text-muted-foreground">Favorites</p>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Games list */}
        <div className="space-y-3">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="flex items-center justify-between"
          >
            <h2 className="text-base font-semibold">All Games</h2>
            <button className="text-xs text-primary hover:underline">
              Sort by: Recent
            </button>
          </motion.div>

          <div className="space-y-2">
            {games.map((game, index) => (
              <GameCard key={game.name} {...game} index={index} />
            ))}
          </div>
        </div>

        {/* Bottom space for scrolling */}
        <div className="h-8" />
      </main>
    </div>
  );
}
