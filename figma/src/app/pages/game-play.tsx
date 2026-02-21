import { motion } from "motion/react";
import {
  ArrowLeft,
  Play,
  Save,
  Settings,
  Zap,
  Globe,
  Code,
  ChevronRight,
  Clock,
} from "lucide-react";
import { useNavigate, useParams } from "react-router";
import { useState } from "react";

interface SaveState {
  id: string;
  name: string;
  timestamp: string;
  screenshot: string;
  progress: string;
}

export default function GamePlay() {
  const navigate = useNavigate();
  const { platform, gameId } = useParams<{ platform: string; gameId: string }>();
  const [selectedFps, setSelectedFps] = useState("60");
  const [selectedLanguage, setSelectedLanguage] = useState("English");

  // Mock save states
  const saveStates: SaveState[] = [
    {
      id: "auto",
      name: "Auto Save",
      timestamp: "2 minutes ago",
      screenshot: "https://images.unsplash.com/photo-1511512578047-dfb367046420?w=300&h=200&fit=crop",
      progress: "Latest checkpoint",
    },
    {
      id: "state-1",
      name: "Save State 1",
      timestamp: "15 minutes ago",
      screenshot: "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=300&h=200&fit=crop",
      progress: "Level 3 - Boss Fight",
    },
    {
      id: "state-2",
      name: "Save State 2",
      timestamp: "1 hour ago",
      screenshot: "https://images.unsplash.com/photo-1542751371-adc38448a05e?w=300&h=200&fit=crop",
      progress: "Level 2 - Main Area",
    },
    {
      id: "state-3",
      name: "Save State 3",
      timestamp: "2 hours ago",
      screenshot: "https://images.unsplash.com/photo-1606144042614-b2417e99c4e3?w=300&h=200&fit=crop",
      progress: "Level 1 - Start",
    },
  ];

  const fpsOptions = ["30", "60", "120", "Unlimited"];
  const languageOptions = ["English", "Japanese", "Spanish", "French", "German"];

  const cheatCodes = [
    { name: "Infinite Health", code: "8E2991F4", enabled: false },
    { name: "Max Money", code: "820257C4", enabled: false },
    { name: "All Items", code: "420257BC", enabled: true },
    { name: "Unlock All Levels", code: "320257D0", enabled: false },
  ];

  const gameName = gameId?.replace(/-/g, " ") || "Game";
  const gameCover = "https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=400&h=300&fit=crop";

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

      {/* Header with Game Cover */}
      <div className="relative">
        {/* Cover Image Background */}
        <div className="relative h-48 overflow-hidden">
          <img
            src={gameCover}
            alt={gameName}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-b from-background/60 via-background/80 to-background" />
          
          {/* Back button */}
          <motion.button
            whileHover={{ scale: 1.05, x: -2 }}
            whileTap={{ scale: 0.95 }}
            onClick={() => navigate(-1)}
            className="absolute top-8 left-4 w-8 h-8 rounded-full bg-background/80 backdrop-blur-sm hover:bg-background flex items-center justify-center transition-colors border border-border/50"
          >
            <ArrowLeft className="w-4 h-4 text-foreground" />
          </motion.button>

          {/* Game info */}
          <div className="absolute bottom-4 left-4 right-4">
            <div className="flex items-center gap-2 mb-2">
              <div className="px-2 py-0.5 rounded-full bg-primary/90 backdrop-blur-sm">
                <span className="text-[10px] font-semibold text-primary-foreground uppercase">
                  {platform}
                </span>
              </div>
              <div className="px-2 py-0.5 rounded-full bg-green-500/90 backdrop-blur-sm flex items-center gap-1">
                <div className="w-1.5 h-1.5 rounded-full bg-white animate-pulse" />
                <span className="text-[10px] font-semibold text-white">
                  Ready to Play
                </span>
              </div>
            </div>
            <h1 className="text-xl font-bold text-foreground capitalize">
              {gameName}
            </h1>
          </div>
        </div>
      </div>

      {/* Main Content */}
      <main className="relative px-4 py-4 space-y-4">
        {/* Quick Actions */}
        <div className="space-y-2">
          <motion.button
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4 }}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full bg-gradient-to-r from-primary to-accent p-4 rounded-xl flex items-center justify-between group"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center">
                <Play className="w-5 h-5 text-white fill-white" />
              </div>
              <div className="text-left">
                <h3 className="text-sm font-semibold text-white">Quick Start</h3>
                <p className="text-xs text-white/80">Continue from last save</p>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-white group-hover:translate-x-1 transition-transform" />
          </motion.button>

          <motion.button
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.4, delay: 0.1 }}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="w-full bg-card border border-border/50 p-4 rounded-xl flex items-center justify-between group"
          >
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-muted flex items-center justify-center">
                <Save className="w-5 h-5 text-primary" />
              </div>
              <div className="text-left">
                <h3 className="text-sm font-semibold text-foreground">New Game</h3>
                <p className="text-xs text-muted-foreground">Start from beginning</p>
              </div>
            </div>
            <ChevronRight className="w-5 h-5 text-muted-foreground group-hover:translate-x-1 transition-transform" />
          </motion.button>
        </div>

        {/* Save States Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.2 }}
          className="space-y-3"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-primary" />
              <h2 className="text-base font-semibold text-foreground">Save States</h2>
            </div>
            <span className="text-xs text-muted-foreground">
              {saveStates.length} states
            </span>
          </div>

          <div className="grid grid-cols-2 gap-3">
            {saveStates.map((state, index) => (
              <motion.div
                key={state.id}
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ duration: 0.3, delay: 0.3 + index * 0.05 }}
                whileHover={{ scale: 1.03, y: -2 }}
                className="relative group cursor-pointer rounded-xl overflow-hidden bg-card border border-border/50"
              >
                {/* State screenshot */}
                <div className="relative h-20 overflow-hidden">
                  <img
                    src={state.screenshot}
                    alt={state.name}
                    className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-300"
                  />
                  <div className="absolute inset-0 bg-gradient-to-t from-background via-background/60 to-transparent" />
                  
                  {/* Auto save badge */}
                  {state.id === "auto" && (
                    <div className="absolute top-1.5 left-1.5 px-2 py-0.5 rounded-full bg-primary/90 backdrop-blur-sm">
                      <span className="text-[8px] font-semibold text-primary-foreground">
                        AUTO
                      </span>
                    </div>
                  )}
                </div>

                {/* State info */}
                <div className="p-2">
                  <h4 className="text-xs font-semibold text-foreground mb-0.5">
                    {state.name}
                  </h4>
                  <p className="text-[9px] text-muted-foreground mb-1">
                    {state.timestamp}
                  </p>
                  <p className="text-[9px] text-primary truncate">
                    {state.progress}
                  </p>
                </div>

                {/* Hover overlay */}
                <div className="absolute inset-0 bg-gradient-to-t from-primary/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                  <Play className="w-8 h-8 text-white fill-white" />
                </div>
              </motion.div>
            ))}
          </div>
        </motion.div>

        {/* Settings Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.4 }}
          className="space-y-3"
        >
          <div className="flex items-center gap-2">
            <Settings className="w-4 h-4 text-primary" />
            <h2 className="text-base font-semibold text-foreground">Game Settings</h2>
          </div>

          {/* FPS Setting */}
          <div className="bg-card border border-border/50 rounded-xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center">
                  <Zap className="w-4 h-4 text-primary" />
                </div>
                <div>
                  <h3 className="text-sm font-semibold text-foreground">FPS Limit</h3>
                  <p className="text-xs text-muted-foreground">Frame rate control</p>
                </div>
              </div>
            </div>
            <div className="grid grid-cols-4 gap-2">
              {fpsOptions.map((fps) => (
                <button
                  key={fps}
                  onClick={() => setSelectedFps(fps)}
                  className={`px-3 py-2 rounded-lg text-xs font-medium transition-all ${
                    selectedFps === fps
                      ? "bg-primary text-primary-foreground"
                      : "bg-muted text-muted-foreground hover:bg-muted/80"
                  }`}
                >
                  {fps}
                </button>
              ))}
            </div>
          </div>

          {/* Language Setting */}
          <div className="bg-card border border-border/50 rounded-xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary/20 to-accent/20 flex items-center justify-center">
                  <Globe className="w-4 h-4 text-primary" />
                </div>
                <div>
                  <h3 className="text-sm font-semibold text-foreground">Language</h3>
                  <p className="text-xs text-muted-foreground">Game language</p>
                </div>
              </div>
            </div>
            <div className="space-y-2">
              {languageOptions.map((lang) => (
                <button
                  key={lang}
                  onClick={() => setSelectedLanguage(lang)}
                  className={`w-full px-3 py-2 rounded-lg text-sm font-medium text-left transition-all flex items-center justify-between ${
                    selectedLanguage === lang
                      ? "bg-primary/10 text-primary border border-primary/30"
                      : "bg-muted/50 text-foreground hover:bg-muted"
                  }`}
                >
                  {lang}
                  {selectedLanguage === lang && (
                    <div className="w-2 h-2 rounded-full bg-primary" />
                  )}
                </button>
              ))}
            </div>
          </div>
        </motion.div>

        {/* Cheat Codes Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.4, delay: 0.5 }}
          className="space-y-3"
        >
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Code className="w-4 h-4 text-primary" />
              <h2 className="text-base font-semibold text-foreground">Cheat Codes</h2>
            </div>
            <button className="text-xs text-primary hover:text-primary/80 transition-colors">
              Add New
            </button>
          </div>

          <div className="space-y-2">
            {cheatCodes.map((cheat, index) => (
              <motion.div
                key={cheat.code}
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ duration: 0.3, delay: 0.6 + index * 0.05 }}
                className="bg-card border border-border/50 rounded-xl p-3 flex items-center justify-between"
              >
                <div className="flex-1">
                  <h4 className="text-sm font-semibold text-foreground mb-0.5">
                    {cheat.name}
                  </h4>
                  <p className="text-xs text-muted-foreground font-mono">
                    {cheat.code}
                  </p>
                </div>
                <button
                  className={`w-10 h-6 rounded-full transition-all ${
                    cheat.enabled
                      ? "bg-primary"
                      : "bg-muted"
                  }`}
                >
                  <div
                    className={`w-4 h-4 rounded-full bg-white transition-transform ${
                      cheat.enabled ? "translate-x-5" : "translate-x-1"
                    }`}
                  />
                </button>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </main>
    </div>
  );
}
