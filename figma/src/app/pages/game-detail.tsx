import { motion } from "motion/react";
import { useNavigate, useParams } from "react-router";
import {
  ArrowLeft,
  Play,
  Star,
  Clock,
  Calendar,
  Folder,
  Bookmark,
  Share2,
  MoreVertical,
  Gamepad2,
  TrendingUp,
} from "lucide-react";
import { gameDetailsData } from "../data/game-details";

export default function GameDetail() {
  const navigate = useNavigate();
  const { gameId } = useParams<{ gameId: string }>();

  const game = gameId ? gameDetailsData[gameId] : null;

  if (!game) {
    return (
      <div className="min-h-full bg-background flex items-center justify-center">
        <div className="text-center">
          <h2 className="text-xl font-bold text-foreground mb-2">
            Game Not Found
          </h2>
          <button
            onClick={() => navigate("/")}
            className="text-sm text-primary hover:underline"
          >
            Return Home
          </button>
        </div>
      </div>
    );
  }

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

      {/* Header with image background */}
      <div className="relative">
        {/* Background image */}
        <div className="absolute inset-0 overflow-hidden">
          <div className="absolute inset-0 bg-gradient-to-b from-transparent via-background/50 to-background" />
          <img
            src={game.image}
            alt={game.title}
            className="w-full h-full object-cover opacity-30 blur-sm"
          />
        </div>

        {/* Header content */}
        <motion.div
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="relative z-10 px-4 py-3 pt-8 pb-6"
        >
          <div className="flex items-center justify-between mb-4">
            <motion.button
              onClick={() => navigate("/")}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="w-9 h-9 rounded-full bg-background/80 backdrop-blur-md hover:bg-background flex items-center justify-center transition-colors border border-border/50"
            >
              <ArrowLeft className="w-5 h-5 text-foreground" />
            </motion.button>

            <div className="flex items-center gap-2">
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="w-9 h-9 rounded-full bg-background/80 backdrop-blur-md hover:bg-background flex items-center justify-center transition-colors border border-border/50"
              >
                <Share2 className="w-4 h-4 text-foreground" />
              </motion.button>
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="w-9 h-9 rounded-full bg-background/80 backdrop-blur-md hover:bg-background flex items-center justify-center transition-colors border border-border/50"
              >
                <MoreVertical className="w-4 h-4 text-foreground" />
              </motion.button>
            </div>
          </div>

          {/* Game title and info */}
          <div className="flex items-start gap-4">
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{
                type: "spring",
                stiffness: 200,
                delay: 0.2,
              }}
              className="w-24 h-24 rounded-2xl overflow-hidden flex-shrink-0 bg-gradient-to-br from-primary/20 to-accent/20 border-2 border-border/50 shadow-2xl"
            >
              <div className="w-full h-full flex items-center justify-center text-5xl">
                {game.icon}
              </div>
            </motion.div>

            <div className="flex-1 pt-2">
              <motion.div
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.3 }}
                className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-primary/20 border border-primary/30 backdrop-blur-sm mb-2"
              >
                <Gamepad2 className="w-3 h-3 text-primary" />
                <span className="text-xs font-semibold text-primary">
                  {game.consoleFull}
                </span>
              </motion.div>

              <motion.h1
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.5, delay: 0.4 }}
                className="text-2xl font-bold text-foreground mb-1"
              >
                {game.title}
              </motion.h1>

              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.5, delay: 0.5 }}
                className="flex items-center gap-1 mb-2"
              >
                {[...Array(5)].map((_, i) => (
                  <Star
                    key={i}
                    className={`w-4 h-4 ${
                      i < game.rating
                        ? "text-yellow-500 fill-yellow-500"
                        : "text-muted-foreground/30"
                    }`}
                  />
                ))}
              </motion.div>

              <motion.p
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ duration: 0.5, delay: 0.6 }}
                className="text-xs text-muted-foreground"
              >
                {game.genre} • {game.releaseYear}
              </motion.p>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Main content */}
      <main className="relative px-4 py-4 space-y-4">
        {/* Instant Play Button */}
        <motion.button
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.7 }}
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          className="w-full relative group overflow-hidden rounded-xl"
        >
          <div className="absolute inset-0 bg-gradient-to-r from-primary via-accent to-primary opacity-100 group-hover:opacity-90 transition-opacity" />
          <motion.div
            animate={{
              x: ["-100%", "100%"],
            }}
            transition={{
              duration: 3,
              repeat: Infinity,
              ease: "linear",
            }}
            className="absolute inset-0 bg-gradient-to-r from-transparent via-white/20 to-transparent"
          />
          <div className="relative px-6 py-4 flex items-center justify-center gap-3">
            <Play className="w-6 h-6 text-white fill-white" />
            <span className="text-lg font-bold text-white">Instant Play</span>
          </div>
        </motion.button>

        {/* Stats Grid */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.8 }}
          className="grid grid-cols-3 gap-3"
        >
          <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 p-3 text-center">
            <Clock className="w-5 h-5 text-primary mx-auto mb-1" />
            <p className="text-sm font-bold text-foreground mb-0.5">
              {game.totalPlayTime}
            </p>
            <p className="text-xs text-muted-foreground">Play Time</p>
          </div>

          <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 p-3 text-center">
            <Bookmark className="w-5 h-5 text-primary mx-auto mb-1" />
            <p className="text-sm font-bold text-foreground mb-0.5">
              {game.saveStates}
            </p>
            <p className="text-xs text-muted-foreground">Save States</p>
          </div>

          <div className="relative overflow-hidden rounded-xl bg-card border border-border/50 p-3 text-center">
            <Folder className="w-5 h-5 text-primary mx-auto mb-1" />
            <p className="text-sm font-bold text-foreground mb-0.5">
              {game.size}
            </p>
            <p className="text-xs text-muted-foreground">Size</p>
          </div>
        </motion.div>

        {/* About Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 1.0 }}
          className="relative overflow-hidden rounded-xl bg-card border border-border/50 p-4"
        >
          <h3 className="text-base font-semibold text-foreground mb-2 flex items-center gap-2">
            <Gamepad2 className="w-4 h-4 text-primary" />
            About This Game
          </h3>
          <p className="text-sm text-muted-foreground leading-relaxed">
            {game.description}
          </p>
        </motion.div>

        {/* Additional Info */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 1.1 }}
          className="relative overflow-hidden rounded-xl bg-card border border-border/50 p-4 space-y-3"
        >
          <h3 className="text-base font-semibold text-foreground mb-3">
            Game Information
          </h3>

          <div className="space-y-2">
            <div className="flex items-center justify-between py-2 border-b border-border/30">
              <span className="text-sm text-muted-foreground">Console</span>
              <span className="text-sm font-medium text-foreground">
                {game.consoleFull}
              </span>
            </div>
            <div className="flex items-center justify-between py-2 border-b border-border/30">
              <span className="text-sm text-muted-foreground">Genre</span>
              <span className="text-sm font-medium text-foreground">
                {game.genre}
              </span>
            </div>
            <div className="flex items-center justify-between py-2 border-b border-border/30">
              <span className="text-sm text-muted-foreground">Release Year</span>
              <span className="text-sm font-medium text-foreground">
                {game.releaseYear}
              </span>
            </div>
            <div className="flex items-center justify-between py-2">
              <span className="text-sm text-muted-foreground">Rating</span>
              <div className="flex items-center gap-1">
                <Star className="w-4 h-4 text-yellow-500 fill-yellow-500" />
                <span className="text-sm font-medium text-foreground">
                  {game.rating}/5
                </span>
              </div>
            </div>
          </div>
        </motion.div>

        {/* Bottom space for scrolling */}
        <div className="h-8" />
      </main>
    </div>
  );
}